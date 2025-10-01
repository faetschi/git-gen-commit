# =======================================================
# Git Gen Commit PowerShell Setup Script
# =======================================================

################################################
###  ⚠️  IMPORTANT CONFIGURATION STEP ⚠️   ####
###   REPLACE THE $SCRIPT_SOURCE BELOW WITH #### 
###      YOUR ACTUAL SCRIPT LOCATION        ####
################################################
$SCRIPT_SOURCE = Join-Path -Path $PSScriptRoot -ChildPath "git-gen-commit.ps1"
################################################

# Configuration - Make it consistent with bash version
$INSTALL_DIR = "$env:USERPROFILE/bin/git-gen-commit"
$CONFIG_FILE = "$INSTALL_DIR/model-config.json"

Write-Host "Starting git-gen-commit setup..." -ForegroundColor White

# Step 1: Create directories properly using Windows path
# Convert to proper Windows path format
$USERPROFILE_WIN = $env:USERPROFILE -replace '/', '\'
$WIN_INSTALL_DIR = "$USERPROFILE_WIN\bin\git-gen-commit"
Write-Host "Creating directory: $WIN_INSTALL_DIR" -ForegroundColor White

# Create the full directory structure with explicit nested directory creation
try {
    # Remove existing directory if it exists
    Remove-Item -Path $WIN_INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue
    
    # Create directory structure step by step to ensure it works
    $parentDir = Split-Path $WIN_INSTALL_DIR -Parent
    Write-Host "Creating parent directory: $parentDir" -ForegroundColor White
    if (!(Test-Path $parentDir)) {
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
        Write-Host "Created parent directory successfully" -ForegroundColor White
    }
    
    Write-Host "Creating final directory: $WIN_INSTALL_DIR" -ForegroundColor White
    New-Item -Path $WIN_INSTALL_DIR -ItemType Directory -Force | Out-Null
    Write-Host "Created directories successfully: $WIN_INSTALL_DIR" -ForegroundColor White
    
} catch {
    Write-Host "Error creating directories: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Copy your PowerShell script
$SCRIPT_DESTINATION = "$WIN_INSTALL_DIR\git-gen-commit.ps1"

Write-Host "Copying script from: $SCRIPT_SOURCE" -ForegroundColor White
Write-Host "Copying script to: $SCRIPT_DESTINATION" -ForegroundColor White

if (Test-Path $SCRIPT_SOURCE) {
    try {
        Copy-Item $SCRIPT_SOURCE $SCRIPT_DESTINATION
        Write-Host "Copied PowerShell script successfully" -ForegroundColor White
        
        # Verify the file was copied
        if (Test-Path $SCRIPT_DESTINATION) {
            Write-Host "Verified: Script copied to destination" -ForegroundColor White
        } else {
            Write-Host "Error: Script not found at destination" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "Error copying script: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Warning: Script not found at source: $SCRIPT_SOURCE" -ForegroundColor Yellow
    Write-Host "Please ensure your git-gen-commit.ps1 exists at this location" -ForegroundColor Yellow
    exit 1
}

######################################
###  CHANGE DEFAULT PROMPTS HERE  #### 
######################################

# Step 3: Create model-config.json with default values
$defaultConfig = @{
    model_sp_change = "tavernari/git-commit-message:sp_change"
    model_sp_commit = "qwen3-coder:latest"
    model_sp_change_default = "tavernari/git-commit-message:sp_change"
    model_sp_commit_default = "qwen3-coder:latest"
    summary_prompt_template = @'
You are an expert software engineer analyzing a Git diff.
Your task is to create a **very short, concise summary** (1-2 sentences max) of what changed.
Focus on the functional impact and technical details that matter to developers.
Include specific file names, function names, or code patterns that were modified.
Keep it factual and technical - no introductory phrases.
Here is the diff:
{diff_content}
IMPORTANT: Limit your response to maximum {max_chars} characters.
'@
    commit_prompt_template = @'
You are a conventional commit message generator.
Generate ONLY ONE conventional commit message in EXACT format:
1. First line: A short, concise subject line (50 characters max) in conventional commit format: <type>: <subject>
2. Second line: Blank line
3. Third line onwards: A detailed explanation of what changed, why it was changed, and any important implementation details. This should be 1-2 sentences max for larger changes, but can be more concise for smaller changes.
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
"{summary}"
Commit message (respond with ONLY this):
'@
    max_chars = "200"
} | ConvertTo-Json
$defaultConfig | Out-File -FilePath "$WIN_INSTALL_DIR\model-config.json" -Encoding UTF8
Write-Host "Created default configuration file: $WIN_INSTALL_DIR\model-config.json" -ForegroundColor White

# Step 4: Create batch file wrapper for Windows terminal compatibility
$batchContent = "@echo off
REM System-wide git-gen-commit wrapper
powershell -ExecutionPolicy Bypass -File `"$WIN_INSTALL_DIR\git-gen-commit.ps1`" %*"

try {
    # Write with explicit ASCII encoding to prevent any BOM issues
    $batchContent | Out-File -FilePath "$WIN_INSTALL_DIR\git-gen-commit.bat" -Encoding Ascii -Force -NoNewline
    Write-Host "Created batch file: $WIN_INSTALL_DIR\git-gen-commit.bat" -ForegroundColor White
    
    # Verify batch file was created
    if (Test-Path "$WIN_INSTALL_DIR\git-gen-commit.bat") {
        Write-Host "Verified: Batch file created successfully" -ForegroundColor White
    } else {
        Write-Host "Error: Batch file not created" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Error creating batch file: $_" -ForegroundColor Red
    exit 1
}

# Step 5: Set up Git alias using simple approach that works with all parameters
Write-Host "Setting up Git alias..." -ForegroundColor White

try {
    # Simple approach that works reliably with all parameters
    $gitAlias = '!C:/Users/Developer/bin/git-gen-commit/git-gen-commit.bat'
    git config --global alias.gen-commit "$gitAlias"
    Write-Host "Git alias 'gen-commit' set successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "Warning: Could not set Git alias automatically." -ForegroundColor Yellow
    Write-Host "Set it manually with this command:" -ForegroundColor Yellow
    Write-Host "  git config --global alias.gen-commit '!C:/Users/Developer/bin/git-gen-commit/git-gen-commit.bat'" -ForegroundColor Cyan
}

# Step 5: Add to PATH (as before)
$existingPath = [System.Environment]::GetEnvironmentVariable("Path", "User")

if ($existingPath -notlike "*$WIN_INSTALL_DIR*") {
    $newPath = $existingPath + ";$WIN_INSTALL_DIR"
    [System.Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "Added $WIN_INSTALL_DIR to User PATH successfully!" -ForegroundColor White
    Write-Host "NOTE: You need to restart your terminal/command prompt for PATH changes to take effect" -ForegroundColor Yellow
} else {
    Write-Host "PATH already contains $WIN_INSTALL_DIR" -ForegroundColor Yellow
}

# Step 6: Final verification
Write-Host "`nFinal verification:" -ForegroundColor Magenta
Write-Host "1. Directory exists: $(Test-Path $WIN_INSTALL_DIR)" -ForegroundColor Green
Write-Host "2. Script exists: $(Test-Path "$WIN_INSTALL_DIR\git-gen-commit.ps1")" -ForegroundColor Green
Write-Host "3. Batch file exists: $(Test-Path "$WIN_INSTALL_DIR\git-gen-commit.bat")" -ForegroundColor Green

Write-Host "`nSetup complete!`n" -ForegroundColor Green

Write-Host "Important: You MUST restart your terminal/command prompt for the changes to take effect.`n" -ForegroundColor Red
Write-Host "After restarting, you can test:" -ForegroundColor Yellow
Write-Host "  git gen-commit --h" -ForegroundColor Cyan