---
created: "11.03.2026 11:19"
tags:
  - work/project
related:
  - "[[CRM]]"
---

## Notes

Пример получения токена инфы для деплоя из crm

```bash
curl -H "X-API-LOGIN: api_user" -H "X-API-PASSWORD: pa3NQwAEHDXtRV" "https://scrm.1sx.biz/api/domains/cloudflare?domain=casinobossycz.com"

```

response example 

```json
{
  "account_id": "26e826dd283cb030d51ab8884fca3f15",
  "global_api_token": "f6d7fc53cb6ae9f5eb81c70e3030bf7206091",
  "account_api_token": "ywGPaBJanpMdM4Tnpyt30iD7zOlCvto1r6hag76_"
}

```

## Prompt

Сейчас, что бы задеплоить сайт с генератора используется отдельный сервис, мы туда отправляем инфу с архивом и он там себе работает. Но проблема в том, что он все эмулирует через хром и работает не стабильно, по этому я решил сделать весь деплой на нашей стороне. вот у меня есть базовый пример ![[cf-pages-deploy.sh]]
Нужно сделать из него класс сервис, с помощью которого будут деплоится сайты через джобу. Так же, если сайт отправляется на деплой повторно, но на CF pages уже сайт есть, то нужно удалить его от туда и загрузить снова. так же, учти, что у сайта есть папки со станицами, их в рулсы добавть тоже нужно. токен клауд флер и аккаунт id берется из нашей црм, вот пример запроса через curl

```bash
curl -H "X-API-LOGIN: api_user" -H "X-API-PASSWORD: pa3NQwAEHDXtRV" "https://scrm.1sx.biz/api/domains/cloudflare?domain=casinobossycz.com"

```

Естсвенно, после деплоя джоба должна обновлять статус таски