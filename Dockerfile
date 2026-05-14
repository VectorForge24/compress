# ---- Build stage ----
FROM debian:bookworm-slim AS builder

# Install build tools and dependencies for compilation
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    make \
    cmake \
    g++ \
    libssl-dev \
    zlib1g-dev \
    libc-ares-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone and compile the Telegram Bot API server
RUN git clone --depth 1 https://github.com/tdlib/telegram-bot-api.git && \
    cd telegram-bot-api && \
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release .. && \
    cmake --build . --target telegram-bot-api -j$(nproc) && \
    cp telegram-bot-api /usr/local/bin/

# ---- Runtime stage ----
FROM debian:bookworm-slim

# Install only runtime dependencies + ffmpeg
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libssl-dev \
    zlib1g-dev \
    libc-ares-dev \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Copy the compiled binary from builder
COPY --from=builder /usr/local/bin/telegram-bot-api /usr/local/bin/telegram-bot-api

# Install Python packages (use a requirements file that includes only what’s needed)
COPY requirements.txt .
RUN pip3 install --break-system-packages -r requirements.txt

# Copy the rest of the project
COPY . .

# Make start.sh executable
RUN chmod +x start.sh

# Start both services
CMD ["bash", "start.sh"]
