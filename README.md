![GitHub Release](https://img.shields.io/github/v/release/piyook/gitrid)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

# gitrid: A Git Branch Batch Deletion Command Line Utility for Humans and AI Agents :scissors:

Lets face it - old redundant branches can quickly start to get out of hand and clog up your local repo. :face_with_spiral_eyes:

Tidying up a local repo by deleting branches one by one can be a real pain and using the usual Git command can mean accidentally deleting the wrong branch or deleting a branch you don't want to delete. :cursing_face:

gitrid is a simple bash script that allows you (or your coding agent) to safely delete all branches matching a given pattern in a LOCAL git repository with a single command.

The search pattern automatically excludes protected branches to prevent deleting them by accident: the default branch ('main' or 'master') and 'dev', 'develop' and 'development'. A branch is protected only if its whole name is one of these, so 'feature/device-list' or 'chore/maintenance' can still be deleted. Other protected branches can be added to the EXCEPTIONS variable in the script. The branch you are on is never deleted either, nor is a branch checked out in another worktree.

In a repository with no 'main' or 'master', the default branch is the one the remote names as its default ('origin/HEAD', which `git clone` sets). If there is none to be found, gitrid stops with an error and deletes nothing.

This script is easier and safer than using the usual Git command below:

```bash
git branch -D $(git branch --list 'pattern/*')
```

It is built to be used both ways:

- **By you, in a terminal**: one command, a colour-coded list of what is merged and what is not, a count of the commits each branch would lose, and an "Are you sure?" before anything goes.
- **By a coding agent or a script**: `--dry-run` to preview, `--yes` to delete with no prompt, `--list --porcelain` for output a program can read, and exit codes that say what happened. See [Scripts and AI agents](#scripts-and-ai-agents) and [llms.txt](llms.txt).

## Usage

Run gitrid in a Git repo with the pattern you want to match as an argument. For example:

```bash
gitrid feature/
```

This lists every local branch with "feature/" in its name and asks before deleting them:

```bash
The following local branches will be deleted:
  feature/login
  feature/payment  (2 commits on no remote)
WARNING: commits on no remote are not in 'main' either. Deleting the branch loses them,
unless its pull request was squash-merged and the remote branch then deleted.
Are you sure? (y/n)
```

The pattern is a regular expression matched anywhere in the branch name (as `grep -E` does), not a glob: use `feature/`, not `feature/*`, and `^fix/` for branches that start with "fix/".

Only one pattern is taken: for either of two, write `'feat/|fix/'`. A pattern that starts with `-` would be read as an option, so write it as `'[-]123$'`, or put it after `--` (`gitrid --dry-run -- '-123$'`; not in PowerShell, which takes the `--` for itself).

Only local branches are deleted. Remote branches are never touched.

## Options

Which branches:

- `--merged` or `-m`: only branches fully MERGED into main (or master). A branch counts as merged if it is merged into your local main or into 'origin/main' as last fetched, so after a pull request is merged on the remote, run `git fetch` and the branch shows as merged without updating your local main first.
- `--gone` or `-g`: only branches whose upstream branch has been deleted on the remote, as it usually is once a pull request is merged. Run `git fetch --prune` first. This finds squash-merged branches, which `--merged` can not, since their commits are never in main. A gone upstream is not proof of a merge: a remote branch deleted for any other reason looks the same, and a branch that was never pushed is never "gone".
- `--nuke`: ALL local branches except the protected ones and the one you are on :bomb: :bomb: :boom: It takes no pattern: giving both is an error.

With `--merged` or `--gone` the pattern can be left out, and every branch that passes is taken. Used together, a branch must pass both. Without `--merged`, branches are deleted whether merged or not, so the list shows how many commits each one holds that are on no remote branch and not in main: work that deleting the branch would lose.

<i>Note: branches that are newly created from the main branch with no new commits that match the search pattern will also be deleted with --merged since they are fully merged by default.</i>

How it runs:

- `--dry-run` or `-n`: show what would be deleted and stop. Nothing is deleted and nothing is asked.
- `--yes` or `-y`: delete without asking "Are you sure?".

Other commands:

- `--list` or `-l`: list all branches with their status (see below)
- `--porcelain`: with `--list`, a fixed format for scripts to read
- `--version`: display the current version
- `--help` or `-h`: display a help message

Options can come before or after the pattern.

E.g

```bash
gitrid feature/ --merged
```

will only delete branches merged into main (or are identical) that match the pattern 'feature/'

```bash
git fetch --prune
gitrid --gone --dry-run
gitrid --gone
```

shows, then deletes, the branches whose pull requests were merged and their remote branches deleted.

## Listing Branches

To view all branches in your repository with their status, use the `--list` option:

```bash
gitrid --list
```

In a terminal the branch names are coloured:

- 🔴 **Red**: Protected branches (main, dev, develop, development)
- 🟢 **Green**: Merged branches (fully merged into main)
- 🟡 **Yellow**: Unmerged branches (not yet merged)

Where the output is not a terminal (piped, or run by a script) the status is a label in front of the name:

```
[PROTECTED] main
[MERGED] feature/login
[MERGED] feature/dashboard
[UNMERGED] feature/payment (2 commits on no remote)
[UNMERGED] bugfix/issue-123 (1 commit on no remote, upstream gone)
```

A branch is also marked with the commits it holds that are on no remote branch and not in main, and with "upstream gone" if its remote branch has been deleted.

For a script, `gitrid --list --porcelain` prints one branch per line with no header and no colours, as four tab-separated fields: status (`protected`, `merged`, `unmerged`), branch, commits on no remote, and upstream (`tracked`, `gone`, `none`):

```
protected	main	0	tracked
merged	feature/login	0	tracked
unmerged	feature/payment	2	none
```

## Scripts and AI agents

gitrid can be run without anyone at the keyboard:

1. `git fetch --prune`, so merged and gone are judged from the remote as it is now (gitrid never fetches)
2. run the command with `--dry-run` to see what would be deleted
3. an agent shows that list to its user and gets a yes. A `WARNING:` line in it means some branch holds commits that are nowhere else
4. run the same command with `--yes`

```bash
git fetch --prune
gitrid --merged --dry-run
gitrid --merged --yes
```

Without `--yes`, and with nothing to answer the prompt, gitrid deletes nothing and exits with an error, so a script never takes a silent cancel for a clean-up.

To decide for itself what is safe, a script reads `gitrid --list --porcelain` ([above](#listing-branches)): a branch is safe to delete if its status is `merged` or its commits on no remote are `0`.

The setup scripts make `gitrid` a command on the PATH, so it works in a shell that is not interactive (a script, a hook, an agent) as it does at the prompt. Versions before this one made it an alias in `~/.bashrc`, which such a shell does not load: if an agent or script gets "command not found", run the setup script again.

The exit code says what happened:

| Code | Meaning |
|---|---|
| 0 | Branches deleted, or a list, dry run, help or version shown |
| 1 | Error: bad usage, not a git repository, no answer to the prompt, or git could not delete a branch |
| 2 | No branch matched, so there was nothing to delete |
| 3 | Cancelled at the prompt |

[llms.txt](llms.txt) is the full reference written for AI agents: point your agent at it.

## Installation

To install gitrid, simply run the appropriate setup script for your system. The setup scripts can be used for both initial installation and updating to newer versions.

### Linux / Mac / WSL:

1. Run the setup script from the gitrid folder (it uses `sudo` to copy the script to `/usr/local/bin`):

```bash
bash setup_linux.sh
```

This copies the script to `/usr/local/bin/gitrid.sh` and makes `/usr/local/bin/gitrid` a link to it. If gitrid is already installed, the script replaces it with this version.

2. Check it works:

```bash
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
- Copy `gitrid.ps1` (which PowerShell runs) and `gitrid.bat` (for cmd) to your Windows user PATH (no admin required)

In cmd, put a pattern that has a `^` in double quotes, `gitrid "^fix/"`, or cmd drops the `^`. PowerShell needs nothing special.

2. Check it works:

```PowerShell
gitrid --help
```

### Git Bash on Windows:

1. Run the setup script:

```bash
bash setup_gitbash.sh
```

This creates a Scripts directory in the user's home directory (if one doesn't already exist), copies the gitrid.sh script into it and makes it executable. It then writes the `gitrid` command to `~/bin/gitrid`, a small script that runs `~/Scripts/gitrid.sh`. Run it again to update an existing installation.

Git Bash puts `~/bin` on the PATH when the folder exists. If the setup script had to create it, open a new Git Bash window before using `gitrid`.

2. Check it works:

```bash
gitrid --help
```

### Updating gitrid

To update gitrid to the latest version, simply run the same setup script again with the newer version. 

### Version Management

Check your current version with:
```bash
gitrid --version
```


## Tests

The tests in `tests/gitrid.bats` run the script against a throwaway repository and check what it lists, what it deletes and its exit codes. They use [bats](https://github.com/bats-core/bats-core), and need bash, git and Node (for `npx`):

```bash
npx bats tests
```

They run on every pull request, on Linux and macOS, along with [ShellCheck](https://www.shellcheck.net/) on the shell scripts.

## License

This script is released under the [MIT License](https://opensource.org/licenses/MIT).
