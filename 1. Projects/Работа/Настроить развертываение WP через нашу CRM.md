Created: 08.03.2026 - 03:43
Related: - [[Arminlife]], [[CRM]]

---

## Notes

Был написан bash script для развертывания сайта на wordpress на сервере. 
Нужно его переписать под сервис на php и внедрить в CRM

```bash

cat << 'EOF' > install-wp.sh
#!/bin/bash
# ============================================================
#  WordPress Auto-Installer for HestiaCP
#
#  Usage:
#    bash install-wp.sh <domain> [options]
#
#  Options:
#    --source=repo     Clone from GitLab repo (default)
#    --source=clean    Install clean WordPress
#    --httpauth=on     Enable HTTP Basic Auth (admin/admin)
#    --httpauth=off    Disable HTTP Basic Auth
#
#  Examples:
#    bash install-wp.sh example.com
#    bash install-wp.sh example.com --source=clean --httpauth=on
#    bash install-wp.sh example.com --httpauth=off
# ============================================================

set -euo pipefail

# ──────────────────────────────────────────────
# PARSE ARGUMENTS
# ──────────────────────────────────────────────
if [[ -z "${1:-}" || "$1" == --* ]]; then
  echo "Usage: bash install-wp.sh <domain> [options]"
  echo ""
  echo "Options:"
  echo "  --source=repo     Clone WordPress with Mercury theme from GitLab (default)"
  echo "  --source=clean    Install clean WordPress with default theme"
  echo "  --httpauth=on     Enable HTTP Basic Auth (admin/admin)"
  echo "  --httpauth=off    Disable HTTP Basic Auth"
  echo ""
  echo "What the script does:"
  echo "  1. Adds domain to HestiaCP"
  echo "  2. Downloads WordPress core"
  echo "  3. Copies wp-content from GitLab repo (--source=repo) or keeps default (--source=clean)"
  echo "  4. Creates MySQL database"
  echo "  5. Generates wp-config.php"
  echo "  6. Installs WordPress (admin user: wpadmin)"
  echo "  7. Activates Mercury theme + ACF Pro + Mercury Addons (repo only)"
  echo "  8. Issues Let's Encrypt SSL (if DNS points to this server)"
  echo "  9. Configures HTTP Basic Auth (optional)"
  echo "  10. Sets PHP upload limit to 1024M"
  echo ""
  echo "  All steps are idempotent — safe to re-run."
  echo "  Credentials saved to /root/wp-credentials-<domain>.txt"
  echo ""
  echo "Examples:"
  echo "  bash install-wp.sh example.com                              # repo source, no auth"
  echo "  bash install-wp.sh example.com --source=clean               # clean WP, no auth"
  echo "  bash install-wp.sh example.com --source=repo --httpauth=on  # repo + basic auth"
  echo "  bash install-wp.sh example.com --httpauth=off               # disable auth on existing site"
  exit 1
fi
DOMAIN="$1"
WWW_DOMAIN="www.${DOMAIN}"
shift

# Defaults
WP_SOURCE="repo"
HTTPAUTH_ACTION=""

for arg in "$@"; do
  case "$arg" in
    --source=repo)   WP_SOURCE="repo" ;;
    --source=clean)  WP_SOURCE="clean" ;;
    --httpauth=on)   HTTPAUTH_ACTION="on" ;;
    --httpauth=off)  HTTPAUTH_ACTION="off" ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

# ──────────────────────────────────────────────
# CONFIG
# ──────────────────────────────────────────────
EMAIL="arminlife@developers.ninja"

# HestiaCP API
HESTIA_API="https://109.61.125.121:8083/api/"
HESTIA_ACCESS_KEY="ZaadObuGR7Pqa9ITdqr1"
HESTIA_SECRET_KEY="yCyXqO=tU1OnkiMJcOWEfYb6k=1Tp4RA03X=osmc"
HESTIA_USER="hestia"
SERVER_IP="109.61.125.121"

# GitLab
GITLAB_HOST="gitlab.1sx.biz"
GITLAB_REPO="arminlife/wordpress-zello"
GITLAB_TOKEN_USER="gitlab+deploy-token-59"
GITLAB_TOKEN="gldt-EwXpUZDwG1nKYyPiovvv"
GITLAB_BRANCH="main"
GITLAB_URL="https://${GITLAB_TOKEN_USER}:${GITLAB_TOKEN}@${GITLAB_HOST}/${GITLAB_REPO}.git"

# HTTP Auth
HTTPAUTH_USER="admin"
HTTPAUTH_PASS="admin"

# Paths
WEB_ROOT="/home/${HESTIA_USER}/web/${DOMAIN}/public_html"
LOG_FILE="/root/wp-install-${DOMAIN}.log"
RESULT_FILE="/root/wp-credentials-${DOMAIN}.txt"

# Plugins to activate after repo install
REPO_PLUGINS="advanced-custom-fields-pro mercury-addons"

# mu-plugins to remove (incompatible with WP 6.8+ password hashing)
REMOVE_MU_PLUGINS="wp-password-bcrypt.php"

# ──────────────────────────────────────────────
# GENERATE CREDENTIALS
# ──────────────────────────────────────────────
DB_NAME="wp_$(echo "$DOMAIN" | tr '.-' '_' | cut -c1-12)"
DB_USER="wp_$(openssl rand -hex 4)"
DB_PASS=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
WP_ADMIN_USER="wpadmin"
WP_ADMIN_PASS=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)

# ──────────────────────────────────────────────
# HELPERS
# ──────────────────────────────────────────────
log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()  { echo "  :white_check_mark: $*" | tee -a "$LOG_FILE"; }
err() { echo "  :x: $*" | tee -a "$LOG_FILE"; exit 1; }
warn(){ echo "  :warning:  $*" | tee -a "$LOG_FILE"; }

hestia_api() {
  local cmd="$1"
  shift
  local data="hash=${HESTIA_ACCESS_KEY}:${HESTIA_SECRET_KEY}&returncode=yes&cmd=${cmd}"
  for arg in "$@"; do
    data+="&${arg}"
  done
  curl -s -k -X POST "$HESTIA_API" -d "$data"
}

# ──────────────────────────────────────────────
# HTTPAUTH-ONLY MODE
# ──────────────────────────────────────────────
if [[ -n "$HTTPAUTH_ACTION" && -f "$WEB_ROOT/wp-login.php" ]]; then
  DOMAIN_CHECK=$(hestia_api "v-list-web-domain" "arg1=${HESTIA_USER}" "arg2=${DOMAIN}")
  if [[ "$DOMAIN_CHECK" != "0" ]]; then
    err "Domain ${DOMAIN} does not exist on this server"
  fi

  HTPASSWD_FILE="/home/${HESTIA_USER}/conf/web/${DOMAIN}/htpasswd"

  if [[ "$HTTPAUTH_ACTION" == "on" ]]; then
    if [[ -f "$HTPASSWD_FILE" ]]; then
      warn "HTTP Auth already enabled for ${DOMAIN}, skipping"
    else
      RESULT=$(hestia_api "v-add-web-domain-httpauth" \
        "arg1=${HESTIA_USER}" "arg2=${DOMAIN}" "arg3=${HTTPAUTH_USER}" "arg4=${HTTPAUTH_PASS}")
      if [[ "$RESULT" == "0" ]]; then
        ok "HTTP Auth ON for ${DOMAIN} (${HTTPAUTH_USER}:${HTTPAUTH_PASS})"
      else
        err "Failed to enable HTTP Auth (code: $RESULT)"
      fi
    fi
  elif [[ "$HTTPAUTH_ACTION" == "off" ]]; then
    if [[ ! -f "$HTPASSWD_FILE" ]]; then
      warn "HTTP Auth is not enabled for ${DOMAIN}, nothing to disable"
    else
      RESULT=$(hestia_api "v-delete-web-domain-httpauth" \
        "arg1=${HESTIA_USER}" "arg2=${DOMAIN}" "arg3=${HTTPAUTH_USER}")
      if [[ "$RESULT" == "0" ]]; then
        ok "HTTP Auth OFF for ${DOMAIN}"
      else
        err "Failed to disable HTTP Auth (code: $RESULT)"
      fi
    fi
  fi
  exit 0
fi

# ──────────────────────────────────────────────
echo "" | tee -a "$LOG_FILE"
log "============================================="
log " WordPress Installer — $(date)"
log " Domain  : $DOMAIN"
log " Source  : $WP_SOURCE"
log " Server  : $SERVER_IP"
log "============================================="

# ──────────────────────────────────────────────
# STEP 1 — Dependencies
# ──────────────────────────────────────────────
log "[1/10] Checking dependencies..."

for dep in curl git openssl; do
  if ! command -v "$dep" &>/dev/null; then
    err "Not found: $dep"
  fi
done

if ! command -v wp &>/dev/null; then
  log "  Installing WP-CLI..."
  curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x wp-cli.phar
  mv wp-cli.phar /usr/local/bin/wp
  ok "WP-CLI installed"
else
  ok "WP-CLI ready: $(wp --version --allow-root)"
fi

# ──────────────────────────────────────────────
# STEP 2 — API check
# ──────────────────────────────────────────────
log "[2/10] Checking HestiaCP API..."

API_CHECK=$(hestia_api "v-list-user" "arg1=${HESTIA_USER}")
if [[ "$API_CHECK" != "0" ]]; then
  err "HestiaCP API unavailable or invalid keys. Response: $API_CHECK"
fi
ok "HestiaCP API ok"

# ──────────────────────────────────────────────
# STEP 3 — Add domain
# ──────────────────────────────────────────────
log "[3/10] Adding domain $DOMAIN..."

DOMAIN_CHECK=$(hestia_api "v-list-web-domain" "arg1=${HESTIA_USER}" "arg2=${DOMAIN}")
if [[ "$DOMAIN_CHECK" == "0" ]]; then
  warn "Domain already exists, skipping"
else
  RESULT=$(hestia_api "v-add-web-domain" \
    "arg1=${HESTIA_USER}" "arg2=${DOMAIN}" "arg3=${SERVER_IP}")
  if [[ "$RESULT" != "0" ]]; then
    err "Failed to add domain. Code: $RESULT"
  fi
  ok "Domain $DOMAIN added"
fi

# ──────────────────────────────────────────────
# STEP 4 — WordPress core + source
# ──────────────────────────────────────────────
log "[4/10] Installing WordPress ($WP_SOURCE)..."

if [[ -f "$WEB_ROOT/wp-login.php" ]]; then
  warn "WordPress already downloaded, skipping"
else
  if [[ -d "$WEB_ROOT" ]]; then
    rm -rf "${WEB_ROOT:?}"/*
    rm -rf "${WEB_ROOT:?}"/.[!.]*  2>/dev/null || true
  fi
  mkdir -p "$WEB_ROOT"

  wp core download --path="$WEB_ROOT" --locale=en_US --allow-root 2>&1 | tee -a "$LOG_FILE"

  if [[ "$WP_SOURCE" == "repo" ]]; then
    TEMP_REPO="/tmp/wp-repo-${DOMAIN}"
    rm -rf "$TEMP_REPO"
    git clone --branch "$GITLAB_BRANCH" --depth 1 "$GITLAB_URL" "$TEMP_REPO" 2>&1 | tee -a "$LOG_FILE"

    if [[ -d "$TEMP_REPO/wp-content" ]]; then
      rm -rf "$WEB_ROOT/wp-content"
      cp -a "$TEMP_REPO/wp-content" "$WEB_ROOT/wp-content"
      ok "wp-content copied from repo"
    fi

    for f in php.ini .htaccess; do
      [[ -f "$TEMP_REPO/$f" ]] && cp "$TEMP_REPO/$f" "$WEB_ROOT/$f"
    done

    rm -rf "$TEMP_REPO"
  fi

  # Remove incompatible mu-plugins
  for muplugin in $REMOVE_MU_PLUGINS; do
    if [[ -f "$WEB_ROOT/wp-content/mu-plugins/$muplugin" ]]; then
      rm -f "$WEB_ROOT/wp-content/mu-plugins/$muplugin"
      ok "Removed incompatible mu-plugin: $muplugin"
    fi
  done

  if [[ ! -f "$WEB_ROOT/wp-login.php" ]]; then
    err "wp-login.php not found"
  fi
  ok "WordPress files ready ($WP_SOURCE)"
fi

# ──────────────────────────────────────────────
# STEP 5 — Database
# ──────────────────────────────────────────────
log "[5/10] Creating database..."

REAL_DB_NAME="${HESTIA_USER}_${DB_NAME}"
REAL_DB_USER="${HESTIA_USER}_${DB_USER}"

if [[ -f "$WEB_ROOT/wp-config.php" ]]; then
  EXISTING_DB_NAME=$(grep -oP "define\(\s*'DB_NAME'\s*,\s*'\K[^']+" "$WEB_ROOT/wp-config.php" || true)
  EXISTING_DB_USER=$(grep -oP "define\(\s*'DB_USER'\s*,\s*'\K[^']+" "$WEB_ROOT/wp-config.php" || true)
  EXISTING_DB_PASS=$(grep -oP "define\(\s*'DB_PASSWORD'\s*,\s*'\K[^']+" "$WEB_ROOT/wp-config.php" || true)
  if [[ -n "$EXISTING_DB_NAME" ]]; then
    REAL_DB_NAME="$EXISTING_DB_NAME"
    REAL_DB_USER="$EXISTING_DB_USER"
    DB_PASS="$EXISTING_DB_PASS"
    warn "Database already exists, using credentials from wp-config.php"
  fi
else
  RESULT=$(hestia_api "v-add-database" \
    "arg1=${HESTIA_USER}" "arg2=${DB_NAME}" "arg3=${DB_USER}" "arg4=${DB_PASS}" "arg5=mysql")

  if [[ "$RESULT" == "4" ]]; then
    warn "Database already exists, skipping"
  elif [[ "$RESULT" != "0" ]]; then
    err "Failed to create DB. Code: $RESULT"
  else
    ok "Database created: $REAL_DB_NAME"
  fi
fi

# ──────────────────────────────────────────────
# STEP 6 — wp-config.php
# ──────────────────────────────────────────────
log "[6/10] Creating wp-config.php..."

if [[ -f "$WEB_ROOT/wp-config.php" ]]; then
  warn "wp-config.php already exists, skipping"
else
  wp config create \
    --path="$WEB_ROOT" \
    --dbname="$REAL_DB_NAME" \
    --dbuser="$REAL_DB_USER" \
    --dbpass="$DB_PASS" \
    --dbhost="localhost" \
    --dbprefix="wp_" \
    --allow-root \
    2>&1 | tee -a "$LOG_FILE"

  wp config set WP_DEBUG false --raw --path="$WEB_ROOT" --allow-root
  wp config set WP_DEBUG_LOG false --raw --path="$WEB_ROOT" --allow-root
  wp config set DISALLOW_FILE_EDIT true --raw --path="$WEB_ROOT" --allow-root

  ok "wp-config.php created"
fi

# ──────────────────────────────────────────────
# STEP 7 — Install WordPress
# ──────────────────────────────────────────────
log "[7/10] Installing WordPress..."

if wp core is-installed --path="$WEB_ROOT" --allow-root 2>/dev/null; then
  warn "WordPress already installed, updating admin password"
  sudo -u "$HESTIA_USER" wp user update "$WP_ADMIN_USER" \
    --user_pass="$WP_ADMIN_PASS" \
    --path="$WEB_ROOT" 2>&1 | tee -a "$LOG_FILE"
  ok "Admin password updated"
else
  wp core install \
    --path="$WEB_ROOT" \
    --url="https://${DOMAIN}" \
    --title="${DOMAIN}" \
    --admin_user="$WP_ADMIN_USER" \
    --admin_password="$WP_ADMIN_PASS" \
    --admin_email="$EMAIL" \
    --skip-email \
    --allow-root \
    2>&1 | tee -a "$LOG_FILE"

  ok "WordPress installed"
fi

# ──────────────────────────────────────────────
# STEP 8 — Activate plugins (repo source only)
# ──────────────────────────────────────────────
log "[8/10] Activating theme and plugins..."

if [[ "$WP_SOURCE" == "repo" ]]; then
  # Activate theme
  REPO_THEME="mercury"
  CURRENT_THEME=$(sudo -u "$HESTIA_USER" wp theme list --status=active --field=name --path="$WEB_ROOT" 2>/dev/null || true)
  if [[ "$CURRENT_THEME" != "$REPO_THEME" ]]; then
    if sudo -u "$HESTIA_USER" wp theme is-installed "$REPO_THEME" --path="$WEB_ROOT" 2>/dev/null; then
      sudo -u "$HESTIA_USER" wp theme activate "$REPO_THEME" --path="$WEB_ROOT" 2>&1 | tee -a "$LOG_FILE"
      ok "Theme activated: $REPO_THEME"
    else
      warn "Theme $REPO_THEME not found, skipping"
    fi
  else
    warn "Theme $REPO_THEME already active"
  fi

  # Activate plugins
  for plugin in $REPO_PLUGINS; do
    if sudo -u "$HESTIA_USER" wp plugin is-installed "$plugin" --path="$WEB_ROOT" 2>/dev/null; then
      if ! sudo -u "$HESTIA_USER" wp plugin is-active "$plugin" --path="$WEB_ROOT" 2>/dev/null; then
        sudo -u "$HESTIA_USER" wp plugin activate "$plugin" --path="$WEB_ROOT" 2>&1 | tee -a "$LOG_FILE"
        ok "Activated: $plugin"
      else
        warn "$plugin already active"
      fi
    else
      warn "$plugin not found, skipping"
    fi
  done
else
  ok "Clean install, no theme/plugins to activate"
fi

# ──────────────────────────────────────────────
# STEP 9 — Let's Encrypt SSL
# ──────────────────────────────────────────────
log "[9/10] Let's Encrypt SSL..."

SSL_CONF="/home/${HESTIA_USER}/conf/web/${DOMAIN}/nginx.ssl.conf"

if [[ -f "$SSL_CONF" ]]; then
  warn "SSL already configured, skipping"
else
  RESULT=$(hestia_api "v-add-letsencrypt-domain" \
    "arg1=${HESTIA_USER}" "arg2=${DOMAIN}")

  if [[ "$RESULT" == "0" ]]; then
    ok "SSL certificate installed"
  else
    warn "SSL failed (code: $RESULT). DNS may not be pointing to this server yet."
  fi
fi

# ──────────────────────────────────────────────
# STEP 10 — HTTP Basic Auth
# ──────────────────────────────────────────────
log "[10/10] HTTP Basic Auth..."

HTPASSWD_FILE="/home/${HESTIA_USER}/conf/web/${DOMAIN}/htpasswd"

if [[ "$HTTPAUTH_ACTION" == "on" ]]; then
  if [[ -f "$HTPASSWD_FILE" ]]; then
    warn "HTTP Auth already enabled, skipping"
  else
    RESULT=$(hestia_api "v-add-web-domain-httpauth" \
      "arg1=${HESTIA_USER}" "arg2=${DOMAIN}" "arg3=${HTTPAUTH_USER}" "arg4=${HTTPAUTH_PASS}")
    if [[ "$RESULT" == "0" ]]; then
      ok "HTTP Auth ON (${HTTPAUTH_USER}:${HTTPAUTH_PASS})"
    else
      warn "HTTP Auth failed (code: $RESULT)"
    fi
  fi
elif [[ "$HTTPAUTH_ACTION" == "off" ]]; then
  if [[ ! -f "$HTPASSWD_FILE" ]]; then
    warn "HTTP Auth is not enabled, nothing to disable"
  else
    RESULT=$(hestia_api "v-delete-web-domain-httpauth" \
      "arg1=${HESTIA_USER}" "arg2=${DOMAIN}" "arg3=${HTTPAUTH_USER}")
    if [[ "$RESULT" == "0" ]]; then
      ok "HTTP Auth OFF"
    else
      warn "HTTP Auth disable failed (code: $RESULT)"
    fi
  fi
else
  ok "HTTP Auth skipped (use --httpauth=on or --httpauth=off)"
fi

# ──────────────────────────────────────────────
# PERMISSIONS
# ──────────────────────────────────────────────
find "$WEB_ROOT" -type d -exec chmod 755 {} \;
find "$WEB_ROOT" -type f -exec chmod 644 {} \;
chmod 600 "$WEB_ROOT/wp-config.php"
chown -R "${HESTIA_USER}:${HESTIA_USER}" "$WEB_ROOT"

# .htaccess git protection (idempotent)
if [[ -d "$WEB_ROOT/.git" ]]; then
  if ! grep -q 'RewriteRule \^\\\.git' "$WEB_ROOT/.htaccess" 2>/dev/null; then
    cat >> "$WEB_ROOT/.htaccess" <<'HTEOF'

<IfModule mod_rewrite.c>
RewriteRule ^\.git - [F,L]
</IfModule>
HTEOF
    ok ".htaccess git protection added"
  fi
fi

# ──────────────────────────────────────────────
# CLEANUP test files
# ──────────────────────────────────────────────
rm -f "$WEB_ROOT/phpver.php" "$WEB_ROOT/test-pass"*.php

# ──────────────────────────────────────────────
# RESULT
# ──────────────────────────────────────────────
HTTPAUTH_STATUS="disabled"
[[ -f "$HTPASSWD_FILE" ]] && HTTPAUTH_STATUS="${HTTPAUTH_USER}:${HTTPAUTH_PASS}"

cat > "$RESULT_FILE" <<EOF
=====================================================
  WordPress installed successfully!
  Date: $(date)
=====================================================

  Site:          https://${DOMAIN}
  Admin:         https://${DOMAIN}/wp-admin
  WP Login:      ${WP_ADMIN_USER}
  WP Password:   ${WP_ADMIN_PASS}
  Email:         ${EMAIL}
  Source:        ${WP_SOURCE}

-----------------------------------------------------
  Database:      ${REAL_DB_NAME}
  DB User:       ${REAL_DB_USER}
  DB Password:   ${DB_PASS}
  DB Host:       localhost
-----------------------------------------------------

  HTTP Auth:     ${HTTPAUTH_STATUS}
  Web Root:      ${WEB_ROOT}
  GitLab branch: ${GITLAB_BRANCH}
  Log:           ${LOG_FILE}
=====================================================
EOF

chmod 600 "$RESULT_FILE"
cat "$RESULT_FILE" | tee -a "$LOG_FILE"

log "Credentials saved: $RESULT_FILE"
EOF
```
