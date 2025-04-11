# GitHub CLI Integration

This directory contains scripts and configurations for the GitHub CLI (gh), which is a command-line tool that brings GitHub to your terminal.

## Features

- Automatic installation of GitHub CLI across different platforms (macOS, Linux)
- Interactive and non-interactive authentication options
- Configuration of common settings (git protocol, editor, shell completions)
- Update functionality to keep GitHub CLI current
- Integration with the main dotfiles installation system

## Installation

The GitHub CLI is automatically installed and configured when you run the main `install.sh` script. No additional steps are required.

## Manual Usage

You can also run the installation script manually:

```bash
# Basic installation with interactive authentication
./install-github-cli.sh

# Installation without authentication
./install-github-cli.sh --no-auth

# Update an existing installation
./install-github-cli.sh --update

# Non-interactive installation (for automated scripts)
./install-github-cli.sh --non-interactive

# Show help
./install-github-cli.sh --help
```

## Non-interactive Authentication

For non-interactive authentication, set your GitHub token as an environment variable:

```bash
export GITHUB_TOKEN=your_github_token
./install-github-cli.sh --non-interactive
```

## Command Examples

After installation, you can use the GitHub CLI for many common tasks:

```bash
# Authenticate with GitHub
gh auth login

# View repositories
gh repo list

# Create a pull request
gh pr create

# View issues
gh issue list

# Run a GitHub workflow
gh workflow run

# View pull requests
gh pr list
```

## Configuration

The installation script configures GitHub CLI with these defaults:

- SSH protocol for Git operations
- Your preferred editor (from EDITOR environment variable, or nvim/vim if available)
- Shell tab completions for Zsh or Bash

You can override these settings after installation using:

```bash
gh config set KEY VALUE
```

For example:

```bash
gh config set git_protocol https
gh config set editor code
```