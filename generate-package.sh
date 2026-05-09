#!/bin/bash
set -e

PLUGIN_ID=$(grep -oP '"Id":\s*"\K[^"]+' package/metadata.json)
VERSION=$(grep -oP '"Version":\s*"\K[^"]+' package/metadata.json)
OUTPUT="${PLUGIN_ID}-${VERSION}.tar.gz"

tar -czf "$OUTPUT" --transform "s,^package,${PLUGIN_ID}," package/

echo "Created $OUTPUT"
