#!/bin/bash

input=$(cat)

# Check if jq command exists
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq not found. Please install jq"
    exit 0
fi

# Cache file path
CACHE_FILE="$HOME/.claude/.usage_cache.json"

# Check if cache is valid
is_cache_valid() {
    if [ ! -f "$CACHE_FILE" ]; then
        return 1
    fi

    CACHED_RESET=$(jq -r '.resets_at' "$CACHE_FILE" 2>/dev/null)
    if [ -z "$CACHED_RESET" ] || [ "$CACHED_RESET" = "null" ]; then
        return 1
    fi

    CURRENT_TIME=$(date -u +%s)
    # Support both Linux(GNU date) and macOS(BSD date)
    RESET_TIME=$(date -d "$CACHED_RESET" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${CACHED_RESET%%.*}" +%s 2>/dev/null)

    if [ -z "$RESET_TIME" ]; then
        return 1
    fi

    [ $CURRENT_TIME -lt $RESET_TIME ]
}

# Fetch usage data from API and update cache
fetch_usage_data() {
    TOKEN=$(jq -r '.claudeAiOauth.accessToken' "$HOME/.claude/.credentials.json" 2>/dev/null)
    if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
        return 1
    fi

    curl -s \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -H "anthropic-beta: oauth-2025-04-20" \
        https://api.anthropic.com/api/oauth/usage 2>/dev/null | \
    jq '{resets_at: .five_hour.resets_at, utilization: .five_hour.utilization}' > "$CACHE_FILE" 2>/dev/null
}

# Get model name
MODEL=$(echo "$input" | jq -r '.model.display_name')

# Calculate context window utilization
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size')
USAGE=$(echo "$input" | jq '.context_window.current_usage')

# Calculate total tokens (cumulative)
TOTAL_TOKENS=$(echo "$input" | jq -r '
    ((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)) as $total |
    if $total >= 1000 then
        (($total / 1000 * 10 | floor) / 10 | tostring) + "k"
    else
        ($total | tostring)
    end
')

# Get reset time
if ! is_cache_valid; then
    fetch_usage_data
fi

RESET_TIME=""
if [ -f "$CACHE_FILE" ]; then
    RESET_AT=$(jq -r '.resets_at' "$CACHE_FILE" 2>/dev/null)
    if [ -n "$RESET_AT" ] && [ "$RESET_AT" != "null" ]; then
        # Convert to Unix time and add 59 seconds (always round up)
        UNIX_TIME=$(date -d "$RESET_AT" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${RESET_AT%%+*}" +%s 2>/dev/null)
        ROUNDED_TIME=$((UNIX_TIME + 59))
        # Support both Linux(GNU date) and macOS(BSD date)
        RESET_TIME=$(date -d "@$ROUNDED_TIME" +%H:%M 2>/dev/null || date -r "$ROUNDED_TIME" +%H:%M 2>/dev/null)
    fi
fi

if [ "$USAGE" != "null" ] && [ "$CONTEXT_SIZE" != "0" ]; then
    # Support up to two decimal places
    PERCENT_USED=$(echo "$input" | jq -r '
        (.context_window.current_usage.input_tokens // 0) as $input |
        (.context_window.current_usage.cache_creation_input_tokens // 0) as $cache_create |
        (.context_window.current_usage.cache_read_input_tokens // 0) as $cache_read |
        .context_window.context_window_size as $size |
        (($input + $cache_create + $cache_read) * 100 / $size * 100 | floor) / 100
    ')

    if [ -n "$RESET_TIME" ]; then
        echo "Model: ${MODEL} | Total Tokens: ${TOTAL_TOKENS} | 5h Usage: ${PERCENT_USED}% | 5h Resets: ${RESET_TIME}"
    else
        echo "Model: ${MODEL} | Total Tokens: ${TOTAL_TOKENS} | 5h Usage: ${PERCENT_USED}% | 5h Resets: N/A"
    fi
else
    if [ -n "$RESET_TIME" ]; then
        echo "Model: ${MODEL} | Total Tokens: ${TOTAL_TOKENS} | 5h Usage: 0.00% | 5h Resets: ${RESET_TIME}"
    else
        echo "Model: ${MODEL} | Total Tokens: ${TOTAL_TOKENS} | 5h Usage: 0.00% | 5h Resets: N/A"
    fi
fi
