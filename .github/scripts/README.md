# GitHub Actions Scripts

This directory contains utility scripts for managing GitHub Actions workflows.

## restart_workflows_staggered.sh

A bash script to restart failed GitHub Actions workflows in a staggered manner. This helps avoid `OVER_RATE_LIMIT` issues by spacing out workflow restarts.

### Prerequisites

- **GitHub CLI (gh)**: Must be installed and authenticated
  - Install from: https://cli.github.com/
  - Authenticate with: `gh auth login`
- **Permissions**: Requires `workflow:write` permission

### Usage

```bash
./restart_workflows_staggered.sh [OPTIONS]
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-d, --delay SECONDS` | Delay between workflow restarts | 30 seconds |
| `-t, --date DATE` | Filter workflows by date (YYYY-MM-DD) | Today |
| `-n, --dry-run` | Show what would be restarted without actually restarting | N/A |
| `-h, --help` | Show help message | N/A |

### Examples

**Restart today's failed workflows with default 30-second delay:**
```bash
./restart_workflows_staggered.sh
```

**Dry run to see what would be restarted:**
```bash
./restart_workflows_staggered.sh --dry-run
```

**Restart workflows from a specific date with 60-second delay:**
```bash
./restart_workflows_staggered.sh --delay 60 --date 2025-12-29
```

**Quick restart with minimal delay (use cautiously):**
```bash
./restart_workflows_staggered.sh --delay 10
```

### How It Works

1. Fetches all workflow runs for the specified date
2. Filters for failed or cancelled workflows
3. Displays a summary of workflows to be restarted
4. Prompts for confirmation (unless dry-run)
5. Restarts each workflow sequentially with the specified delay between each

### Rate Limit Considerations

- **Default delay (30s)**: Safe for most situations
- **Minimum recommended (10s)**: Use only if you're sure about rate limits
- **Higher delay (60s+)**: Use if you recently hit rate limits or have many workflows

GitHub API rate limits:
- **Authenticated requests**: 5,000 requests per hour
- **Workflow rerun API**: Subject to secondary rate limits

### Troubleshooting

**"Error: GitHub CLI (gh) is not installed"**
- Install GitHub CLI from https://cli.github.com/

**"Error: Not authenticated with GitHub CLI"**
- Run `gh auth login` and follow the prompts

**"Failed to restart" for specific workflows**
- Workflow may already be running
- Workflow may not be restartable (too old or not failed)
- Check workflow status at: https://github.com/NREL/REopt.jl/actions

**Still hitting rate limits**
- Increase the delay between restarts (`--delay 60` or higher)
- Restart in smaller batches
- Wait before restarting more workflows

### Notes

- The script only restarts workflows from the specified date
- Only failed or cancelled workflows are targeted for restart
- Each restart requires an API call, so be mindful of rate limits
- Use `--dry-run` first to verify which workflows will be restarted
