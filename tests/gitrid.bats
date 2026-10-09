#!/usr/bin/env bats

# Tests for gitrid.sh. Each test runs the script against a copy of a throwaway
# repository (a bare "remote" and a working clone), built once in setup_file.
#
# The branches in the working clone, as 'gitrid --list --porcelain' sees them:
#
#   bugfix/issue-123       unmerged   1 commit on no remote   upstream gone
#   chore/fresh            merged     new from main, no commits of its own
#   dev                    protected
#   feature/device-list    unmerged   1 commit on no remote   never pushed
#   feature/login          merged     into local main only, still on the remote
#   feature/payment        unmerged   2 commits on no remote  never pushed
#   feature/remote-merged  merged     into origin/main only   upstream gone
#   main                   protected  the current branch

GITRID="$BATS_TEST_DIRNAME/../gitrid.sh"

gitrid() {
    bash "$GITRID" "$@"
}

# Keep the user's own git settings out of the tests
git_env() {
    export GIT_CONFIG_GLOBAL=/dev/null
    export GIT_CONFIG_NOSYSTEM=1
    export GIT_AUTHOR_NAME="gitrid tests" GIT_AUTHOR_EMAIL="tests@example.com"
    export GIT_COMMITTER_NAME="gitrid tests" GIT_COMMITTER_EMAIL="tests@example.com"
}

# A new branch from main holding the given number of commits
new_branch() {
    local i
    git checkout -q -b "$1" main
    for ((i = 1; i <= $2; i++)); do
        git commit -q --allow-empty -m "$1 commit $i"
    done
}

setup_file() {
    git_env
    export TEMPLATE="$BATS_FILE_TMPDIR/template"
    mkdir -p "$TEMPLATE"
    cd "$TEMPLATE"

    git init -q --bare -b main remote.git
    git init -q -b main work
    cd work
    git remote add origin ../remote.git
    git commit -q --allow-empty -m "init"
    git push -q -u origin main

    # A pull request merged on the remote and its branch deleted there, with
    # local main left behind: merged into origin/main only
    new_branch feature/remote-merged 1
    git push -q -u origin feature/remote-merged
    git checkout -q main
    git merge -q --no-ff feature/remote-merged -m "merge feature/remote-merged"
    git push -q origin main
    git push -q origin --delete feature/remote-merged
    git reset -q --hard HEAD~1

    new_branch feature/login 1
    git push -q -u origin feature/login
    new_branch feature/payment 2
    new_branch feature/device-list 1
    new_branch bugfix/issue-123 1
    git push -q -u origin bugfix/issue-123
    git push -q origin --delete bugfix/issue-123
    git checkout -q -b dev main
    git checkout -q -b chore/fresh main

    git checkout -q main
    git merge -q --no-ff feature/login -m "merge feature/login"
    git fetch -q --prune
}

setup() {
    git_env
    cp -R "$TEMPLATE/." "$BATS_TEST_TMPDIR/"
    cd "$BATS_TEST_TMPDIR/work"
}

# --- helpers ---------------------------------------------------------------

# Plain tests and greps are used below, not [[ ]], which bats can't see fail
# on the bash 3.2 that macOS ships.

assert_status() {
    if [ "$status" -ne "$1" ]; then
        echo "expected exit code $1, got $status. Output:"
        echo "$output"
        return 1
    fi
}

assert_output_has() {
    if ! grep -Fq -- "$1" <<< "$output"; then
        echo "expected the output to contain: $1"
        echo "$output"
        return 1
    fi
}

refute_output_has() {
    if grep -Fq -- "$1" <<< "$output"; then
        echo "expected the output not to contain: $1"
        echo "$output"
        return 1
    fi
}

# The branches a deletion or dry run lists, one name per line
listed_branches() {
    grep '^  ' <<< "$output" | awk '{ print $1 }'
}

# The listed branches are exactly the ones given, in order
assert_listed() {
    local expected
    expected=$(printf '%s\n' "$@")
    if [ "$(listed_branches)" != "$expected" ]; then
        echo "expected these branches to be listed:"
        echo "$expected"
        echo "Output:"
        echo "$output"
        return 1
    fi
}

branch_exists() {
    git show-ref --verify --quiet "refs/heads/$1"
}

assert_branch() {
    if ! branch_exists "$1"; then
        echo "expected branch '$1' to still exist"
        return 1
    fi
}

refute_branch() {
    if branch_exists "$1"; then
        echo "expected branch '$1' to be deleted"
        return 1
    fi
}

branch_count() {
    git for-each-ref refs/heads/ | wc -l | tr -d ' '
}

# --- listing ---------------------------------------------------------------

@test "--list labels every branch and notes the work it holds" {
    run gitrid --list
    assert_status 0
    assert_output_has "[PROTECTED] main"
    assert_output_has "[PROTECTED] dev"
    assert_output_has "[MERGED] chore/fresh"
    assert_output_has "[MERGED] feature/login"
    assert_output_has "[MERGED] feature/remote-merged (upstream gone)"
    assert_output_has "[UNMERGED] feature/payment (2 commits on no remote)"
    assert_output_has "[UNMERGED] feature/device-list (1 commit on no remote)"
    assert_output_has "[UNMERGED] bugfix/issue-123 (1 commit on no remote, upstream gone)"
}

@test "--list --porcelain prints four tab-separated fields per branch" {
    run gitrid --list --porcelain
    assert_status 0
    expected=$(printf '%s\t%s\t%s\t%s\n' \
        unmerged bugfix/issue-123 1 gone \
        merged chore/fresh 0 none \
        protected dev 0 none \
        unmerged feature/device-list 1 none \
        merged feature/login 0 tracked \
        unmerged feature/payment 2 none \
        merged feature/remote-merged 0 gone \
        protected main 0 tracked)
    if [ "$output" != "$expected" ]; then
        echo "expected:"
        echo "$expected"
        echo "got:"
        echo "$output"
        return 1
    fi
}

@test "-l is --list" {
    run gitrid -l
    assert_status 0
    assert_output_has "[PROTECTED] main"
}

@test "--list deletes nothing" {
    run gitrid --list
    [ "$(branch_count)" -eq 8 ]
}

@test "--porcelain without --list is an error" {
    run gitrid --porcelain
    assert_status 1
    assert_output_has "--porcelain is used with --list"
}

# --- which branches --------------------------------------------------------

@test "a pattern matches anywhere in the branch name, merged or not" {
    run gitrid feature/ --dry-run
    assert_status 0
    assert_listed feature/device-list feature/login feature/payment feature/remote-merged
}

@test "a pattern is a regular expression, so it can be anchored" {
    run gitrid '^bugfix/' --dry-run
    assert_listed bugfix/issue-123

    run gitrid 'issue-[0-9]+$' --dry-run
    assert_listed bugfix/issue-123

    run gitrid '^issue' --dry-run
    assert_status 2
}

@test "--merged takes branches merged into local main or origin/main" {
    run gitrid --merged --dry-run
    assert_status 0
    assert_listed chore/fresh feature/login feature/remote-merged
    assert_output_has "fully merged into 'main' or 'origin/main'"
}

@test "--merged with a pattern takes only the merged branches that match" {
    run gitrid --merged feature/ --dry-run
    assert_listed feature/login feature/remote-merged
}

@test "--gone takes branches whose upstream was deleted on the remote" {
    run gitrid --gone --dry-run
    assert_status 0
    assert_listed bugfix/issue-123 feature/remote-merged
}

@test "--merged with --gone takes branches that pass both" {
    run gitrid --merged --gone --dry-run
    assert_listed feature/remote-merged
}

@test "-m and -g are --merged and --gone" {
    run gitrid -m -g -n
    assert_status 0
    assert_listed feature/remote-merged
}

@test "--nuke takes every branch but the protected ones and the current one" {
    run gitrid --nuke --dry-run
    assert_status 0
    assert_listed bugfix/issue-123 chore/fresh feature/device-list feature/login \
        feature/payment feature/remote-merged
}

@test "--nuke with --merged takes only the merged branches" {
    run gitrid --nuke --merged --dry-run
    assert_listed chore/fresh feature/login feature/remote-merged
}

@test "options can come before or after the pattern" {
    run gitrid --merged feature/ --dry-run
    before="$output"
    run gitrid feature/ --dry-run --merged
    [ "$output" = "$before" ]
}

@test "a pattern that starts with a dash goes after -- or is written [-]" {
    run gitrid --dry-run -- '-123$'
    assert_status 0
    assert_listed bugfix/issue-123

    run gitrid '[-]123$' --dry-run
    assert_status 0
    assert_listed bugfix/issue-123

    run gitrid '-123$' --dry-run
    assert_status 1
    assert_output_has "put after '--'"
}

@test "a second pattern is an error, not a replacement for the first" {
    run gitrid feature/ bugfix/ --yes
    assert_status 1
    assert_output_has "two patterns given ('feature/' and 'bugfix/')"
    [ "$(branch_count)" -eq 8 ]
}

@test "--nuke with a pattern is an error, whichever comes first" {
    run gitrid --nuke feature/ --yes
    assert_status 1
    assert_output_has "--nuke takes every branch"

    run gitrid feature/ --nuke --yes
    assert_status 1
    [ "$(branch_count)" -eq 8 ]
}

@test "--merged is judged against origin/main when there is no local main" {
    git checkout -q dev
    git branch -q -D main
    run gitrid --merged --dry-run
    assert_status 0
    assert_listed chore/fresh feature/remote-merged
    assert_output_has "fully merged into 'origin/main'"
}

# --- protected branches ----------------------------------------------------

@test "a branch is protected only if its whole name is a protected name" {
    run gitrid dev --dry-run
    assert_status 0
    assert_listed feature/device-list
}

@test "protected branches survive --nuke" {
    run gitrid --nuke --yes
    assert_status 0
    assert_branch main
    assert_branch dev
    [ "$(branch_count)" -eq 2 ]
}

@test "the current branch is skipped, with a message" {
    git checkout -q chore/fresh
    run gitrid --merged --yes
    assert_status 0
    assert_output_has "Skipping 'chore/fresh': it is the current branch."
    assert_branch chore/fresh
    refute_branch feature/login
}

@test "master is the protected default branch when there is no main" {
    mkdir "$BATS_TEST_TMPDIR/old"
    cd "$BATS_TEST_TMPDIR/old"
    git init -q -b master
    git commit -q --allow-empty -m "init"
    git checkout -q -b feature/x
    git commit -q --allow-empty -m "x"
    git checkout -q master

    run gitrid --list --porcelain
    assert_output_has "$(printf 'protected\tmaster')"

    run gitrid --nuke --yes
    assert_status 0
    assert_branch master
    refute_branch feature/x
}

@test "a branch checked out in another worktree is skipped, with a message" {
    git worktree add -q "$BATS_TEST_TMPDIR/other" feature/payment
    run gitrid feature/ --yes
    assert_status 0
    assert_output_has "Skipping 'feature/payment': it is checked out in another worktree."
    assert_branch feature/payment
    refute_branch feature/login
    refute_branch feature/device-list
}

@test "the remote's default branch is protected when there is no main or master" {
    mkdir "$BATS_TEST_TMPDIR/trunk"
    cd "$BATS_TEST_TMPDIR/trunk"
    git init -q --bare -b trunk remote.git
    git init -q -b trunk work
    cd work
    git remote add origin ../remote.git
    git commit -q --allow-empty -m "init"
    git push -q -u origin trunk
    git remote set-head origin trunk
    git branch feature/merged
    git checkout -q -b feature/x
    git commit -q --allow-empty -m "x"

    run gitrid --list --porcelain
    assert_status 0
    assert_output_has "$(printf 'protected\ttrunk')"
    assert_output_has "$(printf 'merged\tfeature/merged')"
    assert_output_has "$(printf 'unmerged\tfeature/x')"

    # trunk is not the current branch here, so only its name protects it
    run gitrid --nuke --yes
    assert_status 0
    assert_branch trunk
    refute_branch feature/merged
}

@test "with no default branch to be found it deletes nothing and exits 1" {
    mkdir "$BATS_TEST_TMPDIR/local"
    cd "$BATS_TEST_TMPDIR/local"
    git init -q -b trunk
    git commit -q --allow-empty -m "init"
    git branch feature/x

    run gitrid --nuke --yes
    assert_status 1
    assert_output_has "can't tell which branch is the default one"
    assert_branch feature/x

    run gitrid --list
    assert_status 1
}

# --- work at risk ----------------------------------------------------------

@test "the list counts the commits each branch holds that are on no remote" {
    run gitrid feature/ --dry-run
    assert_output_has "  feature/payment  (2 commits on no remote)"
    assert_output_has "  feature/device-list  (1 commit on no remote)"
    assert_output_has "WARNING: commits on no remote are not in 'main' either."
}

@test "there is no warning when no branch listed holds such commits" {
    run gitrid --merged --dry-run
    refute_output_has "WARNING"
    refute_output_has "on no remote"
}

# --- how it runs -----------------------------------------------------------

@test "--dry-run lists the branches, deletes nothing and does not ask" {
    run gitrid feature/ --dry-run </dev/null
    assert_status 0
    assert_output_has "The following local branches would be deleted:"
    assert_output_has "Dry run: nothing was deleted."
    refute_output_has "Are you sure?"
    [ "$(branch_count)" -eq 8 ]
}

@test "--yes deletes without asking" {
    run gitrid feature/ --yes </dev/null
    assert_status 0
    assert_output_has "Local branches deleted."
    refute_branch feature/login
    refute_branch feature/payment
    refute_branch feature/device-list
    refute_branch feature/remote-merged
    [ "$(branch_count)" -eq 4 ]
}

@test "-y is --yes" {
    run gitrid --gone -y </dev/null
    assert_status 0
    refute_branch bugfix/issue-123
}

@test "answering y at the prompt deletes" {
    run bash -c 'echo y | bash "$1" --merged' _ "$GITRID"
    assert_status 0
    refute_branch feature/login
    assert_branch feature/payment
}

@test "an answer that ends with a carriage return, as from PowerShell, is read" {
    run bash -c 'printf "y\r\n" | bash "$1" --merged' _ "$GITRID"
    assert_status 0
    refute_branch feature/login
}

@test "a branch with a quote in its name can be deleted" {
    git branch "fix/it's"
    run gitrid "it's" --yes
    assert_status 0
    refute_branch "fix/it's"
    [ "$(branch_count)" -eq 8 ]
}

@test "answering anything else cancels with exit code 3" {
    run bash -c 'echo n | bash "$1" feature/' _ "$GITRID"
    assert_status 3
    assert_output_has "Deletion cancelled."
    [ "$(branch_count)" -eq 8 ]
}

@test "with nothing to answer the prompt it deletes nothing and exits 1" {
    run gitrid feature/ </dev/null
    assert_status 1
    assert_output_has "no answer to the prompt, so nothing was deleted"
    [ "$(branch_count)" -eq 8 ]
}

@test "remote branches are never deleted" {
    run gitrid feature/ --yes
    assert_status 0
    refute_branch feature/login
    git ls-remote --exit-code --heads origin feature/login
}

# --- exit codes and errors -------------------------------------------------

@test "no branch matching is exit code 2" {
    run gitrid no-such-branch --yes
    assert_status 2
    assert_output_has "No local branches found matching pattern: no-such-branch"

    run gitrid no-such-branch --dry-run
    assert_status 2
}

@test "no pattern and no option is an error" {
    run gitrid
    assert_status 1
    assert_output_has "Usage: gitrid [options] [--] <pattern>"
}

@test "an unknown option is an error" {
    run gitrid --wat feature/
    assert_status 1
    assert_output_has "Unknown command '--wat'"
    [ "$(branch_count)" -eq 8 ]
}

@test "outside a git repository is an error" {
    mkdir "$BATS_TEST_TMPDIR/empty"
    cd "$BATS_TEST_TMPDIR/empty"
    export GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR"
    run gitrid --list
    assert_status 1
    assert_output_has "not inside a git repository"
}

@test "--help and -h show the usage" {
    run gitrid --help
    assert_status 0
    assert_output_has "Usage: gitrid [options] [--] <pattern>"
    assert_output_has "Exit codes:"

    run gitrid -h
    assert_status 0
    assert_output_has "Usage: gitrid [options] [--] <pattern>"
}

@test "--version shows the version in the script" {
    version=$(sed -n 's/^VERSION="\(.*\)"$/\1/p' "$GITRID")
    [ -n "$version" ]
    run gitrid --version
    assert_status 0
    [ "$output" = "gitrid version $version" ]
}

@test "llms.txt describes the same version as the script" {
    version=$(sed -n 's/^VERSION="\(.*\)"$/\1/p' "$GITRID")
    grep -Fq "Describes gitrid $version " "$BATS_TEST_DIRNAME/../llms.txt"
    grep -Fq "gitrid version $version" "$BATS_TEST_DIRNAME/../llms.txt"
}
