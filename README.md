# rrainn/homebrew-tap

Homebrew tap for [LabelTruth](https://github.com/rrainn/LabelTruth).

## Installation

### Prerequisites

- [Homebrew](https://brew.sh/)
- [Node.js](https://nodejs.org/) 20+ (installed automatically via the `node` dependency)
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
echo $HOMEBREW_GITHUB_API_TOKEN
# Should print your token starting with ghp_
```

### "Already installed"

```bash
brew reinstall labeltruth
```

## How it works

This tap is updated automatically. When a new version of the LabelTruth CLI is
released (via a `v*` tag push to the main repo), the release workflow:

1. Builds platform tarballs for macOS (arm64, x64) and Linux (x64)
2. Creates a GitHub Release with those tarballs
3. Sends a `repository_dispatch` event to this tap repository
4. The update-formula workflow in this repo updates `Formula/labeltruth.rb`
   with the new version, URLs, and SHA256 checksums

## Formulae

| Formula | Description | Version |
|---------|-------------|---------|
| labeltruth | CLI tool for LabelTruth workflows | See [Formula/labeltruth.rb](Formula/labeltruth.rb) |