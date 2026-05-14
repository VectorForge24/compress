# Stage 1 – extract the Telegram Bot API server binary
FROM aiogram/telegram-bot-api:latest AS botapi

# Stage 2 – Python environment + runtime deps
FROM python:3.11-slim

# Install only runtime libraries needed by the server binary + ffmpeg
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libssl-dev \
    zlib1g-dev \
    libc-ares-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy the Bot API server binary from stage 1
COPY --from=botapi /usr/local/bin/telegram-bot-api /usr/local/bin/telegram-bot-api

# Install Python dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy bot code
COPY . .

# Start script (already provided by you)
CMD ["bash", "start.sh"]
