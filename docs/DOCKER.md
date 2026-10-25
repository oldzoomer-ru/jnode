# jNode FTN Node - Docker Deployment

## Overview

jNode is a FTN (FidoNet) node software providing mailer, tosser, and tracker functionality in a single Java application.

### Features

- BinkP/1.1 protocol support for bundle exchange
- SQL database storage (H2, PostgreSQL, MySQL, SQLite, etc.)
- HTTPD web module for web-based interface
- Mail module with SMTP support
- File echo management
- NNTP support (via module)
- XMPP integration (via module)
- Point checker (via module)
- RSS module (via module)
- Telegram channel poster (via module)

### Docker Features

- Multi-stage build for minimal image size
- Non-root user for security
- Graceful shutdown handling
- Health checks for BinkP and HTTPD
- Volume-based persistent storage
- Optional database services (PostgreSQL, MySQL)
- H2 Console for database administration
- Environment-based configuration
- Compressed backup support

## Quick Start

### 1. Prepare Configuration

Copy and customize the environment file:

```bash
cp .env.example .env
# Edit .env with your settings
```

### 2. Using H2 Database (Default)

```bash
# Build and start
docker compose up -d --build

# Check logs
docker compose logs -f jnode

# View status
docker compose ps
```

### 3. Using PostgreSQL

```bash
# Start with PostgreSQL profile
docker compose --profile postgres up -d --build

# Update docs/configs/jnode.conf:
#   jdbc.url = jdbc:postgresql://postgres:5432/jnode
#   jdbc.user = jnode
#   jdbc.pass = <your_password>
```

### 4. Using MySQL

```bash
# Start with MySQL profile
docker compose --profile mysql up -d --build

# Update docs/configs/jnode.conf:
#   jdbc.url = jdbc:mysql://mysql:3306/jnode
#   jdbc.user = jnode
#   jdbc.pass = <your_password>
```

## Configuration

### Environment Variables

| Variable              | Default      | Description              |
|-----------------------|--------------|--------------------------|
| `TZ`                  | `UTC`        | Timezone                 |
| `JNODE_XMS`           | `128m`       | Minimum Java heap size   |
| `JNODE_XMX`           | `512m`       | Maximum Java heap size   |
| `JNODE_OPTS`          | (empty)      | Additional JVM options   |
| `JNODE_ENCODING`      | `UTF-8`      | File encoding            |
| `BINKP_PORT`          | `24554`      | Host port for BinkP      |
| `HTTPD_PORT`          | `8080`       | Host port for HTTPD      |
| `POSTGRES_DB`         | `jnode`      | PostgreSQL database name |
| `POSTGRES_USER`       | `jnode`      | PostgreSQL username      |
| `POSTGRES_PASSWORD`   | `jnode`      | PostgreSQL password      |
| `POSTGRES_PORT`       | `5432`       | Host port for PostgreSQL |
| `MYSQL_DATABASE`      | `jnode`      | MySQL database name      |
| `MYSQL_USER`          | `jnode`      | MySQL username           |
| `MYSQL_PASSWORD`      | `jnode`      | MySQL password           |
| `MYSQL_ROOT_PASSWORD` | `jnode_root` | MySQL root password      |
| `MYSQL_PORT`          | `3306`       | Host port for MySQL      |
| `H2_CONSOLE_PORT`     | `9092`       | Host port for H2 Console |

### Docker Compose Profiles

| Profile      | Service    | Description          |
|--------------|------------|----------------------|
| *(default)*  | jnode      | Main application     |
| `postgres`   | postgres   | PostgreSQL database  |
| `mysql`      | mysql      | MySQL database       |
| `h2-console` | h2-console | H2 database admin UI |

Example:

```bash
# Start with PostgreSQL and H2 Console
docker compose --profile postgres --profile h2-console up -d
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

| Volume                | Path Inside Container        | Purpose              |
|-----------------------|------------------------------|----------------------|
| jnode-etc             | `docs/configs/` (bind mount) | Configuration files  |
| jnode-db              | `/app/jnode/db`              | Database files       |
| jnode-log             | `/app/jnode/log`             | Application logs     |
| jnode-inbound         | `/app/jnode/inbound`         | Incoming bundles     |
| jnode-nodelist        | `/app/jnode/nodelist`        | FTN nodelist         |
| jnode-tmp             | `/app/jnode/tmp`             | Temporary files      |
| jnode-files           | `/app/jnode/files`           | File echos           |
| jnode-troubleshooting | `/app/jnode/troubleshooting` | Debug packet storage |
| postgres-data         | `/var/lib/postgresql/data`   | PostgreSQL data      |
| mysql-data            | `/var/lib/mysql`             | MySQL data           |

## Management Commands

```bash
# Start services
docker compose up -d

# Start with specific profiles
docker compose --profile postgres up -d
docker compose --profile postgres --profile h2-console up -d

# Stop services
docker compose down

# Stop and remove volumes (WARNING: deletes all data!)
docker compose down -v

# Restart services
docker compose restart jnode

# View logs
docker compose logs -f jnode

# Execute commands inside container
docker compose exec jnode java -version
docker compose exec jnode ls -la /app/jnode/

# Backup
./scripts/backup.sh

# Restore from backup
# 1. Stop services
docker compose down
# 2. Extract backup
tar xzf jnode-backup-YYYYMMDD-HHMMSS.tar.gz -C /
# 3. Restore volumes (see backup MANIFEST.txt)
# 4. Start services
docker compose up -d
```

## Health Check

The jnode service includes a health check that monitors both HTTPD and BinkP:

```bash
# Check health status
docker compose ps

# Expected output:
# NAME                STATUS
# jnode               Up (healthy)
# jnode-postgres      Up (healthy)
```

## Resource Limits

Default resource limits (in `docker-compose.yml`):

| Resource | Limit     | Reservation |
|----------|-----------|-------------|
| CPU      | 2.0 cores | 0.5 cores   |
| Memory   | 1 GB      | 256 MB      |

To customize, edit the `deploy.resources` section in `docker-compose.yml`.

## Backup

### Automated Backup

```bash
# Full backup with compression
./scripts/backup.sh

# Backup to custom directory
./scripts/backup.sh /path/to/backups

# List backups
ls -la ./backups/
```

### Manual Backup

```bash
# Backup H2 database
docker compose exec jnode cp /app/jnode/db/jnode.mv.db /app/jnode/tmp/backup.db
docker compose cp jnode:/app/jnode/tmp/backup.db ./backup.db

# Backup PostgreSQL
docker compose exec jnode-postgres pg_dump -U jnode jnode > backup.sql

# Backup MySQL
docker compose exec jnode-mysql mysqldump -u jnode -p jnode > backup.sql

# Backup configuration
tar czf configs-backup.tar.gz docs/configs/
```

### Restore Database

```bash
# Restore H2 database
docker compose cp ./backup.db jnode:/app/jnode/db/jnode.mv.db
docker compose restart jnode

# Restore PostgreSQL
docker compose exec -T jnode-postgres psql -U jnode jnode < backup.sql

# Restore MySQL
docker compose exec -T jnode-mysql mysql -u jnode -p jnode < backup.sql
```

## Configuration Files

Located in `docs/configs/`:

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

## Troubleshooting

### Container won't start

```bash
# Check logs
docker compose logs jnode

# Check if ports are available
netstat -tlnp | grep -E '24554|8080'

# Verify configuration
docker compose config
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

# Connect to database
docker compose exec jnode-postgres psql -U jnode -d jnode
```

For MySQL:

```bash
# Check MySQL logs
docker compose logs mysql

# Verify connection
docker compose exec jnode mysql -h mysql -u jnode -p jnode -e "SELECT 1"

# Connect to database
docker compose exec jnode-mysql mysql -u jnode -p jnode
```

### BinkP connection issues

```bash
# Check if port is listening
docker compose exec jnode netstat -tlnp | grep 24554

# Test connection from host
telnet localhost 24554

# Check container network
docker compose exec jnode cat /etc/hosts
```

### Web interface not accessible

```bash
# Check HTTPD module logs
docker compose logs jnode | grep httpd

# Test locally
curl http://localhost:8080/

# Check health
docker inspect --format='{{.State.Health.Status}}' jnode
```

### Running as non-root

The container runs as the `jnode` user (UID 1000). If you need to fix permissions:

```bash
# Fix volume permissions
docker run --rm -v jnode-db:/data alpine chown -R 1000:1000 /data

# Execute as root (for debugging only)
docker compose exec --user root jnode sh
```

### Database corruption recovery

If H2 database gets corrupted:

```bash
# Stop jnode
docker compose stop jnode

# Backup corrupted files
docker compose exec jnode cp -r /app/jnode/db /app/jnode/tmp/db-backup

# Start fresh (WARNING: loses all data)
docker compose down -v
docker compose up -d
```

## Development

### Build locally

```bash
# Build image only
docker build -t jnode:dev -f Dockerfile .

# Build with debug profile (includes all modules)
# Edit Dockerfile to use -Pall instead of -Pstable
```

### Interactive debugging

```bash
# Start shell in container
docker compose exec jnode sh

# Start with root access
docker compose exec --user root jnode sh

# Run with debug flags
docker compose run --rm jnode java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 -cp "/app/jnode/lib/*" jnode.main.Main etc/jnode.cfg
```

### DevContainer

The project includes VS Code DevContainer support with Docker-in-Docker:

```bash
# Open in VS Code
code .

# Or use the CLI
code --folder-uri .
```

The DevContainer provides:

- Java 25 development environment
- Docker-in-Docker for building/testing images
- Docker Compose support

## Security Notes

1. **Change default passwords** - Update `POSTGRES_PASSWORD` and `MYSQL_PASSWORD` in `.env`
2. **Non-root user** - Container runs as `jnode` user, not root
3. **Minimal base image** - Uses `eclipse-temurin:25-jre-noble` (no unnecessary packages)
4. **Read-only config** - Configuration is bind-mounted, not baked into image
5. **Resource limits** - CPU and memory limits prevent resource exhaustion
