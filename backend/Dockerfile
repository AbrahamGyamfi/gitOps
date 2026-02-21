# Backend Dockerfile
FROM node:18-alpine

# Build arguments for metadata
ARG BUILD_DATE
ARG VCS_REF
ARG BUILD_NUMBER

# Labels for image metadata
LABEL maintainer="Abraham Gyamfi <abraham.gyamfi@dev.com>"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.version="${BUILD_NUMBER}"
LABEL org.opencontainers.image.title="TaskFlow Backend API"
LABEL org.opencontainers.image.description="Express.js backend for TaskFlow application"

# Create app directory
WORKDIR /app

# Install wget for healthcheck
RUN apk add --no-cache wget

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy backend source
COPY server.js ./

# Create a non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget -q --spider http://localhost:5000/health || exit 1

# Start the application
CMD ["node", "server.js"]
