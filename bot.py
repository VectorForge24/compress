import os, logging, sys
from telegram.ext import Application, CommandHandler

logging.basicConfig(level=logging.INFO, stream=sys.stdout)
logger = logging.getLogger(__name__)

async def start(update, context):
    await update.message.reply_text("Bot is alive! 🎉")

async def post_init(app):
    me = await app.bot.get_me()
    logger.info(f"Bot connected as @{me.username}")

if __name__ == "__main__":
    token = os.environ.get("TELEGRAM_BOT_TOKEN")
    if not token:
        logger.error("TELEGRAM_BOT_TOKEN missing")
        sys.exit(1)
    app = Application.builder().token(token).post_init(post_init).build()
    app.add_handler(CommandHandler("start", start))
    logger.info("Starting polling...")
    app.run_polling()
