#!/bin/bash

# Fake systemctl for Docker container using supervisord

COMMAND=$1
SERVICE=$2

if [ "$SERVICE" == "hysteria-server.service" ] || [ "$SERVICE" == "hysteria-server" ]; then
    SUPERVISOR_SERVICE="hysteria"
elif [ "$SERVICE" == "hysteria-webpanel.service" ] || [ "$SERVICE" == "hysteria-webpanel" ]; then
    SUPERVISOR_SERVICE="webpanel"
else
    # Fallback or ignore
    echo "Ignoring systemctl command for unknown service: $SERVICE"
    exit 0
fi

case "$COMMAND" in
    start)
        supervisorctl start $SUPERVISOR_SERVICE
        ;;
    stop)
        supervisorctl stop $SUPERVISOR_SERVICE
        ;;
    restart)
        supervisorctl restart $SUPERVISOR_SERVICE
        ;;
    status)
        supervisorctl status $SUPERVISOR_SERVICE
        ;;
    enable)
        echo "Enabled $SERVICE (noop in Docker)"
        ;;
    disable)
        echo "Disabled $SERVICE (noop in Docker)"
        ;;
    is-active)
        STATUS=$(supervisorctl status $SUPERVISOR_SERVICE)
        if [[ "$STATUS" == *"RUNNING"* ]]; then
            exit 0
        else
            exit 1
        fi
        ;;
    *)
        echo "Unknown command: $COMMAND"
        exit 1
        ;;
esac
