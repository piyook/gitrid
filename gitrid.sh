#!/usr/bin/env bash

# Version information
VERSION="3.0.1"

# Verify the main branch name
DEFAULT_BRANCH="main"
if ! git rev-parse --verify "refs/heads/$DEFAULT_BRANCH" >/dev/null 2>&1; then
    DEFAULT_BRANCH="master"  # Fallback to 'master' if 'main' doesn't exist
fi

# Define branches to exclude from deletion. A branch is protected only if its
# whole name is one of these, so 'feature/device' is not protected by 'dev'.
EXCEPTIONS="$DEFAULT_BRANCH|dev|develop|development"

# What a branch is checked against to see if it is merged: the local default
# branch and, if there is one, the remote's copy of it as last fetched. After a
# pull request is merged on the remote the local default branch is often
# behind, so checking it alone would report the merged branch as unmerged.
MERGE_TARGETS=("$DEFAULT_BRANCH")
MERGED_INTO="'$DEFAULT_BRANCH'"
if git rev-parse --verify --quiet "refs/remotes/origin/$DEFAULT_BRANCH" >/dev/null 2>&1; then
    MERGE_TARGETS+=("origin/$DEFAULT_BRANCH")
    MERGED_INTO="$MERGED_INTO or 'origin/$DEFAULT_BRANCH'"
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

# Initialize variables
MERGED=false
PATTERN=""
LIST_MODE=false

# Parse arguments dynamically (allowing --merged first or last)
for arg in "$@"; do
    if [ "$arg" == "--merged" ] || [ "$arg" == "-m" ]; then
        MERGED=true
    elif [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
        echo ""
        echo "Usage: gitrid [--merged | -m, --nuke, --list, --version] <pattern>"
        echo ""
        echo "Use --merged or -m to delete only branches that are fully merged into the main branch."
        echo "Branches matching the pattern will be deleted, excluding: $EXCEPTIONS"
        echo ""
        echo "Example: gitrid --merged 'feature/*' or gitrid 'bugfix/*'"
        echo ""
        echo "Use --nuke to delete all branches matching the pattern except protected branches."
        echo ""
        echo "Use --list to list all branches with color coding:"
        echo "  RED: Protected branches ($EXCEPTIONS)"
        echo "  GREEN: Merged branches"
        echo "  YELLOW: Unmerged branches"
        echo ""
        echo "Use --version to display the current version."
        exit 0
    elif [[ "$arg" == "--version" ]]; then
        echo "gitrid version $VERSION"
        exit 0
    elif [[ "$arg" == "--list" ]]; then
        LIST_MODE=true
    elif [[ "$arg" == "--nuke" ]]; then
        PATTERN=".*"
    elif [[ "$arg" == --* ]]; then
        echo ""
        echo "Error: Unknown command '$arg'"
        echo ""
        echo "Available commands:"
        echo "  --help, -h        Show this help message"
        echo "  --version         Show version information"
        echo "  --list            List all branches with color coding"
        echo "  --merged, -m      Only delete merged branches"
        echo "  --nuke            Delete all branches (except protected)"
        echo ""
        echo "Usage: gitrid [--merged | -m, --nuke, --list, --version] <pattern>"
        exit 1
    else
        PATTERN="$arg"
    fi
done

# Handle list mode
if [ "$LIST_MODE" = true ]; then
    # Check if running in interactive terminal (supports ANSI colors)
    if [ -t 1 ] && [ "$TERM" != "dumb" ]; then
        
        # Get all branches
        ALL_BRANCHES=$(all_branches)
        
        # Get merged branches
        MERGED_BRANCHES=$(merged_branches)
        
        while IFS= read -r branch; do
            if [[ "$branch" =~ ^($EXCEPTIONS)$ ]]; then
                # Protected branches - red
                echo -e "\033[31m$branch\033[0m"
            elif echo "$MERGED_BRANCHES" | grep -Fxq -- "$branch"; then
                # Merged branches - green
                echo -e "\033[32m$branch\033[0m"
            else
                # Unmerged branches - yellow
                echo -e "\033[33m$branch\033[0m"
            fi
        done <<< "$ALL_BRANCHES"
    else
        # Non-interactive terminal (PowerShell, etc.) - use text labels
        echo "Listing all branches with color coding:"
        echo "  Protected branches ($EXCEPTIONS):"
        echo "  Merged branches:"
        echo "  Unmerged branches:"
        echo ""
        
        # Get all branches
        ALL_BRANCHES=$(all_branches)
        
        # Get merged branches
        MERGED_BRANCHES=$(merged_branches)
        
        while IFS= read -r branch; do
            if [[ "$branch" =~ ^($EXCEPTIONS)$ ]]; then
                # Protected branches
                echo "[PROTECTED] $branch"
            elif echo "$MERGED_BRANCHES" | grep -Fxq -- "$branch"; then
                # Merged branches
                echo "[MERGED] $branch"
            else
                # Unmerged branches
                echo "[UNMERGED] $branch"
            fi
        done <<< "$ALL_BRANCHES"
    fi
    
    exit 0
fi

# Ensure a pattern is provided
if [ -z "$PATTERN" ]; then
    echo ""
    echo "Usage: gitrid [--merged | -m] <pattern>"
    echo ""
    echo "Use --merged or -m to delete only branches that are fully merged into the main branch."
    echo "Branches matching the pattern will be deleted, excluding: $EXCEPTIONS"
    echo ""
    echo "Example: gitrid --merged 'feature/*' or gitrid 'bugfix/*'"
    exit 1
fi

# Get the list of branches matching the pattern, excluding exceptions
if [ "$MERGED" = true ]; then
    CANDIDATES=$(merged_branches)
else
    CANDIDATES=$(all_branches)
fi
LOCAL_BRANCHES=$(echo "$CANDIDATES" | grep -E -- "$PATTERN" | grep -Evx -- "($EXCEPTIONS)")

# Git can't delete the branch that is checked out, so leave it out and say so
CURRENT_BRANCH=$(git branch --show-current)
if [ -n "$CURRENT_BRANCH" ] && echo "$LOCAL_BRANCHES" | grep -Fxq -- "$CURRENT_BRANCH"; then
    echo "Skipping '$CURRENT_BRANCH': it is the current branch."
    LOCAL_BRANCHES=$(echo "$LOCAL_BRANCHES" | grep -Fvx -- "$CURRENT_BRANCH")
fi

# Check if any branches match the pattern
if [ -z "$LOCAL_BRANCHES" ]; then
    if [ "$MERGED" = true ]; then
        echo "No local branches found matching pattern: $PATTERN that were also merged into $MERGED_INTO (excluding $EXCEPTIONS branches)"
    else
        echo "No local branches found matching pattern: $PATTERN (excluding $EXCEPTIONS branches)"
    fi
    exit 0
fi

# Display appropriate confirmation message
echo "The following local branches will be deleted:"
echo "$LOCAL_BRANCHES" | sed 's/^/  /'

if [ "$MERGED" = true ]; then
    echo "(These branches were fully merged into $MERGED_INTO.)"
fi

read -p "Are you sure? (y/n) " CONFIRM

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "$LOCAL_BRANCHES" | xargs git branch -D
    echo "Local branches deleted."
else
    echo "Deletion cancelled."
fi