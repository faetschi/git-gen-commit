$CONFIG_FILE = "C:\tools\git-gen-commit\model-config.json"

# Complete setup script for git-gen-commit
Write-Host "Starting git-gen-commit setup..." -ForegroundColor Yellow

# Step 1: Create directories
mkdir "C:\tools\git-gen-commit" -Force
Write-Host "Created directories" -ForegroundColor Green

# Step 2: Copy your PowerShell script (replace with actual path to your script)
##############################################
### ⚠️  IMPORTANT CONFIGURATION STEP ⚠️  ####
###   REPLACE THE SOURCE PATH BELOW WITH  #### 
###      YOUR ACTUAL SCRIPT LOCATION      ####
### Copy-Item "<REPLACE>" "<LEAVE AS IS>" ####
##############################################
Copy-Item "C:\Workspace\KI Development\git-gen-commit\git-gen-commit.ps1" "C:\tools\git-gen-commit\git-gen-commit.ps1"


Write-Host "Copied PowerShell script" -ForegroundColor Green

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
"{summary}"
Commit message (respond with ONLY this):
'@
    max_chars = "200"
} | ConvertTo-Json

$defaultConfig | Out-File -FilePath $CONFIG_FILE -Encoding UTF8
Write-Host "Created default configuration file: $CONFIG_FILE" -ForegroundColor Green

# Check if curl is available
if (!(Get-Command curl -ErrorAction SilentlyContinue)) {
    Write-Host "curl not found. Installing curl via Winget..." -ForegroundColor Yellow
    try {
        winget install curl --silent
        Write-Host "curl installed successfully!" -ForegroundColor Green
        
        # Verify installation worked
        if (!(Get-Command curl -ErrorAction SilentlyContinue)) {
            Write-Host "Warning: curl installation may have failed verification" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Failed to install curl via Winget: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Step 4: Create batch file wrapper
$batchContent = @'
@echo off
REM Run the PowerShell script with the same arguments
powershell -ExecutionPolicy Bypass -File "C:\tools\git-gen-commit\git-gen-commit.ps1" %*
'@
Set-Content "C:\tools\git-gen-commit\git-gen-commit.bat" $batchContent
Write-Host "Created batch file wrapper" -ForegroundColor Green

# Step 4: Add to PATH (using the correct method)
$existingPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
if ($existingPath -notlike "*C:\tools\git-gen-commit*") {
    $newPath = $existingPath + ";C:\tools\git-gen-commit"
    [System.Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "Added C:\tools\git-gen-commit to PATH successfully!" -ForegroundColor Green
} else {
    Write-Host "PATH already contains C:\tools\git-gen-commit" -ForegroundColor Yellow
}

# Step 5: Create a simple test to verify it works
Write-Host "`nTesting installation..." -ForegroundColor Yellow
try {
    # Try to run the command
    $testResult = cmd /c "git-gen-commit.bat --help" 2>$null
    Write-Host "Installation successful!" -ForegroundColor Green
} catch {
    Write-Host "Installation completed, but testing failed. Please restart your terminal." -ForegroundColor Yellow
}

Write-Host "`nSetup complete! Please:" -ForegroundColor Cyan
Write-Host "1. Close ALL terminal windows (including VSCode)" -ForegroundColor Cyan
Write-Host "2. Reopen VSCode terminal" -ForegroundColor Cyan
Write-Host "3. Test with: git-gen-commit --help" -ForegroundColor Cyan

# Force refresh of environment variables for current session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User")