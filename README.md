# Installation Guide
This guide explains how to install and use `git-gen-commit` in different terminal environments.

## For PowerShell

### Steps:
1. **Navigate to the project directory**
2. **Adjust paths in the ``installer.ps1`` script**
3. **Run the installer script**
   ``.\installer.ps1``
4. **(Optional)** Adjust model configuration in "C:\tools\git-gen-commit\model-config.json"


## Usage

After installation, you can run the script from anywhere in your terminal:

git-gen-commit



> **[!WARNING]**  
> GIT BASH / WSL VERSION IS DEPRECATED, NEEDS UPDATES FROM POWERSHELL VERSION

## For Git Bash / WSL

Navigate to the project directory

1. **Create a bin directory in your user folder**
   mkdir -p ~/bin

2. **Copy the script to the bin directory**
   cp git-gen-commit.sh ~/bin/git-gen-commit

3. **Make it executable**
   chmod +x ~/bin/git-gen-commit

4. **Add `~/bin` to your PATH (if not already there)**
   echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
   source ~/.bashrc