#!/bin/bash

set -e

if ! command -v nixpacks &>/dev/null; then
  echo "Installing Nixpacks..."
  curl -sSL https://nixpacks.com/install.sh | bash
fi

repository_author() {
  local repo=$1
  local owner_login owner_name owner_email owner_info

  if [ -z "$repo" ]; then
    echo "Error: Repository not specified."
    return 1
  fi

  # Fetch the owner's login (username)
  owner_login=$(gh repo view "$repo" --json owner --jq '.owner.login' | tr -d '[:space:]')

  # Fetch the owner's name, remove trailing and leading whitespace
  owner_name=$(gh api "users/$owner_login" --jq '.name' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  # Attempt to fetch the owner's publicly available email
  owner_email=$(gh api "users/$owner_login" --jq '.email' | tr -d '[:space:]')

  # Check if an email was fetched; if not, use just the name
  if [ -z "$owner_email" ] || [ "$owner_email" = "null" ]; then
    owner_info="$owner_name"
  else
    owner_info="$owner_name <$owner_email>"
  fi

  echo "$owner_info"
}

repository_license() {
  local repo=$1
  gh api /repos/$repo/license 2>/dev/null | jq -r '.license.key // ""'
}

BUILD_CMD="nixpacks build $INPUT_CONTEXT"
GHCR_IMAGE_NAME="ghcr.io/$GITHUB_REPOSITORY"

# add NIXPACKS_ prefixed environment variables to the build command
# https://nixpacks.com/docs/configuration/environment
for var in $(env | grep ^NIXPACKS_); do
  BUILD_CMD="$BUILD_CMD --env $var"
done

# Incorporate provided input parameters from actions.yml into the Nixpacks build command
if [ -n "${INPUT_TAGS}" ]; then
  read -ra TAGS <<<"$(echo "$INPUT_TAGS" | tr ',\n' ' ')"
else
  # if not tags are provided, assume ghcr.io as the default registry
  echo "No tags provided. Defaulting to ghcr.io registry."
  BUILD_DATE_TIMESTAMP=$(date +%s)
  TAGS=("$GHCR_IMAGE_NAME:$GIT_SHA" "$GHCR_IMAGE_NAME:latest" "$GHCR_IMAGE_NAME:$BUILD_DATE_TIMESTAMP")
fi

if [ -n "${INPUT_LABELS}" ]; then
  read -ra LABELS <<<"$(echo "$INPUT_LABELS" | tr ',\n' ' ')"
fi

if [[ "$INPUT_CACHE" == "true" ]]; then
  if [ -z "$INPUT_CACHE_TAG" ]; then
    INPUT_CACHE_TAG=$(echo "$GHCR_IMAGE_NAME" | tr '[:upper:]' '[:lower:]')
  fi
  BUILD_CMD="$BUILD_CMD --inline-cache --cache-from $INPUT_CACHE_TAG"
fi

# TODO should check if these labels are already defined
LABELS+=("org.opencontainers.image.source=$GITHUB_REPOSITORY_URL")
LABELS+=("org.opencontainers.image.revision=$GITHUB_SHA")
LABELS+=("org.opencontainers.image.created=\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"")

REPO_AUTHOR=$(repository_author "$GITHUB_REPOSITORY")
if [ -n "$REPO_AUTHOR" ]; then
  LABELS+=("org.opencontainers.image.authors=\"$REPO_AUTHOR\"")
fi

REPO_LICENSE=$(repository_license "$GITHUB_REPOSITORY")
if [ -n "$REPO_LICENSE" ]; then
  LABELS+=("org.opencontainers.image.licenses=\"$REPO_LICENSE\"")
fi

# TODO add the description label as well? Does this add any value?
# TODO add org.opencontainers.image.title?

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
  echo "Building for multiple architectures: ${PLATFORMS[*]}"

  local manifest_list=()

  for platform in "${PLATFORMS[@]}"; do
    local build_cmd=$BUILD_CMD
    # Replace '/' with '-'
    local normalized_platform=${platform//\//-}
    local architecture_image_name=${GHCR_IMAGE_NAME}:$normalized_platform

    build_cmd="$build_cmd --platform $platform"
    build_cmd="$build_cmd --tag $architecture_image_name"

    echo "Executing Nixpacks build command for $platform:"
    echo "$build_cmd"

    eval "$build_cmd"

    manifest_list+=("$architecture_image_name")
  done

  echo "All architectures built. Pushing images..."
  for architecture_image_name in "${manifest_list[@]}"; do
    # if we don't push the images the multi-architecture manifest will not be created
    # best practice here seems to be to push `base:platform` images to the registry
    # when they are overwritten by the next architecture build, the previous manifest
    # will reference the sha of the image instead of the tag
    docker push "$architecture_image_name"
  done

  echo "Constructing manifest and pushing to registry..."

  # now, with all architectures built locally, we can construct a manifest and push to the registry
  for tag in "${TAGS[@]}"; do
    local manifest_creation="docker manifest create $tag ${manifest_list[@]}"
    echo "Creating manifest: $manifest_creation"
    eval "$manifest_creation"

    docker manifest push "$tag"
  done
}

if [ "${#PLATFORMS[@]}" -gt 1 ]; then
  build_and_push_multiple_architectures
else 
  build_and_push
fi

echo "Nixpacks Build & Push completed successfully."
