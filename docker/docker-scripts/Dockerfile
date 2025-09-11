# Custom Home Assistant Dockerfile
FROM homeassistant/home-assistant:stable

# Set working directory to match Home Assistant expectations
WORKDIR /config

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
    gzip \
    unzip

# Install additional Python packages
RUN pip3 install --no-cache-dir --root-user-action=ignore \
    pycryptodome \
    pillow \
    beautifulsoup4 \
    pyserial \
    requests \
    numpy

# Create directories for custom components and configurations
RUN mkdir -p /config/custom_components \
    /config/www \
    /config/themes \
    /config/backups

# Create HACS installation script for runtime
RUN echo '#!/bin/bash' > /usr/local/bin/install-hacs.sh && \
    echo 'if [ ! -d "/config/custom_components/hacs" ]; then' >> /usr/local/bin/install-hacs.sh && \
    echo '  echo "Installing HACS..."' >> /usr/local/bin/install-hacs.sh && \
    echo '  mkdir -p /config/custom_components' >> /usr/local/bin/install-hacs.sh && \
    echo '  cd /config/custom_components' >> /usr/local/bin/install-hacs.sh && \
    echo '  wget -q https://github.com/hacs/integration/releases/latest/download/hacs.zip' >> /usr/local/bin/install-hacs.sh && \
    echo '  unzip -q hacs.zip' >> /usr/local/bin/install-hacs.sh && \
    echo '  rm hacs.zip' >> /usr/local/bin/install-hacs.sh && \
    echo '  echo "HACS installed successfully"' >> /usr/local/bin/install-hacs.sh && \
    echo 'else' >> /usr/local/bin/install-hacs.sh && \
    echo '  echo "HACS already installed"' >> /usr/local/bin/install-hacs.sh && \
    echo 'fi' >> /usr/local/bin/install-hacs.sh && \
    chmod +x /usr/local/bin/install-hacs.sh

# Create backup script with corrected paths
RUN echo '#!/bin/bash' > /usr/local/bin/backup-script.sh && \
    echo 'BACKUP_DIR="/config/backups"' >> /usr/local/bin/backup-script.sh && \
    echo 'TIMESTAMP=$(date +"%Y%m%d_%H%M%S")' >> /usr/local/bin/backup-script.sh && \
    echo 'BACKUP_NAME="homeassistant_backup_$TIMESTAMP.tar.gz"' >> /usr/local/bin/backup-script.sh && \
    echo 'mkdir -p "$BACKUP_DIR"' >> /usr/local/bin/backup-script.sh && \
    echo 'cd /config && tar --exclude="backups" -czf "$BACKUP_DIR/$BACKUP_NAME" .' >> /usr/local/bin/backup-script.sh && \
    echo 'echo "Backup created: $BACKUP_NAME"' >> /usr/local/bin/backup-script.sh && \
    echo 'find "$BACKUP_DIR" -name "*.tar.gz" -mtime +30 -delete' >> /usr/local/bin/backup-script.sh && \
    echo 'echo "Old backups cleaned up"' >> /usr/local/bin/backup-script.sh && \
    chmod +x /usr/local/bin/backup-script.sh

# Create startup script that installs HACS and starts HA
RUN echo '#!/bin/bash' > /usr/local/bin/start-homeassistant.sh && \
    echo '/usr/local/bin/install-hacs.sh' >> /usr/local/bin/start-homeassistant.sh && \
    echo 'exec python -m homeassistant --config /config "$@"' >> /usr/local/bin/start-homeassistant.sh && \
    chmod +x /usr/local/bin/start-homeassistant.sh

# Set proper permissions for config directory
RUN chown -R root:root /config

# Expose the default Home Assistant port
EXPOSE 8123

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s \
  CMD curl -f http://localhost:8123 || exit 1

# Use the startup script as the default command
CMD ["/usr/local/bin/start-homeassistant.sh"]
