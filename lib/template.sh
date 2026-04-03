#!/bin/bash
# lib/template.sh - ç®€å•æ¨¡æ¿å¼•æ“Ž

render_template() {
    local template="$1"
    local output="$2"
    
    if [[ ! -f "$template" ]]; then
        echo "Error: Template not found: $template" >&2
        return 1
    fi
    
    # å¤åˆ¶æ¨¡æ¿åˆ°è¾“å‡º
    cp "$template" "$output"
    
    # æ›¿æ¢å˜é‡ (æ ¼å¼: {{ VAR_NAME }})
    local var
    while IFS= read -r line; do
        while [[ "$line" =~ \{\{[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\}\} ]]; do
            local var_name="${BASH_REMATCH[1]}"
            local var_value="${!var_name}"
            var_value="${var_value:-}"
            line="${line//\{\{${var_name}\}\}/$var_value}"
        done
        echo "$line"
    done < "$output" > "${output}.tmp"
    
    mv "${output}.tmp" "$output"
}

# æ¸²æŸ“ Nomad é…ç½®
render_nomad_config() {
    local role="$1"  # server | client
    local output="$2"
    local template_dir="$(dirname "$0")/../templates/nomad"
    
    case "$role" in
        server)
            render_template "$template_dir/server.hcl.tpl" "$output"
            ;;
        client)
            render_template "$template_dir/client.hcl.tpl" "$output"
            ;;
        *)
            echo "Error: Unknown Nomad role: $role" >&2
            return 1
            ;;
    esac
}
