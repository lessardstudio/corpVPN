from aiogram import Bot, Dispatcher, types, F
from aiogram.filters import Command
from aiogram.types import Message
import logging
from config import get_settings
from database import Database

logger = logging.getLogger(__name__)
settings = get_settings()

bot = Bot(token=settings.TELEGRAM_BOT_TOKEN)
dp = Dispatcher()
db = Database(settings.DB_PATH)

@dp.message(Command("start"))
async def cmd_start(message: Message):
    await message.answer(
        "Welcome to the Corporate VPN Bot.\n"
        "Your Telegram ID is: " + str(message.from_user.id) + "\n"
        "Please contact your administrator to grant access."
    )

@dp.message(Command("my_config"))
async def cmd_my_config(message: Message):
    # This assumes we have a way to link Telegram ID to Corporate ID
    # For now, just a placeholder
    await message.answer("Feature not implemented yet. Please use the link provided by your administrator.")

async def start_bot():
    try:
        await dp.start_polling(bot)
    except Exception as e:
        logger.error(f"Bot error: {e}")
