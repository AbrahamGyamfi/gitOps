# Frontend Dockerfile - Multi-stage build optimized

# Stage 1: Dependencies
FROM node:18-alpine AS dependencies

WORKDIR /app

# Copy package files only (for better layer caching)
COPY package*.json ./

# Install dependencies
RUN npm install --legacy-peer-deps && npm cache clean --force

# Stage 2: Build
FROM node:18-alpine AS build

ARG BUILD_DATE
ARG VCS_REF
ARG BUILD_NUMBER

WORKDIR /app

# Copy dependencies from previous stage
COPY --from=dependencies /app/node_modules ./node_modules
COPY package*.json ./

# Copy source code
COPY public/ ./public/
COPY src/ ./src/

# Build the app
RUN npm run build

# Stage 3: Production
FROM nginx:alpine AS production

# Labels for image metadata
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.version="${BUILD_NUMBER}"
LABEL org.opencontainers.image.title="TaskFlow Frontend"
LABEL org.opencontainers.image.description="React frontend for TaskFlow application"

# Create nginx user and set permissions
RUN addgroup -g 101 -S nginx || true && \
    adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx || true && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid && \
    chown -R nginx:nginx /usr/share/nginx/html

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy build files from build stage (only production artifacts)
COPY --from=build /app/build /usr/share/nginx/html

# Switch to non-root user
# USER nginx

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget -q --spider http://localhost:80/ || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
