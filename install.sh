#!/bin/zsh

set -euo pipefail

repo_dir="${0:A:h}"
source_workflow="$repo_dir/Zip Using gitignore.workflow"
services_dir="$HOME/Library/Services"
installed_workflow="$services_dir/Zip Using gitignore.workflow"

[[ -d "$source_workflow" ]] || {
  print -u2 -- "Workflow not found: $source_workflow"
  exit 1
}

/bin/mkdir -p "$services_dir"
/usr/bin/ditto "$source_workflow" "$installed_workflow"
/System/Library/CoreServices/pbs -flush 2>/dev/null || true

print -- "Installed Zip Using .gitignore."
print -- "Now enable it in:"
print -- "System Settings → General → Login Items & Extensions → Finder"

