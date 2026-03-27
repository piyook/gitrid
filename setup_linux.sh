#!/usr/bin/env bash
# set -euo pipefail

# Define the source script and destination
SOURCE_SCRIPT="gitrid.sh"
DESTINATION="/usr/local/bin/gitrid.sh"

# Ensure the script is executable
chmod +x "$SOURCE_SCRIPT"


# Move the script, overwriting if necessary
if [ -f "$DESTINATION" ]; then
    sudo rm -f "$DESTINATION"
fi
sudo cp "$SOURCE_SCRIPT" "$DESTINATION"


echo "Scripts successfully installed to $DESTINATION"

# Create an alias for easy access
if ! grep -q "alias gitrid" ~/.bashrc; then
    echo "alias gitrid=$DESTINATION" >> ~/.bashrc
    echo "Alias 'gitrid' added to ~/.bashrc"
else
    echo "Alias 'gitrid' already exists in ~/.bashrc"
fi