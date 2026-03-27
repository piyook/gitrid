#!/usr/bin/env bash

# Version information
VERSION="2.1.0"

# Verify the main branch name
DEFAULT_BRANCH="main"
if ! git rev-parse --verify "refs/heads/$DEFAULT_BRANCH" >/dev/null 2>&1; then
    DEFAULT_BRANCH="master"  # Fallback to 'master' if 'main' doesn't exist
fi

# Define branches to exclude from deletion
EXCEPTIONS="$DEFAULT_BRANCH|dev|development"

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
        ALL_BRANCHES=$(git branch --format="%(refname:short)")
        
        # Get merged branches
        MERGED_BRANCHES=$(git branch --merged "$DEFAULT_BRANCH" --format="%(refname:short)")
        
        while IFS= read -r branch; do
            if [[ "$branch" =~ ^($EXCEPTIONS)$ ]]; then
                # Protected branches - red
                echo -e "\033[31m$branch\033[0m"
            elif echo "$MERGED_BRANCHES" | grep -q "^$branch$"; then
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
        ALL_BRANCHES=$(git branch --format="%(refname:short)")
        
        # Get merged branches
        MERGED_BRANCHES=$(git branch --merged "$DEFAULT_BRANCH" --format="%(refname:short)")
        
        while IFS= read -r branch; do
            if [[ "$branch" =~ ^($EXCEPTIONS)$ ]]; then
                # Protected branches
                echo "[PROTECTED] $branch"
            elif echo "$MERGED_BRANCHES" | grep -q "^$branch$"; then
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

# Get the list of merged branches matching the pattern, excluding exceptions
if [ "$MERGED" = true ]; then
    LOCAL_BRANCHES=$(git branch --merged "$DEFAULT_BRANCH" | grep -E "$PATTERN" | grep -Ev "$EXCEPTIONS")
else
    LOCAL_BRANCHES=$(git branch | grep -E "$PATTERN" | grep -Ev "$EXCEPTIONS")
fi

# Check if any branches match the pattern
if [ -z "$LOCAL_BRANCHES" ]; then
    if [ "$MERGED" = true ]; then
        echo "No local branches found matching pattern: $PATTERN that were also merged into '$DEFAULT_BRANCH' (excluding $EXCEPTIONS branches)"
    else
        echo "No local branches found matching pattern: $PATTERN (excluding $EXCEPTIONS branches)"
    fi
    exit 0
fi

# Display appropriate confirmation message
echo "The following local branches will be deleted:"
echo "$LOCAL_BRANCHES"

if [ "$MERGED" = true ]; then
    echo "(These branches were fully merged into '$DEFAULT_BRANCH'.)"
fi

read -p "Are you sure? (y/n) " CONFIRM

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "$LOCAL_BRANCHES" | xargs git branch -D
    echo "Local branches deleted."
else
    echo "Deletion cancelled."
fi