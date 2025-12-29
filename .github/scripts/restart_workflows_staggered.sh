#!/bin/bash

# Script to restart failed GitHub Actions workflows in a staggered manner
# This helps avoid OVER_RATE_LIMIT issues by spacing out workflow restarts

set -e

# Configuration
OWNER="NREL"
REPO="REopt.jl"
DEFAULT_DELAY=30  # seconds between restarts
DATE_FILTER=$(date -u +%Y-%m-%d)  # Today's date in UTC

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Restart failed GitHub Actions workflows in a staggered manner"
    echo ""
    echo "Options:"
    echo "  -d, --delay SECONDS      Delay between workflow restarts (default: $DEFAULT_DELAY)"
    echo "  -t, --date DATE          Filter workflows by date (format: YYYY-MM-DD, default: today)"
    echo "  -n, --dry-run            Show what would be restarted without actually restarting"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Requirements:"
    echo "  - GitHub CLI (gh) must be installed and authenticated"
    echo "  - Requires workflow:write permission"
    echo ""
    echo "Example:"
    echo "  $0 --delay 60 --date 2025-12-29"
    exit 1
}

# Parse arguments
DELAY=$DEFAULT_DELAY
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--delay)
            DELAY="$2"
            shift 2
            ;;
        -t|--date)
            DATE_FILTER="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
    echo "Please install it from: https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: Not authenticated with GitHub CLI${NC}"
    echo "Please run: gh auth login"
    exit 1
fi

echo -e "${GREEN}Staggered Workflow Restart Tool${NC}"
echo "================================"
echo "Repository: $OWNER/$REPO"
echo "Date filter: $DATE_FILTER"
echo "Delay between restarts: ${DELAY}s"
echo ""

# Get workflow runs from today
echo -e "${YELLOW}Fetching workflow runs...${NC}"
RUNS=$(gh api \
    "/repos/$OWNER/$REPO/actions/runs" \
    --jq ".workflow_runs[] | select(.created_at | startswith(\"$DATE_FILTER\")) | select(.conclusion == \"failure\" or .conclusion == \"cancelled\" or .status == \"completed\" and .conclusion == \"failure\") | {id: .id, name: .name, status: .status, conclusion: .conclusion, created_at: .created_at, html_url: .html_url}" \
    | jq -s '.')

# Count runs to restart
RUN_COUNT=$(echo "$RUNS" | jq 'length')

if [ "$RUN_COUNT" -eq 0 ]; then
    echo -e "${GREEN}No failed or cancelled workflows found for $DATE_FILTER${NC}"
    exit 0
fi

echo -e "${YELLOW}Found $RUN_COUNT workflow run(s) to restart:${NC}"
echo ""
echo "$RUNS" | jq -r '.[] | "\(.id) | \(.name) | \(.conclusion // .status) | \(.created_at)"' | column -t -s '|'
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}DRY RUN - No workflows will be restarted${NC}"
    echo "Would restart $RUN_COUNT workflow(s) with ${DELAY}s delay between each"
    exit 0
fi

# Confirm before proceeding
read -p "Do you want to proceed with restarting these workflows? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Restart workflows with staggering
counter=0
echo "$RUNS" | jq -r '.[].id' | while read -r run_id; do
    counter=$((counter + 1))
    workflow_name=$(echo "$RUNS" | jq -r ".[] | select(.id == $run_id) | .name")
    
    echo -e "${YELLOW}[$counter/$RUN_COUNT] Restarting workflow: $workflow_name (ID: $run_id)${NC}"
    
    if gh api \
        --method POST \
        "/repos/$OWNER/$REPO/actions/runs/$run_id/rerun" \
        > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Successfully restarted${NC}"
    else
        echo -e "${RED}✗ Failed to restart (may already be running or not restartable)${NC}"
    fi
    
    # Wait before next restart (except for the last one)
    if [ "$counter" -lt "$RUN_COUNT" ]; then
        echo "Waiting ${DELAY}s before next restart..."
        sleep "$DELAY"
        echo ""
    fi
done

echo ""
echo -e "${GREEN}Workflow restart process completed!${NC}"
echo "Monitor progress at: https://github.com/$OWNER/$REPO/actions"
