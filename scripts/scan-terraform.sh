#!/bin/bash

# Terraform Security Scanner Script
# This script runs Checkov, Terrascan, and tfsec security scans
# on Terraform code and generates reports

# Set base directory for Terraform code
TERRAFORM_DIR="/Users/santoshbaruah/Developer/DevOps-Challenge-main/terraform"
REPORTS_DIR="$TERRAFORM_DIR/security-reports"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Create reports directory if it doesn't exist
mkdir -p "$REPORTS_DIR"

echo -e "${BLUE}===========================================================${RESET}"
echo -e "${BLUE}      Terraform Security Scanner - Starting Scans          ${RESET}"
echo -e "${BLUE}===========================================================${RESET}"
echo ""

# Check if tools are installed
check_tool_installed() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}[ERROR] $1 is not installed. Please install it first.${RESET}"
        echo "Installation instructions:"
        case $1 in
            checkov)
                echo "  pip install checkov"
                ;;
            terrascan)
                echo "  brew install terrascan  # macOS"
                echo "  OR"
                echo "  curl -L \"$(curl -s https://api.github.com/repos/accurics/terrascan/releases/latest | grep -o 'https://.*_Darwin_x86_64.tar.gz')\" > terrascan.tar.gz"
                echo "  tar -xf terrascan.tar.gz terrascan && rm terrascan.tar.gz"
                echo "  sudo install terrascan /usr/local/bin && rm terrascan"
                ;;
            tfsec)
                echo "  brew install tfsec  # macOS"
                echo "  OR"
                echo "  curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash"
                ;;
        esac
        return 1
    fi
    return 0
}

# Run Checkov
run_checkov() {
    echo -e "${YELLOW}Running Checkov scan...${RESET}"

    if check_tool_installed checkov; then
        CHECKOV_REPORT="$REPORTS_DIR/checkov-report.json"
        echo "Scanning $TERRAFORM_DIR..."

        # Run Checkov and save output to report file
        checkov -d "$TERRAFORM_DIR" --output json > "$CHECKOV_REPORT" 2>/dev/null

        # Extract and print summary
        FAILED=$(cat "$CHECKOV_REPORT" | grep -c "FAILED")
        PASSED=$(cat "$CHECKOV_REPORT" | grep -c "PASSED")

        if [ $FAILED -gt 0 ]; then
            echo -e "${RED}Checkov found $FAILED issues!${RESET}"
        else
            echo -e "${GREEN}Checkov found 0 issues.${RESET}"
        fi

        echo -e "${GREEN}$PASSED checks passed.${RESET}"
        echo -e "Detailed report saved to: $CHECKOV_REPORT"
        echo ""

        # Extract top issues for display
        if [ $FAILED -gt 0 ]; then
            echo -e "${YELLOW}Top issues found by Checkov:${RESET}"
            checkov -d "$TERRAFORM_DIR" --compact --quiet | head -n 20
            echo "..."
            echo ""
        fi
    fi
}

# Run Terrascan
run_terrascan() {
    echo -e "${YELLOW}Running Terrascan scan...${RESET}"

    if check_tool_installed terrascan; then
        TERRASCAN_REPORT="$REPORTS_DIR/terrascan-report.json"
        echo "Scanning $TERRAFORM_DIR..."

        # Run Terrascan and save output to report file
        terrascan scan -d "$TERRAFORM_DIR" -o json --config-path "$TERRAFORM_DIR/.terrascan-ignore.toml" > "$TERRASCAN_REPORT" 2>/dev/null

        # Extract and print summary
        VIOLATIONS=$(cat "$TERRASCAN_REPORT" | grep -c "resource")

        if [ $VIOLATIONS -gt 0 ]; then
            echo -e "${RED}Terrascan found $VIOLATIONS potential violations!${RESET}"
        else
            echo -e "${GREEN}Terrascan found 0 issues.${RESET}"
        fi

        echo -e "Detailed report saved to: $TERRASCAN_REPORT"
        echo ""

        # Extract top issues for display
        if [ $VIOLATIONS -gt 0 ]; then
            echo -e "${YELLOW}Top issues found by Terrascan:${RESET}"
            terrascan scan -d "$TERRAFORM_DIR" --config-path "$TERRAFORM_DIR/.terrascan-ignore.toml" | head -n 20
            echo "..."
            echo ""
        fi
    fi
}

# Run tfsec
run_tfsec() {
    echo -e "${YELLOW}Running tfsec scan...${RESET}"

    if check_tool_installed tfsec; then
        TFSEC_REPORT="$REPORTS_DIR/tfsec-report.json"
        echo "Scanning $TERRAFORM_DIR..."

        # Run tfsec and save output to report file
        tfsec "$TERRAFORM_DIR" --format json > "$TFSEC_REPORT" 2>/dev/null

        # Extract and print summary
        ISSUES=$(cat "$TFSEC_REPORT" | grep -c "results")

        if [ $ISSUES -gt 0 ]; then
            echo -e "${RED}tfsec found issues!${RESET}"
        else
            echo -e "${GREEN}tfsec found 0 issues.${RESET}"
        fi

        echo -e "Detailed report saved to: $TFSEC_REPORT"
        echo ""

        # Display issues for display
        if [ $ISSUES -gt 0 ]; then
            echo -e "${YELLOW}Issues found by tfsec:${RESET}"
            tfsec "$TERRAFORM_DIR" --no-color 2>/dev/null | head -n 20
            echo "..."
            echo ""
        fi
    fi
}

# Run all scanners
run_checkov
run_terrascan
run_tfsec

echo -e "${BLUE}===========================================================${RESET}"
echo -e "${BLUE}      Terraform Security Scanner - Scans Completed          ${RESET}"
echo -e "${BLUE}===========================================================${RESET}"
echo ""
echo -e "All reports saved to: ${YELLOW}$REPORTS_DIR${RESET}"
echo -e "Use the following commands to view detailed reports:"
echo -e "${GREEN}cat $REPORTS_DIR/checkov-report.json | jq '.'${RESET}"
echo -e "${GREEN}cat $REPORTS_DIR/terrascan-report.json | jq '.'${RESET}"
echo -e "${GREEN}cat $REPORTS_DIR/tfsec-report.json | jq '.'${RESET}"