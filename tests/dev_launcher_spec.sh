#!/bin/sh

set -eu

repository_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/nvim-obsidian-para-flow-launcher.XXXXXX")
vault_dir="$test_root/dev-vault"

cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT HUP INT TERM

OBSIDIAN_PARA_DEV_VAULT_DIR="$vault_dir" "$repository_dir/scripts/nvim-dev" --prepare >/dev/null
test -f "$vault_dir/Templates/Inbox.md"
test -f "$vault_dir/.obsidian/plugins/quickadd/data.json"

touch "$vault_dir/marker"
OBSIDIAN_PARA_DEV_VAULT_DIR="$vault_dir" \
  "$repository_dir/scripts/nvim-dev" --reset --prepare >/dev/null
test ! -e "$vault_dir/marker"
find "$test_root" -maxdepth 1 -type d -name 'dev-vault.backup.*' | grep -q .
