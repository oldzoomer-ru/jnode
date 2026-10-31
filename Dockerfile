# syntax=docker/dockerfile:1

# ============================================================
# Build stage
# ============================================================
# Используем образ Maven на базе Alpine для минимизации размера и консистентности
FROM maven:3.9-eclipse-temurin-25-alpine AS build
WORKDIR /workspace

# Установка зависимостей сборки через apk
RUN apk add --no-cache \
    git \
    unzip \
    ca-certificates

# Копируем Maven POM файлы первыми для оптимального кэширования слоев Docker
COPY pom.xml .
COPY jnode-core/pom.xml jnode-core/
COPY jnode-httpd-module/pom.xml jnode-httpd-module/
COPY jnode-mail-module/pom.xml jnode-mail-module/
COPY jnode-assembly/pom.xml jnode-assembly/
COPY jnode-assembly/distribution-stable.xml jnode-assembly/

# Загрузка зависимостей (выполняется повторно только при изменении pom.xml)
RUN mvn dependency:go-offline -Pstable -q

# Копируем исходный код
COPY jnode-core/ jnode-core/
COPY jnode-httpd-module/ jnode-httpd-module/
COPY jnode-mail-module/ jnode-mail-module/
COPY jnode-assembly/ jnode-assembly/

# Сборка дистрибутива
RUN mvn clean package -Pstable -q

# ============================================================
# Runtime stage
# ============================================================
FROM eclipse-temurin:25-jre-alpine
WORKDIR /app

# Установка зависимостей времени выполнения и создание системного пользователя jnode
RUN apk add --no-cache \
    unzip \
    curl \
    ca-certificates \
    && addgroup -S jnode \
    && adduser -S -G jnode jnode

# Копируем собранный архив из этапа сборки
COPY --from=build /workspace/jnode-assembly/target/*.zip /app/

# Распаковка архива и удаление временного файла zip
RUN unzip -q /app/*.zip -d /app \
    && rm /app/*.zip

# Создание необходимых директорий и настройка прав для пользователя jnode
RUN mkdir -p /app/jnode/{inbound,db,log,tmp,nodelist,files,troubleshooting} \
    && chown -R jnode:jnode /app/jnode

# Копирование скрипта точки входа и установка прав на выполнение
COPY docker-entrypoint.sh /app/jnode/docker-entrypoint.sh
RUN chmod +x /app/jnode/docker-entrypoint.sh \
    && chown jnode:jnode /app/jnode/docker-entrypoint.sh

WORKDIR /app/jnode

# Переключение на непривилегированного пользователя jnode
USER jnode

# Открытие портов (BinkP и HTTPD)
EXPOSE 24554
EXPOSE 8080

# Проверка работоспособности (Health check)
# Обратите внимание: синтаксис netcat (nc) в Alpine (BusyBox) отличается от Debian
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=60s \
    CMD curl -f http://localhost:8080/ || nc -w 1 localhost 24554 || exit 1

ENTRYPOINT ["/app/jnode/docker-entrypoint.sh"]
