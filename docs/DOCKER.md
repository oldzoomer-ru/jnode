# jNode FTN Node - Docker Deployment

## Overview

jNode is a FTN (FidoNet) node software providing mailer, tosser, and tracker functionality in a single Java application.

### Features

- BinkP/1.1 protocol support for bundle exchange
- SQL database storage (H2, PostgreSQL, MySQL, SQLite, etc.)
- HTTPD web module for web-based interface
- Mail module with SMTP support
- File echo management
- NNTP support
- XMPP integration
- Point checker
- RSS module
- Telegram channel poster

## Quick Start

### 1. Using H2 Database (Default)

```bash
# Build and start
docker compose up -d --build

# Check logs
docker compose logs -f jnode

# View status
docker compose ps
```

### 2. Using PostgreSQL

1. Uncomment the `postgres` service in `docker-compose.yml`
2. Update `jnode-etc/jnode.conf` JDBC URL:

   ```
   jdbc.url = jdbc:postgresql://postgres:5432/jnode
   jdbc.user = jnode
   jdbc.pass = jnode
   ```

3. Start services:

   ```bash
   docker compose up -d --build
   ```

### 3. Using MySQL

1. Uncomment the `mysql` service in `docker-compose.yml`
2. Update `jnode-etc/jnode.conf` JDBC URL:

   ```
   jdbc.url = jdbc:mysql://mysql:3306/jnode
   jdbc.user = jnode
   jdbc.pass = jnode
   ```

3. Start services:

   ```bash
   docker compose up -d --build
   ```

## Ports

| Port  | Service          | Protocol |
|-------|------------------|----------|
| 24554 | BinkP            | FTN Bundle Exchange |
| 8080  | HTTPD            | Web Interface |
| 5432  | PostgreSQL       | Database (optional) |
| 3306  | MySQL            | Database (optional) |
| 9092  | H2 Console       | Database Admin (optional) |

## Volumes

| Volume              | Path Inside Container      | Purpose                    |
|---------------------|----------------------------|----------------------------|
| jnode-etc           | /app/jnode/etc             | Configuration files        |
| jnode-db            | /app/jnode/db              | Database files             |
| jnode-log           | /app/jnode/log             | Application logs           |
| jnode-inbound       | /app/jnode/inbound         | Incoming bundles           |
| jnode-nodelist      | /app/jnode/nodelist        | FTN nodelist               |
| jnode-tmp           | /app/jnode/tmp             | Temporary files            |
| jnode-files         | /app/jnode/files           | File echos                 |
| jnode-troubleshooting | /app/jnode/troubleshooting | Debug packet storage       |

## Configuration

### Main Configuration Files

Located in `jnode-etc` volume:

1. **jnode.conf** - Main node configuration
   - Node name, address, location
   - BinkP settings
   - Database connection
   - Module loading

2. **httpd_module.conf** - HTTP web module
   - Web server port
   - Bind address
   - Registration settings

3. **mail_module.conf** - Email module
   - SMTP settings
   - From address

### Example jnode.conf

```
# Node's name
info.stationname = My FTN Node

# Node's location
info.location = Moscow, Russia

# Sysop name
info.sysop = Ivan Sysop

# Node's FTN address
info.address = 2:5020/1234

# JDBC URL (H2)
jdbc.url = jdbc:h2:/app/jnode/etc/jnode
jdbc.user = jnode
jdbc.pass = jnode

# BinkP settings
binkp.server = true
binkp.client = true
binkp.bind = 0.0.0.0
binkp.port = 24554
binkp.inbound = /app/jnode/inbound

# Modules
modules = org.jnode.httpd.HttpdModule:/app/jnode/etc/httpd_module.conf,org.jnode.mail.MailModule:/app/jnode/etc/mail_module.conf
```

## Management Commands

```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# Restart services
docker compose restart jnode

# View logs
docker compose logs -f jnode

# Execute commands inside container
docker compose exec jnode java -version
docker compose exec jnode ls -la /app/jnode/

# Backup database
docker compose exec jnode cp /app/jnode/db/jnode.mv.db /app/jnode/tmp/backup.db
docker compose cp jnode:/app/jnode/tmp/backup.db ./backup.db

# Restore database
docker compose cp ./backup.db jnode:/app/jnode/db/jnode.mv.db
docker compose restart jnode

# Access H2 Console (if enabled)
# Open http://localhost:9092 in browser
```

## Health Check

The jnode service includes a health check that monitors the HTTPD module:

```bash
# Check health status
docker compose ps

# Expected output:
# NAME                STATUS
# jnode               Up (healthy)
```

## Troubleshooting

### Container won't start

```bash
# Check logs
docker compose logs jnode

# Check if ports are available
netstat -tlnp | grep -E '24554|8080'
```

### Database connection issues

For H2 (default):

```bash
# Verify database files exist
docker compose exec jnode ls -la /app/jnode/db/
```

For PostgreSQL:

```bash
# Check PostgreSQL logs
docker compose logs postgres

# Verify connection
docker compose exec jnode pg_isready -h postgres -p 5432
```

### BinkP connection issues

```bash
# Check if port is listening
docker compose exec jnode netstat -tlnp | grep 24554

# Test connection from host
telnet localhost 24554
```

### Web interface not accessible

```bash
# Check HTTPD module logs
docker compose logs jnode | grep httpd

# Test locally
curl http://localhost:8080/
```

## Security Notes

1. Change default database passwords
2. Use strong passwords for SMTP and XMPP
3. Consider binding HTTPD to 127.0.0.1 if not exposing publicly
4. Keep jNode updated to latest version
5. Regularly backup database and configuration
