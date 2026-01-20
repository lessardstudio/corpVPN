#!/bin/bash
set -e
export DOCKER_BUILDKIT=0
export COMPOSE_DOCKER_CLI_BUILD=0
docker-compose down || true
systemctl restart containerd || true
systemctl restart docker || true
docker builder prune -af || true
docker system prune -af --volumes || true
rm -rf /var/lib/docker/buildkit/* || true
docker-compose build --no-cache
docker-compose up -d

