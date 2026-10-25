# syntax=docker/dockerfile:1

# ============================================================
# Build stage
# ============================================================
FROM maven:3.9-eclipse-temurin-25 AS build
WORKDIR /workspace

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Copy Maven POMs first for better layer caching
COPY pom.xml .
COPY jnode-core/pom.xml jnode-core/
COPY jnode-httpd-module/pom.xml jnode-httpd-module/
COPY jnode-mail-module/pom.xml jnode-mail-module/
COPY jnode-assembly/pom.xml jnode-assembly/
COPY jnode-assembly/distribution-stable.xml jnode-assembly/

# Resolve dependencies (cached unless pom.xml changes)
RUN mvn dependency:go-offline -Pstable -q

# Copy remaining module POMs
COPY jnode-httpd-module/pom.xml jnode-httpd-module/
COPY jnode-mail-module/pom.xml jnode-mail-module/

# Copy source code
COPY jnode-core/ jnode-core/
COPY jnode-httpd-module/ jnode-httpd-module/
COPY jnode-mail-module/ jnode-mail-module/
COPY jnode-assembly/ jnode-assembly/

# Build the distribution
RUN mvn clean package -Pstable -q

# ============================================================
# Runtime stage
# ============================================================
FROM eclipse-temurin:25-jre-noble
WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && addgroup --system jnode \
    && adduser --system --ingroup jnode jnode

# Copy assembled distribution from the build stage
COPY --from=build /workspace/jnode-assembly/target/*.zip /app/

# Extract and clean up
RUN unzip -q /app/*.zip -d /app && rm /app/*.zip

# Create required directories and set permissions
RUN mkdir -p /app/jnode/{inbound,db,log,tmp,nodelist,files,troubleshooting} \
    && chown -R jnode:jnode /app/jnode

# Copy entrypoint script
COPY docker-entrypoint.sh /app/jnode/docker-entrypoint.sh
RUN chmod +x /app/jnode/docker-entrypoint.sh \
    && chown jnode:jnode /app/jnode/docker-entrypoint.sh

WORKDIR /app/jnode

# Switch to non-root user
USER jnode

# Expose ports
EXPOSE 24554
EXPOSE 8080

# Health check (tests both BinkP and HTTPD)
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=60s \
    CMD curl -f http://localhost:8080/ || nc -z localhost 24554 || exit 1

ENTRYPOINT ["/app/jnode/docker-entrypoint.sh"]
