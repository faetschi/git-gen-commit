# Installation Guide
This guide explains how to install and use `git-gen-commit` in different terminal environments.

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

After installation, you can run the git alias ``git gen-commit`` from anywhere in your terminal/bash:
```bash
git gen-commit
```