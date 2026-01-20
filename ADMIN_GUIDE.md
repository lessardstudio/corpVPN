# Руководство администратора (Administration Guide)

## 1. Обзор архитектуры
Проект представляет собой корпоративный VPN-шлюз на базе протокола **Hysteria2**, управляемый через панель **Blitz**.
Система состоит из двух основных компонентов:
1.  **Blitz Panel**: Управление пользователями, трафиком и настройками Hysteria2.
2.  **Automation Service**: API-шлюз и Telegram-бот для автоматизации выдачи доступов и интеграции с HR-системами.

**Стек технологий:**
*   **VPN Core**: Hysteria2 (UDP, высокая производительность).
*   **Управление**: Blitz (Python/FastAPI).
*   **Автоматизация**: Python 3.11 (FastAPI, Aiogram 3.x).
*   **База данных**: MongoDB (для Blitz), SQLite (локальный кэш Automation Service).

---

## 2. Развертывание (Deployment)

### Предварительные требования
*   **ОС**: Ubuntu 22.04 LTS (рекомендуется).
*   **Ресурсы**: Минимум 1 CPU, 1GB RAM.
*   **Сеть**: Открытые порты 8000 (TCP), 8080 (TCP), 443 (TCP/UDP).
*   **Домен**: A-запись, указывающая на IP сервера (например, `vpn.company.com`).

### Вариант А: Полный Docker стек (Рекомендуемый)
Все сервисы работают в контейнерах.

1.  **Подготовка**:
    ```bash
    git clone https://github.com/your-org/corp-vpn.git
    cd corp-vpn
    # Создание .env и генерация паролей
    chmod +x scripts/setup_env.sh
    ./scripts/setup_env.sh
    ```

2.  **Запуск**:
    ```bash
    docker-compose up -d --build
    ```

3.  **Доступ**:
    *   Blitz Panel: `http://ВАШ_IP:8000/blitz/login`
    *   Учетные данные администратора находятся в файле `.env` (переменные `BLITZ_ADMIN_PASSWORD`).

### Вариант Б: Гибридный режим (Manual Blitz + Docker Automation)
Blitz устанавливается как системный сервис (systemd) для максимальной производительности, Automation Service — в Docker.

1.  **Установка Blitz**:
    ```bash
    chmod +x scripts/install_manual_blitz.sh
    ./scripts/install_manual_blitz.sh
    ```

2.  **Запуск Automation Service**:
    ```bash
    docker-compose -f docker-compose.manual-blitz.yml up -d --build
    ```

---

## 3. Конфигурация и Безопасность

### Переменные окружения (.env)
Файл `.env` является критически важным. Основные параметры:

| Переменная | Описание | Пример |
|------------|----------|--------|
| `DOMAIN` | Домен для генерации ссылок | `vpn.company.com` |
| `BLITZ_ADMIN_PASSWORD` | Пароль администратора панели | `сложный_пароль` |
| `BLITZ_SECRET_KEY` | Токен API (используется для связи сервисов) | `hex_строка` |
| `TELEGRAM_BOT_TOKEN` | Токен бота от @BotFather | `123:ABC...` |
| `CORPORATE_SECRET` | Секрет для защиты вебхуков | `hex_строка` |

### Рекомендации по безопасности
1.  **Firewall (UFW)**:
    ```bash
    ufw default deny incoming
    ufw allow ssh
    ufw allow 8000/tcp  # Blitz Panel
    ufw allow 8080/tcp  # Automation API
    ufw allow 443/udp   # Hysteria2 Traffic
    ufw allow 443/tcp   # Hysteria2 Fallback
    ufw enable
    ```
2.  **Ротация секретов**: При смене `BLITZ_SECRET_KEY` необходимо перезапустить оба сервиса.
3.  **SSL**: Blitz может автоматически управлять сертификатами, если порт 80 доступен, либо используйте Nginx как reverse proxy.

---

## 4. Обслуживание и Мониторинг

### Обновление системы
Для обновления кода и пересборки контейнеров:
```bash
git pull
docker-compose build --no-cache
docker-compose up -d
```

### Просмотр логов
*   **Automation Service**:
    ```bash
    docker-compose logs -f automation-service
    ```
*   **Blitz (Docker)**:
    ```bash
    docker-compose logs -f blitz
    ```
*   **Blitz (Systemd)**:
    ```bash
    journalctl -u blitz -f
    ```

### Резервное копирование
Необходимо регулярно делать бэкап следующих данных:
1.  Файл `.env` (конфигурация).
2.  Папка `blitz_data/db` (база MongoDB).
3.  Папка `automation_data` (база SQLite пользователей).

Пример скрипта бэкапа:
```bash
#!/bin/bash
BACKUP_DIR="/backup/$(date +%F)"
mkdir -p "$BACKUP_DIR"
cp .env "$BACKUP_DIR/"
cp -r blitz_data "$BACKUP_DIR/"
cp -r automation_data "$BACKUP_DIR/"
# Архивация
tar -czf "$BACKUP_DIR.tar.gz" "$BACKUP_DIR"
rm -rf "$BACKUP_DIR"
```

---

## 5. Устранение неполадок (Troubleshooting)

### Проблема: "Could not open requirements.txt" при сборке
**Причина**: Отсутствуют файлы исходного кода на сервере.
**Решение**:
```bash
# Выполнить на локальной машине
scp -r .\blitz_source root@IP:~/corpVPN/
scp -r .\automation-service root@IP:~/corpVPN/
```
Либо используйте скрипт восстановления: `./scripts/fix_blitz.sh`.

### Проблема: Telegram бот не отвечает
**Причина**: Неверный токен или бот не запущен.
**Диагностика**:
1.  Проверьте `TELEGRAM_BOT_TOKEN` в `.env`.
2.  Проверьте логи: `docker-compose logs automation-service`.
3.  Убедитесь, что сообщение "Run polling for bot..." присутствует в логах.

### Проблема: Конфликт портов (Address already in use)
**Причина**: Порт 8000 или 443 занят другим процессом (например, Nginx).
**Решение**:
Проверьте занятые порты: `netstat -tulpn | grep LISTEN`.
Измените порт в `docker-compose.yml` (раздел `ports`) и в `.env`.

### Проблема: Ошибка зависимостей (aiogram/pydantic)
**Решение**:
Обновите `automation-service/requirements.txt` до совместимых версий (aiogram 3.17.0+, pydantic 2.x) и пересоберите контейнер с `--no-cache`.
