#!/bin/zsh

set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin"

fail() {
  if [[ "${ZIP_GITIGNORE_NO_UI:-0}" != 1 ]]; then
    /usr/bin/osascript \
      -e 'on run argv' \
      -e 'display alert "Zip Using .gitignore" message (item 1 of argv) as critical' \
      -e 'end run' \
      "$1" >/dev/null 2>&1 || true
  fi
  print -r -u2 -- "$1"
  exit 1
}

next_archive_path() {
  local parent="$1"
  local name="$2"
  local candidate="$parent/$name.zip"
  local number=2

  while [[ -e "$candidate" ]]; do
    candidate="$parent/$name-$number.zip"
    (( number += 1 ))
  done

  print -r -- "$candidate"
}

[[ "$#" -gt 0 ]] || fail "Select one or more folders in Finder first."
git_bin="$(command -v git 2>/dev/null || true)"
[[ -n "$git_bin" ]] || fail "Git is required. Install the Xcode Command Line Tools with: xcode-select --install"

if [[ "$git_bin" == /usr/bin/git ]] && ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
  fail "Git is required. Install the Xcode Command Line Tools with: xcode-select --install"
fi

"$git_bin" --version >/dev/null 2>&1 || fail "Git is unavailable. Install the Xcode Command Line Tools with: xcode-select --install"

typeset -a created_archives

for folder in "$@"; do
  [[ -d "$folder" ]] || fail "This action only accepts folders: $folder"
  [[ -f "$folder/.gitignore" ]] || fail "No .gitignore was found directly inside: $folder"

  folder="${folder:A}"
  local_name="${folder:t}"
  parent="${folder:h}"
  archive="$(next_archive_path "$parent" "$local_name")"
  temp_root="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/zip-gitignore.XXXXXX")"

  cleanup() {
    /bin/rm -rf -- "$temp_root"
  }
  trap cleanup EXIT INT TERM

  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
    "$git_bin" init --quiet "$temp_root/repo"
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
    "$git_bin" \
    --git-dir="$temp_root/repo/.git" \
    --work-tree="$folder" \
    ls-files --others --exclude-standard --exclude='.git/' -z > "$temp_root/files"

  /bin/mkdir -p "$temp_root/stage/$local_name"
  /usr/bin/tar -cf "$temp_root/payload.tar" -C "$folder" --null -T "$temp_root/files"
  /usr/bin/tar -xf "$temp_root/payload.tar" -C "$temp_root/stage/$local_name"

  /usr/bin/ditto -c -k --norsrc --keepParent \
    "$temp_root/stage/$local_name" "$archive"

  created_archives+=("$archive")
  cleanup
  trap - EXIT INT TERM
done

if [[ "${ZIP_GITIGNORE_NO_UI:-0}" != 1 ]]; then
  if (( ${#created_archives} == 1 )); then
    /usr/bin/open -R "${created_archives[1]}"
  else
    /usr/bin/open "${created_archives[1]:h}"
  fi

  /usr/bin/osascript -e "display notification \"Created ${#created_archives} archive(s)\" with title \"Zip Using .gitignore\"" >/dev/null 2>&1 || true
fi
