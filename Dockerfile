# Production-ready Habitica image built for docker-compose deployments
FROM node:20-bookworm AS builder

RUN apt-get update \
  && apt-get install -y --no-install-recommends git \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/habitica

# Install server and client dependencies upfront for reproducible builds
COPY package*.json ./
COPY website/client/package*.json website/client/
RUN npm ci && cd website/client && npm ci

# Copy the full source into the build context
COPY . .

# Provide a default config so the container can boot without extra files
RUN cp config.json.example config.json

# Build backend and frontend assets
RUN npm run postinstall \
  && npm run client:build \
  && gulp build:prod

# Trim build-only dependencies before assembling the runtime image
RUN rm -rf node_modules website/client/node_modules

FROM node:20-bookworm-slim AS runner

ENV NODE_ENV=production
RUN apt-get update \
  && apt-get install -y --no-install-recommends git \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /usr/src/habitica

# Install only production dependencies
COPY --from=builder /usr/src/habitica/package*.json ./
COPY --from=builder /usr/src/habitica/website/client/package*.json website/client/
RUN npm ci --omit=dev && cd website/client && npm ci --omit=dev

# Bring in the compiled application artifacts
COPY --from=builder /usr/src/habitica .

EXPOSE 3000
CMD ["npm", "run", "start:simple"]
