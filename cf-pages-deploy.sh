#!/bin/bash
# =============================================================================
# Cloudflare Pages — Direct Upload Deploy (без Wrangler)
# Использование: ./cf-pages-deploy.sh site.zip
# =============================================================================

set -euo pipefail

# ─── Настройки ────────────────────────────────────────────────────────────────
ACCOUNT_ID="ВАШ_ACCOUNT_ID"
API_TOKEN="ВАШ_API_TOKEN"
PROJECT_NAME="ВАШ_ПРОЕКТ"
BRANCH="main"

# ─── Цвета для вывода ─────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()     { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC}   $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERR]${NC}  $1" >&2; exit 1; }

# ─── Проверка аргументов ──────────────────────────────────────────────────────
ZIP_FILE="${1:-}"
[[ -z "$ZIP_FILE" ]]    && error "Укажите путь к ZIP-архиву: $0 site.zip"
[[ ! -f "$ZIP_FILE" ]]  && error "Файл не найден: $ZIP_FILE"

# ─── Проверка зависимостей ────────────────────────────────────────────────────
for cmd in curl unzip jq; do
    command -v "$cmd" &>/dev/null || error "Не установлен: $cmd"
done

BASE_URL="https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/pages/projects/${PROJECT_NAME}"
AUTH_HEADER="Authorization: Bearer ${API_TOKEN}"
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

# =============================================================================
# ШАГ 1 — Распаковать архив
# =============================================================================
log "Распаковка архива: $ZIP_FILE"
unzip -q "$ZIP_FILE" -d "$WORK_DIR"

# Убрать вложенную папку, если архив содержит одну корневую директорию
ITEMS=("$WORK_DIR"/*)
if [[ ${#ITEMS[@]} -eq 1 && -d "${ITEMS[0]}" ]]; then
    SITE_DIR="${ITEMS[0]}"
    warn "Обнаружена вложенная папка: $(basename "$SITE_DIR") — используется как корень"
else
    SITE_DIR="$WORK_DIR"
fi

FILE_COUNT=$(find "$SITE_DIR" -type f | wc -l | tr -d ' ')
success "Распаковано файлов: $FILE_COUNT"

# =============================================================================
# ШАГ 2 — Получить JWT-токен для загрузки
# Endpoint: POST /deployments  (без файлов — только инициализация)
# =============================================================================
log "Инициализация деплоя (получение upload JWT)..."

INIT_RESPONSE=$(curl -s -X POST \
    "${BASE_URL}/deployments" \
    -H "$AUTH_HEADER" \
    -F "manifest={}"
)

# Проверка ответа
SUCCESS=$(echo "$INIT_RESPONSE" | jq -r '.success')
[[ "$SUCCESS" != "true" ]] && {
    echo "$INIT_RESPONSE" | jq '.errors'
    error "Не удалось инициализировать деплой"
}

DEPLOYMENT_ID=$(echo "$INIT_RESPONSE"  | jq -r '.result.id')
JWT_TOKEN=$(echo "$INIT_RESPONSE"      | jq -r '.result.jwt')
UPLOAD_URL=$(echo "$INIT_RESPONSE"     | jq -r '.result.upload_url // empty')

success "Deployment ID: $DEPLOYMENT_ID"

# =============================================================================
# ШАГ 3 — Загрузить файлы
# Если upload_url пришёл — грузим туда, иначе — через /deployments с файлами
# =============================================================================

if [[ -n "$UPLOAD_URL" ]]; then
    # ── Вариант А: Bulk upload через upload_url ──────────────────────────────
    log "Загрузка файлов через upload_url..."

    # Собрать multipart аргументы
    CURL_ARGS=()
    while IFS= read -r -d '' FILE_PATH; do
        REL_PATH="${FILE_PATH#$SITE_DIR/}"
        CURL_ARGS+=(-F "file=@${FILE_PATH};filename=${REL_PATH}")
    done < <(find "$SITE_DIR" -type f -print0)

    UPLOAD_RESPONSE=$(curl -s -X POST \
        "$UPLOAD_URL" \
        -H "Authorization: Bearer ${JWT_TOKEN}" \
        "${CURL_ARGS[@]}"
    )

    UPLOAD_SUCCESS=$(echo "$UPLOAD_RESPONSE" | jq -r '.success // "true"')
    [[ "$UPLOAD_SUCCESS" == "false" ]] && {
        echo "$UPLOAD_RESPONSE" | jq '.errors'
        error "Ошибка загрузки файлов"
    }

    success "Файлы загружены"

    # ── Финализировать деплой ─────────────────────────────────────────────────
    log "Финализация деплоя..."

    FINAL_RESPONSE=$(curl -s -X PATCH \
        "${BASE_URL}/deployments/${DEPLOYMENT_ID}" \
        -H "$AUTH_HEADER" \
        -H "Content-Type: application/json" \
        -d "{\"branch\": \"${BRANCH}\"}"
    )

else
    # ── Вариант Б: Всё одним POST-запросом с файлами ─────────────────────────
    log "Загрузка всех файлов одним запросом..."

    CURL_ARGS=()
    while IFS= read -r -d '' FILE_PATH; do
        REL_PATH="${FILE_PATH#$SITE_DIR/}"
        CURL_ARGS+=(-F "files=@${FILE_PATH};filename=${REL_PATH}")
    done < <(find "$SITE_DIR" -type f -print0)

    FINAL_RESPONSE=$(curl -s -X POST \
        "${BASE_URL}/deployments" \
        -H "$AUTH_HEADER" \
        -F "branch=${BRANCH}" \
        "${CURL_ARGS[@]}"
    )
fi

# =============================================================================
# ШАГ 4 — Вывод результата
# =============================================================================
FINAL_SUCCESS=$(echo "$FINAL_RESPONSE" | jq -r '.success')

if [[ "$FINAL_SUCCESS" == "true" ]]; then
    DEPLOY_URL=$(echo "$FINAL_RESPONSE" | jq -r '.result.url // .result.deployment_trigger.metadata.commit_hash // "—"')
    ALIASES=$(echo "$FINAL_RESPONSE"    | jq -r '.result.aliases[]? // empty' | head -1)

    echo ""
    success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    success "  Деплой успешен!"
    success "  Deployment ID : $DEPLOYMENT_ID"
    success "  URL           : ${ALIASES:-$DEPLOY_URL}"
    success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo "$FINAL_RESPONSE" | jq '.errors'
    error "Деплой завершился с ошибкой"
fi
