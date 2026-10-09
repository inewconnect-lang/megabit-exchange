# Megabit Exchange - production image
FROM node:22-bookworm-slim AS deps
WORKDIR /app
# Build tools are only used if no prebuilt better-sqlite3 binary exists for this platform.
RUN apt-get update && apt-get install -y --no-install-recommends python3 make g++ && rm -rf /var/lib/apt/lists/*
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

FROM node:22-bookworm-slim
ENV NODE_ENV=production \
    PORT=3000 \
    HOST=0.0.0.0 \
    DATABASE_PATH=/app/data/megabit.db
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY server ./server
COPY shared ./shared
COPY public ./public
COPY content ./content
COPY scripts ./scripts
RUN mkdir -p /app/data && chown -R node:node /app/data
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
STOPSIGNAL SIGTERM
CMD ["node", "server/index.js"]
