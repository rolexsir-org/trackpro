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
# The image runs as the unprivileged `node` user. /data is the persistent store
# volume; TRACK_STORE_PATH defaults to /data/purchases.json below.

FROM node:20-alpine

ENV NODE_ENV=production \
    PORT=8080 \
    TRACK_STORE_PATH=/data/purchases.json

WORKDIR /app

COPY package.json ./
COPY src ./src

RUN mkdir -p /data && chown -R node:node /data /app

USER node

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:8080/healthz',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

CMD ["node", "src/index.js"]
