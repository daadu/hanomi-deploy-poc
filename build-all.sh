#!/usr/bin/env bash

set -e

echo "Building all services..."

./1-worker/build.sh
echo "============"
./2-backend/build.sh
echo "============"
./3-frontend/build.sh
echo "============"
echo "All services built successfully!"