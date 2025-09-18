#!/usr/bin/env bash

set -euo pipefail

# =======================================================
# 🎨 Minimal Colors
# =======================================================
BOLD=$'\033[1m'
RESET=$'\033[0m'
FG_RED=$'\033[31m'
FG_GREEN=$'\033[32m'
FG_YELLOW=$'\033[33m'
FG_BLUE=$'\033[34m'
FG_CYAN=$'\033[36m'
FG_GRAY=$'\033[90m'

# =========================
# Minimal UI Helpers
# =========================
log_ok()   { [ "$ONLY_MESSAGE" = "false" ] && echo -e "${FG_GREEN}[OK]${RESET} $1"; }
log_warn() { [ "$ONLY_MESSAGE" = "false" ] && echo -e "${FG_YELLOW}[WARN]${RESET} $1"; }
log_err()  { echo -e "${FG_RED}[ERROR]${RESET} $1"; }
log_info() { [ "$ONLY_MESSAGE" = "false" ] && echo -e "${FG_BLUE}>${RESET} $1"; }

# =======================
# Flags
# =========================
ONLY_MESSAGE=false
VERBOSE=false
HELP=false
MODEL_VARIANT="${GIT_GEN_COMMIT_MODEL:-default}"
DIFF_CONTEXT=5
MODEL_FLAG_PROVIDED=false

# Argument parsing (switched to while loop)
while [[ $# -gt 0 ]]; do
  arg="$1"
  case "$arg" in
    --only-message) ONLY_MESSAGE=true; shift ;;
    --verbose)      VERBOSE=true; shift ;;
    -h|--help)      HELP=true; shift ;;
    --model)
      if [[ -z "$2" ]]; then
        log_err "The --model flag requires a value"
        exit 1
      fi
      MODEL_VARIANT="$2"
      MODEL_FLAG_PROVIDED=true
      shift 2 ;;
    --context)
      if [[ -z "$2" || ! "$2" =~ ^[0-9]+$ ]]; then
        log_err "The --context flag requires a numeric value."
        exit 1
      fi
      DIFF_CONTEXT="$2"
      shift 2 ;;
    *) shift ;;
  esac
done

# =========================
# Help
# =========================
if [ "$HELP" = "true" ]; then
  cat <<'EOF'
Gen Commit (Ollama) - Minimalist
Usage:
  git-gen-commit [flags]

Flow:
  1) Analyzes staged files.
  2) Generates a summary for each file change.
  3) Synthesizes a final commit message.
  4) Presents a compact menu to commit, edit, regenerate, or discard.
  
Flags:
  --verbose       Show the diff for each file during analysis.
  --only-message  Print only the final commit message and exit. Clean output for scripting.
  --model <variant>  Choose model variant: e.g. qwen2.5-coder:1.5b. Overrides GIT_GEN_COMMIT_MODEL env var.
  --context <n>      Set the number of context lines for the diff (default: 5).
Environment:
  GIT_GEN_COMMIT_MODEL  Set default model variant (e.g. qwen2.5-coder:1.5b). Can be overridden with --model.
EOF
  exit 0
fi

# =========================
# Model configuration
# =========================
DEFAULT_MODEL_SP_CHANGE="tavernari/git-commit-message:sp_change"
DEFAULT_MODEL_SP_COMMIT="tavernari/git-commit-message:sp_commit"

if [[ "$MODEL_FLAG_PROVIDED" == false ]]; then
  # No --model flag provided at all, use defaults
  MODEL_SP_CHANGE="$DEFAULT_MODEL_SP_CHANGE"
  MODEL_SP_COMMIT="$DEFAULT_MODEL_SP_COMMIT"
else
  # --model was provided, use that model for both stages
  MODEL_SP_CHANGE="$MODEL_VARIANT"
  MODEL_SP_COMMIT="$MODEL_VARIANT"
fi

# =======================
# Header (only in interactive mode)
# =========================
if [ "$ONLY_MESSAGE" = "false" ]; then
  echo -e "${BOLD}Gen Commit${RESET}"
  echo -e "${FG_YELLOW}Using ${MODEL_VARIANT} model${RESET}"
fi

# =======================
# Collect diffs
# =========================
DIFF="$(git diff --staged -U${DIFF_CONTEXT})"
if [ -z "$DIFF" ]; then
  log_err "No staged changes detected. Run 'git add' first."
  exit 1
fi

# =========================
# Utils
# =========================
colorize_diff() {
  while IFS= read -r line; do
    if [[ $line == "+"* ]]; then printf "  ${FG_GREEN}%s${RESET}\n" "$line";
    elif [[ $line == "-"* ]]; then printf "  ${FG_RED}%s${RESET}\n" "$line";
    else printf "  ${FG_GRAY}%s${RESET}\n" "$line"; fi
  done <<< "$1"
}

split_diff() {
  local diff_content="$1"
  local chunk=""
  local chunks=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ $line == " "* ]] && [[ -n "$chunk" ]]; then
      chunks+=("$chunk")
      chunk=""
    fi
    chunk+="$line"$'\n'
  done <<< "$diff_content"

  [[ -n "$chunk" ]] && chunks+=("$chunk")

  # Export the result so it can be used later (this is not ideal, but works)
  export CHUNKS=("${chunks[@]}")
}

# =========================
# Two-stage prompt generation
# =========================

generate_summary_prompt() {
  local diff_content="$1"
  cat << EOF
You are an expert software engineer analyzing a Git diff.
Your task is to create a **very short, concise summary** (1-2 sentences max) of what changed.
Focus on the functional impact and technical details that matter to developers.
Include specific file names, function names, or code patterns that were modified.
Keep it factual and technical - no introductory phrases.

Here is the diff:
${diff_content}
EOF
}

generate_commit_prompt() {
  local summary="$1"
  cat << EOF
You are a conventional commit message generator.
Generate ONLY ONE conventional commit message in EXACT format:
<type>: <subject>

Commit message types and their meanings:
- fix: A bug fix
- feat: A new feature
- docs: Documentation only changes
- style: Changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc)
- refactor: A code change that neither fixes a bug nor adds a feature
- perf: A code change that improves performance
- test: Adding missing tests or correcting existing tests
- chore: Changes to the build process or auxiliary tools and libraries such as documentation generation
- ci: Changes to our CI configuration files and scripts
- revert: Reverts a previous commit

DO NOT include ANY introductory text, explanations, or markdown.
DO NOT include any words like "This is", "Here's", "The change", etc.
DO NOT add any extra formatting or quotes.
DO NOT respond with anything except the commit message.

Summary of changes:
"$summary"

Commit message (respond with ONLY this):
EOF
}

# =========================
# Remote Ollama API Call Function
# =========================
ollama_api_call() {
  local model="$1"
  local prompt="$2"

  # Build JSON payload step by step to avoid shell quoting issues
  local json_payload="{\"model\":\"$model\",\"prompt\":\""
  
  # Escape special characters in prompt
  local escaped_prompt="$prompt"
  escaped_prompt="${escaped_prompt//\\/\\\\}"  # Escape backslashes first
  escaped_prompt="${escaped_prompt//\"/\\\"}"  # Escape quotes
  escaped_prompt="${escaped_prompt//$'\n'/\\n}" # Escape newlines
  escaped_prompt="${escaped_prompt//$'\r'/\\r}" # Escape carriage returns
  escaped_prompt="${escaped_prompt//$'\t'/\\t}" # Escape tabs
  
  json_payload="${json_payload}${escaped_prompt}\",\"stream\":false,\"think\":false}"

  # Call Ollama API
  local response
  response=$(curl -s -X POST "http://lxiki001t.oekb.co.at:11434/api/generate" \
    -H "Content-Type: application/json" \
    -d "$json_payload")

  # Check if response contains an error
  if [[ "$response" == *\"error\"* ]]; then
    log_err "Ollama API Error: $response"
    return 1
  fi

  # Try to parse using jq first (if available)
  if command -v jq >/dev/null 2>&1; then
    local extracted
    extracted=$(echo "$response" | jq -r '.response' 2>/dev/null)
    if [[ $? -eq 0 && -n "$extracted" ]]; then
      echo "$extracted"
      return 0
    fi
  fi

  # Fallback: manual parsing
  local extracted
  if [[ "$response" =~ \"response\":\"([^\"]*)\" ]]; then
    extracted="${BASH_REMATCH[1]}"
    # Replace escaped newlines with actual newlines
    extracted=$(echo "$extracted" | sed 's/\\n/\n/g')
    echo "$extracted"
    return 0
  fi

  # If we get here, parsing failed completely
  log_err "Failed to parse response from Ollama API."
  echo "$response"
  return 1
}

# =========================
# Generate Final Commit Message
# =========================
generate_final_commit() {
  local diff_content="$1"
  local output=""
  local summary=""
  
  # Generate summary
  summary=$(ollama_api_call "$MODEL_SP_CHANGE" "$(generate_summary_prompt "$diff_content")")
  if [[ -z "$summary" ]]; then
    log_warn "Failed to generate summary."
    return 1
  fi
  
  # Generate commit message from summary
  output=$(ollama_api_call "$MODEL_SP_COMMIT" "$(generate_commit_prompt "$summary")")
  
  if [[ -n "$output" ]]; then
    FINAL_COMMIT_MESSAGE="$output"
    return 0
  else
    log_warn "Generation failed."
    return 1
  fi
}

# =========================
# Initial Generation
# =========================
split_diff "$DIFF"

FINAL_COMMIT_MESSAGE=""
attempt=0
max_attempts=3

while [[ $attempt -lt $max_attempts ]]; do
  if generate_final_commit "$DIFF"; then
    break
  else
    ((attempt++))
    log_warn "Retrying ($attempt/$max_attempts)..."
  fi
done

if [[ $attempt -eq $max_attempts ]]; then
  log_err "Failed to generate commit message after $max_attempts attempts."
  exit 1
fi

if [ "$ONLY_MESSAGE" = "true" ]; then
  printf "%s\n" "$FINAL_COMMIT_MESSAGE"
  exit 0
fi

# =======================
# Interactive Menu
# =========================
while true; do
  echo "--- Proposed Commit ---"
  printf "%s\n" "$FINAL_COMMIT_MESSAGE"
  echo "-----------------------"
  read -r -p "$(echo -e "${BOLD}${FG_YELLOW}Choose: ${FG_GREEN}(c)ommit, ${FG_CYAN}(e)dit, ${FG_YELLOW}(r)egenerate, ${FG_RED}(d)iscard > ${RESET}")" final_choice

  case "$final_choice" in
    c)
      TEMP_FILE="$(mktemp)"
      printf "%s\n" "$FINAL_COMMIT_MESSAGE" > "$TEMP_FILE"
      if git commit -F "$TEMP_FILE"; then log_ok "Committed."; else log_err "Commit failed."; fi
      rm -f "$TEMP_FILE"
      break
      ;;
    e)
      TEMP_FILE="$(mktemp)"
      printf "%s\n" "$FINAL_COMMIT_MESSAGE" > "$TEMP_FILE"
      # Try preferred editors in order
      if command -v vim >/dev/null 2>&1; then
        EDITOR=vim
      elif command -v vi >/dev/null 2>&1; then
        EDITOR=vi
      fi
      if git commit -e -F "$TEMP_FILE"; then 
        log_ok "Committed."; 
      else 
        log_err "Commit failed."; 
      fi
      rm -f "$TEMP_FILE"
      break
      ;;
    r)
      echo
      generate_final_commit "$DIFF" || break
      continue
      ;;
    d|q|*)
      log_warn "Discarded."
      break
      ;;
  esac
done