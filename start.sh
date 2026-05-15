#!/bin/bash

# Start the local API server (uses the binary from the Docker image)
telegram-bot-api --api-id ${TELEGRAM_API_ID} --api-hash ${TELEGRAM_API_HASH} \
    --http-port 8081 --http-ip-address "0.0.0.0" --dir /tmp/telegram-bot-api --local &
BOTAPI_PID=$!

# Wait until it responds to the bot token
echo "Waiting for local API server..."
for i in $(seq 1 30); do
    if curl -s "http://127.0.0.1:8081/bot${TELEGRAM_BOT_TOKEN}/getMe" | grep -q '"ok":true'; then
        echo "Local API server ready."
        break
    fi
    sleep 1
done

# Start the bot (always works, public API for polling, proxy for workflow)
python bot.py

# Cleanup
kill $BOTAPI_PID 2>/dev/null
