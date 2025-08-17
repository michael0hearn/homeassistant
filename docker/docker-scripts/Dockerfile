# Custom Home Assistant Dockerfile
FROM homeassistant/home-assistant:stable

# Set working directory
WORKDIR /docker/homeassistant/config

# Install additional system packages
USER root
RUN apk add --no-cache \
    git \
    curl \
    wget \
    nano \
    iputils \
    net-tools \
    bash \
    tar \
    gzip

# Install additional Python packages
RUN pip3 install --no-cache-dir --root-user-action=ignore \
    pycryptodome \
    pillow \
    beautifulsoup4 \
    pyserial \
    requests \
    numpy


# Create directories for custom components and configurations
RUN mkdir -p /docker/homeassistant/config/custom_components
RUN mkdir -p /docker/homeassistant/config/www
RUN mkdir -p /docker/homeassistant/config/themes
RUN mkdir -p /docker/homeassistant/config/backups

# Create backup script directly in the container
RUN echo '#!/bin/bash' > /usr/local/bin/backup-script.sh && \
    echo 'BACKUP_DIR="/docker/homeassistant/config/backups"' >> /usr/local/bin/backup-script.sh && \
    echo 'TIMESTAMP=$(date +"%Y%m%d_%H%M%S")' >> /usr/local/bin/backup-script.sh && \
    echo 'BACKUP_NAME="homeassistant_backup_$TIMESTAMP.tar.gz"' >> /usr/local/bin/backup-script.sh && \
    echo 'mkdir -p "$BACKUP_DIR"' >> /usr/local/bin/backup-script.sh && \
    echo 'tar --exclude="$BACKUP_DIR" -czf "$BACKUP_DIR/$BACKUP_NAME" -C / config/' >> /usr/local/bin/backup-script.sh && \
    echo 'echo "Backup created: $BACKUP_NAME"' >> /usr/local/bin/backup-script.sh && \
    chmod +x /usr/local/bin/backup-script.sh

# Expose the default Home Assistant port
EXPOSE 8123

# Health check
HEALTHCHECK --interval=30s --timeout=10s \
  CMD curl -f http://localhost:8123 || exit 1

# Default command (inherited from base image)
CMD ["python", "-m", "homeassistant", "--config", "/config"]
