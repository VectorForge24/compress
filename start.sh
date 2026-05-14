#!/bin/bash
set -e

# Start Telegram Bot API server in background
telegram-bot-api --api-id ${TELEGRAM_API_ID} --api-hash ${TELEGRAM_API_HASH} \
    --http-port 8081 --dir /tmp/telegram-bot-api --local &
BOTAPI_PID=$!

# Wait until the API server is actually ready
echo "Waiting for Bot API server to become ready..."
for i in $(seq 1 30); do
    if curl -s http://localhost:8081/getMe >/dev/null 2>&1; then
        echo "Bot API server is ready."
        break
    fi
    sleep 1
done

# If still not ready after 30s, kill and exit
if ! kill -0 $BOTAPI_PID 2>/dev/null; then
    echo "Bot API server failed to start."
    exit 1
fi

# Start the Python bot (polling + reverse proxy)
python bot.py

# If bot exits, stop the API server
kill $BOTAPI_PID 2>/dev/null
