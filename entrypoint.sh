#!/bin/bash

set -e

if ! command -v nixpacks &> /dev/null; then
    echo "Installing Nixpacks..."
    curl -sSL https://nixpacks.com/install.sh | bash
fi

BUILD_CMD="nixpacks build $INPUT_CONTEXT"

# Incorporate provided input parameters from actions.yml into the Nixpacks build command
if [ -n "${INPUT_TAGS}" ]; then
    read -ra TAGS <<< "$(echo "$INPUT_TAGS" | tr ',\n' ' ')"
    for tag in "${TAGS[@]}"; do
        BUILD_CMD="$BUILD_CMD --tag $tag"
    done
else
    # if not tags are provided, assume ghcr.io as the default registry
    echo "No tags provided. Defaulting to ghcr.io registry."
    BUILD_DATE_TIMESTAMP=$(date +%s)
    BUILD_CMD="$BUILD_CMD --tag ghcr.io/$GITHUB_REPOSITORY:$GIT_SHA --tag ghcr.io/$GITHUB_REPOSITORY:latest --tag ghcr.io/$GITHUB_REPOSITORY:$BUILD_DATE_TIMESTAMP"
fi

BUILD_CMD="$BUILD_CMD --label org.opencontainers.image.source=$GITHUB_REPOSITORY_URL"
# TODO add the description label as well

if [ -n "${INPUT_LABELS}" ]; then
    read -ra LABELS <<< "$(echo "$INPUT_LABELS" | tr ',\n' ' ')"
    for label in "${LABELS[@]}"; do
        BUILD_CMD="$BUILD_CMD --label $label"
    done
fi

if [ -n "${INPUT_PLATFORMS}" ]; then
    read -ra PLATFORMS <<< "$(echo "$INPUT_PLATFORMS" | tr ',\n' ' ')"
    for platform in "${PLATFORMS[@]}"; do
        BUILD_CMD="$BUILD_CMD --platform $platform"
    done
fi

if [ -n "${INPUT_PKGS}" ]; then
    read -ra PKGS_ARR <<< "$(echo "$INPUT_PKGS" | tr ',\n' ' ')"
    BUILD_CMD="$BUILD_CMD --pkgs '${PKGS_ARR[*]}'"
fi

if [ -n "${INPUT_APT}" ]; then
    read -ra APT_ARR <<< "$(echo "$INPUT_APT" | tr ',\n' ' ')"
    BUILD_CMD="$BUILD_CMD --apt '${APT_ARR[*]}'"
fi

# Include environment variables in the build command
if [ -n "${INPUT_ENV}" ]; then
    IFS=',' read -ra ENVS <<< "$INPUT_ENV"
    for env_var in "${ENVS[@]}"; do
        BUILD_CMD="$BUILD_CMD --env $env_var"
    done
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
else
    echo "Skipping Docker image push."
fi

echo "Nixpacks Build & Push completed successfully."
