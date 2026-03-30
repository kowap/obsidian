---
tags:
  - work/area
  - work/docs
  - work/ip
related:
  - "[[Trafbrazza]]"
---
ip нового сервака 159.65.195.39
на всякий случай еще 178.62.226.221

CRM IP's
159.65.195.39
178.62.226.221

Jenkins
51.89.60.252

## Зміст
  
1. [Загальний опис](#загальний-опис)  
2. [Технологічний стек](#технологічний-стек)  
3. [Архітектура проєкту](#архітектура-проєкту)  
4. [Модулі системи](#модулі-системи)  
   - [DomainManager — Управління доменами](#1-domainmanager--управління-доменами)  
   - [Generator — AI-генерація контенту](#2-generator--ai-генерація-контенту)  
   - [Analytics — Аналітика та статистика](#3-analytics--аналітика-та-статистика)  
   - [Media — Медіа-менеджер](#4-media--медіа-менеджер)  
   - [TaskManager — Управління задачами](#5-taskmanager--управління-задачами)  
   - [UserManager — Управління користувачами](#6-usermanager--управління-користувачами)  
   - [Shared — Спільні компоненти](#7-shared--спільні-компоненти)  
5. [Система прав доступу](#система-прав-доступу)  
6. [Реальний час (WebSocket)](#реальний-час-websocket)  
7. [Фонові задачі та черги](#фонові-задачі-та-черги)  
8. [База даних](#база-даних)  
9. [Фронтенд](#фронтенд)  
10. [Тестування](#тестування)  
11. [DevOps та деплой](#devops-та-деплой)  
12. [Налаштування та запуск](#налаштування-та-запуск)  
  
---  
  
## Загальний опис  
  
**v3-crm** — це внутрішня CRM-система, побудована на Laravel 12, яка автоматизує повний цикл роботи з доменами: від пошуку та купівлі через реєстраторів, до генерації контенту за допомогою AI, аналітики трафіку та управління задачами.  
  
Система складається з 7 модулів, кожен з яких відповідає за окрему бізнес-функцію. Доступ до модулів контролюється через гнучку систему прав на рівні користувачів.  
  
**Продакшн URL:** `https://scrm.1sx.biz`  
**Репозиторій:** `gitlab.1sx.biz:generator/v3-crm`  
  
---  
  
## Технологічний стек  
  
### Backend  
  
| Технологія | Версія | Призначення |  
|---|---|---|  
| PHP | 8.4 | Мова програмування |  
| Laravel | 12 | Основний фреймворк |  
| Livewire | 3 | Реактивні компоненти без JS |  
| MySQL | 8.0 | Основна база даних |  
| Redis | 7 | Черги, кеш |  
| PHPUnit | 11 | Тестування |  
  
### Frontend  
  
| Технологія | Версія | Призначення |  
|---|---|---|  
| Alpine.js | 3 | Легкий JS-фреймворк (вбудований в Livewire) |  
| Tailwind CSS | 3 | CSS-фреймворк |  
| Vite | 7 | Збірка фронтенду |  
| ApexCharts | — | Графіки та діаграми |  
| Monaco Editor | — | Редактор коду для промптів |  
| Flowbite | — | UI-компоненти на базі Tailwind |  
| Laravel Echo + Pusher | — | WebSocket-клієнт |  
  
### Зовнішні API та інтеграції  
  
| Сервіс | Призначення |  
|---|---|  
| OpenAI (GPT, DALL-E) | Генерація тексту та зображень |  
| Anthropic (Claude) | Генерація тексту |  
| Namecheap API | Реєстрація доменів |  
| Dynadot API | Реєстрація доменів |  
| Ilkari API | Реєстрація доменів (внутрішній SDK) |  
| Cloudflare API | DNS-управління (через внутрішній Jenkins API) |  
| Keitaro API | Трекер трафіку та конверсій |  
| BunnyCDN | Хмарне сховище медіафайлів |  
| TinyPNG (Tinify) | Оптимізація зображень |  
| SlotsLaunch API | Синхронізація ігрових даних |  
| Google Sheets | Інтеграція з таблицями |  
  
---  
  
## Архітектура проєкту  
  
### Структура директорій  
  
```  
app/  
├── Console/Commands/       # Artisan-команди  
├── Http/                   # Базові контролери, middleware  
├── Listeners/              # Слухачі подій черг  
├── Modules/                # *** ОСНОВНА БІЗНЕС-ЛОГІКА ***  
│   ├── Analytics/          # Аналітика  
│   ├── DomainManager/      # Управління доменами  
│   ├── Generator/          # AI-генерація  
│   ├── Media/              # Медіа-файли  
│   ├── Shared/             # Спільні компоненти  
│   ├── TaskManager/        # Задачі  
│   └── UserManager/        # Користувачі  
├── Providers/              # Сервіс-провайдери  
└── View/                   # Компоненти Blade  
```  
  
### Архітектурні патерни  
  
Кожен модуль дотримується чіткої шарової архітектури:  
  
```  
Controller → Action → Service → Repository → Model  
```  
  
1. **Repository Pattern** — вся взаємодія з БД через інтерфейси репозиторіїв. Інтерфейси в `Eloquent/Interfaces/`, реалізації в `Eloquent/Repositories/`. Прив'язки реєструються в `AppServiceProvider::register()`.  
  
2. **Action Pattern** — одноцільові класи-дії для create/update операцій. Кожен Action — це інвокабельний клас з одним методом `__invoke()`.  
  
3. **Service Layer** — сервіси оркеструють репозиторії та містять бізнес-логіку. Контролери ніколи не працюють з репозиторіями напряму.  
  
4. **Observer Pattern** — обсервери моделей автоматично заповнюють поля `created_by` / `updated_by`.  
  
5. **Factory Pattern** — `RegistrarFactory` створює адаптери для різних доменних реєстраторів.  
  
6. **DTO Pattern** — Data Transfer Objects для API-запитів та відповідей.  
  
7. **Enum Convention** — backed enums з методами `label()`, `options()`, і часто `color()`.  
  
---  
  
## Модулі системи  
  
### 1. DomainManager — Управління доменами  
  
**Розташування:** `app/Modules/DomainManager/`  
**Middleware:** `module:1`  
**Маршрутний префікс:** `/domain/`  
  
Найбільший модуль системи. Відповідає за повний цикл роботи з доменами.  
  
#### Що робить  
  
- **Пошук та купівля доменів** через кілька реєстраторів (Namecheap, Dynadot, Ilkari)  
- **Синхронізація** списку доменів з акаунтів реєстраторів  
- **Кошик покупок** — масова купівля доменів з відстеженням статусу в реальному часі  
- **Cloudflare інтеграція** — синхронізація DNS-зон, акаунтів CF  
- **Тегування** — створення тегів та масове призначення доменам  
- **Кампанії Keitaro** — прив'язка доменів до рекламних кампаній  
- **Колекції** — групування доменів з кастомними атрибутами (текст, чекбокс, число, селект, дата)  
- **Моніторинг продовження** — відстеження доменів, що потребують продовження  
- **Історія покупок** — перегляд усіх минулих покупок  
  
#### Моделі  
  
| Модель | Таблиця | Опис |  
|---|---|---|  
| `Domain` | `domains` | Основна модель домену (ім'я, дати реєстрації/закінчення, статус, зв'язки з акаунтом, кампанією, брендом) |  
| `DomainAccounts` | `domain_accounts` | Акаунти реєстраторів (API-ключі, баланс, тип реєстратора) |  
| `DomainTag` | `domain_tags` | Теги для доменів |  
| `Basket` | `baskets` | Кошик покупок (InProgress, Completed, Failed, Pending) |  
| `BasketDomain` | `basket_domains` | Домени в кошику |  
| `Collection` | `collections` | Колекції доменів |  
| `CollectionAttribute` | `collection_attributes` | Кастомні атрибути колекцій |  
| `KeitaroCampaign` | `keitaro_campaigns` | Кампанії Keitaro (з сортуванням) |  
| `DomainCloudflareAccount` | `domain_cloudflare_accounts` | Дані Cloudflare для домену |  
  
#### Реєстратори  
  
Система підтримує три реєстратори через патерн Factory. Всі реалізують `RegistrarInterface`:  
  
```php  
interface RegistrarInterface {  
    public function syncBalance(): float;     // Синхронізація балансу  
    public function listDomains(): array;     // Список доменів  
    public function findDomain(string $domain): SearchDomainDTO; // Пошук домену  
    public function buy(string $domain): string|bool; // Купівля  
}  
```  
  
- **Namecheap** — через пакет `kowap/namecheap-php`  
- **Dynadot** — через пакет `level23/dynadot-api`  
- **Ilkari** — через власний PHP SDK (`Services/Custom/Ilkari/`)  
  
#### Фонові задачі  
  
| Задача | Розклад | Опис |  
|---|---|---|  
| `BuyDomainJob` | За запитом | Купівля домену з кошика, broadcasting прогресу |  
| `SyncDomainRegistratorJob` | За запитом | Синхронізація доменів з API реєстратора |  
| `SyncCloudflareApiDomainJob` | Щодня о 03:00 | Синхронізація Cloudflare акаунтів |  
| `AddZonesFromBasketJob` | За запитом | Додавання CF-зон для куплених доменів |  
| `CheckPendingDomainsJob` | Кожні 2 хв | Перевірка статусу очікуючих покупок |  
  
#### Livewire-компоненти  
  
- **ListDomains** — список доменів з пошуком, фільтрами (акаунт, тег, кампанія, статус закінчення, блокування, діапазон дат), сортуванням, масовим призначенням тегів/кампаній  
- **DomainModal** — модальне вікно з деталями домену  
- **NeedRenewal** — домени, що потребують продовження  
- **ListTags** — управління тегами  
- **ListKeitaroCampaigns** — управління кампаніями  
- **ListCollections** — управління колекціями  
  
#### Сторінки (URL)  
  
| URL | Опис |  
|---|---|  
| `/domain/list` | Список доменів з фільтрацією |  
| `/domain/registrators` | CRUD акаунтів реєстраторів |  
| `/domain/buy` | Купівля доменів |  
| `/domain/tags` | Управління тегами |  
| `/domain/keitaro-campaigns` | Управління кампаніями Keitaro |  
| `/domain/basket/{basket}` | Перегляд кошика покупок |  
| `/domain/purchase-history` | Історія покупок |  
| `/domain/collections` | Колекції доменів |  
| `/domain/need-renewal` | Домени для продовження |  
  
#### Як користуватися  
  
1. **Додати акаунт реєстратора:** `/domain/registrators` → «Додати» → вказати тип (Namecheap/Dynadot/Ilkari), API-ключі, email  
2. **Синхронізувати домени:** на сторінці акаунту натиснути «Sync» — запуститься `SyncDomainRegistratorJob`  
3. **Купити домен:** `/domain/buy` → ввести доменне ім'я → обрати акаунт → додати в кошик → підтвердити покупку. Прогрес відображається в реальному часі через WebSocket  
4. **Тегування:** `/domain/tags` → створити теги → на сторінці доменів обрати домени → масово призначити теги  
5. **Колекції:** `/domain/collections` → створити колекцію → додати кастомні атрибути → додати домени  
  
---  
  
### 2. Generator — AI-генерація контенту  
  
**Розташування:** `app/Modules/Generator/`  
**Middleware:** `module:3`  
**Маршрутний префікс:** `/generator/`  
  
Система генерації контенту через AI-моделі OpenAI та Anthropic.  
  
#### Що робить  
  
- **Управління промптами** — створення, редагування, групування, сортування шаблонів промптів  
- **Генерація тексту** — через GPT-4o, GPT-4.1, GPT-5, Claude Opus 4, Claude Sonnet 4, Claude Haiku 3.5  
- **Генерація зображень** — через DALL-E 2, DALL-E 3, GPT-image-1  
- **Ігрові пресети** — управління пресетами ігор (SlotsLaunch)  
- **Налаштування API** — зберігання ключів OpenAI та Anthropic  
  
#### Моделі  
  
| Модель | Таблиця | Опис |  
|---|---|---|  
| `GeneratorPrompt` | `generator_prompts` | Шаблон промпту (назва, тип, модель, JSON-контент, порядок) |  
| `GeneratorPromptGroup` | `generator_prompt_groups` | Група промптів |  
| `SlotsLaunchGame` | `slots_launch_games` | Ігрові дані |  
| `SlotsLaunchGamePreset` | `slots_launch_game_presets` | Пресети ігор |  
| `SlotsLaunchProvider` | `slots_launch_providers` | Провайдери ігор |  
| `SlotsLaunchType` | `slots_launch_types` | Типи ігор |  
| `SlotsLaunchTheme` | `slots_launch_themes` | Теми ігор |  
  
#### Типи промптів (GeneratorPromptType)  
  
| Значення | Тип | Опис |  
|---|---|---|  
| 0 | System | Системний промпт |  
| 1 | SEO | SEO-оптимізований контент |  
| 2 | Hero | Hero-секція |  
| 3 | Article | Стаття |  
| 4 | FAQ | Питання та відповіді |  
| 5 | Call to Action | Заклик до дії |  
| 6 | Section | Довільна секція |  
| 7 | Demo | Демо-контент |  
| 8 | Reviews | Огляди/відгуки |  
| 9 | Offer List | Список пропозицій |  
| 10 | Author | Біографія автора |  
  
#### Підтримувані AI-моделі (GeneratorPromptModel)  
  
**Текст:** GPT-4o, GPT-4o-mini, GPT-4.1, GPT-4.1-mini, GPT-3.5, GPT-5-search-api, Claude Opus 4, Claude Sonnet 4, Claude Haiku 3.5  
  
**Зображення:** DALL-E 2, DALL-E 3, GPT-image-1  
  
#### Ключовий сервіс — AiGeneratorService  
  
```  
generateFromPrompt()     — генерація з збереженого шаблону  
generate()               — пряма генерація тексту (маршрутизація OpenAI / Anthropic за моделлю)  
generateImageFromPrompt() — генерація зображення з промпту  
generateImage()          — пряма генерація зображення  
quickGenerate()          — спрощена генерація (рядок → рядок)  
quickGenerateImage()     — спрощена генерація зображення  
```  
  
#### Налаштування (Spatie Settings)  
  
Зберігаються в БД через `GeneralSettings`:  
- `allowed_languages` — дозволені мови для генерації  
- `open_ai_api_key` — ключ API OpenAI  
- `open_ai_project_id` — ID проєкту OpenAI  
- `anthropic_api_key` — ключ API Anthropic  
  
#### Сторінки (URL)  
  
| URL | Опис |  
|---|---|  
| `/generator` | Головна сторінка генератора |  
| `/generator/prompts` | Список промптів (CRUD, drag-and-drop сортування) |  
| `/generator/prompts/group` | Групи промптів |  
| `/generator/settings/ai` | Налаштування API-ключів |  
| `/generator/settings/game-presets` | Ігрові пресети |  
| `/generator/media` | Медіа-браузер в контексті генератора |  
  
#### Як користуватися  
  
1. **Налаштувати API:** `/generator/settings/ai` → ввести ключі OpenAI / Anthropic  
2. **Створити групу промптів:** `/generator/prompts/group` → «Створити»  
3. **Створити промпт:** `/generator/prompts` → «Створити» → обрати тип, модель, групу → написати JSON-промпт у Monaco-редакторі  
4. **Генерувати контент:** використовувати промпт на головній сторінці генератора  
5. **Сортування:** перетягнути промпти для зміни порядку (drag-and-drop)  
  
---  
  
### 3. Analytics — Аналітика та статистика  
  
**Розташування:** `app/Modules/Analytics/`  
**Middleware:** `module:4`  
**Маршрутний префікс:** `/analytics/`  
  
Модуль для відстеження кліків, конверсій та статистики трафіку.  
  
#### Що робить  
  
- **Трекінг кліків** — запис кліків по доменах з IP-адресами  
- **Синхронізація з Keitaro** — автоматичне підтягування статистики кліків та лідів з трекера  
- **Аналітичні дашборди** — графіки та таблиці статистики (ApexCharts)  
- **Milestones** — відстеження досягнень доменів  
  
#### Моделі  
  
| Модель | Таблиця | Опис |  
|---|---|---|  
| `DomainClick` | `domain_clicks` | Запис кліку (домен, кампанія, IP, час) |  
| `KeitaroClickStat` | `keitaro_click_stats` | Синхронізована статистика кліків з Keitaro |  
| `KeitaroLead` | `keitaro_leads` | Конверсії/ліди з Keitaro |  
  
#### Інтеграція з Keitaro  
  
**KeitaroClient** — HTTP-клієнт для Keitaro Admin API v1:  
- `getCampaigns()` — отримати список кампаній  
- `buildReport()` — побудувати звіт  
- `getConversions()` — отримати конверсії  
  
**KeitaroSyncService** — сервіс синхронізації:  
- `syncClickStats()` — синхронізація кліків (дедуплікація за click_id, денні чанки)  
- `syncLeads()` — синхронізація конверсій з пагінацією  
  
#### Фонові задачі  
  
| Задача | Розклад | Опис |  
|---|---|---|  
| `SyncKeitaroStatsJob` | Кожні 35 хв | Синхронізація кліків та лідів з Keitaro |  
  
#### Сторінки (URL)  
  
| URL | Опис |  
|---|---|  
| `/analytics/click-logs` | Журнал кліків з фільтрацією |  
| `/analytics/keitaro-stats` | Дашборд статистики Keitaro (графіки) |  
| `/analytics/domain-milestones` | Milestones доменів |  
  
#### Як користуватися  
  
1. **Налаштувати Keitaro:** в `.env` вказати `KEITARO_URL` та `KEITARO_API_KEY`  
2. **Синхронізація** відбувається автоматично кожні 35 хвилин  
3. **Перегляд статистики:** `/analytics/keitaro-stats` — графіки, фільтри за датами, кампаніями  
4. **Журнал кліків:** `/analytics/click-logs` — деталізація по кожному кліку  
  
#### Зовнішній API для запису кліків  
  
```  
GET /api/domains/click?domain=example.com&campaign_id=1&ip=1.2.3.4  
```  
  
Публічний ендпоінт для запису кліків з зовнішніх джерел.  
  
---  
  
### 4. Media — Медіа-менеджер  
  
**Розташування:** `app/Modules/Media/`  
**Маршрутний префікс:** `/generator/media`  
  
Файловий менеджер з підтримкою хмарного сховища BunnyCDN.  
  
#### Що робить  
  
- **Завантаження файлів** з автоматичною конвертацією в WebP  
- **Оптимізація зображень** через TinyPNG  
- **Генерація мініатюр** (200x200)  
- **Папки та навігація** — ієрархічна структура з хлібними крихтами  
- **Хмарне сховище** — підтримка BunnyCDN як альтернатива локальному сховищу  
  
#### Моделі  
  
| Модель | Таблиця | Опис |  
|---|---|---|  
| `MediaFile` | `media_files` | Файл (ім'я, шлях, MIME, розмір, розміри, мініатюра, alt) |  
| `MediaFolder` | `media_folders` | Папка (назва, батьківська папка) |  
  
#### Автоматична обробка при завантаженні  
  
1. **Конвертація в WebP** — JPEG, PNG, GIF, BMP автоматично конвертуються в WebP з якістю 85%  
2. **Оптимізація TinyPNG** — якщо налаштовано API-ключ Tinify  
3. **Мініатюра** — створюється зменшена копія 200x200 в `.thumbnails/`  
4. **Метадані** — зберігаються розміри (width/height), MIME-тип, розмір файлу  
  
#### Сховище  
  
Визначається змінною `MEDIA_DISK_DRIVER`:  
- `local` — `storage/app/public/media/`  
- `bunny` — BunnyCDN (потрібні: `BUNNY_STORAGE_ZONE`, `BUNNY_API_KEY`, `BUNNY_REGION`)  
  
#### Livewire-компоненти  
  
- **MediaBrowser** — повноцінний файловий браузер з навігацією по папках  
- **MediaUploader** — компонент завантаження файлів  
- **MediaPicker** — вбудовуваний вибір файлів (для форм)  
- **MediaPreview** — попередній перегляд файлів  
  
#### Як користуватися  
  
1. **Перейти:** `/generator/media`  
2. **Створити папку:** кнопка «New Folder»  
3. **Завантажити файл:** drag-and-drop або кнопка завантаження  
4. **Навігація:** клік на папку → перехід, хлібні крихти для повернення  
5. **Інтеграція:** в інших модулях файли обираються через MediaPicker  
  
---  
  
### 5. TaskManager — Управління задачами  
  
**Розташування:** `app/Modules/TaskManager/`  
**Middleware:** `module:5`  
**Маршрутний префікс:** `/tasks`, `/brands`, `/default-pages`  
  
Модуль управління задачами для доменних робочих процесів.  
  
#### Що робить  
  
- **Задачі** — створення та відстеження задач з прив'язкою до доменів, брендів, мов  
- **Бренди** — управління брендами (Casino, Game), масове додавання  
- **Default Pages** — шаблони сторінок за замовчуванням (з drag-and-drop сортуванням)  
- **Sidebar** — швидке редагування задачі в бічній панелі  
  
#### Моделі  
  
| Модель | Таблиця | Опис |  
|---|---|---|  
| `Task` | `tasks` | Задача (домен, локаль, виконавець, статус, дедлайн, бренд, тип генератора, нотатки) |  
| `Brand` | `brands` | Бренд (назва, slug, тип, is_abused) |  
| `DefaultPage` | `default_pages` | Шаблон сторінки (назва, enabled_by_default, disabled, порядок) |  
  
#### Статуси задач (TaskStatus)  
  
| Значення | Статус | Колір |  
|---|---|---|  
| 1 | New | Синій |  
| 2 | In Progress | Жовтий |  
| 3 | Review | Фіолетовий |  
| 4 | Done | Зелений |  
  
#### Типи брендів (BrandType)  
  
| Значення | Тип | Колір |  
|---|---|---|  
| 1 | Casino | Червоний |  
| 2 | Game | Зелений |  
  
#### Типи генератора (GeneratorType)  
  
| Значення | Тип | Колір |  
|---|---|---|  
| 1 | Affbulk | Синій |  
| 2 | Self | Зелений |  
  
#### Поля задачі  
  
- **Домен** — обирається через автокомпліт (Livewire DomainSearch)  
- **CF API Token** — токен Cloudflare для домену  
- **Основна локаль** — мова сайту (через LocaleSearch)  
- **Додаткові локалі** — багато-до-багатьох зв'язок  
- **Default Pages** — вибір шаблонних сторінок з можливістю вказати ключові слова для кожної  
- **Бренд** — прив'язка до бренду (через BrandSearch)  
- **Тип генератора** — Affbulk або Self  
- **Виконавець** — хто відповідає за задачу  
- **Статус** — New → In Progress → Review → Done  
- **Дедлайн** — дата виконання  
- **Нотатки** — вільний текст  
  
#### Сторінки (URL)  
  
| URL | Опис |  
|---|---|  
| `/tasks` | Список задач з пошуком, фільтрами (статус, виконавець), пагінацією |  
| `/tasks/create` | Створення задачі |  
| `/tasks/{task}/edit` | Редагування задачі |  
| `/brands` | Список брендів |  
| `/brands/create` | Створення бренду |  
| `/brands/{brand}/edit` | Редагування бренду |  
| `/default-pages` | Управління шаблонами сторінок |  
  
#### Livewire-компоненти  
  
- **ListTasks** — таблиця задач з фільтрами та пагінацією  
- **TaskSidebar** — бічна панель швидкого редагування задачі  
- **ListBrands** — таблиця брендів з пошуком та фільтром за типом  
- **BulkAddBrands** — масове додавання брендів  
- **BrandSearch** — автокомпліт пошуку брендів  
- **ListDefaultPages** — список шаблонних сторінок з drag-and-drop  
  
#### Як користуватися  
  
1. **Створити бренд:** `/brands` → «Add Brand» → вказати назву, slug, тип (Casino/Game)  
2. **Масове додавання брендів:** «Bulk Add» → вставити список назв  
3. **Налаштувати default pages:** `/default-pages` → створити шаблони, перетягнути для сортування  
4. **Створити задачу:** `/tasks/create` → обрати домен → обрати локалі, сторінки, бренд → призначити виконавця → встановити дедлайн  
5. **Швидке редагування:** на списку задач клікнути на задачу → відкриється sidebar  
  
---  
  
### 6. UserManager — Управління користувачами  
  
**Розташування:** `app/Modules/UserManager/`  
**Middleware:** `module:2`  
**Маршрутний префікс:** `/users`  
  
Управління обліковими записами та правами доступу.  
  
#### Що робить  
  
- **CRUD користувачів** — створення, редагування, зміна статусу  
- **Модульний доступ** — налаштування доступу до модулів системи  
- **Доступ до акаунтів доменів** — гранулярні права на операції з доменами  
  
#### Система модулів (Module Enum)  
  
| Значення | Модуль | Опис |  
|---|---|---|  
| 1 | Domains | Управління доменами |  
| 2 | Users | Управління користувачами |  
| 3 | Generator | AI-генерація |  
| 4 | Analytics | Аналітика |  
| 5 | TaskManager | Задачі |  
  
#### Права доступу до акаунтів доменів  
  
Для кожного акаунту реєстратора можна налаштувати:  
  
| Право | Опис |  
|---|---|  
| `can_view` | Перегляд доменів акаунту |  
| `can_buy` | Купівля доменів |  
| `can_renew` | Продовження доменів |  
| `can_transfer` | Трансфер доменів |  
| `can_manage_dns` | Управління DNS |  
| `can_view_balance` | Перегляд балансу акаунту |  
  
**Спеціальні прапорці:**  
- `is_root` — повний доступ до всього (обхід усіх перевірок)  
- `domain_access_all` — повний доступ до всіх акаунтів доменів  
  
#### Статуси користувачів  
  
| Значення | Статус |  
|---|---|  
| 0 | Inactive |  
| 1 | Active |  
| 2 | Blocked |  
  
#### Сторінки (URL)  
  
| URL | Опис |  
|---|---|  
| `/users` | Список користувачів |  
| `/users/add` | Створення користувача |  
| `/users/{user}/edit` | Редагування користувача |  
| `/users/{user}/domain-accounts-access` | Налаштування доступу до акаунтів доменів |  
  
#### Як користуватися  
  
1. **Створити користувача:** `/users/add` → заповнити ім'я, email, пароль → обрати модулі доступу  
2. **Налаштувати доступ до модулів:** на сторінці редагування користувача обрати чекбокси модулів  
3. **Налаштувати доступ до доменів:** `/users/{user}/domain-accounts-access` → для кожного акаунту реєстратора встановити гранулярні права  
  
> **Важливо:** Реєстрація нових користувачів через форму логіну вимкнена. Нові акаунти створюються тільки адміністраторами.  
  
---  
  
### 7. Shared — Спільні компоненти  
  
**Розташування:** `app/Modules/Shared/`  
  
Модуль з компонентами, які використовуються в інших модулях.  
  
#### Моделі  
  
| Модель | Таблиця | Опис |  
|---|---|---|  
| `User` | `users` | Модель користувача (статус, root-перевірки, доступ до модулів) |  
| `Locale` | `locales` | Мови/країни/валюти (ISO-коди, прапорці, TLD, континенти) |  
| `JobLog` | `job_logs` | Логування виконання фонових задач |  
  
#### Система трекінгу задач (TrackableJob)  
  
Трейт `TrackableJob` автоматизує логування фонових задач:  
  
1. Створює запис `JobLog` при старті задачі  
2. Відслідковує стани: `pending` → `running` → `completed` / `failed`  
3. Broadcasting оновлень через WebSocket на канал `job-logs`  
4. Автоматичний збір метаданих через рефлексію  
  
`JobEventSubscriber` слухає Laravel-події черг і автоматично оновлює логи.  
  
#### Livewire-компоненти  
  
- **DomainSearch** — автокомпліт пошуку доменів (використовується у формі задач)  
- **LocaleSearch** — автокомпліт пошуку локалей  
  
#### Інші сервіси  
  
- **JenkinsCloudflareApi** — HTTP-клієнт для внутрішнього API управління Cloudflare (`http://51.89.60.252:3000/api`)  
- **ModuleLogger** — логування з розділенням по каналах  
- **RedisQueueStatus** — моніторинг стану черг Redis  
  
---  
  
## Система прав доступу  
  
### Рівні доступу  
  
```  
Root User (is_root = true)  
  └── Повний доступ до всього без перевірок  
  
Regular User  
  ├── Module Access (UserModuleAccess)  
  │   ├── Domains (module:1)  
  │   ├── Users (module:2)  
  │   ├── Generator (module:3)  
  │   ├── Analytics (module:4)  
  │   └── TaskManager (module:5)  
  │  
  └── Domain Account Access (per registrar account)  
      ├── can_view  
      ├── can_buy  
      ├── can_renew  
      ├── can_transfer  
      ├── can_manage_dns  
      └── can_view_balance  
```  
  
### Middleware  
  
- `CheckModuleAccess` — перевіряє, чи має користувач доступ до модуля. Застосовується до груп маршрутів через `module:{id}`.  
- Root-користувачі обходять усі перевірки модулів і акаунтів.  
  
### Навігація  
  
Навігаційне меню автоматично показує тільки ті модулі, до яких у користувача є доступ. При вході (`/`) користувач перенаправляється на перший доступний модуль.  
  
---  
  
## Реальний час (WebSocket)  
  
### Інфраструктура  
  
- **Dev:** Soketi (self-hosted WebSocket сервер)  
- **Production:** Pusher  
- **Клієнт:** Laravel Echo + pusher-js  
  
### Канали broadcasting  
  
| Канал | Подія | Опис |  
|---|---|---|  
| `queue-status` | `QueueUpdated` | Загальні оновлення черг (завершення синхронізації) |  
| `job-logs` | `JobLogUpdated` | Оновлення статусу фонових задач (для Job Queue Widget у навбарі) |  
| `queue-buy-domain` | `QueueBuyDomain` | Прогрес купівлі доменів (статус кожного домену, прогрес-бар кошика) |  
  
### Job Queue Widget  
  
У навігаційній панелі відображається віджет стану черг, який оновлюється в реальному часі:  
- Кількість задач у черзі  
- Статуси виконання (running, completed, failed)  
- Клік → перехід до деталей  
  
---  
  
## Фонові задачі та черги  
  
### Автоматичний розклад  
  
| Задача | Розклад | Модуль |  
|---|---|---|  
| `SyncCloudflareApiDomainJob` | Щодня 03:00 | DomainManager |  
| `SyncLatestGamesJob` | Щодня 03:00 | Generator |  
| `CheckPendingDomainsJob` | Кожні 2 хв | DomainManager |  
| `SyncKeitaroStatsJob` | Кожні 35 хв | Analytics |  
  
### Задачі за запитом  
  
| Задача | Тригер | Модуль |  
|---|---|---|  
| `BuyDomainJob` | Підтвердження покупки | DomainManager |  
| `SyncDomainRegistratorJob` | Кнопка «Sync» | DomainManager |  
| `AddZonesFromBasketJob` | Після покупки | DomainManager |  
| `SyncAllGamesJob` | Ручний запуск | Generator |  
  
### Інфраструктура черг  
  
- **Driver:** Redis (в Docker), Database (за замовчуванням)  
- **Worker:** окремий Docker-контейнер `queue`  
- **Tracking:** всі задачі з трейтом `TrackableJob` автоматично логуються в `job_logs`  
  
---  
  
## База даних  
  
### Основні таблиці (60+ міграцій)  
  
#### Ядро системи  
- `users` — користувачі (auth + status, is_root, domain_access_all)  
- `user_module_accesses` — доступ до модулів  
- `settings` — налаштування (Spatie Settings)  
- `job_logs` — логи фонових задач  
- `locales` — довідник мов/країн/валют  
  
#### Домени  
- `domain_accounts` — акаунти реєстраторів  
- `domains` — домени  
- `domain_tags` / `domain_tag_assignments` — теги  
- `domain_cloudflare_accounts` — Cloudflare-дані  
- `domain_account_accesses` — права доступу  
- `baskets` / `basket_domains` — кошики покупок  
- `collections` / `collection_domain` / `collection_attributes` / `collection_attribute_values` — колекції  
- `keitaro_campaigns` — кампанії  
  
#### Аналітика  
- `domain_clicks` — кліки  
- `keitaro_click_stats` — статистика з Keitaro  
- `keitaro_leads` — ліди/конверсії  
  
#### Генератор  
- `generator_prompts` / `generator_prompt_groups` — промпти  
- `slots_launch_*` — ігрові дані  
  
#### Медіа  
- `media_files` — файли  
- `media_folders` — папки  
  
#### Задачі  
- `tasks` — задачі  
- `task_locales` — локалі задачі  
- `task_default_pages` — сторінки задачі (з ключовими словами)  
- `brands` — бренди  
- `default_pages` — шаблони сторінок  
  
---  
  
## Фронтенд  
  
### Структура views  
  
```  
resources/views/  
├── layouts/  
│   ├── app.blade.php           # Основний layout (авторизований)  
│   ├── guest.blade.php         # Layout для гостей (логін)  
│   └── navigation.blade.php   # Навігація з модульними посиланнями + Job Queue Widget  
├── components/                 # 22 Blade-компоненти  
│   ├── buttons (primary, secondary, danger)  
│   ├── inputs (text, label, select, textarea)  
│   ├── modals, dropdowns  
│   ├── navigation (nav-link, responsive-nav-link)  
│   └── status badges, alerts  
└── modules/                    # Views по модулях  
    ├── Analytics/              # Сторінки + Livewire  
    ├── DomainManager/          # Сторінки + Livewire  
    ├── Generator/              # Сторінки + Livewire  
    ├── Media/                  # Livewire-компоненти  
    ├── Shared/                 # Спільні Livewire  
    ├── TaskManager/            # Сторінки + Livewire  
    └── UserManager/            # Сторінки  
```  
  
### JavaScript-модулі  
  
| Файл | Призначення |  
|---|---|  
| `app.js` | Головний entry point: Alpine, SortableJS, ApexCharts, Monaco, Notyf, Echo |  
| `echo.js` | Налаштування Laravel Echo + Pusher (локальний vs продакшн) |  
| `echo-listeners.js` | WebSocket обробники подій |  
| `buy-domain.js` | Інтерактивність сторінки покупки |  
| `registrators.js` | Форми реєстраторів |  
| `tag-input.js` | Компонент введення тегів |  
| `monaco.js` | Ініціалізація Monaco Editor |  
  
### View Namespaces  
  
Зареєстровані в `AppServiceProvider::boot()`:  
- `DomainManager::` → `resources/views/modules/DomainManager/`  
- `Generator::` → `resources/views/modules/Generator/`  
- `Analytics::` → `resources/views/modules/Analytics/`  
- `Media::` → `resources/views/modules/Media/`  
- `Shared::` → `resources/views/modules/Shared/`  
- `TaskManager::` → `resources/views/modules/TaskManager/`  
- `UserManager::` → `resources/views/modules/UserManager/`  
  
---  
  
## Тестування  
  
### Налаштування  
  
- **Фреймворк:** PHPUnit 11  
- **БД для тестів:** SQLite in-memory (`:memory:`)  
- **Фабрики:** UserFactory, DomainAccountsFactory, GeneratorPromptFactory, TaskFactory, BrandFactory, DefaultPageFactory, LocaleFactory  
  
### Покриття тестами (34 файли)  
  
| Модуль | Тести |  
|---|---|  
| Auth | AuthenticationTest, EmailVerificationTest, PasswordConfirmationTest, PasswordResetTest, PasswordUpdateTest, RegistrationTest |  
| Analytics | ClickRouterPageTest, KeitaroClientTest, KeitaroModelsTest, KeitaroStatsPageTest, KeitaroStatsServiceTest, KeitaroSyncServiceTest |  
| Generator | AiGeneratorServiceTest, SlotsLaunchServiceTest |  
| Media | MediaBrowserTest, MediaUploadTest |  
| TaskManager | BrandCrudTest, BrandObserverTest, BulkAddBrandsTest, DefaultPageCrudTest, DefaultPageObserverTest, ListBrandsTest, ListTasksTest, TaskCrudTest, TaskModuleAccessTest, TaskObserverTest, TaskSidebarTest |  
| UserManager | ModuleAccessTest, RegistratorAccessTest, UserPermissionsFormTest |  
| Shared | JobLogTrackingTest |  
  
### Запуск тестів  
  
```bash  
# Всі тести  
php artisan test  
  
# Конкретний файл  
php artisan test tests/Feature/TaskManager/TaskCrudTest.php  
  
# Конкретний тест  
php artisan test --filter=testName  
```  
  
---  
  
## DevOps та деплой  
  
### Docker (розробка)  
  
`docker-compose.yml` піднімає 7 сервісів:  
  
| Сервіс | Опис | Порт |  
|---|---|---|  
| `app` | PHP-FPM | — |  
| `nginx` | Reverse proxy | 80 |  
| `mysql` | MySQL 8.0 | 3306 |  
| `redis` | Redis 7 (черги, кеш) | 6379 |  
| `queue` | Laravel queue worker | — |  
| `soketi` | WebSocket сервер | 6001 |  
| `node` | npm install + build | — |  
  
### CI/CD (GitLab)  
  
`.gitlab-ci.yml` — два етапи на semver-тегах (`v*.*.*`):  
  
1. **build** — збірка Docker-образу → push до GitLab Container Registry  
2. **gitops** — оновлення FluxCD/Kustomize маніфесту на гілці `k3s` → автоматичний деплой на K3s кластер  
  
### Kubernetes  
  
Директорія `flux/` містить маніфести FluxCD/Kustomize для деплою на K3s.  
  
---  
  
## Налаштування та запуск  
  
### Вимоги  
  
- PHP 8.4+  
- MySQL 8.0+  
- Redis 7+  
- Node.js LTS  
- Composer 2  
  
### Швидкий старт (Docker)  
  
```bash  
# Клонувати репозиторій  
git clone git@gitlab.1sx.biz:generator/v3-crm.git  
cd v3-crm  
  
# Скопіювати конфігурацію  
cp .env.example .env  
  
# Запустити Docker  
docker-compose up -d  
  
# Встановити залежності  
docker-compose run --rm composer install  
docker-compose run --rm node npm install && npm run build  
  
# Підготувати БД  
docker-compose exec app php artisan migrate --seed  
docker-compose exec app php artisan key:generate  
```  
  
### Швидкий старт (локально)  
  
```bash  
# Залежності  
composer install  
npm install  
  
# Конфігурація  
cp .env.example .env  
php artisan key:generate  
  
# Налаштувати .env (MySQL, Redis)  
  
# БД  
php artisan migrate --seed  
  
# Запуск  
php artisan serve  
npm run dev  
  
# Queue worker (окремий термінал)  
php artisan queue:work redis  
```  
  
### Ключові змінні оточення (.env)  
  
| Змінна | Опис |  
|---|---|  
| `DB_*` | Підключення до MySQL |  
| `REDIS_*` | Підключення до Redis |  
| `QUEUE_CONNECTION` | Драйвер черг (redis / database) |  
| `BROADCAST_CONNECTION` | Драйвер broadcasting (pusher / log) |  
| `MEDIA_DISK_DRIVER` | Сховище медіа (local / bunny) |  
| `BUNNY_*` | BunnyCDN (якщо MEDIA_DISK_DRIVER=bunny) |  
| `KEITARO_URL` | URL Keitaro-трекера |  
| `KEITARO_API_KEY` | API-ключ Keitaro |  
| `TINIFY_API_KEY` | API-ключ TinyPNG |  
| `PUSHER_*` | Налаштування WebSocket |  
| `SOKETI_*` | Налаштування Soketi (dev) |  
  
### Корисні команди  
  
```bash  
# Форматування коду  
vendor/bin/pint --dirty  
  
# Запуск тестів  
php artisan test  
  
# Синхронізація доменів (ручна)  
php artisan schedule:run  
  
# Перегляд логів  
# Через веб: Laravel Telescope на /telescope  
# Через веб: Log Viewer на /log-viewer  
  
# Збірка фронтенду  
npm run build       # Production  
npm run dev         # Dev-сервер з HMR  
```  
  
### Зовнішні API (публічні)  
  
| Ендпоінт | Метод | Опис | Автентифікація |  
|---|---|---|---|  
| `/api/domains/all` | GET | Всі домени | `X-API-LOGIN` + `X-API-PASSWORD` |  
| `/api/domains/click` | GET | Запис кліку | Без автентифікації |  
| `/domain/ping/{domain}` | POST | Ping домену (CF sync) | Без автентифікації |