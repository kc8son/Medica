#!/bin/zsh
#
# Day 1 Mac setup for a data engineering workstation
# Installs tools with Homebrew and applies common post-install settings.
#
# What this script covers:
# - Homebrew shell setup
# - CLI tools
# - GUI apps
# - useful shell aliases
# - Git defaults
# - pipx path setup
# - optional Python packages for dbt adapters
# - reminders for manual steps after install
#
# Notes:
# - Run this as your normal user, not with sudo.
# - You may be prompted for your password for some Homebrew cask installs.
# - A few tools still need manual first-run or login steps after installation.
#

set -euo pipefail

echo "=== Checking for Homebrew ==="
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is not installed."
  echo "Install it first with:"
  echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  exit 1
fi

# Ensure brew is available in this shell, especially on Apple Silicon Macs.
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

echo "=== Updating Homebrew ==="
brew update

echo "=== Installing CLI tools ==="
brew install \
  awscli \
  dbt-core \
  gh \
  jq \
  mssql-tools \
  pipx \
  python \
  snowflake-cli \
  sqlfluff \
  terraform

echo "=== Installing GUI applications ==="
brew install --cask \
  azure-data-studio \
  brave-browser \
  dbeaver-community \
  docker \
  firefox \
  google-chrome \
  sublime-text \
  visual-studio-code

echo "=== Installing optional quality-of-life CLI tools ==="
brew install \
  fzf \
  htop \
  tree

echo "=== Configuring shell profile (~/.zshrc) ==="
ZSHRC="$HOME/.zshrc"
touch "$ZSHRC"

append_if_missing() {
  local line="$1"
  if ! grep -Fqx "$line" "$ZSHRC"; then
    echo "$line" >> "$ZSHRC"
  fi
}

# Homebrew shell initialization
append_if_missing ''
append_if_missing '# Homebrew'
append_if_missing 'if [ -x /opt/homebrew/bin/brew ]; then'
append_if_missing '  eval "$(/opt/homebrew/bin/brew shellenv)"'
append_if_missing 'fi'

# PATH additions
append_if_missing ''
append_if_missing '# PATH additions'
append_if_missing 'export PATH="/opt/homebrew/opt/mssql-tools/bin:$PATH"'
append_if_missing 'export PATH="$HOME/.local/bin:$PATH"'

# Optional AWS default region placeholder
append_if_missing ''
append_if_missing '# Optional AWS default region'
append_if_missing '# export AWS_DEFAULT_REGION=us-east-1'

# Handy aliases
append_if_missing ''
append_if_missing '# Useful aliases'
append_if_missing 'alias ll="ls -lah"'
append_if_missing 'alias gs="git status"'
append_if_missing 'alias gd="git diff"'
append_if_missing 'alias gp="git pull"'
append_if_missing 'alias gl="git log --oneline --graph --decorate"'

echo "=== Activating pipx path ==="
pipx ensurepath || true

echo "=== Setting Git defaults if not already set ==="
if ! git config --global --get init.defaultBranch >/dev/null 2>&1; then
  git config --global init.defaultBranch main
fi

echo "=== Installing dbt adapters for common warehouse targets ==="
python3 -m pip install --upgrade pip
python3 -m pip install dbt-postgres dbt-snowflake

echo "=== Creating ~/.dbt directory if needed ==="
mkdir -p "$HOME/.dbt"

echo "=== Homebrew health check ==="
brew doctor || true

cat <<'EOF'

========================================
INSTALL COMPLETE
========================================

Open a new terminal window, or run:
  source ~/.zshrc

Recommended validation commands:
  brew --version
  git --version
  gh --version
  aws --version
  snow --version
  dbt --version
  sqlfluff --version
  sqlcmd -?
  code --version
  docker --version

Manual steps still needed:
  1. Launch Docker Desktop once:
       open /Applications/Docker.app

  2. Authenticate GitHub CLI:
       gh auth login

  3. Configure AWS CLI:
       aws configure
     or, if your company uses SSO:
       aws configure sso

  4. Add a Snowflake CLI connection:
       snow connection add

  5. In DBeaver, create connections for:
       - Snowflake
       - PostgreSQL
       - SQL Server
       - Oracle
     DBeaver will usually prompt to download JDBC drivers automatically.

  6. In VS Code, install extensions you want, such as:
       - Python
       - Jupyter
       - Docker
       - AWS Toolkit
       - SQLFluff
       - dbt Power User
       - YAML
       - GitLens

Notes about database drivers:
  - DBeaver usually handles Snowflake, SQL Server, PostgreSQL, and Oracle drivers for you.
  - SQL Server CLI support comes from mssql-tools.
  - Oracle command-line client tools are not included here.

EOF