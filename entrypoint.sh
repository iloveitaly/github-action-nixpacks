#!/bin/bash

set -e

if ! command -v nixpacks &>/dev/null; then
  echo "Installing Nixpacks..."
  curl -sSL https://nixpacks.com/install.sh | bash
fi

BUILD_CMD="nixpacks build $INPUT_CONTEXT"

# Incorporate provided input parameters from actions.yml into the Nixpacks build command
if [ -n "${INPUT_TAGS}" ]; then
  read -ra TAGS <<<"$(echo "$INPUT_TAGS" | tr ',\n' ' ')"
else
  # if not tags are provided, assume ghcr.io as the default registry
  echo "No tags provided. Defaulting to ghcr.io registry."
  BUILD_DATE_TIMESTAMP=$(date +%s)
  TAGS=("ghcr.io/$GITHUB_REPOSITORY:$GIT_SHA" "ghcr.io/$GITHUB_REPOSITORY:latest" "ghcr.io/$GITHUB_REPOSITORY:$BUILD_DATE_TIMESTAMP")
fi

if [ -n "${INPUT_LABELS}" ]; then
  read -ra LABELS <<<"$(echo "$INPUT_LABELS" | tr ',\n' ' ')"
fi

LABELS+=("org.opencontainers.image.source=$GITHUB_REPOSITORY_URL")
LABELS+=("org.opencontainers.image.revision=$GITHUB_SHA")
LABELS+=("org.opencontainers.image.created=\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"")

# lunchmoney/lunchmoney-assets/Dockerfile:13:7:      org.opencontainers.image.licenses="MIT" \
# TODO add the description label as well
# asdf-devcontainer/Dockerfile:9:7:LABEL org.opencontainers.image.authors="Michael Bianco <mike@mikebian.co>" \

for label in "${LABELS[@]}"; do
  BUILD_CMD="$BUILD_CMD --label $label"
done

if [ -n "${INPUT_PKGS}" ]; then
  read -ra PKGS_ARR <<<"$(echo "$INPUT_PKGS" | tr ',\n' ' ')"
  BUILD_CMD="$BUILD_CMD --pkgs '${PKGS_ARR[*]}'"
fi

if [ -n "${INPUT_APT}" ]; then
  read -ra APT_ARR <<<"$(echo "$INPUT_APT" | tr ',\n' ' ')"
  BUILD_CMD="$BUILD_CMD --apt '${APT_ARR[*]}'"
fi

# Include environment variables in the build command
if [ -n "${INPUT_ENV}" ]; then
  IFS=',' read -ra ENVS <<<"$INPUT_ENV"
  for env_var in "${ENVS[@]}"; do
    BUILD_CMD="$BUILD_CMD --env $env_var"
  done
fi

if [ -n "${INPUT_PLATFORMS}" ]; then
  read -ra PLATFORMS <<<"$(echo "$INPUT_PLATFORMS" | tr ',\n' ' ')"
fi

if [ "${#PLATFORMS[@]}" -gt 1 ] && [ "$INPUT_PUSH" != "true" ]; then
  echo "Multi-platform builds *must* be pushed to a registry. Please set 'push: true' in your action configuration or do a single architecture build."
  exit 1
fi

function build_and_push() {
  local build_cmd=$BUILD_CMD

  if [ -n "$PLATFORMS" ]; then
    build_cmd="$build_cmd --platform $PLATFORMS"
  fi

  for tag in "${TAGS[@]}"; do
    build_cmd="$build_cmd --tag $tag"
  done

  echo "Executing Nixpacks build command:"
  echo "$build_cmd"

  eval "$build_cmd"

  # Conditionally push the images based on the 'push' input
  if [[ "$INPUT_PUSH" == "true" ]]; then
    for tag in "${TAGS[@]}"; do
      echo "Pushing Docker image: $tag"
      docker push "$tag"
    done
  else
    echo "Skipping Docker image push."
  fi
}

function build_and_push_multiple_architectures() {
  for platform in "${PLATFORMS[@]}"; do
    local build_cmd=$BUILD_CMD
    local temporary_image_name=${GITHUB_REPOSITORY}-local-build:$platform

    build_cmd="$build_cmd --platform $platform"
    build_cmd="$build_cmd --tag $temporary_image_name"

    echo "Executing Nixpacks build command:"
    echo "$build_cmd"

    eval "$build_cmd"
  done

  local manifest_list=$(for PLATFORM in "${PLATFORMS[@]}"; do echo "$IMAGE_NAME:temp-$PLATFORM"; done)

  # now, with all architectures built locally, we can construct a manifest and push to the registry
  for tag in "${TAGS[@]}"; do
    echo "Creating manifest and pushing for tag $tag..."

    docker manifest create "$tag" "$manifest_list"
    docker manifest push "$tag"
  done
}

if [ "${#PLATFORMS[@]}" -gt 1 ]; then
  build_and_push_multiple_architectures
elif [ -n "$PLATFORMS" ]; then
  build_and_push
fi

echo "Nixpacks Build & Push completed successfully."
