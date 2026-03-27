#!/bin/bash
set -e

REPO_NAME="plasma-wallpaper-potd-enhanced"
VERSION=$(grep -oP '"Version":\s*"\K[^"]+' package/metadata.json)
OUTPUT="${REPO_NAME}-${VERSION}.tar.gz"

tar -czf "$OUTPUT" --transform "s,^package,${REPO_NAME}," package/

echo "Created $OUTPUT"
