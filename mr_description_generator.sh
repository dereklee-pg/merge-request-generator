#!/usr/bin/env zsh

# Global variable for selected template
SELECTED_TEMPLATE=""

# Configuration paths with namespace prefix
MRG_CONFIG_DIR="${HOME}/.mrg_config"
MRG_TEMPLATES_DIR="${MRG_CONFIG_DIR}/templates"
MRG_API_KEY_FILE="${MRG_CONFIG_DIR}/api_key"
MRG_CONFIG_FILE="${MRG_CONFIG_DIR}/config"

# Configuration keys and their usage:
# JIRA_TICKET_URL_BASE: Base URL for JIRA ticket links
#   - Must include the protocol (https://) and end with a forward slash (/)
#   - Used to generate clickable links in merge request descriptions
#   - Example: JIRA_TICKET_URL_BASE=https://positivegrid.atlassian.net/browse/
#   - If ticket number is mrp-174, it will generate: [MRP-174](https://positivegrid.atlassian.net/browse/mrp-174)

# Internal function to read config value
mrg_read_config_value() {
    typeset key=$1
    if [[ ! -f $MRG_CONFIG_FILE ]]; then
        echo "Error: Config file not found at $MRG_CONFIG_FILE" >&2
        return 1
    fi
    
    typeset value=$(grep "^${key}=" "$MRG_CONFIG_FILE" | cut -d'=' -f2-)
    if [[ -z "$value" ]]; then
        echo "Error: Config key '$key' not found" >&2
        return 1
    fi
    
    echo "$value"
    return 0
}

# Internal function to select template
mrg_select_template() {
    SELECTED_TEMPLATE=""
    # Initialize storage if needed
    if [[ ! -d $MRG_TEMPLATES_DIR ]]; then
        mrg_init_template_storage
    fi
    
    # Get list of templates
    templates=(${MRG_TEMPLATES_DIR}/*.md)
    template_count=${#templates[@]}
    
    if [[ $template_count -eq 0 ]]; then
        echo "Error: No templates found" >&2
        return 1
    fi
    
    # Display template selection menu
    echo -e "\nSelect template type:"
    typeset i=1
    for template in $templates; do
        template_name=$(basename $template .md)
        echo "$i) ${template_name%.*}"  # Remove extension
        ((i++))
    done
    
    echo -n -e "\nEnter number (1-$template_count): "
    read -r template_choice
    
    # Validate choice
    if [[ ! $template_choice =~ ^[0-9]+$ ]] || \
       [[ $template_choice -lt 1 ]] || \
       [[ $template_choice -gt $template_count ]]; then
        echo "Invalid selection. Please choose 1-$template_count." >&2
        return 1
    fi
    
    # Store selected template content
    SELECTED_TEMPLATE=$(<"${templates[$template_choice]}")  # Arrays are 1-based
    return 0
}

# Internal function to check if Claude API key is configured
mrg_check_claude_api_key() {
    if [[ ! -f $MRG_API_KEY_FILE ]]; then
        return 1
    fi
    
    api_key=$(cat $MRG_API_KEY_FILE)
    if [[ -z $api_key ]]; then
        return 1
    fi
    
    return 0
}

# Internal function to get stored Claude API key
mrg_get_claude_api_key() {
    if [[ ! -f $MRG_API_KEY_FILE ]]; then
        echo "API key file not found at $MRG_API_KEY_FILE" >&2
        return 1
    fi
    
    typeset api_key
    api_key=$(<$MRG_API_KEY_FILE)
    
    if [[ -z $api_key ]]; then
        echo "API key is empty" >&2
        return 1
    fi
    
    echo "$api_key"
    return 0
}

# Internal function to setup config file
mrg_setup_config() {
    echo "Config File Setup"
    echo "================"
    echo "This will setup your configuration in $MRG_CONFIG_FILE"
    echo ""
    
    # Create config directory if it doesn't exist
    mkdir -p "$(dirname $MRG_CONFIG_FILE)"
    
    # Check if config already exists
    if [[ -f $MRG_CONFIG_FILE ]]; then
        echo "A config file already exists."
        echo -n "Do you want to reconfigure it? [y/N] "
        read -r response
        
        if [[ ! $response =~ ^[Yy]$ ]]; then
            echo "Setup cancelled."
            return 0
        fi
    fi
    
    # Prompt for JIRA URL
    echo -n "Enter your JIRA ticket URL base (e.g., https://your-domain.atlassian.net/browse/): "
    read -r jira_url
    
    # Validate URL format
    if [[ ! $jira_url =~ ^https?:// ]] || [[ ! $jira_url =~ /$ ]]; then
        echo "Error: URL must start with http:// or https:// and end with /" >&2
        return 1
    fi
    
    # Save config
    echo "JIRA_TICKET_URL_BASE=$jira_url" > $MRG_CONFIG_FILE
    chmod 600 $MRG_CONFIG_FILE
    
    echo "Configuration has been successfully saved!"
}

# Internal function to setup Claude API key
mrg_setup_claude_api_key() {
    echo "Claude API Key Setup"
    echo "==================="
    echo "This will store your Claude API key securely in $MRG_API_KEY_FILE"
    echo ""
    
    # Check if API key already exists
    if mrg_check_claude_api_key; then
        echo "An API key is already configured."
        echo -n "Do you want to replace it? [y/N] "
        read -r response
        
        if [[ ! $response =~ ^[Yy]$ ]]; then
            echo "Setup cancelled."
            return 0
        fi
    fi
    
    # Prompt for API key
    echo -n "Please enter your Claude API key: "
    read -rs api_key
    echo "" # New line after hidden input
    
    if [[ -z $api_key ]]; then
        echo "Error: API key cannot be empty" >&2
        return 1
    fi
    
    # Create config directory if it doesn't exist
    mkdir -p "$(dirname $MRG_API_KEY_FILE)"
    
    # Save API key to file with restricted permissions
    echo $api_key > $MRG_API_KEY_FILE
    chmod 600 $MRG_API_KEY_FILE
    
    echo "Claude API key has been successfully stored!"
}

# Internal function to initialize template storage
mrg_init_template_storage() {
    # Create template directory if it doesn't exist
    if [[ ! -d $MRG_TEMPLATES_DIR ]]; then
        mkdir -p $MRG_TEMPLATES_DIR
        
        # Create default templates
        echo "Initializing default templates..."
        
        # Story/Task template
        cat > "${MRG_TEMPLATES_DIR}/story.md" << 'EOL'
## Story / Task
[<ticket_number>](<link_to_ticket>)
### Summary
- Brief description of the story / task.
### Requirements
- List key spec requirements
- Include technical constraints
- Note any dependencies

## Implementation
### How
- Explain the feature implementation approach
- Detail key technical decisions
- Describe architectural considerations
### Files Changed
- List modified components
- Include new files added
- Note configuration changes

## Test Plans
- [ ] **Unit Tests:** Ensure core functionality works
- [ ] **Integration Tests:** Verify feature works with other components
- [ ] **UI/UX Tests:** Check user interaction flows

## Screenshots / Video
- Include relevant UI/UX changes
- Add workflow demonstrations
- Show before/after comparisons

## Follow-Up
- List potential improvements
- Note technical debt items
- Suggest future enhancements
EOL

        # Bugfix template
        cat > "${MRG_TEMPLATES_DIR}/bugfix.md" << 'EOL'
## Bugfix
[<ticket_number>](<link_to_ticket>)
### Description
- Brief explanation of the bug and its impact.
### Root Cause
- Detail what caused the bug
- Include technical analysis
- Note affected components

## Fix
### Solution
- Explain the fix implementation
- Detail technical changes made
- Describe any architectural impacts
### Files Changed
- List modified components
- Include new files if added
- Note configuration changes

## Test Plans
- [ ] **Bug Verification:** Confirm the bug is fixed
- [ ] **Regression Testing:** Check no new issues introduced
- [ ] **Edge Cases:** Test boundary conditions

## Screenshots / Video
- Show the bug reproduction
- Demonstrate the fix working
- Include relevant logs/errors

## Follow-Up
- Note potential related issues
- Suggest preventive measures
- List technical debt items
EOL

        # Refactor template
        cat > "${MRG_TEMPLATES_DIR}/refactor.md" << 'EOL'
## Code Refactor
[<ticket_number>](<link_to_ticket>)
### Refactor Summary
- Briefly describe the reason for the refactor, including architectural changes and improvements.

## Changes
### Modified Areas
- List modified files and components
- Include new files added
### Improvements
- Detail specific improvements made
- Highlight architectural changes
- Note any pattern implementations

## Testing
- [ ] **Test Coverage:** Ensure all related tests still pass.
- [ ] **Functionality Check:** Verify existing functionality remains unchanged, and new features work as expected.

## Follow-Up
- List potential improvements or next steps
- Note areas that could benefit from similar refactoring
EOL

        echo "Default templates created successfully!"
    fi
}

# Internal function to gather commit messages
mrg_gather_commit_messages() {
    typeset start_point=$1
    
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Error: Not in a git repository" >&2
        return 1
    fi
    
    if ! git rev-parse "$start_point" >/dev/null 2>&1; then
        echo "Error: Invalid start point: $start_point" >&2
        return 1
    fi
    
    git log --reverse --pretty=format:"* %s%n%b" "$start_point"..HEAD
}

# Internal function to generate MR description
mrg_generate_description() {
    # Check for required argument
    if [[ $# -lt 1 ]]; then
        echo "Error: Missing branch start point" >&2
        echo "Usage: merge_request_generator generate <branch_start_point>" >&2
        echo "Examples:" >&2
        echo "  merge_request_generator generate main" >&2
        echo "  merge_request_generator generate HEAD~5" >&2
        return 1
    fi

    typeset branch_start=$1
    typeset regenerate=${2:-false}  # Optional parameter for regeneration
    
    # Check if we're in a git repository
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Error: Not in a git repository" >&2
        return 1
    fi
    
    # Check if branch point exists
    if ! git rev-parse "$branch_start" >/dev/null 2>&1; then
        echo "Error: Invalid start point: $branch_start" >&2
        return 1
    fi
    
    # Check for required commands
    typeset deps=(git curl jq)
    for dep in $deps; do
        if ! command -v $dep &> /dev/null; then
            echo "Error: Required command '$dep' not found" >&2
            return 1
        fi
    done
    
    # Get stored API key
    typeset api_key=$(mrg_get_claude_api_key)
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Select template only if not regenerating
    if [[ "$regenerate" != "true" ]]; then
        mrg_select_template
        if [[ $? -ne 0 ]] || [[ -z "$SELECTED_TEMPLATE" ]]; then
            echo "Error: Failed to select template" >&2
            return 1
        fi
    fi

    # Get ticket number from branch name (e.g. mrp-174 from feature/mrp-174-something)
    typeset ticket=$(git rev-parse --abbrev-ref HEAD | grep -o 'mrp-[0-9]\+')
    if [[ -n "$ticket" ]]; then
        # Get JIRA URL base from config
        typeset jira_url_base=$(mrg_read_config_value "JIRA_TICKET_URL_BASE")
        if [[ $? -eq 0 ]]; then
            # Create ticket link with the configured URL (uppercase the ticket)
            typeset ticket_upper=$(echo "$ticket" | tr '[:lower:]' '[:upper:]')
            typeset ticket_link="[${ticket_upper}](${jira_url_base}${ticket})"
            # Replace template placeholders with actual ticket link
            SELECTED_TEMPLATE=$(echo "$SELECTED_TEMPLATE" | sed "s|\[<ticket_number>\](<link_to_ticket>)|${ticket_link}|g")
        else
            echo "Warning: Using ticket number without URL due to missing config" >&2
            SELECTED_TEMPLATE=$(echo "$SELECTED_TEMPLATE" | sed "s|<ticket_number>|${ticket}|g")
        fi
    fi

    # Gather commit messages
    typeset commits=$(mrg_gather_commit_messages "$branch_start")
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Pre-process the content to handle control characters
    typeset content=$(printf '%s' "Please help me generate a merge request description based on these commits:

$commits

Please generate a merge request description that follows this template EXACTLY. Do not add or remove any newlines or spaces:

$SELECTED_TEMPLATE

The description should:
1. Follow the exact template format without any modifications to spacing or newlines
2. Use the commit messages to fill in the appropriate sections
3. Include specific technical details from the commits
4. Use bullet points exactly as shown in the template
5. Put code terms in backticks
6. Keep the checkboxes unchanged
7. The description must be human-readable and friendly explanatory text
8. Do not add any extra newlines or spaces" | sed 's/[[:cntrl:]]/ /g')

    echo -e "\nGenerating MR description...\n"
    
    typeset response=$(curl -s -X POST "https://api.anthropic.com/v1/messages" \
    -H "Content-Type: application/json" \
    -H "x-api-key: $api_key" \
    -H "anthropic-version: 2023-06-01" \
    -d "{
        \"model\": \"claude-3-sonnet-20240229\",
        \"max_tokens\": 1024,
        \"messages\": [{
            \"role\": \"user\",
            \"content\": $(printf '%s' "$content" | jq -Rsa)
        }]
    }")

    if echo "$response" | grep -q '"type":"message"'; then
         # First let's see what we're getting
        # echo "Raw API Response:"
        # echo "----------------"
        # echo "$response"
        # echo "----------------"


        # Format the description
        typeset formatted_description=$(echo "$response" | tr -d '\000-\037' | python3 -c 'import sys, json
import re

try:
    response = json.load(sys.stdin)
    if response.get("content") and len(response["content"]) > 0:
        text = response["content"][0]["text"]
        
        # Format markdown structure
        # Add newlines before headers while preserving their level
        text = re.sub(r"(#{1,3})\s+", r"\n\1 ", text)
        # Format links - keep the original captured content
        text = re.sub(r"\[(.*?)\]", lambda m: "\n[" + m.group(1) + "]", text)
        # Format list items
        text = re.sub(r"-\s+", "\n- ", text)
        # Clean up multiple newlines and pound signs
        text = re.sub(r"\n{3,}", "\n\n", text)
        text = re.sub(r"#\n", "\n", text)
        # Remove standalone #
        text = re.sub(r"\s+#\s*$", "", text, flags=re.MULTILINE)
        
        print(text.strip())
except Exception as e:
    print(f"Error parsing response: {e}", file=sys.stderr)')

        echo "Generated Merge Request Description:"
        echo "-----------------------------------"
        echo "$formatted_description"
        
        # Ask if user wants to regenerate
        echo -e "\nWould you like to:"
        echo "1) Use this description and copy to pasteboard"
        echo "2) Regenerate with the same template"
        echo "3) Try a different template"
        echo -n -e "\nEnter choice (1-3): "
        read choice
        
        case $choice in
            1) 
                echo "$formatted_description" | pbcopy
                echo "Description copied to clipboard!"
                return 0 
                ;;
            2) mrg_generate_description "$branch_start" "true" ;;  # Pass regenerate flag
            3) SELECTED_TEMPLATE=""; mrg_generate_description "$branch_start" ;;  # Clear template for new selection
            *)
                echo "Invalid choice. Using current description." >&2
                return 0
                ;;
        esac
    else
        echo "Error: Failed to get response from Claude API" >&2
        echo "API Response: $response" >&2
        return 1
    fi
}

# Internal function to show help
mrg_show_help() {
    echo "Merge Request Generator Usage"
    echo "============================"
    echo "Commands:"
    echo "  setup           - Configure JIRA URL and Claude API key"
    echo "  init-templates  - Initialize default templates"
    echo "  generate       - Generate MR description"
    echo "  help           - Show this help message"
    echo ""
    echo "Examples:"
    echo "  merge_request_generator setup"
    echo "  merge_request_generator generate main"
    echo "  merge_request_generator generate HEAD~5"
}

# Main entry point function
merge_request_generator() {
    typeset command=$1
    shift  # Remove first argument, leaving remaining args

    case $command in
        "setup")
            mrg_setup_config && mrg_setup_claude_api_key
            ;;
        "init-templates")
            mrg_init_template_storage
            ;;
        "generate")
            mrg_generate_description "$@"
            ;;
        "help"|"")
            mrg_show_help
            ;;
        *)
            echo "Unknown command: $command" >&2
            mrg_show_help
            return 1
            ;;
    esac
}
