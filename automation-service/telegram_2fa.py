from aiogram import Bot, Dispatcher, types, F
from aiogram.filters import Command, StateFilter
from aiogram.types import Message, CallbackQuery
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
import logging
from typing import Optional
from datetime import datetime, timedelta
import secrets
import re
import string

from config import get_settings
from database import Database

logger = logging.getLogger(__name__)
settings = get_settings()

# FSM States for 2FA flow
class AuthStates(StatesGroup):
    waiting_for_corporate_id = State()
    waiting_for_verification_code = State()
    authenticated = State()

class AdminStates(StatesGroup):
    waiting_for_owner = State()
    waiting_for_revoke_id = State()
    waiting_for_search = State()
    waiting_for_validate_id = State()

class Telegram2FA:
    def __init__(self):
        self.bot = Bot(token=settings.TELEGRAM_BOT_TOKEN)
        self.dp = Dispatcher()
        self.db = Database(settings.DB_PATH)
        self.verification_codes = {}  # In production, use Redis or database
        self.admin_ids = set([x.strip() for x in settings.ADMIN_TELEGRAM_IDS.split(',') if x.strip()])

    def is_admin(self, user_id: int) -> bool:
        return str(user_id) in self.admin_ids

    def generate_corporate_id(self) -> str:
        letters = ''.join([c for c in string.ascii_uppercase if c not in 'IO'])
        prefix = ''.join(secrets.choice(letters) for _ in range(2))
        digits = ''.join(secrets.choice(string.digits) for _ in range(6))
        return prefix + digits
        
    async def start_command(self, message: Message, state: FSMContext):
        """Handle /start command and initiate 2FA process"""
        user = message.from_user
        
        # Check if user already has corporate ID linked
        existing_user = await self.db.get_user_by_telegram_id(str(user.id))
        
        if existing_user:
            await message.answer(
                f"✅ Вы уже аутентифицированы!\n"
                f"Ваш корпоративный ID: {existing_user['corporate_id']}\n"
                f"Используйте /help для списка команд."
            )
            await state.set_state(AuthStates.authenticated)
            return
        
        await message.answer(
            "🔐 Добро пожаловать в Corporate VPN Bot!\n\n"
            "Для получения доступа к VPN, мне нужно связать ваш Telegram аккаунт с корпоративным ID.\n\n"
            "Пожалуйста, введите ваш корпоративный ID:"
        )
        await state.set_state(AuthStates.waiting_for_corporate_id)
    
    async def handle_corporate_id(self, message: Message, state: FSMContext):
        """Handle corporate ID input and send verification code"""
        corporate_id = message.text.strip()
        
        # Validate corporate ID format
        if not corporate_id or len(corporate_id) < 3:
            await message.answer("❌ Неверный формат корпоративного ID. Попробуйте еще раз:")
            return
        
        # Check if corporate ID exists in system (would integrate with HR system)
        # For now, we'll accept any valid format
        
        # Generate verification code
        verification_code = secrets.token_hex(3).upper()  # 6 character hex code
        
        # Store verification code with expiration (5 minutes)
        self.verification_codes[message.from_user.id] = {
            'corporate_id': corporate_id,
            'code': verification_code,
            'expires_at': datetime.now() + timedelta(minutes=5)
        }
        
        await message.answer(
            f"📧 Код подтверждения отправлен на ваш корпоративный email.\n\n"
            f"Пожалуйста, введите 6-значный код подтверждения:"
        )
        
        # In production, send email to corporate email
        logger.info(f"Verification code for {corporate_id}: {verification_code}")
        
        await state.set_state(AuthStates.waiting_for_verification_code)
        await state.update_data(corporate_id=corporate_id)
    
    async def handle_verification_code(self, message: Message, state: FSMContext):
        """Handle verification code input"""
        user_code = message.text.strip().upper()
        user_id = message.from_user.id
        
        # Get stored verification data
        verification_data = self.verification_codes.get(user_id)
        
        if not verification_data:
            await message.answer("❌ Код подтверждения истёк. Пожалуйста, начните сначала с команды /start")
            await state.clear()
            return
        
        # Check expiration
        if datetime.now() > verification_data['expires_at']:
            del self.verification_codes[user_id]
            await message.answer("❌ Код подтверждения истёк. Пожалуйста, начните сначала с команды /start")
            await state.clear()
            return
        
        # Verify code
        if user_code != verification_data['code']:
            await message.answer("❌ Неверный код подтверждения. Попробуйте еще раз:")
            return
        
        # Success! Link Telegram ID to corporate ID
        corporate_id = verification_data['corporate_id']
        telegram_id = str(message.from_user.id)
        
        # Store the mapping in database
        await self.db.link_telegram_to_corporate(telegram_id, corporate_id)
        
        # Clean up verification data
        del self.verification_codes[user_id]
        
        await message.answer(
            "✅ Аутентификация успешно завершена!\n\n"
            "Теперь вы можете получить свою VPN конфигурацию.\n"
            "Используйте команду /get_config для получения конфигурации."
        )
        
        await state.set_state(AuthStates.authenticated)
    
    async def get_config_command(self, message: Message, state: FSMContext):
        """Handle /get_config command for authenticated users"""
        current_state = await state.get_state()
        
        if current_state != AuthStates.authenticated:
            await message.answer("❌ Сначала пройдите аутентификацию с помощью команды /start")
            return
        
        telegram_id = str(message.from_user.id)
        user = await self.db.get_user_by_telegram_id(telegram_id)
        
        if not user:
            await message.answer("❌ Пользователь не найден. Пожалуйста, пройдите аутентификацию заново.")
            await state.clear()
            return
        
        # Get subscription URL from our automation service
        subscription_url = user.get('subscription_url')
        
        if not subscription_url:
            # Request new subscription from automation service
            corporate_id = user['corporate_id']
            # This would call our automation service API
            # For now, show placeholder
            await message.answer(
                "📋 Ваша VPN конфигурация готовится...\n"
                "Пожалуйста, подождите несколько минут."
            )
            return
        
        # Send configuration to user
        await message.answer(
            "📱 Ваша VPN конфигурация:\n\n"
            f"Корпоративный ID: {user['corporate_id']}\n"
            f"Username: {user['marzban_username']}\n\n"
            "🔗 Ссылка на конфигурацию:\n"
            f"{subscription_url}\n\n"
            "Инструкции по установке:\n"
            "1. Установите приложение Hiddify\n"
            "2. Импортируйте конфигурацию по ссылке\n"
            "3. Подключитесь к VPN"
        )
    
    async def help_command(self, message: Message):
        """Handle /help command"""
        await message.answer(
            "🤖 Доступные команды:\n\n"
            "/start - Начать аутентификацию\n"
            "/get_config - Получить VPN конфигурацию\n"
            "/help - Показать это сообщение\n\n"
            "Админ команды:\n"
            "/issue_id - Выдать новый корпоративный ID\n"
            "/revoke_id - Отозвать корпоративный ID\n"
            "/search_id - Найти корпоративный ID\n"
            "/validate_id - Проверить валидность ID\n\n"
            "Для получения VPN доступа:\n"
            "1. Используйте /start для аутентификации\n"
            "2. Введите ваш корпоративный ID\n"
            "3. Подтвердите email кодом\n"
            "4. Получите конфигурацию через /get_config"
        )

    async def notify_admins(self, text: str):
        # send message to all admin IDs
        for admin_id in self.admin_ids:
            try:
                await self.bot.send_message(chat_id=admin_id, text=text)
            except Exception as e:
                logger.error(f"notify_admin {admin_id} failed: {e}")

    async def issue_id_command(self, message: Message, state: FSMContext):
        if not self.is_admin(message.from_user.id):
            await message.answer("❌ Доступ запрещен")
            return
        await message.answer("Введите имя владельца для нового ID:")
        await state.set_state(AdminStates.waiting_for_owner)

    async def handle_owner_for_issue(self, message: Message, state: FSMContext):
        owner = message.text.strip()
        new_id = self.generate_corporate_id()
        while await self.db.get_id(new_id):
            new_id = self.generate_corporate_id()
        await self.db.create_id(new_id, owner)
        await self.db.audit_id_action(new_id, "issue", str(message.from_user.id), owner)
        await message.answer(f"✅ Новый ID выдан: {new_id}\nВладелец: {owner}")
        await state.clear()

    async def revoke_id_command(self, message: Message, state: FSMContext):
        if not self.is_admin(message.from_user.id):
            await message.answer("❌ Доступ запрещен")
            return
        await message.answer("Введите ID для отзыва:")
        await state.set_state(AdminStates.waiting_for_revoke_id)

    async def handle_revoke_id(self, message: Message, state: FSMContext):
        id_value = message.text.strip().upper()
        if not re.match(r"^[A-HJ-NP-Z]{2}\d{6}$", id_value):
            await message.answer("❌ Неверный формат ID. Пример: AB123456")
            return
        rec = await self.db.get_id(id_value)
        if not rec:
            await message.answer("❌ ID не найден")
            return
        await self.db.set_id_status(id_value, "revoked")
        await self.db.audit_id_action(id_value, "revoke", str(message.from_user.id), "")
        await message.answer("✅ ID отозван")
        await state.clear()

    async def search_id_command(self, message: Message, state: FSMContext):
        if not self.is_admin(message.from_user.id):
            await message.answer("❌ Доступ запрещен")
            return
        await message.answer("Введите поисковый запрос (ID/владелец/статус):")
        await state.set_state(AdminStates.waiting_for_search)

    async def handle_search_id(self, message: Message, state: FSMContext):
        query = message.text.strip()
        rows = await self.db.search_ids(query)
        if not rows:
            await message.answer("Ничего не найдено")
        else:
            text = "\n".join([f"{r['id']} | {r.get('owner','')} | {r.get('status','')}" for r in rows])
            await message.answer(f"Результаты:\n{text}")
        await state.clear()

    async def validate_id_command(self, message: Message, state: FSMContext):
        await message.answer("Введите ID для проверки:")
        await state.set_state(AdminStates.waiting_for_validate_id)

    async def handle_validate_id(self, message: Message, state: FSMContext):
        id_value = message.text.strip().upper()
        if not re.match(r"^[A-HJ-NP-Z]{2}\d{6}$", id_value):
            await message.answer("❌ Неверный формат ID. Пример: AB123456")
            return
        rec = await self.db.get_id(id_value)
        if not rec:
            await message.answer("❌ ID не найден")
        else:
            await message.answer(f"✅ ID валиден. Статус: {rec.get('status','')} Владелец: {rec.get('owner','')}")
        await state.clear()
    
    def setup_handlers(self):
        """Setup bot handlers"""
        self.dp.message.register(self.start_command, Command("start"))
        self.dp.message.register(self.help_command, Command("help"))
        self.dp.message.register(self.get_config_command, Command("get_config"))
        self.dp.message.register(self.issue_id_command, Command("issue_id"))
        self.dp.message.register(self.revoke_id_command, Command("revoke_id"))
        self.dp.message.register(self.search_id_command, Command("search_id"))
        self.dp.message.register(self.validate_id_command, Command("validate_id"))
        
        # Handle corporate ID input
        self.dp.message.register(
            self.handle_corporate_id,
            AuthStates.waiting_for_corporate_id
        )
        
        # Handle verification code input
        self.dp.message.register(
            self.handle_verification_code,
            AuthStates.waiting_for_verification_code
        )

        self.dp.message.register(
            self.handle_owner_for_issue,
            AdminStates.waiting_for_owner
        )

        self.dp.message.register(
            self.handle_revoke_id,
            AdminStates.waiting_for_revoke_id
        )

        self.dp.message.register(
            self.handle_search_id,
            AdminStates.waiting_for_search
        )

        self.dp.message.register(
            self.handle_validate_id,
            AdminStates.waiting_for_validate_id
        )
    
    async def start_bot(self):
        """Start the Telegram bot"""
        try:
            self.setup_handlers()
            await self.dp.start_polling(self.bot)
        except Exception as e:
            logger.error(f"Bot error: {e}")
            raise
