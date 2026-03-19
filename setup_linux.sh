#!/usr/bin/env bash
# set -euo pipefail

# Define the source script and destination
SOURCE_SCRIPT="gitcrop.sh"
DESTINATION="/usr/local/bin/gitcrop.sh"

# Ensure the script is executable
chmod +x "$SOURCE_SCRIPT"


# Move the script, overwriting if necessary
if [ -f "$DESTINATION" ]; then
    sudo rm -f "$DESTINATION"
fi
sudo cp "$SOURCE_SCRIPT" "$DESTINATION"

echo "Scripts successfully installed to $DESTINATION"