#!/usr/bin/env bash
# set -euo pipefail

# Define the source script and destination
SOURCE_SCRIPT="gitrid.sh"
DESTINATION="/usr/local/bin/gitrid.sh"
# The 'gitrid' command, a link to the script
COMMAND="/usr/local/bin/gitrid"

# Ensure the script is executable
chmod +x "$SOURCE_SCRIPT"


# Move the script, overwriting if necessary
if [ -f "$DESTINATION" ]; then
    sudo rm -f "$DESTINATION"
fi
sudo cp "$SOURCE_SCRIPT" "$DESTINATION" || exit 1


echo "Scripts successfully installed to $DESTINATION"

# Make 'gitrid' a command on the PATH. An alias in ~/.bashrc is not enough: a
# shell that is not interactive (a script, a hook, an AI agent) does not load
# aliases.
sudo ln -sf "$DESTINATION" "$COMMAND" || exit 1

echo "Command 'gitrid' installed to $COMMAND"
