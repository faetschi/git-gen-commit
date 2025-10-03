#!/usr/bin/env pwsh
# =======================================================
# Git Gen Commit PowerShell Version
# =======================================================

# Initialize variables
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition
$CONFIG_FILE = Join-Path $SCRIPT_DIR "model-config.json"
$SetModel = $null
$Limit = $null
$Model = $null
$DIFF_CONTEXT = $null
$Reset = $false
$HELP = $false
$Verbose = $false
$OnlyMessage = $false

##################################
### ENTER YOUR OLLAMA API HERE ###
##################################
$OLLAMA_URL = "https://ollama-url.com"

# (OPTIONAL) Adjust specific Ollama Options here
$NumCtx = 6144
$NumPredict = $null
$Temperature = $null
$TopK = $null
$TopP = $null

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

# Parse arguments manually since PowerShell's param() doesn't support complex argument parsing like bash
$argIndex = 0
while ($argIndex -lt $args.Count) {
    $arg = $args[$argIndex]
    switch ($arg) {
        "--only-message" { $OnlyMessage = $true; $argIndex++ }
        "--verbose" { $Verbose = $true; $argIndex++ }
        "--h" { $HELP = $true; $argIndex++ }
        "--h" { $HELP = $true; $argIndex++ }
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
        "--reset" { 
            $Reset = $true; 
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

# =======================================================
# 📋 Header
# =======================================================
if (-not $HELP -and -not $OnlyMessage) {
    Write-Bold "Git Gen Commit v1.0"
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
    Write-Host "  -h                 Show this help message" -ForegroundColor White
    Write-Host "  --model MODEL      Specify model variant" -ForegroundColor White
    Write-Host "  --set-model MODEL  Set the model for commit message generation" -ForegroundColor White
    Write-Host "  --reset            Reset configuration to defaults" -ForegroundColor White
    Write-Host "  --context NUM      Set diff context lines (default: 3)" -ForegroundColor White
    Write-Host "  --limit NUM        Limit response to maximum number of characters" -ForegroundColor White
    exit 0
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
    # Load existing config
    $existingConfig = Get-Content -Path $CONFIG_FILE -Raw | ConvertFrom-Json
    $MODEL_SP_CHANGE = $existingConfig.model_sp_change
    $MODEL_SP_COMMIT = $SetModel
    $MODEL_SP_CHANGE_DEFAULT = $existingConfig.model_sp_change_default
    $MODEL_SP_COMMIT_DEFAULT = $existingConfig.model_sp_commit_default
    $SUMMARY_PROMPT_TEMPLATE = $existingConfig.summary_prompt_template
    $COMMIT_PROMPT_TEMPLATE = $existingConfig.commit_prompt_template

} else {
    # This shouldn't happen: config is always generated at installation
    Write-Error "Configuration file not found. Please reinstall the tool."
    exit 1
}

# Set Fallback Default Config, used for re-writing the model-config.json
$defaultConfig = @{
    model_sp_change = "tavernari/git-commit-message:sp_change"
    model_sp_commit = "qwen3-coder:latest"
    model_sp_change_default = "tavernari/git-commit-message:sp_change"
    model_sp_commit_default = "qwen3-coder:latest"
    summary_prompt_template = $SUMMARY_PROMPT_TEMPLATE  # Use the template from existing config if available
    commit_prompt_template = $COMMIT_PROMPT_TEMPLATE   # Use the template from existing config if available
    max_chars = "200"
} | ConvertTo-Json

# Set fallback defaults if not found in config
if (-not $DEFAULT_MODEL_SP_CHANGE) {
    $DEFAULT_MODEL_SP_CHANGE = "tavernari/git-commit-message:sp_change"
}
if (-not $DEFAULT_MODEL_SP_COMMIT) {
    $DEFAULT_MODEL_SP_COMMIT = "qwen3-coder:latest"
}

# =======================================================
# 🔍 Model Validation Function
# =======================================================
function TestModelExists {
    param([string]$ModelName)
    
    try {
        # Get list of available models
        $models = Invoke-RestMethod -Uri ($OLLAMA_URL + "/api/tags") -Method Get -TimeoutSec 10
        
        if ($models -and $models.models) {
            # Check if model exists in the list
            foreach ($model in $models.models) {
                if ($model.name -eq $ModelName -or $model.name -like "${ModelName}*") {
                    return $true
                }
            }
        }
        return $false
    } catch {
        Write-Color "Warning: Could not validate model existence. Proceeding with API call." -Color "yellow"
        Write-Color "Error: $($_.Exception.Message)" -Color "red"
        return $true  # Continue anyway if validation fails
    }
}

function Get-AvailableModels {
    try {
        $models = Invoke-RestMethod -Uri ($OLLAMA_URL + "/api/tags") -Method Get -TimeoutSec 10
        
        if ($models -and $models.models) {
            return $models.models | ForEach-Object { $_.name }
        } else {
            return @("No models found")
        }
    } catch {
        return @("Error retrieving models: $($_.Exception.Message)")
    }
}

# Check if user wants to set model permanently
if ($SetModel) {
     # Validate that the model exists before setting it
    if (-not (TestModelExists $SetModel)) {
        Write-Color "Error: Model '$SetModel' not found on Ollama server." -Color "red"
        Write-Color "Available models:" -Color "yellow"
        Get-AvailableModels | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        exit 1
    }
    
    # Save to config file
    try {
        $config = @{
            model_sp_change = $MODEL_SP_CHANGE
            model_sp_commit = $MODEL_SP_COMMIT
            model_sp_change_default = $MODEL_SP_CHANGE_DEFAULT
            model_sp_commit_default = $MODEL_SP_COMMIT_DEFAULT
            summary_prompt_template = $SUMMARY_PROMPT_TEMPLATE
            commit_prompt_template = $COMMIT_PROMPT_TEMPLATE
    max_chars = "200"
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

if ($Reset) {
    Write-Host "Resetting to default configuration..." -ForegroundColor Yellow
    
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

# Check if there are any changes to commit
$gitStatus = git status --porcelain
if ([string]::IsNullOrWhiteSpace($gitStatus)) {
    Write-Color "No changes to commit. Nothing to process." -Color "red"
    exit 0
}

# Display current configuration if verbose is enabled
if ($Verbose) {
    if ($MODEL_VARIANT) {
        Write-Host "Model set to: $MODEL_VARIANT" -ForegroundColor Cyan
    }
}

if ($Limit) {
    Write-Host "Character limit set to: $Limit characters" -ForegroundColor Green
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
            if (!$OnlyMessage) {
                Write-Host "Loaded model configuration from: $CONFIG_FILE" -ForegroundColor Cyan
            }
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
if ($DIFF_CONTEXT -gt 0) {
    Write-Host "Using context: $DIFF_CONTEXT" -ForegroundColor Green
    # Use explicit command execution with proper quoting
    $DIFF = & git diff --staged "--unified=$DIFF_CONTEXT"
} else {
    $DIFF = git diff --staged -U3
}
if ([string]::IsNullOrWhiteSpace($DIFF)) {
    Write-Color "No staged changes detected. Run 'git add' first." -Color "red"
    exit 1
}

# =======================================================
# 🛠️ Helper/Utility Functions
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

function ConvertToShorterCommit {
    param([string]$OriginalMessage)
    
    $shortenPrompt = @'
You are a commit message editor. 
Make the following commit message more concise and shorter while preserving its meaning and technical accuracy.
Keep it under 70 characters for the subject line, and limit the explanation to 1-2 sentences max.
Return ONLY the shortened commit message in conventional commit format.

Original commit message:
"{original_message}"
'@

    $shortenPrompt = $shortenPrompt -replace '\{original_message\}', $OriginalMessage
    
    # Use a simpler model or same model for shortening
    $shortened = Invoke-OllamaApi $MODEL_SP_COMMIT $shortenPrompt $options
    
    return $shortened
}

function GetUserContext {
    Write-Host "Enter additional context for commit message (press Enter on empty line to finish):" -ForegroundColor Yellow
    $userContext = ""
    while ($true) {
        $inputLine = Read-Host
        if ([string]::IsNullOrWhiteSpace($inputLine)) {
            break
        }
        $userContext += "$inputLine`n"
    }
    
    return $userContext.Trim()
}

# =======================================================
# 📝 Prompt Generation Functions
# =======================================================
function Generate-Summary-Prompt {
    param([string]$DiffContent, [int]$MaxChars)
    $summaryTemplate = $null
    if (Test-Path $CONFIG_FILE) {
        try {
            $config = Get-Content $CONFIG_FILE | ConvertFrom-Json
            if ($config -and $config.summary_prompt_template) {
                $summaryTemplate = $config.summary_prompt_template
            }
        }
        catch {
            Write-Color "Error reading summary prompt template from config" -Color "red"
            exit 1
        }
    }
    if (-not $summaryTemplate) {
        Write-Color "Error: summary_prompt_template not found in config file" -Color "red"
        exit 1
    }
    
    # Use the actual template with proper variable replacement using {diff_content} and {max_chars}
    $prompt = $summaryTemplate -replace '\{diff_content\}', $DiffContent
    if ($MaxChars -gt 0) {
        $prompt = $prompt -replace '\{max_chars\}', $MaxChars.ToString()
    }
    return $prompt.Trim()
}

function Generate-Commit-Prompt {
    param([string]$Summary, [int]$MaxChars)
    
    # Load template from config
    $commitTemplate = $null
    if (Test-Path $CONFIG_FILE) {
        try {
            $config = Get-Content $CONFIG_FILE | ConvertFrom-Json
            if ($config -and $config.commit_prompt_template) {
                $commitTemplate = $config.commit_prompt_template
            }
        }
        catch {
            Write-Color "Error reading commit prompt template from config" -Color "red"
            exit 1
        }
    }
    
    if (-not $commitTemplate) {
        Write-Color "Error: commit_prompt_template not found in config file" -Color "red"
        exit 1
    }
    
    # Use the actual template with proper variable replacement using {summary} and {max_chars}
    $prompt = $commitTemplate -replace '\{summary\}', $Summary
    if ($MaxChars -gt 0) {
        $prompt = $prompt -replace '\{max_chars\}', $MaxChars.ToString()
    }
    
    return $prompt.Trim()
}

# =======================================================
# 📝 Prompt Generation Functions WITH CONTEXT
# =======================================================

function Generate-Commit-PromptWithContext {
    param([string]$Summary, [string]$UserContext, [int]$MaxChars)
    
    # Load template from config
    $commitTemplate = $null
    if (Test-Path $CONFIG_FILE) {
        try {
            $config = Get-Content $CONFIG_FILE | ConvertFrom-Json
            if ($config -and $config.commit_prompt_template) {
                $commitTemplate = $config.commit_prompt_template
            }
        }
        catch {
            Write-Color "Error reading commit prompt template from config" -Color "red"
            exit 1
        }
    }
    
    if (-not $commitTemplate) {
        Write-Color "Error: commit_prompt_template not found in config file" -Color "red"
        exit 1
    }
    
    # Add user context to the summary for better commit message generation
    $prompt = $commitTemplate -replace '\{summary\}', "$Summary`n`nUser Context: $UserContext"
    if ($MaxChars -gt 0) {
        $prompt = $prompt -replace '\{max_chars\}', $MaxChars.ToString()
    }
    
    return $prompt.Trim()
}

# =======================================================
# 📝 Generate Final Commit Messages
# =======================================================
function Generate-Final-Commit {
    param([string]$DiffContent)

    $options = @{}
    if ($NumCtx) { $options.num_ctx = $NumCtx }
    if ($NumPredict) { $options.num_predict = $NumPredict }
    if ($Temperature) { $options.temperature = $Temperature }
    if ($TopK) { $options.top_k = $TopK }
    if ($TopP) { $options.top_p = $TopP }
    
    # Generate summary
    $summaryPrompt = Generate-Summary-Prompt $DiffContent $Limit
    $summary = Invoke-OllamaApi $MODEL_SP_CHANGE $summaryPrompt $options
    
    if (-not $summary) {
        Write-Color "Failed to generate summary." -Color "yellow"
        return $null
    }

    # Generate commit message from summary
    $commitPrompt = Generate-Commit-Prompt $summary $Limit
    $output = Invoke-OllamaApi $MODEL_SP_COMMIT $commitPrompt $options
    
    if ($output) {
        return $output
    } else {
        Write-Color "Generation failed." -Color "yellow"
        return $null
    }
}

# =======================================================
# 📝 Generate Final Commit Messages WITH CONTEXT
# =======================================================

function Generate-Final-CommitWithContext {
    param([string]$DiffContent, [string]$UserContext)
    
    $options = @{ }
    if ($NumCtx) { $options.num_ctx = $NumCtx }
    if ($NumPredict) { $options.num_predict = $NumPredict }
    if ($Temperature) { $options.temperature = $Temperature }
    if ($TopK) { $options.top_k = $TopK }
    if ($TopP) { $options.top_p = $TopP }
    
    # Generate summary with context
    $summaryPrompt = Generate-Summary-Prompt $DiffContent $Limit
    $summary = Invoke-OllamaApi $MODEL_SP_CHANGE $summaryPrompt $options
    
    if (-not $summary) {
        Write-Color "Failed to generate summary with context." -Color "yellow"
        return $finalCommitMessage  # Return original message if summary fails
    }

    # Generate commit message from summary with context
    $commitPrompt = Generate-Commit-PromptWithContext $summary $UserContext $Limit
    $output = Invoke-OllamaApi $MODEL_SP_COMMIT $commitPrompt $options
    
    if ($output) {
        return $output
    } else {
        Write-Color "Generation failed." -Color "yellow"
        return $finalCommitMessage  # Return original message if generation fails
    }
}

# =======================================================
# 🤖 Ollama API Call Function
# =======================================================
function Invoke-OllamaApi {
    param([string]$Model, [string]$Prompt, [hashtable]$Options)
    
    # Create JSON payload
    $escapedPrompt = $Prompt -replace '\\', '\\\\' -replace '"', '\\"' -replace "`n", '\n' -replace "`r", '\r' -replace "`t", '\t'
    $jsonPayload = @{
        model = $Model
        prompt = $escapedPrompt
        stream = $false
        think = $false
        options = @{
            num_ctx = $NumCtx
            num_predict = $NumPredict
            temperature = $Temperature
            top_k = $TopK
            top_p = $TopP
        }
    } | ConvertTo-Json
    
    try {
        # Call Ollama API
        $response = Invoke-RestMethod -Uri ($OLLAMA_URL + "/api/generate") `
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
    Write-Host "Choose: (c)ommit, (e)dit, (r)egenerate, (d)iscard, (s)horter, (p)ropose > "
    
    $finalChoice = Read-Host
    
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
            # Regenerate commit message
			Write-Host ""
			$finalCommitMessage = Generate-Final-Commit $DIFF
			continue
		}
        "s" {
            # Make commit message more concise
            Write-Host "Making commit message more concise..." -ForegroundColor Yellow
            
            $shortenedMessage = ConvertToShorterCommit $finalCommitMessage
            
            if ($shortenedMessage) {
                $finalCommitMessage = $shortenedMessage
                continue
            } else {
                Write-Color "Failed to shorten commit message." -Color "red"
                continue
            }
        }
        "p" {
            # Propose additional context for commit message
            $userContext = GetUserContext
            if ($userContext) {
                Write-Host "Generating commit message with additional context..." -ForegroundColor Cyan
                $finalCommitMessage = Generate-Final-CommitWithContext $DIFF $userContext
            } else {
                Write-Color "No context provided. Continuing with current message." -Color "yellow"
            }
            continue
        }
		{($_ -eq "d") -or ($_ -eq "q")} {
            # Exit after discarding
			Write-Color "Discarded." -Color "yellow"
			exit 0 
		}
		default {
			Write-Color "Invalid choice. Please try again." -Color "yellow"
			continue
		}
	}
}