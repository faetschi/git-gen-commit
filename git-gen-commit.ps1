#!/usr/bin/env pwsh
# =======================================================
# Git Gen Commit PowerShell Version
# =======================================================

# Argument parsing
param(
    [switch]$OnlyMessage,
    [switch]$Verbose,
    [switch]$ResetModels
)

# Initialize variables
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition
$CONFIG_FILE = Join-Path $SCRIPT_DIR "model-config.json"
$SetModel = $null
$Limit = $null
$Model = $null
$DIFF_CONTEXT = $null
$ResetModels = $false
$HELP = $false

# Parse arguments manually since PowerShell's param() doesn't support complex argument parsing like bash
$argIndex = 0
while ($argIndex -lt $args.Count) {
    $arg = $args[$argIndex]
    switch ($arg) {
        "--only-message" { $OnlyMessage = $true; $argIndex++ }
        "--verbose" { $Verbose = $true; $argIndex++ }
        "-h" { $HELP = $true; $argIndex++ }
        "--help" { $HELP = $true; $argIndex++ }
        "--model" {
            if ($argIndex + 1 -lt $args.Count -and $args[$argIndex + 1] -notmatch "^--") {
                $MODEL_VARIANT = $args[$argIndex + 1]
                $argIndex += 2
            } else {
                Write-Color "Error: The --model flag requires a value" -Color "red"
                exit 1
            }
        }
        "--set-model" {
            if ($argIndex + 1 -lt $args.Count -and $args[$argIndex + 1] -notmatch "^--") {
                $SetModel = $args[$argIndex + 1]
                $argIndex += 2
            } else {
                Write-Color "Error: The --set-model flag requires a value" -Color "red"
                exit 1
            }
        }
        "--reset-models" { 
            $ResetModels = $true; 
            $argIndex++ 
        }
        "--reset-model" { 
            $ResetModels = $true; 
            $argIndex++ 
        }
        "--context" {
            if ($argIndex + 1 -lt $args.Count -and $args[$argIndex + 1] -match "^[0-9]+$") {
                $DIFF_CONTEXT = [int]$args[$argIndex + 1]
                $argIndex += 2
            } else {
                Write-Color "Error: Invalid context value" -Color "red"
                exit 1
            }
        }
        "--limit" {
            if ($argIndex + 1 -lt $args.Count -and $args[$argIndex + 1] -match "^[0-9]+$") {
                $Limit = [int]$args[$argIndex + 1]
                # Add validation for low limit values
                if ($Limit -lt 10) {
                    Write-Color "Warning: Limit set to less than 10 characters, may cause issues." -Color "yellow"
                }
                $argIndex += 2
            } else {
                Write-Color "Error: Invalid limit value" -Color "red"
                exit 1
            }
        }
        default {
            $argIndex++
        }
    }
}

# Colors (PowerShell equivalent)
function Write-Color {
    param([string]$Text, [string]$Color)
    switch ($Color) {
        "red" { Write-Host $Text -ForegroundColor Red }
        "green" { Write-Host $Text -ForegroundColor Green }
        "yellow" { Write-Host $Text -ForegroundColor Yellow }
        "gray" { Write-Host $Text -ForegroundColor Gray }
        "white" { Write-Host $Text -ForegroundColor White }
        "cyan" { Write-Host $Text -ForegroundColor Cyan }
        "magenta" { Write-Host $Text -ForegroundColor Magenta }
        default { Write-Host $Text }
    }
}

function Write-Bold {
    param([string]$Text)
    Write-Host $Text -ForegroundColor White -BackgroundColor Black
}

### Load Config

# Load defaults from config file or set fallbacks
$DEFAULT_MODEL_SP_CHANGE = $null
$DEFAULT_MODEL_SP_COMMIT = $null
if (Test-Path $CONFIG_FILE) {
    try {
        $config = Get-Content $CONFIG_FILE | ConvertFrom-Json
        if ($config -and $config.model_sp_change_default) {
            $DEFAULT_MODEL_SP_CHANGE = $config.model_sp_change_default
        }
        if ($config -and $config.model_sp_commit_default) {
            $DEFAULT_MODEL_SP_COMMIT = $config.model_sp_commit_default
        }
    }
    catch {
        Write-Host "⚠️ Error reading config file, using fallback defaults" -ForegroundColor Yellow
        $DEFAULT_MODEL_SP_CHANGE = "tavernari/git-commit-message:sp_change"
        $DEFAULT_MODEL_SP_COMMIT = "qwen3-coder:latest"
    }
}

# Set fallback defaults if not found in config
if (-not $DEFAULT_MODEL_SP_CHANGE) {
    $DEFAULT_MODEL_SP_CHANGE = "tavernari/git-commit-message:sp_change"
}
if (-not $DEFAULT_MODEL_SP_COMMIT) {
    $DEFAULT_MODEL_SP_COMMIT = "qwen3-coder:latest"
}

### Set Model

# Check if user wants to set model permanently
if ($SetModel) {
    # Load existing config if it exists
    if (Test-Path $CONFIG_FILE) {
        $existingConfig = Get-Content -Path $CONFIG_FILE -Raw | ConvertFrom-Json
        $MODEL_SP_CHANGE = $existingConfig.model_sp_change
        $MODEL_SP_COMMIT = $SetModel
        $MODEL_SP_CHANGE_DEFAULT = $existingConfig.model_sp_change_default
        $MODEL_SP_COMMIT_DEFAULT = $existingConfig.model_sp_commit_default
    } else {
        # If no existing config, use defaults
        $MODEL_SP_CHANGE = $DEFAULT_MODEL_SP_CHANGE
        $MODEL_SP_COMMIT = $SetModel
    }
    
    # Save to config file
    try {
        $config = @{
            model_sp_change = $MODEL_SP_CHANGE
            model_sp_commit = $MODEL_SP_COMMIT
            model_sp_change_default = $MODEL_SP_CHANGE_DEFAULT
            model_sp_commit_default = $MODEL_SP_COMMIT_DEFAULT
        } | ConvertTo-Json

        $config | Out-File -FilePath $CONFIG_FILE -Encoding UTF8
        Write-Host "Model permanently set to: $SetModel" -ForegroundColor Green
        Write-Host "Configuration saved to: $CONFIG_FILE" -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Error "Failed to save model configuration: $_"
        exit 1
    }
}

### Reset Model
if ($ResetModels) {
    Write-Host "Resetting models to default configuration..." -ForegroundColor Yellow
    $defaultConfig = @{
        model_sp_change = "tavernari/git-commit-message:sp_change"
        model_sp_commit = "qwen3-coder:latest" # "tavernari/git-commit-message:sp_commit"
        model_sp_change_default = "tavernari/git-commit-message:sp_change"
        model_sp_commit_default = "qwen3-coder:latest" # "tavernari/git-commit-message:sp_commit"
    } | ConvertTo-Json
    
    # Ensure directory exists
    $configDir = Split-Path $CONFIG_FILE -Parent
    if (!(Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force
    }
    
    # Write default configuration to file
    try {
        $defaultConfig | Out-File -FilePath $CONFIG_FILE -Encoding UTF8
        Write-Host "Model configuration reset to defaults successfully!" -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Color "Error: Failed to write configuration file: $($_.Exception.Message)" -Color "Red"
        exit 1
    }
}

# =======================================================
# 📋 Header
# =======================================================
if (-not $HELP -and -not $OnlyMessage) {
    Write-Bold "Git Gen Commit"
}

# =======================================================
# INFO
# =======================================================

# Check for help flag and display usage information
if ($HELP) {
    Write-Host "Git Gen Commit Help" -ForegroundColor Green
    Write-Host "Usage: git-gen-commit [OPTIONS]" -ForegroundColor Yellow
    Write-Host " "
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  --only-message     Output only the commit message" -ForegroundColor White
    Write-Host "  --verbose          Enable verbose output" -ForegroundColor White
    Write-Host "  -h, --help         Show this help message" -ForegroundColor White
    Write-Host "  --model MODEL      Specify model variant" -ForegroundColor White
    Write-Host "  --set-model MODEL  Set the model for commit message generation" -ForegroundColor White
    Write-Host "  --reset-models     Reset model configuration to defaults" -ForegroundColor White
    Write-Host "  --context NUM      Set diff context lines (default: 3)" -ForegroundColor White
    Write-Host "  --limit NUM        Limit response to maximum number of characters" -ForegroundColor White
    exit 0
}

# Check if there are any changes to commit
$gitStatus = git status --porcelain
if ([string]::IsNullOrWhiteSpace($gitStatus)) {
    Write-Color "No changes to commit. Nothing to process." -Color "red"
    exit 0
}

# Display current configuration if verbose is enabled
if ($Verbose) {
    if ($OnlyMessage) {
        Write-Host "Only message mode active" -ForegroundColor Green
    }
    if ($MODEL_VARIANT) {
        Write-Host "Model set to: $MODEL_VARIANT" -ForegroundColor Cyan
    }
    if ($Limit -gt 0) {
        Write-Host "Character limit set to: $Limit characters" -ForegroundColor Cyan
    }
    if ($DIFF_CONTEXT -gt 0) {
        Write-Host "Context set to: $DIFF_CONTEXT lines" -ForegroundColor Cyan
    }
}


# =======================================================
# ⚙️ Configuration
# =======================================================

# Priority order:
# 1. If —model parameter is provided: Use that model (overrides everything)
# 2. If no —model parameter but config file exists: Use models from config file
# 3. If no —model parameter and no config file: Use default models

if ($Model) {
    # CLI override takes precedence
    $MODEL_SP_CHANGE = $Model
    $MODEL_SP_COMMIT = $Model
    Write-Host "Overriding with CLI model: $Model" -ForegroundColor Yellow
} elseif (Test-Path $CONFIG_FILE) {
    # Check config file
    try {
        $config = Get-Content $CONFIG_FILE | ConvertFrom-Json
        if ($config -and $config.model_sp_change -and $config.model_sp_commit) {
            $MODEL_SP_CHANGE = $config.model_sp_change
            $MODEL_SP_COMMIT = $config.model_sp_commit
            Write-Host "Loaded model configuration from: $CONFIG_FILE" -ForegroundColor Cyan
        } else {
            # Config file exists but has missing fields, use defaults
            $MODEL_SP_CHANGE = $DEFAULT_MODEL_SP_CHANGE
            $MODEL_SP_COMMIT = $DEFAULT_MODEL_SP_COMMIT
            Write-Host "Config file missing model definitions, using defaults" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Error reading config file, using defaults" -ForegroundColor Red
        $MODEL_SP_CHANGE = $DEFAULT_MODEL_SP_CHANGE
        $MODEL_SP_COMMIT = $DEFAULT_MODEL_SP_COMMIT
    }
} else {
    # No models defined in config file, use defaults
    $MODEL_SP_CHANGE = $DEFAULT_MODEL_SP_CHANGE
    $MODEL_SP_COMMIT = $DEFAULT_MODEL_SP_COMMIT
    Write-Host "Using default commit model: $DEFAULT_MODEL_SP_COMMIT" -ForegroundColor Yellow
}

if ($Verbose) {
    Write-Host "Using commit model: $MODEL_SP_COMMIT" -ForegroundColor Green
    Write-Host "Using change model: $MODEL_SP_CHANGE" -ForegroundColor Green
}

# =======================================================
# 🔄 Model Switching Functionality
# =======================================================
function Update-ConfigFile {
    $config = @{
        model_sp_change = $MODEL_SP_CHANGE
        model_sp_commit = $MODEL_SP_COMMIT
    } | ConvertTo-Json
    
    $config | Out-File -FilePath $CONFIG_FILE -Encoding UTF8
    Write-Host "✅ Configuration saved to: $CONFIG_FILE" -ForegroundColor Green
}

# =======================================================
# 🔍 Collect diffs
# =======================================================
$DIFF = git diff --staged -U3
if ([string]::IsNullOrWhiteSpace($DIFF)) {
    Write-Color "No staged changes detected. Run 'git add' first." -Color "red"
    exit 1
}

# =======================================================
# 🛠️ Utility Functions
# =======================================================
function Colorize-Diff {
    param([string]$DiffContent)
    $lines = $DiffContent -split "`n"
    foreach ($line in $lines) {
        if ($line.StartsWith("+")) {
            Write-Color $line -Color "green"
        } elseif ($line.StartsWith("-")) {
            Write-Color $line -Color "red"
        } else {
            Write-Color $line -Color "gray"
        }
    }
}

function Split-Diff {
    param([string]$DiffContent)
    # PowerShell equivalent of bash splitting logic
    $chunks = @()
    $currentChunk = ""
    
    $lines = $DiffContent -split "`n"
    foreach ($line in $lines) {
        if ($line.StartsWith(" ") -and $currentChunk) {
            $chunks += $currentChunk
            $currentChunk = $line + "`n"
        } else {
            $currentChunk += $line + "`n"
        }
    }
    
    if ($currentChunk) {
        $chunks += $currentChunk
    }
    
    # Return chunks array (PowerShell doesn't have global vars like bash)
    return $chunks
}

# =======================================================
# 📝 Prompt Generation Functions
# =======================================================
function Generate-Summary-Prompt {
    param([string]$DiffContent, [int]$MaxChars)
    $prompt = @"
You are an expert software engineer analyzing a Git diff.
Your task is to create a **very short, concise summary** (1-2 sentences max) of what changed.
Focus on the functional impact and technical details that matter to developers.
Include specific file names, function names, or code patterns that were modified.
Keep it factual and technical - no introductory phrases.
Here is the diff:
$DiffContent
"@

    if ($MaxChars -gt 0) {
        $prompt += "`nIMPORTANT: Limit your response to maximum $MaxChars characters."
    }
    
    return $prompt.Trim()
}

function Generate-Commit-Prompt {
    param([string]$Summary, [int]$MaxChars)
    
    $prompt = @"
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
"$Summary"
Commit message (respond with ONLY this):
"@
    if ($MaxChars -gt 0) {
        $prompt += "`nIMPORTANT: Limit your response to maximum $MaxChars characters."
    }
    
    return $prompt.Trim()
}

# =======================================================
# 🤖 Ollama API Call Function
# =======================================================
function Invoke-OllamaApi {
    param([string]$Model, [string]$Prompt)
    
    # Create JSON payload
    $escapedPrompt = $Prompt -replace '\\', '\\\\' -replace '"', '\\"' -replace "`n", '\n' -replace "`r", '\r' -replace "`t", '\t'
    $jsonPayload = @{
        model = $Model
        prompt = $escapedPrompt
        stream = $false
        think = $false
    } | ConvertTo-Json
    
    try {
        # Call Ollama API
        $response = Invoke-RestMethod -Uri "http://lxiki001t.oekb.co.at:11434/api/generate" `
                                     -Method Post `
                                     -ContentType "application/json" `
                                     -Body $jsonPayload
        
        # Extract response
        if ($response.response) {
            return $response.response
        } else {
            Write-Color "Ollama API Error: No response found" -Color "red"
            return $null
        }
    } catch {
        Write-Color "Ollama API Error: $($_.Exception.Message)" -Color "red"
        return $null
    }
}

# =======================================================
# 📝 Generate Final Commit Message
# =======================================================
function Generate-Final-Commit {
    param([string]$DiffContent)
    
    # Generate summary
    $summaryPrompt = Generate-Summary-Prompt $DiffContent $Limit
    $summary = Invoke-OllamaApi $MODEL_SP_CHANGE $summaryPrompt
    
    if (-not $summary) {
        Write-Color "Failed to generate summary." -Color "yellow"
        return $null
    }
    
    # Generate commit message from summary
    $commitPrompt = Generate-Commit-Prompt $summary $Limit
    $output = Invoke-OllamaApi $MODEL_SP_COMMIT $commitPrompt
    
    if ($output) {
        return $output
    } else {
        Write-Color "Generation failed." -Color "yellow"
        return $null
    }
}

# =======================================================
# 🚀 Main Execution
#    EDIT exec param here
# =======================================================
# Show diff in verbose mode
if ($Verbose) {
    Write-Host "`n=== VERBOSE MODE: Full Diff ===" -ForegroundColor Yellow
    
    # Split into lines and process with proper coloring
    $diffLines = $DIFF -split "`n"
    foreach ($line in $diffLines) {
        if ($line -match '^diff --git') {
            Write-Host $line -ForegroundColor Cyan
        } elseif ($line -match '^@@.*@@') {
            Write-Host $line -ForegroundColor Yellow
        } elseif ($line.StartsWith("+")) {
            Write-Host $line -ForegroundColor Green
        } elseif ($line.StartsWith("-")) {
            Write-Host $line -ForegroundColor Red
        } else {
            Write-Host $line -ForegroundColor Gray
        }
    }
    
    Write-Host "`n=== End of diff ===`n" -ForegroundColor Yellow
}

$chunks = Split-Diff $DIFF
$finalCommitMessage = $null
$maxAttempts = 3
$attempt = 0

while ($attempt -lt $maxAttempts) {
    $finalCommitMessage = Generate-Final-Commit $DIFF
    if ($finalCommitMessage) {
        break
    } else {
        $attempt++
        Write-Color "Retrying ($attempt/$maxAttempts)..." -Color "yellow"
    }
}

if (-not $finalCommitMessage) {
    Write-Color "Failed to generate commit message after $maxAttempts attempts." -Color "red"
    exit 1
}

if ($OnlyMessage) {
    Write-Host $finalCommitMessage
    exit 0
}

# =======================================================
# 🎮 Interactive Menu
# =======================================================
while ($true) {
    Write-Host "--- Proposed Commit ---"
    Write-Host $finalCommitMessage
    Write-Host "-----------------------"
    
    $finalChoice = Read-Host "Choose: (c)ommit, (e)dit, (r)egenerate, (d)iscard > "
    
	switch ($finalChoice.ToLower()) {
		"c" {
			# Commit the message
			$tempFile = [System.IO.Path]::GetTempFileName()
			Set-Content -Path $tempFile -Value $finalCommitMessage
			try {
				git commit -F $tempFile
				Write-Color "Committed." -Color "green"
			} catch {
				Write-Color "Commit failed." -Color "red"
			}
			Remove-Item $tempFile -Force
			exit 0  #  to exit after committing
		}
		"e" {
			# Edit the message
			$tempFile = [System.IO.Path]::GetTempFileName()
			Set-Content -Path $tempFile -Value $finalCommitMessage
			try {
				git commit -e -F $tempFile
				Write-Color "Committed." -Color "green"
			} catch {
				Write-Color "Commit failed." -Color "red"
			}
			Remove-Item $tempFile -Force
			exit 0  # to exit after editing and committing
		}
		"r" {
			Write-Host ""
			$finalCommitMessage = Generate-Final-Commit $DIFF
			continue
		}
		{($_ -eq "d") -or ($_ -eq "q")} {
			Write-Color "Discarded." -Color "yellow"
			exit 0  # to exit after discarding
		}
		default {
			Write-Color "Invalid choice. Please try again." -Color "yellow"
			continue
		}
	}
}