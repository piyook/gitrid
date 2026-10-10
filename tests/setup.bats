#!/usr/bin/env bats

# Tests for setup_gitbash.sh, which installs into $HOME only, so each test gives
# it a throwaway home. setup_linux.sh writes to /usr/local/bin with sudo and is
# run for real by the workflow in .github/workflows/tests.yml.

REPO="$BATS_TEST_DIRNAME/.."

setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"
    # The setup script takes gitrid.sh from the current directory
    cd "$REPO"
}

# What a new Git Bash window has: ~/bin on the PATH
with_home_bin() {
    PATH="$HOME/bin:$PATH" "$@"
}

@test "setup_gitbash.sh installs the script and the gitrid command" {
    run bash setup_gitbash.sh
    [ "$status" -eq 0 ]
    [ -x "$HOME/Scripts/gitrid.sh" ]
    [ -x "$HOME/bin/gitrid" ]
    cmp gitrid.sh "$HOME/Scripts/gitrid.sh"
}

@test "gitrid resolves in a non-interactive shell after setup_gitbash.sh" {
    bash setup_gitbash.sh
    run with_home_bin bash -c 'command -v gitrid'
    [ "$status" -eq 0 ]
    [ "$output" = "$HOME/bin/gitrid" ]
}

@test "the installed gitrid command runs the installed script" {
    bash setup_gitbash.sh
    run with_home_bin bash -c 'gitrid --version'
    [ "$status" -eq 0 ]
    [ "$output" = "$(bash gitrid.sh --version)" ]
}

@test "the installed gitrid command passes its arguments and exit code through" {
    bash setup_gitbash.sh
    run with_home_bin bash -c 'gitrid --no-such-option'
    [ "$status" -eq 1 ]
}

@test "setup_gitbash.sh does not touch ~/.bashrc" {
    echo "# mine" > "$HOME/.bashrc"
    bash setup_gitbash.sh
    [ "$(cat "$HOME/.bashrc")" = "# mine" ]
}

@test "setup_gitbash.sh run again updates the installed script" {
    bash setup_gitbash.sh
    echo "stale" > "$HOME/Scripts/gitrid.sh"
    echo "stale" > "$HOME/bin/gitrid"
    bash setup_gitbash.sh
    cmp gitrid.sh "$HOME/Scripts/gitrid.sh"
    run with_home_bin bash -c 'gitrid --version'
    [ "$status" -eq 0 ]
}

@test "setup_gitbash.sh says to open a new window when ~/bin is not on the PATH" {
    run bash setup_gitbash.sh
    [[ "$output" == *"open a new Git Bash window"* ]]
    run with_home_bin bash setup_gitbash.sh
    [[ "$output" != *"open a new Git Bash window"* ]]
}

# Windows only: a PowerShell that has ~/bin on its PATH finds the wrapper, which
# it can not run, so setup_gitbash.sh puts a gitrid.ps1 next to it.

@test "setup_gitbash.sh writes gitrid.ps1 next to the command on Windows only" {
    bash setup_gitbash.sh
    if command -v cygpath > /dev/null; then
        [ -f "$HOME/bin/gitrid.ps1" ]
    else
        [ ! -e "$HOME/bin/gitrid.ps1" ]
    fi
}

@test "PowerShell with ~/bin on its PATH runs the installed script" {
    command -v cygpath > /dev/null || skip "Windows only"
    command -v pwsh > /dev/null || skip "PowerShell is not installed"
    bash setup_gitbash.sh
    run with_home_bin pwsh -NoProfile -Command 'gitrid --version; exit $LASTEXITCODE'
    [ "$status" -eq 0 ]
    [ "${output%$'\r'}" = "$(bash gitrid.sh --version)" ]
}

@test "from PowerShell the pattern is passed as typed and the exit code comes back" {
    command -v cygpath > /dev/null || skip "Windows only"
    command -v pwsh > /dev/null || skip "PowerShell is not installed"
    bash setup_gitbash.sh
    # A repository of its own: the checkout the tests run in may have no main
    git init -q -b main "$BATS_TEST_TMPDIR/repo"
    cd "$BATS_TEST_TMPDIR/repo"
    git -c user.name="gitrid tests" -c user.email="tests@example.com" \
        commit -q --allow-empty -m "init"
    run with_home_bin pwsh -NoProfile -Command 'gitrid "^no-such|branch$" --dry-run; exit $LASTEXITCODE'
    [ "$status" -eq 2 ]
    [[ "$output" == *'^no-such|branch$'* ]]
}
