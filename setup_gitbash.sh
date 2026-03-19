#!/usr/bin/env bash

# set -euo pipefail


# Ensure the Scripts directory exists
if [ ! -d "$HOME/Scripts" ]; then
    echo "Creating Scripts directory at $HOME/Scripts"
    mkdir -p "$HOME/Scripts"
fi

# Define the source script and destination
SOURCE_SCRIPT="gitcrop.sh"
DESTINATION="$HOME/Scripts/gitcrop.sh"

# Ensure the script is executable
chmod +x "$SOURCE_SCRIPT"

# Move the script, overwriting if necessary
cp -f $SOURCE_SCRIPT $DESTINATION

# Create an alias for easy access
if ! grep -q "alias gitcrop" ~/.bashrc; then
    echo "alias gitcrop='~/Scripts/gitcrop.sh'" >> ~/.bashrc
    echo "Alias 'gitcrop' added to ~/.bashrc"
else
    echo "Alias 'gitcrop' already exists in ~/.bashrc"
fi

echo "Script successfully installed to $DESTINATION"