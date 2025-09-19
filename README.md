# Installation Guide
This guide explains how to install and use `git-gen-commit` in different terminal environments.

## For PowerShell

### Steps:
1. **Adjust paths in the ``installer.ps1`` script**
2. **Open PowerShell Window**
3. **Navigate to the project directory and run:**
   ```shell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
4. **Run the installer script in the same PowerShell Window:**
   ```shell
   .\installer.ps1
   ```
- **(Optional)** Adjust model configuration in ``"C:\tools\git-gen-commit\model-config.json"``


## Usage

After installation, you can run ``git-gen-commit`` from anywhere in your terminal:
```bash
git-gen-commit
```


> **[!WARNING]**  
> GIT BASH / WSL VERSION IS DEPRECATED
> IT IS MISSING UPDATES/FEATURES FROM POWERSHELL VERSION

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