#!/bin/bash

input=$(cat)

# Check if jq command exists
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq not found. Please install jq"
    exit 0
fi

# Cache file path
CACHE_FILE="$HOME/.claude/.usage_cache.json"

# Cache validity period in seconds (10 minutes)
POLL_INTERVAL=600

# Check if cache is valid
is_cache_valid() {
    if [ ! -f "$CACHE_FILE" ]; then
        return 1
    fi

    CACHED_AT=$(jq -r '.cached_at' "$CACHE_FILE" 2>/dev/null)
    if [ -z "$CACHED_AT" ] || [ "$CACHED_AT" = "null" ]; then
        return 1
    fi

    CURRENT_TIME=$(date -u +%s)
    CACHE_AGE=$((CURRENT_TIME - CACHED_AT))

    [ $CACHE_AGE -lt $POLL_INTERVAL ]
}

# Fetch usage data from API and update cache
fetch_usage_data() {
    TOKEN=$(jq -r '.claudeAiOauth.accessToken' "$HOME/.claude/.credentials.json" 2>/dev/null)
    if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
        return 1
    fi

    CURRENT_TIME=$(date -u +%s)
    curl -s \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -H "anthropic-beta: oauth-2025-04-20" \
        https://api.anthropic.com/api/oauth/usage 2>/dev/null | \
    jq --arg cached_at "$CURRENT_TIME" '{resets_at: .five_hour.resets_at, utilization: .five_hour.utilization, cached_at: ($cached_at | tonumber)}' > "$CACHE_FILE" 2>/dev/null
}

# Get model name
MODEL=$(echo "$input" | jq -r '.model.display_name')

# Calculate total tokens (cumulative)
TOTAL_TOKENS=$(echo "$input" | jq -r '
    ((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)) as $total |
    if $total >= 1000 then
        (($total / 1000 * 10 | floor) / 10 | tostring) + "k"
    else
        ($total | tostring)
    end
')

# Get reset time and 5h usage from cache
if ! is_cache_valid; then
    fetch_usage_data
fi

RESET_TIME=""
FIVE_HOUR_USAGE="0.00"

if [ -f "$CACHE_FILE" ]; then
    RESET_AT=$(jq -r '.resets_at' "$CACHE_FILE" 2>/dev/null)
    if [ -n "$RESET_AT" ] && [ "$RESET_AT" != "null" ]; then
        # Convert to Unix time and add 59 seconds (always round up)
        UNIX_TIME=$(date -d "$RESET_AT" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${RESET_AT%%+*}" +%s 2>/dev/null)
        ROUNDED_TIME=$((UNIX_TIME + 59))
        # Support both Linux(GNU date) and macOS(BSD date)
        RESET_TIME=$(date -d "@$ROUNDED_TIME" +%H:%M 2>/dev/null || date -r "$ROUNDED_TIME" +%H:%M 2>/dev/null)
    fi

    # Get 5h usage from cache (utilization is already in percentage 0-100)
    CACHED_UTILIZATION=$(jq -r '.utilization' "$CACHE_FILE" 2>/dev/null)
    if [ -n "$CACHED_UTILIZATION" ] && [ "$CACHED_UTILIZATION" != "null" ]; then
        FIVE_HOUR_USAGE=$(echo "$CACHED_UTILIZATION" | awk '{printf "%.2f", $1}')
    fi
fi

# Output status line
if [ -n "$RESET_TIME" ]; then
    echo "Model: ${MODEL} | Total Tokens: ${TOTAL_TOKENS} | 5h Usage: ${FIVE_HOUR_USAGE}% | 5h Resets: ${RESET_TIME}"
else
    echo "Model: ${MODEL} | Total Tokens: ${TOTAL_TOKENS} | 5h Usage: ${FIVE_HOUR_USAGE}% | 5h Resets: N/A"
fi
