FROM python:3.11-slim

# Install runtime libraries that the binary needs (Ubuntu 22.04 base)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libssl3 \
    libc-ares2 \
    zlib1g \
    libstdc++6 \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download YOUR compiled binary from the release
RUN wget -q -O /usr/local/bin/telegram-bot-api \
    "https://github.com/eartinityop/compress/releases/download/botapi-binary/telegram-bot-api-linux-amd64" \
    && chmod +x /usr/local/bin/telegram-bot-api

# Install Python dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy bot code
COPY . .

# Make start.sh executable
RUN chmod +x start.sh

# Expose the port Render will use
EXPOSE 8000

# Start everything
CMD ["bash", "start.sh"]
