#!/bin/bash
set -e

# Install Nixpacks if not present
if ! command -v nixpacks &> /dev/null; then
    echo "Installing Nixpacks..."
    curl -sSL https://get.nixpacks.com | sh
fi

# Construct the Nixpacks build command
BUILD_CMD="nixpacks build $INPUT_CONTEXT"

# Incorporate provided input parameters from actions.yml into the Nixpacks build command
if [ -n "${INPUT_TAGS}" ]; then
    IFS=',' read -ra TAGS <<< "$INPUT_TAGS"
    for tag in "${TAGS[@]}"; do
        BUILD_CMD="$BUILD_CMD --tag $tag"
    done
fi

if [ -n "${INPUT_LABELS}" ]; then
    IFS=',' read -ra LABELS <<< "$INPUT_LABELS"
    for label in "${LABELS[@]}"; do
        BUILD_CMD="$BUILD_CMD --label $label"
    done
fi

if [ -n "${INPUT_PLATFORMS}" ]; then
    IFS=',' read -ra PLATFORMS <<< "$INPUT_PLATFORMS"
    for platform in "${PLATFORMS[@]}"; do
        BUILD_CMD="$BUILD_CMD --platform $platform"
    done
fi

# Add the Nix and Apt packages if specified
if [ -n "${INPUT_PKGS}" ]; then
    BUILD_CMD="$BUILD_CMD --pkgs '${INPUT_PKGS}'"
fi

if [ -n "${INPUT_APT}" ]; then
    BUILD_CMD="$BUILD_CMD --apt '${INPUT_APT}'"
fi

# Execute the Nixpacks build command
echo "Executing Nixpacks build command:"
echo $BUILD_CMD
eval $BUILD_CMD

# Push the images
for tag in "${TAGS[@]}"; do
    echo "Pushing Docker image: $tag"
    docker push $tag
done

echo "Nixpacks Build & Push completed successfully."
