#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "${BLUE}=== Cleaning up project files ===${RESET}"

# Function to handle errors
handle_error() {
    echo -e "${RED}Error: $1${RESET}"
    exit 1
}

# Function to confirm action
confirm() {
    read -p "$1 (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Operation cancelled.${RESET}"
        return 1
    fi
    return 0
}

# Check if we're in the project root directory
if [ ! -f "README.md" ] || [ ! -d "scripts" ]; then
    handle_error "Please run this script from the project root directory"
fi

# List of files to remove
DEPRECATED_SCRIPTS=(
    "scripts/deprecated"
    "scripts/view-consumer-venv.sh"
    "scripts/view-consumer-wrapper.sh"
    "scripts/view-consumer.py"
)

# List of documentation files to keep
KEEP_DOCS=(
    "README.md"
    "TECHNICAL_GUIDE.md"
    "GRAFANA_DASHBOARD_GUIDE.md"
    "DEMO_GUIDE.md"
    "KAFKA_SYSTEM_DOCUMENTATION.md"
)

# Step 1: Remove deprecated scripts
echo -e "${YELLOW}Step 1: Removing deprecated scripts...${RESET}"
for script in "${DEPRECATED_SCRIPTS[@]}"; do
    if [ -e "$script" ]; then
        echo -e "  Removing ${BLUE}$script${RESET}"
        rm -rf "$script"
    else
        echo -e "  ${BLUE}$script${RESET} not found, skipping"
    fi
done

# Step 2: Clean up documentation
echo -e "${YELLOW}Step 2: Cleaning up documentation...${RESET}"
find . -maxdepth 1 -name "*.md" | while read -r doc; do
    doc_name=$(basename "$doc")
    keep=false
    
    for keep_doc in "${KEEP_DOCS[@]}"; do
        if [ "$doc_name" == "$keep_doc" ]; then
            keep=true
            break
        fi
    done
    
    if [ "$keep" == "false" ]; then
        echo -e "  Removing ${BLUE}$doc_name${RESET}"
        rm -f "$doc"
    else
        echo -e "  Keeping ${GREEN}$doc_name${RESET}"
    fi
done

# Step 3: Clean up archive directory
if [ -d "archive" ]; then
    echo -e "${YELLOW}Step 3: Cleaning up archive directory...${RESET}"
    if confirm "Do you want to remove the archive directory?"; then
        echo -e "  Removing ${BLUE}archive${RESET} directory"
        rm -rf "archive"
    else
        echo -e "  Keeping ${GREEN}archive${RESET} directory"
    fi
fi

# Step 4: Clean up examples directory
if [ -d "examples" ]; then
    echo -e "${YELLOW}Step 4: Cleaning up examples directory...${RESET}"
    if confirm "Do you want to remove the examples directory?"; then
        echo -e "  Removing ${BLUE}examples${RESET} directory"
        rm -rf "examples"
    else
        echo -e "  Keeping ${GREEN}examples${RESET} directory"
    fi
fi

echo -e "${GREEN}Cleanup complete!${RESET}"
echo -e "${BLUE}=== Project files have been cleaned up ===${RESET}"
