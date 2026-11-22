# Track Pro billing verification service.
#
# Build:
#   docker build -t trackpro-billing ./billing_server
#
# Run (the three secrets are NOT baked into the image):
#   docker run --rm -p 8080:8080 \
#     -e TRACK_BILLING_API_KEYS="$TRACK_BILLING_API_KEYS" \
#     -e TRACK_RTDN_SECRET="$TRACK_RTDN_SECRET" \
#     -v "$PWD/play-service-account.json:/run/secrets/play-service-account.json:ro" \
#     -e GOOGLE_APPLICATION_CREDENTIALS=/run/secrets/play-service-account.json \
#     -v trackpro-billing-data:/data \
#     trackpro-billing
#
# The image stores purchases in /data/purchases.json. The entrypoint (as root)
# makes /data writable by the unprivileged `node` user, then runs the service as
# `node`. This is what lets a Railway Volume mounted at /data be written to by a
# non-root process.

FROM node:20-alpine

ENV NODE_ENV=production \
    PORT=8080 \
    TRACK_STORE_PATH=/data/purchases.json

WORKDIR /app

COPY package.json package-lock.json ./
COPY src ./src
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN mkdir -p /data \
    && chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:8080/healthz',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

ENTRYPOINT ["docker-entrypoint.sh"]
