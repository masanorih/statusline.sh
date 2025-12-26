# statusline.sh

A shell script for displaying Claude Code statusline

## Overview

This script formats and displays information on the Claude Code statusline, including model name, token usage, 5-hour utilization rate, and reset time in a readable format.

## Setup

edit the statusline in Claude Code settings file (`~/.claude/settings.json`)

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

## Features

- Display the current model name
- Show cumulative token count (displayed in "k" units for 1000+)
- Show 5-hour utilization rate as a percentage
- Display the next reset time
- Cache usage data from API to reduce unnecessary API calls

## Prerequisites

- `jq` command must be installed
- Claude Code credentials must be stored in `~/.claude/.credentials.json`

## Installation

Download the script

```bash
curl -o ~/.claude/statusline.sh https://raw.githubusercontent.com/masanorih/statusline.sh/refs/heads/main/statusline.sh
chmod +x ~/.claude/statusline.sh
```

## Usage

When you start Claude Code, the statusline will display information like this:

```
Model: Sonnet 4.5 | Total Tokens: 0 | 5h Usage: 0.00% | 5h Resets: 24:00
```

## Output Fields

| Field | Description |
|-------|-------------|
| Model | Current model name |
| Total Tokens | Cumulative token count (input + output) |
| 5h Usage | 5-hour utilization rate (percentage) |
| 5h Resets | Next reset time (HH:MM format) |

## Cache

Usage data is cached in `~/.claude/.usage_cache.json`. The cache is valid until the reset time, and the script automatically fetches the latest data from the API when the cache expires.

## Supported Platforms

- Linux (GNU date)
- macOS (BSD date)

The script is designed to be compatible with date commands on both platforms.
