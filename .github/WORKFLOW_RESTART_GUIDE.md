# Quick Guide: Restarting Failed Workflows

If you're experiencing `OVER_RATE_LIMIT` errors and need to restart failed workflows, use the staggered restart script:

## Quick Start

```bash
# Navigate to scripts directory
cd .github/scripts

# Preview which workflows will be restarted (recommended first step)
./restart_workflows_staggered.sh --dry-run

# Restart with default 30-second delay
./restart_workflows_staggered.sh

# Or restart with custom 60-second delay for extra safety
./restart_workflows_staggered.sh --delay 60
```

## Prerequisites

1. Install GitHub CLI: https://cli.github.com/
2. Authenticate: `gh auth login`

## Full Documentation

See [.github/scripts/README.md](.github/scripts/README.md) for complete documentation including:
- All command-line options
- Rate limit considerations
- Troubleshooting guide
- Examples for different scenarios

## Example Output

```
Staggered Workflow Restart Tool
================================
Repository: NREL/REopt.jl
Date filter: 2025-12-29
Delay between restarts: 30s

Fetching workflow runs...
Found 3 workflow run(s) to restart:

20561411523  CompatHelper     failure  2025-12-29T00:03:36Z
20546108566  CompatHelper     failure  2025-12-29T00:03:32Z
20531536248  Run tests        failure  2025-12-29T00:03:21Z

Do you want to proceed with restarting these workflows? (y/N)
```
