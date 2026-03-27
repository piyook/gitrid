![GitHub Release](https://img.shields.io/github/v/release/piyook/gitrid)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

# gitrid: A Branch Batch Deletion Command Line Utility for Git Repositories :scissors:

Lets face it - old redundant branches can quickly start to get out of hand and clog up your local repo. :face_with_spiral_eyes:

Tidying up a local repo by deleting branches one by one can be a real pain and using the usual Git command can mean accidentally deleting the wrong branch or deleting a branch you don't want to delete. :cursing_face:

Git Crop is a simple bash script that allows you to safely delete all branches matching a given pattern in a LOCAL git repository with a single command.

The search pattern automatically excludes protected branches such as the default ('main' or 'master') branch and any 'develop' branches to prevent deleting them by accident. Other protected branches patterns can be added into the EXCEPTIONS variable command in the script.

This script is easier and safer than using the usual Git command below:

```bash
git branch -D $(git branch --list 'pattern/*')
```

## Usage

To use Git Crop, simply run the script in a Git repo with the pattern you want to match as an argument. For example:

```bash
gitrid feature/
```

This will delete all branches in the current Git repo that match the pattern "feature/" first listing them and checking you want them deleted before deleting them.

To delete ALL branches except protected ones ('main' or 'develop') use --nuke option :bomb: :bomb: :boom:

```bash
gitrid --nuke

WARNING: The following branches will be PERMANENTLY deleted:
  chore/apply_patch-2
  chore/pr-21
  test/test-1
  feat/jira-123/new-options
  fix/jira-125/comments
  pr-22
Are you sure? (y/n)
```

## Options

- use '--help' or '-h' to display a help message
- use '--nuke' to delete ALL local branches except 'main' or 'develop'
- u.se '--merged' or '-m' to only delete branches MERGED into main (or master) branch matching the supplied pattern
- use '--list' to list all branches with color coding:
  - 🔴 **Red**: Protected branches (main, dev, development)
  - 🟢 **Green**: Merged branches (fully merged into main)
  - 🟡 **Yellow**: Unmerged branches (not yet merged)
- use '--version' to display the current version

<i>Note: branches that are newly created from the main branch with no new commits that match the search pattern will also be deleted since they are fully merged by default.</i>

E.g

```bash
gitrid feature/ --merged
```

will only delete branches merged into main (or are identical) that match the pattern 'feature/'

## Listing Branches

To view all branches in your repository with color-coded status, use the `--list` option:

```bash
gitrid --list
```

Example output:
```
[P] main                    # Protected branch (red)
[M] feature/login           # Merged branch (green)
[M] feature/dashboard       # Merged branch (green)
[UM] feature/payment        # Unmerged branch (yellow)
[UM] bugfix/issue-123       # Unmerged branch (yellow)
```

This feature helps you quickly identify the status of all branches in your repository before deciding which ones to clean up.

**Note on Color Display:**
- **Native terminals** (Linux, macOS, Git Bash): Full ANSI color support with colored branch names
- **PowerShell/Windows**: Text-based labels for better compatibility:
  - `[P] branch-name` for protected branches
  - `[M] branch-name` for merged branches  
  - `[UM] branch-name` for unmerged branches

## Installation

To install Git Crop, simply run the appropriate setup script for your system. The setup scripts can be used for both initial installation and updating to newer versions.

### Linux / Mac / WSL:

1. Run the setup script:

```bash
bash setup_linux.sh
```

The script will automatically detect if gitrid is already installed and update it accordingly.

2. Check it works:

```bash
source ~/.bashrc

gitrid --help
```

### Windows PowerShell:

**Prerequisites**: WSL must be installed and gitrid must be installed in WSL first (run `bash setup_linux.sh` in WSL).

1. Run the PowerShell setup script:

```PowerShell
# Set execution policy if needed (one-time setup)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Run the setup script
.\setup_powershell.ps1
```

The script will:
- Check if gitrid is already installed and update it if needed
- Verify WSL is available and gitrid is installed in WSL
- Copy the batch file to your Windows user PATH (no admin required)

2. Check it works:

```PowerShell
gitrid --help
```

### Git Bash on Windows:

1. Run the setup script:

```bash
bash setup_gitbash.sh
```

This creates a Scripts directory in the user's home directory (if one doesn't already exist) and copies the gitrid.sh script into it, makes it executable and adds an alias for easy access. The script will detect existing installations and update them automatically.

2. Check it works:

```bash
source ~/.bashrc

gitrid --help
```

### Updating gitrid

To update gitrid to the latest version, simply run the same setup script again with the newer version. 

### Version Management

Check your current version with:
```bash
gitrid version
```


## License

This script is released under the [MIT License](https://opensource.org/licenses/MIT).
