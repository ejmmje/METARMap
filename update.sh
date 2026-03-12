#!/usr/bin/env bash

set -Eeuo pipefail
trap 'echo "Error: update failed on line $LINENO."; exit 1' ERR

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
cd "$PROJECT_DIR"

INVOKING_USER="${SUDO_USER:-$USER}"
INVOKING_HOME="$(getent passwd "$INVOKING_USER" | cut -d: -f6 2>/dev/null || true)"
if [[ -z "$INVOKING_HOME" ]]; then
    INVOKING_HOME="$HOME"
fi

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$INVOKING_HOME/METARMapbackup/$TIMESTAMP"

echo -e "${GREEN}Starting METARMap update...${NC}"
echo "Project directory: $PROJECT_DIR"
echo "Backup directory: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Step 1: Stop running processes
echo -e "${YELLOW}Stopping active METARMap processes...${NC}"
if [[ -f "$PROJECT_DIR/lightsoff.sh" ]]; then
    /bin/bash "$PROJECT_DIR/lightsoff.sh" || true
else
    echo -e "${RED}Warning: lightsoff.sh not found; skipping shutdown step.${NC}"
fi

# Step 2: Backup user-specific files
echo -e "${YELLOW}Backing up user files...${NC}"
for file in airports displayairports config.json; do
    if [[ -f "$PROJECT_DIR/$file" ]]; then
        cp "$PROJECT_DIR/$file" "$BACKUP_DIR/$file.bak"
        echo "Backed up $file"
    fi
done

if [[ -t 0 ]]; then
    echo
    ls -l "$BACKUP_DIR" || true
    read -r -p "Press [Enter] to continue update, or Ctrl+C to abort..." _
fi

# Step 3: Ensure git can run safely under sudo/root
if [[ "$EUID" -eq 0 ]]; then
    git config --global --add safe.directory "$PROJECT_DIR" >/dev/null 2>&1 || true
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo -e "${RED}Error: $PROJECT_DIR is not a git repository.${NC}"
    exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" == "HEAD" ]]; then
    echo -e "${RED}Error: detached HEAD detected. Check out a branch before running update.${NC}"
    exit 1
fi

attempt_update() {
    git fetch --all --prune && git pull --rebase --autostash
}

github_ssh_to_https() {
    local remote_url="$1"

    if [[ "$remote_url" =~ ^git@github\.com:(.+)\.git$ ]]; then
        echo "https://github.com/${BASH_REMATCH[1]}.git"
        return 0
    fi

    if [[ "$remote_url" =~ ^git@github\.com:(.+)$ ]]; then
        echo "https://github.com/${BASH_REMATCH[1]}"
        return 0
    fi

    if [[ "$remote_url" =~ ^ssh://git@github\.com/(.+)\.git$ ]]; then
        echo "https://github.com/${BASH_REMATCH[1]}.git"
        return 0
    fi

    if [[ "$remote_url" =~ ^ssh://git@github\.com/(.+)$ ]]; then
        echo "https://github.com/${BASH_REMATCH[1]}"
        return 0
    fi

    return 1
}

# Step 4: Pull latest code
echo -e "${YELLOW}Pulling latest code from branch '$BRANCH'...${NC}"
if ! attempt_update; then
    ORIGIN_URL="$(git remote get-url origin 2>/dev/null || true)"
    HTTPS_URL=""

    if HTTPS_URL="$(github_ssh_to_https "$ORIGIN_URL" 2>/dev/null)"; then
        if [[ "$HTTPS_URL" != "$ORIGIN_URL" ]]; then
            echo -e "${YELLOW}SSH remote failed. Switching origin to HTTPS and retrying...${NC}"
            git remote set-url origin "$HTTPS_URL"
            attempt_update
        else
            echo -e "${RED}Error: git update failed, and no alternate remote URL was found.${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Error: git update failed for origin '$ORIGIN_URL'.${NC}"
        exit 1
    fi
fi

# Step 5: Restore user-specific files
echo -e "${YELLOW}Restoring user files...${NC}"
for file in airports displayairports config.json; do
    if [[ -f "$BACKUP_DIR/$file.bak" ]]; then
        cp "$BACKUP_DIR/$file.bak" "$PROJECT_DIR/$file"
        echo "Restored $file"
    fi
done

# Step 6: Re-run setup non-interactively
echo -e "${YELLOW}Re-running setup in non-interactive mode...${NC}"
if [[ -f "$PROJECT_DIR/setup.sh" ]]; then
    /bin/bash "$PROJECT_DIR/setup.sh" --non-interactive
else
    echo -e "${RED}Error: setup.sh not found.${NC}"
    exit 1
fi

echo
echo -e "${GREEN}METARMap update completed successfully.${NC}"
echo "Backup saved at: $BACKUP_DIR"
