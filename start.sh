#!/bin/bash
set -e

# Start the local Telegram Bot API server (background)
telegram-bot-api --api-id ${TELEGRAM_API_ID} --api-hash ${TELEGRAM_API_HASH} \
    --http-port 8081 --http-ip-address "0.0.0.0" --dir /tmp/telegram-bot-api --local &
BOTAPI_PID=$!

# Wait until the local server is ready
echo "Waiting for local Bot API server..."
for i in $(seq 1 30); do
    if curl -s http://127.0.0.1:8081/getMe | grep -q '"ok":true'; then
        echo "Local Bot API server ready."
        break
    fi
    sleep 1
done

# Delete any existing webhook so that polling can work
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/deleteWebhook" > /dev/null

# Start the Python bot (polling + reverse proxy)
python bot.py

# If the bot exits, stop the local API server
kill $BOTAPI_PID 2>/dev/null
