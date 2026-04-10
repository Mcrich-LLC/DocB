#!/bin/bash
set -e

# Generate documentation for DocBCore package using Swift Package Manager
# This bypasses xcodebuild and docc archive processing, simplifying CI deployment.
swift package \
    --allow-writing-to-directory ./docs \
    generate-documentation --target DocBCore \
    --disable-indexing \
    --transform-for-static-hosting \
    --hosting-base-path / \
    --experimental-skip-synthesized-symbols \
    --output-path ./docs

echo "Documentation generated successfully in ./docs"
