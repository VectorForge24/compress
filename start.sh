#!/bin/bash
set -e

# Start local Telegram Bot API server (background)
telegram-bot-api --api-id ${TELEGRAM_API_ID} --api-hash ${TELEGRAM_API_HASH} \
    --http-port 8081 --http-ip-address "0.0.0.0" --dir /tmp/telegram-bot-api --local &
BOTAPI_PID=$!

# Wait for it
echo "Waiting for local Bot API server..."
for i in $(seq 1 30); do
    if curl -s http://127.0.0.1:8081/getMe | grep -q '"ok":true'; then
        echo "Local Bot API server ready."
        break
    fi
    sleep 1
done

# Delete any existing webhook (public API) and start the bot
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/deleteWebhook" > /dev/null
python bot.py

kill $BOTAPI_PID 2>/dev/null
