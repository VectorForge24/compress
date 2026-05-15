import os, requests, threading, sys, logging
from http.server import HTTPServer, BaseHTTPRequestHandler
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, MessageHandler, CallbackQueryHandler, filters, ContextTypes

logging.basicConfig(level=logging.INFO, stream=sys.stdout)

REPO = "eartinityop/compress"
WF_FILE = "compress.yml"
GITHUB_TOKEN = os.environ["GITHUB_TOKEN"]
CHANNEL_USERNAME = "compresslog"
BOT_USERNAME = "Eartinityvidcomp_bot"

# Health server for Render
class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"OK")

def start_health_server():
    port = int(os.environ.get("PORT", 8000))
    server = HTTPServer(("0.0.0.0", port), HealthHandler)
    threading.Thread(target=server.serve_forever, daemon=True).start()

# Bot handlers
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("I am Eartinity's personal video compressor bot👋👋.\nSend me a video to get started.")

async def video_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    original_caption = update.message.caption or ""
    context.user_data["original_caption"] = original_caption
    context.user_data["original_msg_id"] = update.message.message_id
    forwarded = await update.message.forward(f"@{CHANNEL_USERNAME}")
    context.user_data["fwd_msg_id"] = forwarded.message_id
    context.user_data["user_id"] = update.message.chat_id

    keyboard = [
        [InlineKeyboardButton("Compress this video ✅", callback_data="compress")],
        [InlineKeyboardButton("Cancel the process ❌", callback_data="cancel")]
    ]
    await update.message.reply_text("Video received. What would you like to do?", reply_markup=InlineKeyboardMarkup(keyboard))

async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    data = query.data

    # Cancel a running workflow
    if data.startswith("cancel_run_"):
        run_id = data.split("_", 2)[2]
        url = f"https://api.github.com/repos/{REPO}/actions/runs/{run_id}/cancel"
        headers = {"Authorization": f"token {GITHUB_TOKEN}", "Accept": "application/vnd.github+json"}
        resp = requests.post(url, headers=headers)
        if resp.status_code == 202:
            await query.edit_message_text("❌ Process cancelled by user.")
        else:
            error_msg = resp.json().get("message", "Unknown error")
            await query.edit_message_text(f"❌ Cancellation failed: {error_msg}")
        return

    if data == "cancel":
        await query.edit_message_text("❌ Process cancelled.")
        return

    if data == "compress":
        keyboard = [
            [InlineKeyboardButton("240p", callback_data="quality_240"),
             InlineKeyboardButton("360p", callback_data="quality_360")],
            [InlineKeyboardButton("480p", callback_data="quality_480"),
             InlineKeyboardButton("720p", callback_data="quality_720")],
            [InlineKeyboardButton("1080p", callback_data="quality_1080")],
            [InlineKeyboardButton("Cancel ❌", callback_data="cancel_q")]
        ]
        await query.edit_message_text("Select the desired quality:", reply_markup=InlineKeyboardMarkup(keyboard))
        return

    if data.startswith("quality_"):
        quality = data.split("_")[1]
        fwd_msg_id = context.user_data.get("fwd_msg_id")
        user_id = context.user_data.get("user_id")
        original_msg_id = context.user_data.get("original_msg_id")

        if not fwd_msg_id or not user_id or not original_msg_id:
            await query.edit_message_text("Error: Missing video info.")
            return

        await query.edit_message_text("⏳ Triggering workflow...")
        progress_msg_id = query.message.message_id

        url = f"https://api.github.com/repos/{REPO}/actions/workflows/{WF_FILE}/dispatches"
        headers = {"Authorization": f"token {GITHUB_TOKEN}", "Accept": "application/vnd.github+json"}
        payload = {
            "ref": "main",
            "inputs": {
                "channel_username": CHANNEL_USERNAME,
                "fwd_message_id": str(fwd_msg_id),
                "user_id": str(user_id),
                "quality": quality,
                "message_id": str(progress_msg_id),
                "original_message_id": str(original_msg_id),
                "bot_username": BOT_USERNAME
            }
        }
        resp = requests.post(url, json=payload, headers=headers)
        if resp.status_code != 204:
            await query.edit_message_text(f"❌ Workflow trigger failed: {resp.status_code} {resp.text}")

    elif data == "cancel_q":
        await query.edit_message_text("❌ Compression cancelled.")

async def post_init(application: Application):
    me = await application.bot.get_me()
    print(f"Bot started as @{me.username}")

def main():
    app = Application.builder().token(os.environ["TELEGRAM_BOT_TOKEN"]).post_init(post_init).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(MessageHandler(filters.VIDEO, video_handler))
    app.add_handler(CallbackQueryHandler(button_handler))
    app.run_polling()

if __name__ == "__main__":
    start_health_server()
    main()
