#!/bin/bash
set -e

# Start Telegram Bot API server in background, listening on port 8081 (internal only)
telegram-bot-api --api-id ${TELEGRAM_API_ID} --api-hash ${TELEGRAM_API_HASH} \
    --http-port 8081 --dir /tmp/telegram-bot-api --local &
BOTAPI_PID=$!

# Wait a moment for it to start
sleep 2

# Start the Python bot (our reverse proxy)
python bot.py

# If bot exits, kill the API server
kill $BOTAPI_PID 2>/dev/null
