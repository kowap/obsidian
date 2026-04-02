---
created: 02.04.2026 23:21
tags:
  - daily
related:
  - "[[CRM]]"
---
## Передумови

- Акаунт на [bunny.net](https://vault.bitwarden.com/#/vault?search=bunny&itemId=00b8f550-af97-4067-be8f-b42001047912&action=view)
- Домен зареєстрований на Namecheap (або іншому реєстраторі)
- Файли статичного сайту готові до завантаження
- FTP клієнт (FileZilla або інший)

---
## Крок 1 — Створити Storage Zone

Йди в **Storage → Add Storage Zone**

- **Storage zone name** — назва без крапок, тільки літери/цифри/дефіси. Для домену `mysite.com` пиши `mysite-com`
- **Storage tier** — Standard 
- **Main region** — Frankfurt (DE) для EU 

Клікай **Add Storage Zone**.

---
## Крок 2 — Завантажити файли через FTP

Йди в **Storage → твоя зона → FTP & API Access** (там доступи до FTP)

---
## Крок 3 — Створити Pull Zone

Йди в **CDN → Add Pull Zone**

- **Name** — `mysite-com`
- **Origin type** → вибери **Storage Zone**
- **Storage zone** → вибери щойно створену зону

Клікай **Add Pull Zone**.

---
## Крок 4 — Додати DNS зону в Bunny

Йди в **DNS → Add DNS Zone**

- Вводь свій домен `mysite.com`
- Вибирай **Auto-import or add manually**
- На Step 2 — видали всі імпортовані A і AAAA записи якщо вони вказують на старий хостинг
- Клікай **Confirm and Add**

На **Step 3** (Finish) побачиш NS сервери:

```
kiki.bunny.net
coco.bunny.net
```

(можливо на новому акаунті будуть інши NS)

---
## Крок 5 — Виправити DNS записи

Після створення зони йди в **DNS → mysite.com → DNS records**

Видали всі старі A і AAAA записи. Додай новий:

- **Type** — CNAME
- **Hostname** — порожнє (root `@`)
- **Target** — `mysite-com.b-cdn.net`

Клікай **Add Record**.

---
## Крок 6 — Перевірити Origin

Йди в **CDN → mysite-com → General → Origin**

Переконайся що:
- **Origin type** — Storage Zone (не Origin URL!)
- **Storage zone** — твоя зона

Якщо ні — переключи і клікай **Save Origin**.

---
## Крок 7 — Налаштувати редірект /play → wliny.com

Йди в **CDN → mysite-com → Edge rules → Add Edge Rule**

Заповни форму:

**Description:**
```
Redirect play to external site
```

**Action:**
- Тип → **Redirect**
- Redirect URL → `https://wliny.com`
- Status Code → **301 - Default**

**Conditions:**
- Request URL → `*/play*`

Клікай **Save Edge Rule**.

Wildcard `*/play*` покриває всі варіанти: `/play`, `/play?`, `/play?utm_source=xxx` тощо.