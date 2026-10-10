#!/usr/bin/env bash

# Version information
VERSION="3.1.1"

# Exit codes, so a script or an AI agent can tell the outcomes apart
EXIT_OK=0         # Branches deleted, or a list, dry run, help or version shown
EXIT_ERROR=1      # Bad usage, not a git repository, no answer to the prompt, or git failed
EXIT_NO_MATCH=2   # No branch matched, so there was nothing to delete
EXIT_CANCELLED=3  # The answer to "Are you sure?" was not yes

ref_exists() {
    git rev-parse --verify --quiet "$1" >/dev/null 2>&1
}

# The default branch: a local 'main' or 'master', else the branch the remote
# calls its default (origin/HEAD, which a clone sets), else a 'main' or
# 'master' that is only on the remote. Prints nothing if there is none.
find_default_branch() {
    local name
    for name in main master; do
        if ref_exists "refs/heads/$name"; then
            echo "$name"
            return
        fi
    done
    name=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
    if [ -n "$name" ]; then
        echo "${name#origin/}"
        return
    fi
    for name in main master; do
        if ref_exists "refs/remotes/origin/$name"; then
            echo "$name"
            return
        fi
    done
}

# With no default branch found nothing is deleted (see below); 'main' is then
# only a name for the help text
DEFAULT_BRANCH=$(find_default_branch)
DEFAULT_BRANCH_FOUND=true
if [ -z "$DEFAULT_BRANCH" ]; then
    DEFAULT_BRANCH="main"
    DEFAULT_BRANCH_FOUND=false
fi

# Define branches to exclude from deletion. A branch is protected only if its
# whole name is one of these, so 'feature/device' is not protected by 'dev'.
EXCEPTIONS="$DEFAULT_BRANCH|dev|develop|development"

# What a branch is checked against to see if it is merged: the local default
# branch and, if there is one, the remote's copy of it as last fetched. After a
# pull request is merged on the remote the local default branch is often
# behind, so checking it alone would report the merged branch as unmerged.
MERGE_TARGETS=()
MERGED_INTO=""
if ref_exists "refs/heads/$DEFAULT_BRANCH"; then
    MERGE_TARGETS+=("refs/heads/$DEFAULT_BRANCH")
    MERGED_INTO="'$DEFAULT_BRANCH'"
fi
if ref_exists "refs/remotes/origin/$DEFAULT_BRANCH"; then
    MERGE_TARGETS+=("refs/remotes/origin/$DEFAULT_BRANCH")
    MERGED_INTO="${MERGED_INTO:+$MERGED_INTO or }'origin/$DEFAULT_BRANCH'"
fi
if [ -z "$MERGED_INTO" ]; then
    MERGED_INTO="'$DEFAULT_BRANCH'"
fi

# All local branches, one name per line
all_branches() {
    git for-each-ref --format="%(refname:short)" refs/heads/
}

# Local branches fully merged into any of the merge targets
merged_branches() {
    for target in "${MERGE_TARGETS[@]}"; do
        git for-each-ref --merged "$target" --format="%(refname:short)" refs/heads/
    done | sort -u
}

# Local branches whose upstream branch is gone: it was deleted on the remote,
# as it usually is once its pull request is merged. Git only learns this from
# 'git fetch --prune'.
gone_branches() {
    git for-each-ref --format="%(refname:short)%09%(upstream:track)" refs/heads/ |
        awk -F'\t' '$2 == "[gone]" { print $1 }'
}

# Local branches checked out in a worktree, this one or another. Git refuses
# to delete them.
checked_out_branches() {
    git worktree list --porcelain | sed -n 's|^branch refs/heads/||p'
}

# Where a branch stands with its upstream: 'none' (it has no upstream),
# 'gone' (the upstream was deleted on the remote) or 'tracked'
upstream_state() {
    local upstream track
    upstream=$(git for-each-ref --format="%(upstream:short)" "refs/heads/$1")
    track=$(git for-each-ref --format="%(upstream:track)" "refs/heads/$1")
    if [ -z "$upstream" ]; then
        echo "none"
    elif [ "$track" = "[gone]" ]; then
        echo "gone"
    else
        echo "tracked"
    fi
}

# How many commits a branch holds that are on no remote branch and not in the
# local default branch: the work that deleting the branch would lose. A branch
# whose pull request was squash-merged and its remote branch deleted counts
# its commits here too, since git can't tell they are in the default branch.
local_only_count() {
    local kept=(--remotes)
    if ref_exists "refs/heads/$DEFAULT_BRANCH"; then
        kept+=("refs/heads/$DEFAULT_BRANCH")
    fi
    git rev-list --count "refs/heads/$1" --not "${kept[@]}" 2>/dev/null || echo 0
}

# "1 commit on no remote" or "3 commits on no remote"
local_only_words() {
    if [ "$1" -eq 1 ]; then
        echo "1 commit on no remote"
    else
        echo "$1 commits on no remote"
    fi
}

show_help() {
    cat <<EOF

Usage: gitrid [options] [--] <pattern>
       gitrid --list [--porcelain]

Deletes the LOCAL branches whose name matches <pattern>, after listing them
and asking "Are you sure?". Remote branches are never touched.

<pattern> is a regular expression (as for 'grep -E') matched anywhere in the
branch name, not a glob: 'feature/' matches every branch with 'feature/' in
its name, '^fix/' those that start with 'fix/'. Only one pattern is taken:
for either of two, 'feat/|fix/'. A pattern that starts with '-' is written
'[-]...' or put after '--', so that it is not read as an option.

Never deleted: the branch you are on, a branch checked out in another
worktree, and the branches named exactly
$EXCEPTIONS.

Which branches:
  --merged, -m    Only branches fully merged into $MERGED_INTO
                  (the remote's copy as last fetched).
  --gone, -g      Only branches whose upstream branch was deleted on the
                  remote, as it usually is once a pull request is merged.
                  Run 'git fetch --prune' first. Finds squash-merged branches,
                  which --merged can not.
  --nuke          Every branch, whatever its name. With --merged or --gone,
                  every branch that passes them. Takes no pattern.
  With --merged or --gone the pattern can be left out: all that pass are taken.
  Without --merged, branches are deleted whether merged or not, so work that
  was never pushed is lost. The list shows how many commits each branch holds
  that are on no remote branch and not in '$DEFAULT_BRANCH'.

How it runs:
  --dry-run, -n   Show what would be deleted and stop. Nothing is deleted
                  and nothing is asked.
  --yes, -y       Delete without asking "Are you sure?".

Other commands:
  --list, -l      List every local branch as protected, merged or unmerged.
  --porcelain     With --list: one branch per line for a script to read, as
                  status<TAB>branch<TAB>commits on no remote<TAB>upstream
                  (status: protected, merged, unmerged; upstream: tracked,
                  gone, none). No header and no colours.
  --version       Show the version.
  --help, -h      Show this help.

Examples:
  gitrid --list
  gitrid --merged feature/        Merged branches with 'feature/' in the name
  gitrid --gone --dry-run         What a clean-up after merged PRs would delete
  gitrid --gone --yes             The same, deleted without asking
  gitrid '^bugfix/'               Branches starting 'bugfix/', merged or not

In a script or an AI agent: run with --dry-run to see the list, then run the
same command with --yes. Without --yes and with nothing to answer the prompt,
gitrid deletes nothing and exits with an error.

Exit codes:
  0  Branches deleted, or a list, dry run, help or version shown
  1  Error: bad usage, not a git repository, no answer to the prompt,
     or git could not delete a branch
  2  No branch matched: nothing to delete
  3  Cancelled at the prompt
EOF
}

# Initialize variables
MERGED=false
GONE=false
NUKE=false
LIST_MODE=false
PORCELAIN=false
DRY_RUN=false
ASSUME_YES=false
PATTERN=""
PATTERN_GIVEN=false
OPTIONS_ENDED=false

# Parse arguments dynamically (options can come before or after the pattern).
# After '--' nothing is read as an option, for a pattern that starts with '-'.
for arg in "$@"; do
    if [ "$OPTIONS_ENDED" = false ]; then
        case "$arg" in
            --merged|-m) MERGED=true; continue ;;
            --gone|-g) GONE=true; continue ;;
            --nuke) NUKE=true; continue ;;
            --dry-run|-n) DRY_RUN=true; continue ;;
            --yes|-y) ASSUME_YES=true; continue ;;
            --list|-l) LIST_MODE=true; continue ;;
            --porcelain) PORCELAIN=true; continue ;;
            --) OPTIONS_ENDED=true; continue ;;
            --help|-h)
                show_help
                exit $EXIT_OK
                ;;
            --version)
                echo "gitrid version $VERSION"
                exit $EXIT_OK
                ;;
            -*)
                echo "" >&2
                echo "Error: Unknown command '$arg'" >&2
                echo "" >&2
                echo "A pattern that starts with '-' is written '[-]...' or put after '--'." >&2
                echo "Run 'gitrid --help' for the commands and what they do." >&2
                exit $EXIT_ERROR
                ;;
        esac
    fi

    # A second pattern would replace the first without a word, and the
    # branches deleted would not be the ones asked for
    if [ "$PATTERN_GIVEN" = true ]; then
        echo "Error: two patterns given ('$PATTERN' and '$arg'), and only one is taken." >&2
        echo "To match either of them use one pattern: '$PATTERN|$arg'" >&2
        exit $EXIT_ERROR
    fi
    PATTERN="$arg"
    PATTERN_GIVEN=true
done

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: not inside a git repository." >&2
    exit $EXIT_ERROR
fi

# Without a default branch there is nothing to protect and nothing to judge
# "merged" against, so stop here
if [ "$DEFAULT_BRANCH_FOUND" != true ]; then
    echo "Error: can't tell which branch is the default one: there is no 'main' or 'master'," >&2
    echo "and the remote's default branch ('origin/HEAD') is not set." >&2
    echo "If the repository has a remote, run: git remote set-head origin --auto" >&2
    exit $EXIT_ERROR
fi

if [ "$PORCELAIN" = true ] && [ "$LIST_MODE" != true ]; then
    echo "Error: --porcelain is used with --list." >&2
    exit $EXIT_ERROR
fi

# Handle list mode
if [ "$LIST_MODE" = true ]; then
    MERGED_BRANCHES=$(merged_branches)

    # Colours only in an interactive terminal; text labels otherwise
    COLOURS=false
    if [ -t 1 ] && [ "$TERM" != "dumb" ]; then
        COLOURS=true
    fi

    while IFS= read -r branch; do
        [ -z "$branch" ] && continue

        if [[ "$branch" =~ ^($EXCEPTIONS)$ ]]; then
            STATUS="protected"
            COLOUR="\033[31m"  # red
        elif echo "$MERGED_BRANCHES" | grep -Fxq -- "$branch"; then
            STATUS="merged"
            COLOUR="\033[32m"  # green
        else
            STATUS="unmerged"
            COLOUR="\033[33m"  # yellow
        fi

        LOCAL_ONLY=$(local_only_count "$branch")
        UPSTREAM=$(upstream_state "$branch")

        if [ "$PORCELAIN" = true ]; then
            printf '%s\t%s\t%s\t%s\n' "$STATUS" "$branch" "$LOCAL_ONLY" "$UPSTREAM"
            continue
        fi

        # What is worth knowing before deleting it, if anything
        NOTES=""
        if [ "$LOCAL_ONLY" -gt 0 ]; then
            NOTES=$(local_only_words "$LOCAL_ONLY")
        fi
        if [ "$UPSTREAM" = "gone" ]; then
            NOTES="${NOTES:+$NOTES, }upstream gone"
        fi
        NOTES="${NOTES:+ ($NOTES)}"

        if [ "$COLOURS" = true ]; then
            echo -e "${COLOUR}${branch}\033[0m${NOTES}"
        else
            echo "[$(echo "$STATUS" | tr '[:lower:]' '[:upper:]')] ${branch}${NOTES}"
        fi
    done <<< "$(all_branches)"

    exit $EXIT_OK
fi

if [ "$NUKE" = true ]; then
    if [ "$PATTERN_GIVEN" = true ]; then
        echo "Error: --nuke takes every branch, so it can't be given a pattern ('$PATTERN')." >&2
        echo "Use the pattern or --nuke, not both." >&2
        exit $EXIT_ERROR
    fi
    PATTERN=".*"
fi

# With --merged or --gone the pattern can be left out: all that pass are taken
if [ -z "$PATTERN" ] && { [ "$MERGED" = true ] || [ "$GONE" = true ]; }; then
    PATTERN=".*"
fi

# Ensure a pattern is provided
if [ -z "$PATTERN" ]; then
    echo "" >&2
    echo "Usage: gitrid [options] [--] <pattern>" >&2
    echo "" >&2
    echo "Give a pattern (a regular expression matched in the branch name)," >&2
    echo "or one of --merged, --gone or --nuke." >&2
    echo "" >&2
    echo "Example: gitrid --merged feature/ or gitrid '^bugfix/'" >&2
    echo "" >&2
    echo "Run 'gitrid --help' for the commands and what they do." >&2
    exit $EXIT_ERROR
fi

# Get the list of branches matching the pattern, excluding exceptions
CANDIDATES=$(all_branches)
CHOSEN_BY=""
if [ "$MERGED" = true ]; then
    CANDIDATES=$(echo "$CANDIDATES" | grep -Fxf <(merged_branches))
    CHOSEN_BY="$CHOSEN_BY that were also merged into $MERGED_INTO"
fi
if [ "$GONE" = true ]; then
    CANDIDATES=$(echo "$CANDIDATES" | grep -Fxf <(gone_branches))
    CHOSEN_BY="$CHOSEN_BY whose upstream branch is gone"
fi
LOCAL_BRANCHES=$(echo "$CANDIDATES" | grep -E -- "$PATTERN" | grep -Evx -- "($EXCEPTIONS)")

# Git can't delete a branch that is checked out, here or in another worktree,
# so leave those out and say so
CURRENT_BRANCH=$(git branch --show-current)
while IFS= read -r branch; do
    [ -z "$branch" ] && continue
    if echo "$LOCAL_BRANCHES" | grep -Fxq -- "$branch"; then
        if [ "$branch" = "$CURRENT_BRANCH" ]; then
            echo "Skipping '$branch': it is the current branch."
        else
            echo "Skipping '$branch': it is checked out in another worktree."
        fi
        LOCAL_BRANCHES=$(echo "$LOCAL_BRANCHES" | grep -Fvx -- "$branch")
    fi
done <<< "$(checked_out_branches)"

# Check if any branches match the pattern
if [ -z "$LOCAL_BRANCHES" ]; then
    echo "No local branches found matching pattern: $PATTERN$CHOSEN_BY (excluding $EXCEPTIONS branches)"
    exit $EXIT_NO_MATCH
fi

# Display the branches, each with the work deleting it would lose
if [ "$DRY_RUN" = true ]; then
    echo "The following local branches would be deleted:"
else
    echo "The following local branches will be deleted:"
fi

WORK_AT_RISK=false
while IFS= read -r branch; do
    LOCAL_ONLY=$(local_only_count "$branch")
    if [ "$LOCAL_ONLY" -gt 0 ]; then
        WORK_AT_RISK=true
        echo "  $branch  ($(local_only_words "$LOCAL_ONLY"))"
    else
        echo "  $branch"
    fi
done <<< "$LOCAL_BRANCHES"

if [ "$MERGED" = true ]; then
    echo "(These branches were fully merged into $MERGED_INTO.)"
fi

if [ "$WORK_AT_RISK" = true ]; then
    echo "WARNING: commits on no remote are not in '$DEFAULT_BRANCH' either. Deleting the branch loses them,"
    echo "unless its pull request was squash-merged and the remote branch then deleted."
fi

if [ "$DRY_RUN" = true ]; then
    echo "Dry run: nothing was deleted."
    exit $EXIT_OK
fi

if [ "$ASSUME_YES" != true ]; then
    # With nothing to answer (no terminal and nothing piped in), say so and
    # fail, so a script does not take a silent cancel for a clean-up
    if ! read -r -p "Are you sure? (y/n) " CONFIRM && [ -z "$CONFIRM" ]; then
        echo "" >&2
        echo "Error: no answer to the prompt, so nothing was deleted." >&2
        echo "Run gitrid in a terminal, or pass --yes to delete without asking." >&2
        exit $EXIT_ERROR
    fi

    # An answer piped in from PowerShell or cmd ends with a carriage return
    CONFIRM="${CONFIRM%$'\r'}"

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "Deletion cancelled."
        exit $EXIT_CANCELLED
    fi
fi

# An array, not xargs, which would trip on a quote in a branch name
TO_DELETE=()
while IFS= read -r branch; do
    TO_DELETE+=("$branch")
done <<< "$LOCAL_BRANCHES"

if git branch -D -- "${TO_DELETE[@]}"; then
    echo "Local branches deleted."
    exit $EXIT_OK
fi

echo "Error: git could not delete every branch listed." >&2
exit $EXIT_ERROR
