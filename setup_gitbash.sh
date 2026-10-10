#!/usr/bin/env bash

# set -euo pipefail


# Ensure the Scripts directory exists
if [ ! -d "$HOME/Scripts" ]; then
    echo "Creating Scripts directory at $HOME/Scripts"
    mkdir -p "$HOME/Scripts"
fi

# Define the source script and destination
SOURCE_SCRIPT="gitrid.sh"
DESTINATION="$HOME/Scripts/gitrid.sh"
# The 'gitrid' command: Git for Windows puts ~/bin on the PATH when it exists
COMMAND="$HOME/bin/gitrid"

# Ensure the script is executable
chmod +x "$SOURCE_SCRIPT"

# Move the script, overwriting if necessary
cp -f "$SOURCE_SCRIPT" "$DESTINATION" || exit 1

echo "Script successfully installed to $DESTINATION"

# Make 'gitrid' a command on the PATH. An alias in ~/.bashrc is not enough: a
# shell that is not interactive (a script, a hook, an AI agent) does not load
# aliases. A wrapper, not 'ln -s': Git Bash copies the file where it can not
# make a link, and the copy would go stale when gitrid is updated.
mkdir -p "$HOME/bin"
cat > "$COMMAND" <<'EOF' || exit 1
#!/usr/bin/env bash
exec "$HOME/Scripts/gitrid.sh" "$@"
EOF
chmod +x "$COMMAND"

echo "Command 'gitrid' installed to $COMMAND"

case ":$PATH:" in
    *":$HOME/bin:"*) ;;
    *) echo "$HOME/bin is not on the PATH of this shell: open a new Git Bash window to use 'gitrid'" ;;
esac
