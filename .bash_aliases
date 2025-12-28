### must be sourced not executed since this is meant to modify aliases

# This script modifies the current shell and must be sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: this script must be sourced, not executed." >&2
  echo "Usage: source ${BASH_SOURCE[0]}" >&2

  # If the script was sourced, `return` cleanly stops execution of the sourced file
  # without killing the user's shell.
  # If the script was executed, `return` is invalid and fails, so we fall back to
  # `exit 1` to terminate the process. stderr is silenced to avoid a confusing
  # "return: can only return from a function or sourced script" message.
  #
  # TLDNR: `return` stops a sourced script; if executed, it fails and we fall back to `exit`
  return 1 2>/dev/null || exit 1
fi


alias ga='git add '
alias gb='git branch '
alias gca='git commit -a -v '
alias gc='git commit'
alias gcl='git clone '
alias gco='git checkout '
alias gd='git diff'
alias gh='git log --pretty=format:"%h %ad | %s%d [%an]" --graph --date=short'
alias gl2="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit -p"
alias gl3="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all"
alias gl4="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(bold yellow)%d%C(reset)%n''          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)' --all"
alias gl5="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
#alias gl='git log '
alias gl="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
alias gll="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit -p"

## all branches colored
alias gla="git log --all --graph --decorate --date=format:'%Y-%m-%d %H:%M' --pretty=format:'%C(yellow)%h%Creset %C(cyan)%ad%Creset %C(auto)%d %s'"
alias gla2="git log --all --graph --decorate --date=format:'%Y-%m-%d %H:%M' --pretty=format:'%C(auto)%h %ad %d %s'"

alias gp='git push'
alias gpl='git pull'
alias gps='git push'
alias gpu='git pull'
alias gs='git status '
alias gss='git for-each-ref --sort=-committerdate'


gwww() {
  # Create (or attach) a Git worktree for a branch in ../wt/<branch-name>,
  # and then cd into it.
  #
  # Behaviors:
  #   - If <branch-name> exists locally: add a worktree for it.
  #   - Else if it exists on origin: create a local branch tracking origin/<branch-name> and add a worktree.
  #   - Else: create a new branch from <start-point> (default: main) and add a worktree.
  #
  # Usage:
  #   gwww <branch-name> [<start-point>]
  #
  # Examples:
  #   gwww feature/foo
  #   gwww bugfix/login release/1.2
  #
  # Notes:
  #   - The directory name replaces '/' with '-' so branch names like feature/foo
  #     become ../wt/feature-foo (avoid nested dirs and keep paths shell-friendly).

  if [[ -z "${1:-}" ]]; then
    echo "Usage: gwww <branch-name> [<start-point>]" >&2
    return 1
  fi

  # Ensure we're in a git repository. This fails fast with a clear message instead of
  # letting later git commands print confusing errors.
  #
  # git rev-parse --is-inside-work-tree
  #   - Prints "true" if we're inside a working tree.
  #   - Exits non-zero if not in a git repo at all.
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: not inside a git repository" >&2
    return 1
  fi

  local branch="$1"
  local start_point="${2:-main}"   # default base when creating new branches
  local dir="../wt/${branch//\//-}"

  # Safety: don't create a worktree in an existing path.
  # -e catches both existing directories and existing files/symlinks.
  if [[ -e "$dir" ]]; then
    echo "Error: target path already exists: $dir" >&2
    return 1
  fi

  # CASE 1: Local branch already exists -> just add a worktree pointing at it.
  #
  # git show-ref --verify --quiet "refs/heads/<branch>"
  #   - show-ref lists references (branches, tags, remotes).
  #   - --verify requires an exact ref name; it exits non-zero if it doesn't exist.
  #   - --quiet suppresses output; we only care about the exit code.
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    # git worktree add <path> <branch>
    #   - Creates a new linked worktree at <path>
    #   - Checks out <branch> into that worktree
    #   - Does NOT create a branch; assumes it already exists
    git worktree add "$dir" "$branch" || return 1

    echo "Worktree added for existing local branch '$branch': $dir"
    cd "$dir" || return 1
    return 0
  fi

  # CASE 2: Branch doesn't exist locally, but exists on remote origin -> create local tracking branch.
  #
  # IMPORTANT: This checks your *local* remote-tracking refs (origin/<branch>).
  # If you haven't fetched recently, the remote branch might exist but your local
  # refs/remotes/origin/* might be outdated. Run `git fetch origin` if needed.
  #
  # git show-ref --verify --quiet "refs/remotes/origin/<branch>"
  #   - Tests whether your local remote-tracking ref exists.
  if git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    # git worktree add --track -b <branch> <path> <start-point>
    #   - -b <branch> creates a new local branch named <branch>
    #   - <start-point> here is "origin/<branch>" (the remote-tracking ref)
    #   - --track sets the upstream of the new local branch to origin/<branch>
    #     (so `git pull` and `git push` know where to sync by default)
    #
    # Effectively: "create local branch tracking origin/<branch> and check it out in <path>"
    git worktree add --track -b "$branch" "$dir" "origin/$branch" || return 1

    echo "Worktree added for remote branch 'origin/$branch' (tracking local '$branch'): $dir"
    cd "$dir" || return 1
    return 0
  fi

  # CASE 3: Neither local nor origin/<branch> exists -> create a new branch from start_point.
  #
  # Validate that <start-point> resolves to a commit to give a clean error.
  # git rev-parse --verify --quiet "<name>^{commit}"
  #   - Checks that <name> exists AND points to (or can be peeled to) a commit.
  #   - Works for branch names, tags, and commit hashes.
  if ! git rev-parse --verify --quiet "$start_point^{commit}" >/dev/null; then
    echo "Error: start point not found (or not a commit): $start_point" >&2
    echo "Hint: try 'main', 'master', 'origin/main', a tag, or a commit hash." >&2
    return 1
  fi

  # git worktree add -b <branch> <path> <start-point>
  #   - Creates a new local branch <branch> starting at <start-point>
  #   - Creates a new linked worktree at <path>
  #   - Checks out the newly created branch into that worktree
  git worktree add -b "$branch" "$dir" "$start_point" || return 1

  echo "Worktree created for new branch '$branch' from '$start_point': $dir"
  cd "$dir" || return 1
  return 0
}


