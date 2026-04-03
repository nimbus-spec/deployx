#!/bin/bash
# lib/i18n.sh - Internationalization library

I18N_DEFAULT_LANG="en"
I18N_CURRENT_LANG="en"
I18N_LOADED=0

declare -A T

i18n_init() {
    if [[ -d "$SCRIPT_DIR/translations" ]]; then
        return 0
    fi
    return 1
}

i18n_load() {
    local lang="${1:-$I18N_DEFAULT_LANG}"
    local lang_file="$SCRIPT_DIR/translations/${lang}.sh"
    
    if [[ ! -f "$lang_file" ]]; then
        echo "[WARN] Translation file not found: $lang_file" >&2
        return 1
    fi
    
    unset T
    declare -gA T
    
    source "$lang_file"
    I18N_CURRENT_LANG="$lang"
    I18N_LOADED=1
}

_() {
    local key="$1"
    shift
    local default="${1:-}"
    
    if [[ "$I18N_LOADED" -eq 0 ]]; then
        echo "$default"
        return
    fi
    
    local value="${T[$key]}"
    if [[ -n "$value" ]]; then
        printf '%s' "$value"
    else
        printf '%s' "$default"
    fi
}

i18n_current_lang() {
    echo "$I18N_CURRENT_LANG"
}

i18n_available_langs() {
    local langs=()
    if [[ -d "$SCRIPT_DIR/translations" ]]; then
        for f in "$SCRIPT_DIR/translations/"*.sh; do
            if [[ -f "$f" ]]; then
                langs+=("$(basename "$f" .sh)")
            fi
        done
    fi
    echo "${langs[@]}"
}
