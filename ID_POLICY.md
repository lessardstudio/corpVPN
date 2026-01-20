# Регламент выдачи корпоративных идентификаторов (ID)

## 1. Формат и правила генерации
- Формат: `AA######` — 8 символов: 2 заглавные латинские буквы (`A–Z`) + 6 цифр (`0–9`).
- Ограничения: исключить визуально похожие буквы (`I`, `O`) при генерации; ведущий ноль для чисел разрешён.
- Уникальность: централизованная проверка по реестру ID; запрет повторной выдачи;
- Источник: автоматическая выдача по API (сервис Automation) с возможностью ручной выдачи администратором.
- Коллизии: при генерации использовать криптографически стойкий генератор и проверять занятость — при конфликте повторять попытку.

Пример регулярного выражения для проверки формата:
```
^[A-HJ-NP-Z]{2}\d{6}$
```

## 2. Пользовательский интерфейс (Telegram бот)
- Поле ввода: «Пожалуйста, введите ваш корпоративный ID:».
- Валидация: проверять формат по regex; в случае ошибки — подсказка «Формат: 2 буквы + 6 цифр (например, AB123456)».
- Ошибки: «❌ Неверный формат корпоративного ID. Попробуйте ещё раз:».
- Успешно: переход к шагу подтверждения (2FA) и связывание Telegram-аккаунта с ID.

Пример валидации (фрагмент для `telegram_2fa.py`):
```python
import re
ID_REGEX = re.compile(r"^[A-HJ-NP-Z]{2}\d{6}$")

corporate_id = message.text.strip().upper()
if not ID_REGEX.match(corporate_id):
    await message.answer("❌ Неверный формат корпоративного ID. Формат: AB123456")
    return
```

## 3. База данных и резервирование

Добавить реестр ID и журнал изменений в SQLite (Automation Service):

```sql
-- Таблица реестра ID
CREATE TABLE IF NOT EXISTS id_registry (
  id TEXT PRIMARY KEY,
  owner TEXT,
  status TEXT CHECK(status IN ('issued','active','revoked','archived')) DEFAULT 'issued',
  issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP
);

-- Журнал изменений
CREATE TABLE IF NOT EXISTS id_audit (
  audit_id INTEGER PRIMARY KEY AUTOINCREMENT,
  id TEXT,
  action TEXT,           -- issue/activate/revoke/archive
  actor TEXT,            -- кто инициировал (admin/service)
  details TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(id) REFERENCES id_registry(id)
);
```

Резервное копирование:
- Ежедневный бэкап файла БД `automation_data/users.db` и экспорт `id_registry` в CSV.
- Пример бэкапа:
```bash
sqlite3 automation_data/users.db \
  ".headers on" \
  ".mode csv" \
  "SELECT * FROM id_registry;" > backups/id_registry_$(date +%F).csv
cp automation_data/users.db backups/users_$(date +%F).db
```

## 4. Интеграция и API

Эндпоинты (FastAPI, Automation Service):
- `GET /id/validate?id=AB123456` → `{ valid: true/false, status, owner }`
- `POST /id/issue` (админ/сервис) → создаёт новый ID, возвращает `{ id, status }`
- `POST /id/revoke` → помечает ID как revoked
- `GET /id/export.csv` → выгрузка реестра для внешних систем

Пример интерфейса генерации ID:
```python
import secrets, string

LETTERS = ''.join([c for c in string.ascii_uppercase if c not in 'IO'])
def generate_id():
    prefix = ''.join(secrets.choice(LETTERS) for _ in range(2))
    digits = ''.join(secrets.choice(string.digits) for _ in range(6))
    return prefix + digits
```

Политика доступа:
- Выдача и отзыв ID доступны только аутентифицированным сервисам/админам (по `X-Corporate-Secret`).
- Логи всех операций пишутся в `id_audit` и `auth_logs`.

## 5. Документация и безопасность

Инструкция для пользователей:
- ID выдается отделом кадров/системой; формат: `AB123456`.
- ID используется для аутентификации в Telegram-боте и получения VPN-конфигурации.

Инструкция для администраторов:
- Проверка ID: `/id/validate?id=...`.
- Выдача нового ID: `/id/issue` с `owner` и метаданными.
- Ревокация: `/id/revoke`.
- Экспорт: `/id/export.csv`.

Политика безопасности:
- Конфиденциальность: ID не должен содержать персональные данные.
- Контроль доступа: все административные операции защищены секретами и аудитом.
- Срок хранения: реестр и журнал изменений хранятся не менее 1 года.

## 6. Рабочие процессы (best practices)
- Генерация ID только через централизованный сервис (Automation), ручная выдача — через админ-панель.
- Любое изменение статуса ID сопровождается записью в `id_audit`.
- Регулярные бэкапы и проверка непротиворечивости данных (периодический валидатор уникальности).

