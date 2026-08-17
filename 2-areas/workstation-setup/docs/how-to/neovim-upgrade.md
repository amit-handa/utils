# How to Upgrade Neovim for Workstation Setup

The current Kickstart baseline uses Neovim's built-in `vim.pack` package manager and the `PackChanged` event; the custom plugin overlay uses `vim.pack.add`. Use Neovim **0.12 or newer** before applying the Linux Neovim configuration.

This guide changes only the Neovim executable. It does not modify `/bin/nvim`, copy credentials, or change `~/utils/nvim-custom`.

## Inspect the installed version

```bash
nvim --version
apt-cache policy neovim
```

The configured `apt` candidate must be `0.12` or newer. A successful `apt install neovim` is not sufficient if the distribution repository still offers `0.11`.

## Package-managed upgrade

On Ubuntu, install the repository helper if it is absent:

```bash
sudo apt-get update
sudo apt-get install -y software-properties-common
```

If the stable Neovim PPA is available for the Ubuntu release, add it and install Neovim:

```bash
sudo add-apt-repository ppa:neovim-ppa/stable
sudo apt-get update
sudo apt-get install -y neovim
```

Verify the candidate after adding the PPA:

```bash
apt-cache policy neovim
nvim --version
```

If `add-apt-repository` is unavailable, sudo cannot resolve it, or the PPA still provides only Neovim 0.11, use the user-local fallback below. Do not change the shared configuration to accommodate an older runtime.

## User-local tarball fallback

The official release tarball avoids distro repositories and does not require root. This example installs the tested `v0.12.4` release; replace the version with a newer compatible release when required.

```bash
set -eu

NVIM_VERSION=v0.12.4
case "$(uname -m)" in
  x86_64) NVIM_ASSET=nvim-linux-x86_64.tar.gz ;;
  aarch64|arm64) NVIM_ASSET=nvim-linux-arm64.tar.gz ;;
  *) printf 'Unsupported Linux architecture: %s\n' "$(uname -m)" >&2; exit 1 ;;
esac

NVIM_ROOT="$HOME/.local/opt/nvim-${NVIM_VERSION#v}"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/nvim-upgrade.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$HOME/.local/bin" "$HOME/.local/opt"
curl -fL --retry 3 --retry-delay 1 \
  -o "$TMP_ROOT/nvim.tar.gz" \
  "https://github.com/neovim/neovim/releases/download/$NVIM_VERSION/$NVIM_ASSET"

mkdir "$TMP_ROOT/nvim"
tar -xzf "$TMP_ROOT/nvim.tar.gz" \
  --strip-components=1 \
  -C "$TMP_ROOT/nvim"
test -x "$TMP_ROOT/nvim/bin/nvim"
test -d "$TMP_ROOT/nvim/share/nvim/runtime"

[ ! -e "$NVIM_ROOT" ] || {
  printf 'Install path already exists: %s\n' "$NVIM_ROOT" >&2
  exit 1
}
mv "$TMP_ROOT/nvim" "$NVIM_ROOT"
ln -sfn "$NVIM_ROOT/bin/nvim" "$HOME/.local/bin/nvim"
```
Refresh the current shell command cache before verifying the selected binary, or open a new shell:

```bash
# Bash
hash -r

# Zsh
rehash
```


Ensure `$HOME/.local/bin` precedes `/bin` in the login-shell `PATH`, then verify:

```bash
command -v nvim
nvim --version
```

The expected path is `$HOME/.local/bin/nvim`. Keep the user-local install outside `~/utils`; it is machine-local runtime state.

## Verify the configuration

First verify the required APIs without loading the configuration:

```bash
nvim --clean --headless \
  '+lua assert(vim.fn.has("nvim-0.12") == 1)' \
  '+lua assert(vim.pack ~= nil)' \
  +qa
```

Then exercise the stored configuration:

```bash
timeout 120s nvim --headless '+qa'
```

The first run may download the declared plugins and compile Tree-sitter parsers. If parser compilation reports that the `tree-sitter` executable is missing, install it in the user-local prefix without sudo:

```bash
npm install --prefix "$HOME/.local" tree-sitter-cli
```

Run the headless startup check again after installing the CLI.

## Remote SSH note

For a remote command that needs sudo, allocate a terminal:

```bash
ssh -tt user@host 'sudo apt-get update && sudo apt-get install -y neovim'
```

A noninteractive `ssh host command` may not read the login profile that sets `WORKSTATION_PROFILE`; prefix setup commands explicitly when the selected environment matters:

```bash
ssh user@host 'WORKSTATION_PROFILE=server bash ~/utils/2-areas/workstation-setup/scripts/check.sh --os linux --profile base --utils-path "$HOME/utils"'
```
