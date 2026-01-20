FROM python:3.11-slim

WORKDIR /app

# Set non-interactive frontend for apt
ARG DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    git \
    procps \
    iptables \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Install Hysteria2 binary
RUN curl -Lo /usr/local/bin/hysteria https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64 \
    && chmod +x /usr/local/bin/hysteria

# Copy Blitz source code
COPY blitz_source/ /etc/hysteria/

# Debug file structure
RUN ls -la /etc/hysteria/

# Install Python dependencies
RUN pip install --no-cache-dir -r /etc/hysteria/requirements.txt

# Patch MongoDB connection to use 'mongo' service
RUN sed -i 's/localhost:27017/mongo:27017/g' /etc/hysteria/core/scripts/db/database.py

# Patch app.py to listen on 0.0.0.0:8000
RUN sed -i "s/config.bind = \['127.0.0.1:28260'\]/config.bind = ['0.0.0.0:8000']/g" /etc/hysteria/core/scripts/webpanel/app.py

# Setup Fake systemctl
COPY blitz_docker/systemctl.sh /usr/local/bin/systemctl
RUN chmod +x /usr/local/bin/systemctl

# Setup Supervisor config
COPY blitz_docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Setup entrypoint
COPY blitz_docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Environment variables
ENV PYTHONPATH=/etc/hysteria/core

EXPOSE 8000 443/udp 443/tcp

ENTRYPOINT ["/entrypoint.sh"]
