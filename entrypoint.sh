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
    IFS=', '$'\n' read -ra TAGS <<< "$INPUT_TAGS"
    for tag in "${TAGS[@]}"; do
        BUILD_CMD="$BUILD_CMD --tag $tag"
    done
fi

if [ -n "${INPUT_LABELS}" ]; then
    IFS=', '$'\n' read -ra LABELS <<< "$INPUT_LABELS"
    for label in "${LABELS[@]}"; do
        BUILD_CMD="$BUILD_CMD --label $label"
    done
fi

if [ -n "${INPUT_PLATFORMS}" ]; then
    IFS=', '$'\n' read -ra PLATFORMS <<< "$INPUT_PLATFORMS"
    for platform in "${PLATFORMS[@]}"; do
        BUILD_CMD="$BUILD_CMD --platform $platform"
    done
fi

# Add the Nix and Apt packages if specified
if [ -n "${INPUT_PKGS}" ]; then
    # Using an array to avoid issues if there are spaces in the input
    IFS=', '$'\n' read -ra PKGS_ARR <<< "$INPUT_PKGS"
    BUILD_CMD="$BUILD_CMD --pkgs '${PKGS_ARR[*]}'"
fi

if [ -n "${INPUT_APT}" ]; then
    # Using an array to avoid issues if there are spaces in the input
    IFS=', '$'\n' read -ra APT_ARR <<< "$INPUT_APT"
    BUILD_CMD="$BUILD_CMD --apt '${APT_ARR[*]}'"
fi

# Execute the Nixpacks build command
echo "Executing Nixpacks build command:"
echo "$BUILD_CMD"
eval "$BUILD_CMD"

# Conditionally push the images based on the 'push' input
if [[ "$INPUT_PUSH" == "true" ]]; then
    for tag in "${TAGS[@]}"; do
        echo "Pushing Docker image: $tag"
        docker push "$tag"
    done
fi

echo "Nixpacks Build & Push completed successfully."
