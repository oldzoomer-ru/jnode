#!/bin/sh
# jNode Docker Entrypoint
# Handles initialization, permissions, and graceful shutdown

set -e

# Create required directories if they don't exist
mkdir -p /app/jnode/{inbound,db,log,tmp,nodelist,files,troubleshooting}

# Set proper ownership to jnode user
chown -R jnode:jnode /app/jnode

# Handle graceful shutdown
shutdown() {
    echo "Received shutdown signal, stopping jNode gracefully..."
    if [ -n "$JAVA_PID" ]; then
        kill -TERM "$JAVA_PID" 2>/dev/null
        wait "$JAVA_PID" 2>/dev/null
    fi
    echo "jNode stopped."
}

trap shutdown TERM INT

# Start jNode
echo "Starting jNode..."
exec java \
    -Xms${JNODE_XMS:-128m} \
    -Xmx${JNODE_XMX:-512m} \
    -server \
    -Djava.awt.headless=true \
    -Dfile.encoding=${JNODE_ENCODING:-UTF-8} \
    ${JNODE_OPTS:-} \
    -cp "/app/jnode/lib/*" \
    jnode.main.Main \
    etc/jnode.cfg "$@"
