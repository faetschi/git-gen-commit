# git-gen-commit

AI-powered commit message generator for Git, with PowerShell & Git Bash support and Ollama LLM backend.


## Features

- Generates high-quality, conventional commit messages using local or remote LLMs (Ollama API)
- Interactive menu: commit, edit, regenerate, shorten, or add context to messages
- Supports custom model selection and configuration
- Works in PowerShell and Windows environments
- Easily extensible and configurable

## Installation

1. **Open PowerShell**
2. **Navigate to the project directory:**
   ```powershell
   cd path\to\git-gen-commit
   ```
3. **Set execution policy (if needed):**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

4. **Adjust your Ollama API URL in ``git-gen-commit.ps1``**
   
5. **Run the installer:**
   ```powershell
   .\installer.ps1
   ```

---

## Configuration

- The tool uses a `model-config.json` file for model and prompt settings.
- You can adjust the `Ollama API URL`, ``model names`` and ``prompt templates`` in this file after installation.
- Default config location: `C:\Users\<YourUser>\bin\git-gen-commit\model-config.json`

---

## Usage

After installation, use from any terminal in a Git repository:

```powershell
git gen-commit
```

### Options

- `-h`               Output all usage guide
- `--only-message`   Output only the commit message, useful for scripting
- `--verbose`        Enable verbose output
- `--model MODEL`    Specify model variant
- `--set-model MODEL`  Set the model for commit message generation
- `--reset`          Reset configuration to defaults
- `--context NUM`    Set diff context lines (default: 3)
- `--limit NUM`      Limit response to maximum number of characters

## Requirements

- PowerShell 7+ recommended
- Git must be installed and available in PATH
- Access to an Ollama server (local or remote)

## Planned Features

- Ability to select custom external LLM provider (OpenAI, Anthropic, etc.)
- More configurable parameters (e.g. LLM params like temperature, top_p, etc.)
- Cross-platform installer (Linux, macOS, Windows)
- Enhanced prompt customization (per-project templates)
- Unit and integration tests
- VS Code extension integration
- Improved error handling
- Support for multi-language commit messages

## License

MIT License.

---

## Contributing

> Pull requests and issues are welcome! 

Please open an issue for bugs or feature requests.