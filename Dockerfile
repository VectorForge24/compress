FROM python:3.11-slim

# Install system deps + ffmpeg + build tools + cmake
RUN apt-get update && apt-get install -y \
    ffmpeg \
    git \
    make \
    g++ \
    cmake \
    libssl-dev \
    zlib1g-dev \
    libc-ares-dev \
    && rm -rf /var/lib/apt/lists/*

# Compile Telegram Bot API server (local)
RUN git clone --depth 1 https://github.com/tdlib/telegram-bot-api.git && \
    cd telegram-bot-api && \
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release .. && \
    cmake --build . --target telegram-bot-api -j$(nproc) && \
    cp telegram-bot-api /usr/local/bin/ && \
    cd / && rm -rf telegram-bot-api

# Install Python dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy bot code
COPY . .

# Start script (bot + API server)
CMD ["bash", "start.sh"]
