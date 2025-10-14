#!/bin/bash
# =========================================================
# METARMap Update Script
# Safely updates the METARMap project by pulling latest
# changes from git, while preserving user-specific files:
# airports/ and displayairports/
# =========================================================

set -Eeuo pipefail
trap 'echo "❌ Error occurred on line $LINENO. Aborting."; exit 1' ERR

# ---- Colors ----
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No color

echo -e "${GREEN}Starting METARMap update...${NC}"

# ---- Step 1: Stop any running instances ----
echo -e "${YELLOW}Shutting down any running instances of METARMap...${NC}"
if [ -f lightsoff.sh ]; then
    sh lightsoff.sh
else
    echo -e "${RED}Warning: lightsoff.sh not found, skipping shutdown.${NC}"
fi

# ---- Step 2: Setup paths ----
PROJECT_DIR=$(pwd)
HOME_DIR="$HOME"
TIMESTAMP=$(date +%Y%m%d)
BACKUP_DIR="$HOME_DIR/METARMapbackup/$TIMESTAMP"

echo "Project directory: $PROJECT_DIR"
echo "Backup directory: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# ---- Step 3: Backup user-specific files ----
echo -e "${YELLOW}Backing up user-specific files...${NC}"

if [ -f airports ]; then
    cp airports "$BACKUP_DIR/airports.bak"
    echo "Backed up airports"
fi
if [ -f displayairports ]; then
    cp displayairports "$BACKUP_DIR/displayairports.bak"
    echo "Backed up displayairports"
fi

echo
echo "Backup complete. Contents:"
ls -l "$BACKUP_DIR"

# ---- Step 4: Confirm before proceeding ----
if [ -t 0 ]; then
    read -p "Press [Enter] to continue with the update if you see your backup files or Ctrl+C to abort..."
fi

# ---- Step 5: Update from git safely ----
echo -e "${YELLOW}Updating repository safely (preserving custom files)...${NC}"

git reset --hard
git pull

# ---- Step 6: Restore any missing user-specific files ----
echo -e "${YELLOW}Restoring user-specific files (if needed)...${NC}"
if [ -f "$BACKUP_DIR/airports.bak" ]; then
    mv "$BACKUP_DIR/airports.bak" airports
    echo "✓ Restored airports/"
fi
if [ -f "$BACKUP_DIR/displayairports.bak" ] ; then
    mv "$BACKUP_DIR/displayairports.bak" displayairports
    echo "✓ Restored displayairports/"
fi


# ---- Step 7: Run setup ----
echo -e "${YELLOW}Re-running setup script...${NC}"
if [ -f setup.sh ]; then
    bash setup.sh
else
    echo -e "${RED}Error: setup.sh not found. Cannot complete setup.${NC}"
    exit 1
fi

# ---- Step 8: Completion ----
echo
echo -e "${GREEN}METARMap update completed successfully!${NC}"
echo "Backup saved at: $BACKUP_DIR"
