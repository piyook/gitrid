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

# A PowerShell that has ~/bin on its PATH (one started from Git Bash, say) finds
# the wrapper above before the gitrid.ps1 of the PowerShell setup. It can not
# run a file with no extension, and does nothing. With a gitrid.ps1 next to the
# wrapper, PowerShell runs that. It names Git's bin\bash.exe in full: a plain
# 'bash' in PowerShell can be the one of WSL, and usr\bin\bash.exe does not put
# grep and the rest on the PATH.
if command -v cygpath > /dev/null; then
    GIT_BASH="$(cygpath -w /)bin\\bash.exe"
    if [ -f "$GIT_BASH" ]; then
        # The path goes in a single-quoted PowerShell string: double any quote
        cat > "$COMMAND.ps1" <<EOF || exit 1
# Runs gitrid in Git Bash from PowerShell. Written by setup_gitbash.sh.
\$bash = '${GIT_BASH//\'/\'\'}'
\$script = Join-Path \$PSScriptRoot '..\\Scripts\\gitrid.sh'
if (\$MyInvocation.ExpectingInput) {
    \$input | & \$bash \$script @args
} else {
    & \$bash \$script @args
}
exit \$LASTEXITCODE
EOF
        echo "PowerShell command installed to $COMMAND.ps1"
    fi
fi

case ":$PATH:" in
    *":$HOME/bin:"*) ;;
    *) echo "$HOME/bin is not on the PATH of this shell: open a new Git Bash window to use 'gitrid'" ;;
esac
