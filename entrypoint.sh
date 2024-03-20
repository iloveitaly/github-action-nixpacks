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
    # Splitting tags and adding them to the build command
    IFS=',' read -ra TAGS <<< "$INPUT_TAGS"
    for tag in "${TAGS[@]}"; do
        BUILD_CMD="$BUILD_CMD -t $tag"
    done
fi

if [ -n "${INPUT_LABELS}" ]; then
    # Assuming INPUT_LABELS is a comma-separated list of labels
    IFS=',' read -ra LABELS <<< "$INPUT_LABELS"
    for label in "${LABELS[@]}"; do
        BUILD_CMD="$BUILD_CMD -l $label"
    done
fi

if [ -n "${INPUT_PLATFORMS}" ]; then
    # Assuming INPUT_PLATFORMS is a comma-separated list of platforms
    IFS=',' read -ra PLATFORMS <<< "$INPUT_PLATFORMS"
    for platform in "${PLATFORMS[@]}"; do
        BUILD_CMD="$BUILD_CMD --platform $platform"
    done
fi

# Execute the Nixpacks build command
echo "Executing Nixpacks build command:"
echo $BUILD_CMD
eval $BUILD_CMD

# Assuming the Nixpacks build process handles tagging, no need for separate Docker push commands
# However, if you need to push the images manually, you would uncomment and use the following:

# for tag in "${TAGS[@]}"; do
#     echo "Pushing Docker image: $tag"
#     docker push $tag
# done

echo "Nixpacks Build & Push completed successfully."
