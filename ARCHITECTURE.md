# Архитектура проекта: Corporate VPN Automation Gateway

## 1. Контекст и Цель
Создание защищенного корпоративного шлюза для сотрудников в РФ. Система должна обходить блокировки DPI (через VLESS Reality) и предоставлять доступ **только** к внутренним ресурсам компании, сохраняя обычный интернет-трафик пользователя нетронутым (Split Tunneling).

## 2. Технологический стек
- **Core:** Xray Core (VLESS + Reality)
- **Orchestration:** Marzban (Docker-based)
- **Tunneling:** WireGuard (VPS <-> Office Network)
- **Client:** Hiddify (TUN Mode)
- **Automation:** Python 3.11 (FastAPI / Aiogram 3.x)
- **Database:** SQLite (для локального кэша пользователей)

## 3. Схема потоков данных (Data Flow)



1. **Provisioning:** User -> Telegram Bot -> Marzban API -> Create User.
2. **Subscription:** Hiddify Client -> Marzban Sub Endpoint -> Config JSON (VLESS).
3. **Traffic:** Client Device -> VLESS Reality (Port 443) -> VPS -> WireGuard Tunnel -> Office Server.

## 4. Компоненты системы

### А. Инфраструктура (Marzban)
- Конфигурация `xray_config.json` должна быть в режиме "Whitelist".
- Запрет всего трафика (`blackhole`), кроме подсетей: `192.168.0.0/16`, `10.0.0.0/8`.

### Б. Модуль автоматизации (API Wrapper)
- **Endpoint `POST /access/grant`:** Проверяет корпоративный ID, создает пользователя в Marzban, возвращает `subscription_url`.
- **Logic:** Интеграция с Telegram для двухфакторной аутентификации (опционально).

### В. Сетевой уровень (Routing)
- Использование TUN-интерфейса на стороне клиента.
- Правила маршрутизации передаются через JSON-профиль Sing-box внутри подписки Marzban.

## 5. Ограничения и Безопасность
- **No Global Proxy:** Весь публичный трафик идет мимо VPN (Direct).
- **Reality Stealth:** SNI должен имитировать `dl.google.com` или аналогичный разрешенный ресурс.
- **Short-lived Links:** Ссылки подписки должны аннулироваться при деактивации сотрудника в основной системе (через вебхук).

## 6. Инструкции для Gemini CLI
- При написании кода для бота использовать библиотеку `requests` или `httpx`.
- Всегда следовать принципу асинхронности в Python.
- При генерации конфигов Xray использовать UUID v4.