# ==========================================
# Stage 1: Build Flutter Web Application
# ==========================================
FROM debian:bookworm-slim AS build-env

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Clone Flutter SDK (stable channel)
RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter

# Set PATH for Flutter and Dart
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Verify Flutter installation and enable web support
RUN flutter doctor -v
RUN flutter config --enable-web

# Set working directory inside container
WORKDIR /app

# Copy project files
COPY . .

# Clean and resolve project dependencies
RUN flutter clean
RUN flutter pub get

# Build the Flutter web application in release mode
RUN flutter build web --release

# ==========================================
# Stage 2: Serve using Nginx
# ==========================================
FROM nginx:alpine

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy build artifacts from stage 1 to Nginx directory
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Expose HTTP port
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
