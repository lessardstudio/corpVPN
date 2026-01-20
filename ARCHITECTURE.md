# Архитектура проекта: Corporate VPN Gateway (Blitz + Hysteria2)

## 1. Контекст и цель
Система предоставляет управляемый корпоративный VPN-доступ с централизованным управлением пользователями, выдачей конфигураций и интеграцией с HR-событиями (вебхуки).

## 2. Технологический стек
- **VPN Core:** Hysteria2 (UDP + TCP fallback)
- **Панель управления:** Blitz Panel (web UI + API)
- **Automation:** Python 3.11 (FastAPI + Aiogram 3.x)
- **БД:** MongoDB (Blitz), SQLite (Automation Service: кэш пользователей, реестр ID, аудит)
- **Оркестрация:** Docker Compose

## 3. Компоненты
### A. Blitz (контейнер `blitz`)
- Web UI администратора и API управления пользователями Hysteria2.
- Генерирует/использует конфигурацию Hysteria2 (`/etc/hysteria/config.json`) и запускает Hysteria2 процесс через supervisord.

### B. MongoDB (контейнер `blitz-mongo`)
- Хранилище данных Blitz Panel.

### C. Automation Service (контейнер `automation-service`)
- API для выдачи доступа: `/access/grant`, `/user/{id}/config`, `/user/{id}/deactivate`.
- Telegram-бот для 2FA и администрирования корпоративных ID.
- Хранит SQLite БД: `automation_data/users.db` (пользователи, логи, webhooks, traffic stats, id_registry/id_audit).

## 4. Потоки данных (Data Flow)
1. **Выдача доступа:** HR/сервис → `POST /access/grant` → Automation → Blitz API → создание пользователя → запись в SQLite → возврат `hy2_url` и `subscription_url`.
2. **Получение конфигурации:** Пользователь → Telegram Bot → `/get_config` → ссылка/QR.
3. **Деактивация:** HR webhook → `/webhooks/hr-events` → Automation → Blitz API disable user → отметка `is_active=0`.

## 5. Безопасность
- Все защищенные эндпоинты требуют `X-Corporate-Secret`.
- Вебхуки могут подписываться HMAC (`WEBHOOK_SECRET`).
- `.env` содержит секреты и не должен коммититься; используйте `.env.example` как шаблон.

## 6. Масштабирование
- При росте нагрузки рекомендуется разделить API и Telegram polling на два процесса/контейнера.
- Для продакшна — включить несколько workers для FastAPI (gunicorn/uvicorn workers) и лимиты ресурсов в compose.
