FROM kong:3.5

# Install dependencies for JWT setup
RUN apt-get update && apt-get install -y curl jq nodejs && rm -rf /var/lib/apt/lists/*

# Copy Kong configuration and setup scripts
COPY kong.yml /usr/local/kong/declarative/kong.yml
COPY setup-jwt.sh /usr/local/bin/setup-jwt.sh
RUN chmod +x /usr/local/bin/setup-jwt.sh

# Kong configuration
ENV KONG_DATABASE=off
ENV KONG_DECLARATIVE_CONFIG=/usr/local/kong/declarative/kong.yml
ENV KONG_PROXY_LISTEN=0.0.0.0:8000
ENV KONG_ADMIN_LISTEN=127.0.0.1:8001
ENV KONG_STATUS_LISTEN=0.0.0.0:8100
ENV KONG_LOG_LEVEL=warn
ENV KONG_PROXY_ACCESS_LOG=/dev/stdout
ENV KONG_PROXY_ERROR_LOG=/dev/stderr
ENV KONG_REDIS_HOST=redis.railway.internal
ENV KONG_REDIS_PORT=6379
ENV PORT=8000

# Create startup script that runs Kong and configures JWT
RUN echo '#!/bin/bash' > /usr/local/bin/start-kong.sh && \
    echo 'kong start &' >> /usr/local/bin/start-kong.sh && \
    echo 'sleep 5' >> /usr/local/bin/start-kong.sh && \
    echo '/usr/local/bin/setup-jwt.sh' >> /usr/local/bin/start-kong.sh && \
    echo 'wait' >> /usr/local/bin/start-kong.sh && \
    chmod +x /usr/local/bin/start-kong.sh

EXPOSE 8000

# Use custom startup script instead of default Kong command
CMD ["/usr/local/bin/start-kong.sh"]
