import os, requests, threading, httpx
from http.server import HTTPServer, BaseHTTPRequestHandler
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, MessageHandler, CallbackQueryHandler, filters, ContextTypes

# ========== CONFIGURE THESE ==========
REPO = "eartinityop/compress"
WF_FILE = "compress.yml"
GITHUB_TOKEN = os.environ["GITHUB_TOKEN"]
# =====================================

# The public base URL of this service (Render will provide it)
SERVICE_URL = os.environ.get("RENDER_EXTERNAL_URL", "http://localhost:8000")
BOT_API_LOCAL = "http://localhost:8081"   # the internal API server
BASE_URL = f"{SERVICE_URL}/bot"

RUN_IDS = {}

# ---------- Reverse proxy health server ----------
import urllib.parse

class ProxyHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/bot") or self.path.startswith("/file"):
            # Forward request to local API server
            self.proxy_request("GET")
        else:
            # Health check
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK")

    def do_POST(self):
        if self.path.startswith("/bot") or self.path.startswith("/file"):
            self.proxy_request("POST")
        else:
            self.send_response(404)
            self.end_headers()

    def proxy_request(self, method):
        url = BOT_API_LOCAL + self.path
        if self.headers.get('Content-Type'):
            content_type = self.headers['Content-Type']
            if 'multipart/form-data' in content_type:
                # For file uploads, we need to forward the raw body
                body = self.rfile.read(int(self.headers['Content-Length']))
                resp = requests.request(method, url, data=body, headers={'Content-Type': content_type})
            else:
                body = self.rfile.read(int(self.headers['Content-Length'])) if self.headers.get('Content-Length') else None
                resp = requests.request(method, url, data=body, headers=dict(self.headers))
        else:
            body = self.rfile.read(int(self.headers['Content-Length'])) if self.headers.get('Content-Length') else None
            resp = requests.request(method, url, data=body, headers=dict(self.headers))
        self.send_response(resp.status_code)
        for k, v in resp.headers.items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(resp.content)

def start_proxy_server():
    port = int(os.environ.get("PORT", 8000))
    server = HTTPServer(("0.0.0.0", port), ProxyHandler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
# -----------------------------------------------

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        "I am Eartinity's personal video compressor bot👋👋.\nSend me a video to get started."
    )

async def video_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    # Capture original caption
    context.user_data["original_caption"] = update.message.caption or ""
    # Store file_id directly (no forwarding)
    video = update.message.video
    context.user_data["file_id"] = video.file_id
    context.user_data["user_id"] = update.message.chat_id
    context.user_data["original_msg_id"] = update.message.message_id

    keyboard = [
        [InlineKeyboardButton("Compress this video ✅", callback_data="compress")],
        [InlineKeyboardButton("Cancel the process ❌", callback_data="cancel")]
    ]
    await update.message.reply_text(
        "Video received. What would you like to do?",
        reply_markup=InlineKeyboardMarkup(keyboard)
    )

async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    data = query.data

    if data.startswith("cancel_run_"):
        run_id = data.split("_", 2)[2]
        url = f"https://api.github.com/repos/{REPO}/actions/runs/{run_id}/cancel"
        headers = {
            "Authorization": f"token {GITHUB_TOKEN}",
            "Accept": "application/vnd.github+json"
        }
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
        await query.edit_message_text(
            "Select the desired quality:",
            reply_markup=InlineKeyboardMarkup(keyboard)
        )
        return

    if data.startswith("quality_"):
        quality = data.split("_")[1]
        file_id = context.user_data.get("file_id")
        user_id = context.user_data.get("user_id")
        original_msg_id = context.user_data.get("original_msg_id")
        original_caption = context.user_data.get("original_caption", "")

        if not file_id or not user_id or not original_msg_id:
            await query.edit_message_text("Error: Missing video info.")
            return

        cancel_keyboard = InlineKeyboardMarkup([
            [InlineKeyboardButton("Cancel ❌", callback_data="cancel_pending")]
        ])
        await query.edit_message_text(
            "⏳ Triggering workflow...",
            reply_markup=cancel_keyboard
        )
        progress_msg_id = query.message.message_id

        url = f"https://api.github.com/repos/{REPO}/actions/workflows/{WF_FILE}/dispatches"
        headers = {
            "Authorization": f"token {GITHUB_TOKEN}",
            "Accept": "application/vnd.github+json"
        }
        payload = {
            "ref": "main",
            "inputs": {
                "file_id": file_id,
                "user_id": str(user_id),
                "quality": quality,
                "message_id": str(progress_msg_id),
                "original_message_id": str(original_msg_id),
                "original_caption": original_caption,
                "api_base_url": BASE_URL      # pass the bot API base URL
            }
        }
        resp = requests.post(url, json=payload, headers=headers)
        if resp.status_code != 204:
            await query.edit_message_text(f"❌ Workflow trigger failed: {resp.status_code} {resp.text}")
            return

        runs_url = f"https://api.github.com/repos/{REPO}/actions/runs?event=workflow_dispatch&per_page=1"
        runs_resp = requests.get(runs_url, headers=headers)
        run_id = None
        if runs_resp.status_code == 200:
            runs_data = runs_resp.json()
            if runs_data["total_count"] > 0:
                run_id = runs_data["workflow_runs"][0]["id"]

        if run_id:
            RUN_IDS[(user_id, progress_msg_id)] = run_id
            new_keyboard = InlineKeyboardMarkup([
                [InlineKeyboardButton("Cancel ❌", callback_data=f"cancel_run_{run_id}")]
            ])
            await query.edit_message_reply_markup(reply_markup=new_keyboard)

    elif data == "cancel_q":
        await query.edit_message_text("❌ Compression cancelled.")

async def post_init(application: Application):
    print(f"Bot started. API base URL: {BASE_URL}")

def main():
    app = Application.builder().token(os.environ["TELEGRAM_BOT_TOKEN"]).base_url(BASE_URL).post_init(post_init).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(MessageHandler(filters.VIDEO, video_handler))
    app.add_handler(CallbackQueryHandler(button_handler))
    app.run_polling()

if __name__ == "__main__":
    start_proxy_server()   # reverse proxy + health check
    main()
