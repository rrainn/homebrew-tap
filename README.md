# rrainn/homebrew-tap

Homebrew tap for [LabelTruth](https://github.com/rrainn/LabelTruth).

## Installation

### Prerequisites

- [Homebrew](https://brew.sh/)
- The LabelTruth release bundles Node.js.
- A GitHub Personal Access Token (classic) with the `repo` scope (required for private repository access)

### One-time setup: authenticate with GitHub

Because the LabelTruth repository is private, Homebrew needs a GitHub token to
download release assets. Create a token at
[github.com/settings/tokens](https://github.com/settings/tokens) with the
`repo` scope, then set it in your shell profile:

```bash
# Add to ~/.zshrc, ~/.bashrc, etc.
export HOMEBREW_GITHUB_API_TOKEN=ghp_your_token_here
```

### Install

```bash
brew tap rrainn/tap
brew install labeltruth
```

### Upgrade

```bash
brew upgrade labeltruth
```

## Troubleshooting

### "Failure while executing" / HTTP 401 / 404

Make sure `HOMEBREW_GITHUB_API_TOKEN` is set and the token has the `repo`
scope. Tokens without the `repo` scope cannot access private GitHub releases.

```bash
test -n "${HOMEBREW_GITHUB_API_TOKEN:-}" && echo "GitHub token is set"
```

### "Already installed"

```bash
brew reinstall labeltruth
```

## How it works

When a GitHub release is published in the LabelTruth repository, its release
workflow builds and uploads CLI tarballs for macOS and Linux on arm64 and x64.
It renders the Homebrew formula with the release version, download URLs, and
SHA-256 checksums, then publishes the formula directly to this tap.

## Formulae

| Formula | Description | Version |
|---------|-------------|---------|
| labeltruth | CLI tool for LabelTruth workflows | See [Formula/labeltruth.rb](Formula/labeltruth.rb) |
