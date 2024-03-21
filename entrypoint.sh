#!/bin/bash
set -e

env

# Install Nixpacks if not present
if ! command -v nixpacks &> /dev/null; then
    echo "Installing Nixpacks..."
    curl -sSL https://nixpacks.com/install.sh | bash
fi

BUILD_CMD="nixpacks build $INPUT_CONTEXT"

# Incorporate provided input parameters from actions.yml into the Nixpacks build command
if [ -n "${INPUT_TAGS}" ]; then
    IFS=$', \n' read -ra TAGS <<< "$INPUT_TAGS"
    for tag in "${TAGS[@]}"; do
        BUILD_CMD="$BUILD_CMD --tag $tag"
    done
fi

if [ -n "${INPUT_LABELS}" ]; then
    IFS=$', \n' read -ra LABELS <<< "$INPUT_LABELS"
    for label in "${LABELS[@]}"; do
        BUILD_CMD="$BUILD_CMD --label $label"
    done
fi

if [ -n "${INPUT_PLATFORMS}" ]; then
    IFS=$', \n' read -ra PLATFORMS <<< "$INPUT_PLATFORMS"
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

# Conditionally push the images based on the 'push' input
if [[ "$INPUT_PUSH" == "true" ]]; then
    for tag in "${TAGS[@]}"; do
        echo "Pushing Docker image: $tag"
        docker push $tag
    done
fi

echo "Nixpacks Build & Push completed successfully."
