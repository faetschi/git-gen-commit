# Changelog

All notable changes to this project will be documented in this file.

---

## 2025-10-01

### Overview
- **Propose context** (`p`): Introduced an interactive menu option that prompts the user for additional context and incorporates it into the LLM‑based commit message generation.
- **Shorter commit** (`s`): Added a helper to automatically shorten a generated commit message to a conventional commit subject (≤ 70 characters) and a brief body.
- **Configuration loading**: Now loads model configuration from a `model-config.json` file, allowing support for Ollama model parameters and custom prompt templates.

### Commits
- **158248f** – `feat: implement "p" propose parameter`  
  Added a new interactive menu option `(p)` for users to provide custom context that the LLM will use when generating the commit message.  
  Introduced `GetUserContext()` to collect multi‑line input and `Generate-Final-CommitWithContext()` to incorporate that context into the final commit prompt.

- **30e0129** – `feat: add shorter commit message generation`  
  Implemented the `(s)` option that calls `ConvertToShorterCommit()` to produce a concise commit message (≤ 70 chars subject line).  
  Shortened messages are isolated and do not affect subsequent regeneration.

- **1581ae1** – `fix: correct typo and update paths in README.md`  
  Fixed a typo in the README and updated file paths to match the new repository layout.  
  Minor documentation cleanup for clarity.

- **2c875ca** – `Merge branch 'master' of ssh://devops.oekb.at:22/oekb_dev_int/testprojects/_git/git-gen-commit`  
  Integrated changes from the `master` branch, aligning the main line of development with the feature branch.  
  No new features or bug fixes introduced in this merge.

- **bbc3e93** – `feat: load configuration from file and support Ollama model parameters`  
  Added logic to load model configurations from `model-config.json` (or the default config file) and support custom Ollama request options.  
  Introduced default model selection and validation helpers (`TestModelExists`, `Get-AvailableModels`).  
  Enhanced configuration handling for commit and change models, as well as prompt templates.

---

All changes above have been applied to the latest release. Future releases will build on these foundations.