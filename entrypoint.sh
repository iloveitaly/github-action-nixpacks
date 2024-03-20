#!/bin/bash
set -e

# Install Nixpacks if not present
if ! command -v nixpacks &> /dev/null; then
    echo "Installing Nixpacks..."
    # Adjust the installation command according to Nixpacks' installation instructions
    curl -sSL https://get.nixpacks.com | sh
fi

# Execute Nixpacks build and push
nixpacks build $INPUT_CONTEXT --push $INPUT_PUSH --tags $INPUT_TAGS --labels $INPUT_LABELS --platforms $INPUT_PLATFORMS

if [ $? -ne 0 ]; then
  echo "Nixpacks Build & Push failed."
  exit 1
fi

echo "Nixpacks Build & Push completed successfully."
