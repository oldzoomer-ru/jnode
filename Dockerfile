# syntax=docker/dockerfile:1

# Build stage
FROM eclipse-temurin:25-jdk-resolute AS build
WORKDIR /workspace
RUN apt-get update && apt-get install -y --no-install-recommends maven git unzip ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
COPY pom.xml .
COPY jnode-core/pom.xml jnode-core/
COPY jnode-httpd-module/pom.xml jnode-httpd-module/
COPY jnode-mail-module/pom.xml jnode-mail-module/
COPY jnode-rss-module/pom.xml jnode-rss-module/
COPY jnode-dumb-module/pom.xml jnode-dumb-module/
COPY jnode-xmpp-module/pom.xml jnode-xmpp-module/
COPY jnode-pointchecker-module/pom.xml jnode-pointchecker-module/
COPY jnode-nntp/pom.xml jnode-nntp/
COPY jnode-telegram-channel-poster/pom.xml jnode-telegram-channel-poster/
COPY jnode-assembly/pom.xml jnode-assembly/
COPY jnode-assembly/distribution-dev.xml jnode-assembly/
COPY jnode-assembly/distribution-stable.xml jnode-assembly/
COPY .git .git

# Copy source
COPY jnode-core/ jnode-core/
COPY jnode-httpd-module/ jnode-httpd-module/
COPY jnode-mail-module/ jnode-mail-module/
COPY jnode-rss-module/ jnode-rss-module/
COPY jnode-dumb-module/ jnode-dumb-module/
COPY jnode-xmpp-module/ jnode-xmpp-module/
COPY jnode-pointchecker-module/ jnode-pointchecker-module/
COPY jnode-nntp/ jnode-nntp/
COPY jnode-telegram-channel-poster/ jnode-telegram-channel-poster/
COPY docs/ docs/
COPY jdbc-drivers/ jdbc-drivers/
COPY linux/ linux/
COPY windows/ windows/
COPY LICENSE NOTICE ./

RUN mvn -pl jnode-assembly -Pall -DskipTests package -B

# Runtime stage
FROM eclipse-temurin:25-jre-resolute
WORKDIR /app

# Copy assembled distribution from the build stage
COPY --from=build /workspace/jnode-assembly/target/*.zip /app/

RUN apt-get update && apt-get install -y --no-install-recommends unzip ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && unzip /app/*.zip -d /app && rm /app/*.zip

WORKDIR /app/jnode

# Ensure logs and inbound directories are writable
RUN mkdir -p log inbound tmp db files && chmod -R 777 log inbound tmp db files

ENTRYPOINT ["java", "-cp", "lib/*:jnode.jar", "jnode.main.Main", "etc/jnode.cfg"]
