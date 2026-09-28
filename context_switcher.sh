#!/usr/bin/env bash

# ==============================================================================
# CONTEXT-AWARE CLI SWITCHER
# Scans directories for .devcontext files and automatically updates git configs,
# environment variables, and SSH keys seamlessly upon entry.
# ==============================================================================

# Store the current active context globally to prevent unnecessary re-loading
export CURRENT_DEV_CONTEXT=""

_context_switcher_purge() {
    # If a previous profile set custom environment variables, clear them here
    if [ -n "${CUSTOM_ENV_KEYS:-}" ]; then
        for var in ${(s:,:)CUSTOM_ENV_KEYS}; do
            unset "$var"
        done
        unset CUSTOM_ENV_KEYS
    fi
}

_context_switcher_apply() {
    local context_file="$1"
    
    # Read the file line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Clean whitespaces and ignore comments/empty lines
        line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^# ]] && continue

        # Handle Git Configuration
        if [[ "$line" =~ ^git_email= ]]; then
            local email="${line#*=}"
            git config user.email "$email"
            echo -e "\033[0;34m[Context]\033[0m Git email updated to: \033[0;32m$email\033[0m"
        elif [[ "$line" =~ ^git_name= ]]; then
            local name="${line#*=}"
            git config user.name "$name"
        
        # Handle SSH Key switching
        elif [[ "$line" =~ ^ssh_key= ]]; then
            local key_path="${line#*=}"
            if [ -f "$key_path" ]; then
                # Start ssh-agent if not running, then add key
                eval "$(ssh-agent -s) > /dev/null"
                ssh-add "$key_path" 2>/dev/null
                echo -e "\033[0;34m[Context]\033[0m Loaded active SSH Identity: \033[0;32m$key_path\033[0m"
            else
                echo -e "\033[0;31m[Context Error]\033[0m Defined SSH Key file not found: $key_path"
            fi

        # Handle Custom Environment Variables (Format: env.YOUR_VAR=value)
        elif [[ "$line" =~ ^env\. ]]; then
            local kv="${line#env.}"
            local key="${kv%%=*}"
            local val="${kv#*=}"
            export "$key"="$val"
            # Keep track of injected variables to clear them when leaving the folder
            export CUSTOM_ENV_KEYS="${CUSTOM_ENV_KEYS:-}+$key"
        fi

    done < "$context_file"
}

context_check_loop() {
    # Find the nearest .devcontext file traveling upwards to the root root tree
    local current_dir="$PWD"
    local target_file=""

    while [ "$current_dir" != "/" ]; do
        if [ -f "$current_dir/.devcontext" ]; then
            target_file="$current_dir/.devcontext"
            break
        fi
        current_dir=$(dirname "$current_dir")
    fi

    if [ -n "$target_file" ]; then
        if [ "$CURRENT_DEV_CONTEXT" != "$target_file" ]; then
            _context_switcher_purge
            echo -e "\033[0;35m[Context Switcher]\033[0m Activating environment profile: $target_file"
            _context_switcher_apply "$target_file"
            export CURRENT_DEV_CONTEXT="$target_file"
        fi
    else
        # If we had a context active but now we are outside of it, wipe configurations safely
        if [ -n "$CURRENT_DEV_CONTEXT" ]; then
            echo -e "\033[0;35m[Context Switcher]\033[0m Leaving workspace context. Restoring defaults."
            _context_switcher_purge
            # Reset default global git identity if required
            git config --global --unset user.email || true
            git config --global --unset user.name || true
            export CURRENT_DEV_CONTEXT=""
        fi
    fi
}

# Hook into shell directory change sequences
if [ -n "${ZSH_VERSION:-}" ]; then
    chpwd_functions+=(context_check_loop)
elif [ -n "${BASH_VERSION:-}" ]; then
    # For Bash, we override the default 'cd' command behavior safely
    cd() {
        builtin cd "$@" && context_check_loop
    }
fi
