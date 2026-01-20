#!/bin/bash

# ==============================================================================
# Blitz Build Fixer
# ==============================================================================

set -e

echo "🔧 Starting Blitz build fix..."

# 1. Check if source exists locally (on server)
if [ -d "blitz_source" ] && [ -f "blitz_source/requirements.txt" ]; then
    echo "✅ blitz_source exists and contains requirements.txt"
    NEED_DOWNLOAD=false
else
    echo "⚠️  blitz_source is empty or missing requirements.txt"
    NEED_DOWNLOAD=true
fi

# 2. Download source if needed
if [ "$NEED_DOWNLOAD" = true ]; then
    echo "📥 Downloading Blitz source from GitHub..."
    rm -rf blitz_source
    git clone --depth 1 https://github.com/ReturnFI/Blitz.git blitz_source
    echo "✅ Source downloaded"
fi

# 3. Rebuild containers
echo "🐳 Rebuilding Blitz container..."
docker-compose build --no-cache blitz

# 4. Restart services
echo "🚀 Restarting services..."
docker-compose up -d

echo "✅ Fix complete! Check status with: docker-compose ps"
