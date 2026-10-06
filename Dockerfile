# syntax=docker/dockerfile:1

# ---- Build stage ----
# Compiles the TypeScript sources into dist/ using the full dev dependencies.
FROM node:22-alpine AS build
WORKDIR /app

# Install all dependencies (incl. devDependencies) using the lockfile for
# reproducible builds.
COPY package.json package-lock.json ./
RUN npm ci

# Compile TypeScript -> dist/
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# ---- Dependencies stage ----
# Resolve a clean, production-only node_modules to keep the final image small.
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# ---- Runtime stage ----
FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production \
    PORT=3000 \
    HOST=0.0.0.0

# Only ship production deps and compiled output.
COPY package.json ./
COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist

# Run as the unprivileged user that ships with the node image.
USER node

EXPOSE 3000

CMD ["node", "dist/server.js"]
