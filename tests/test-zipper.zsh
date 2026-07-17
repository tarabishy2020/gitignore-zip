#!/bin/zsh

set -euo pipefail

repo_dir="${0:A:h:h}"
zipper="$repo_dir/Zip Using gitignore.workflow/Contents/Resources/zip-using-gitignore.sh"
test_root="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/gitignore-zip-test.XXXXXX")"

cleanup() {
  /bin/rm -rf -- "$test_root"
}
trap cleanup EXIT INT TERM

fail_test() {
  print -u2 -- "FAIL: $1"
  exit 1
}

project="$test_root/project \"quoted\" \\ slash"
/bin/mkdir -p \
  "$project/.git/objects" \
  "$project/vendor/lib/.git/hooks" \
  "$project/vendor/lib/.git/refs/heads" \
  "$project/nested" \
  "$project/build"

print -r -- 'build/' > "$project/.gitignore"
print -r -- 'secret.txt' > "$project/nested/.gitignore"
print -r -- 'keep' > "$project/keep.txt"
print -r -- 'root git metadata' > "$project/.git/config"
print -r -- 'globally ignored on purpose' > "$project/TODO.md"
print -r -- 'ignore locally' > "$project/build/output.txt"
print -r -- 'ignore nested' > "$project/nested/secret.txt"
print -r -- 'keep nested' > "$project/nested/visible.txt"
print -r -- '# nested repository hook' > "$project/vendor/lib/.git/hooks/pre-commit.sample"
print -r -- 'ref: refs/heads/main' > "$project/vendor/lib/.git/HEAD"
print -r -- 'nested working file' > "$project/vendor/lib/source.txt"

global_excludes="$test_root/global-excludes"
global_config="$test_root/global-config"
print -r -- 'TODO.md' > "$global_excludes"
print -r -- '[core]' > "$global_config"
print -r -- "excludesFile = $global_excludes" >> "$global_config"

ZIP_GITIGNORE_NO_UI=1 GIT_CONFIG_GLOBAL="$global_config" \
  "$zipper" "$project"

archive="$test_root/${project:t}.zip"
[[ -f "$archive" ]] || fail_test "archive was not created"

prefix="${project:t}"
entries="$(/usr/bin/unzip -Z1 "$archive")"

print -r -- "$entries" | /usr/bin/grep -Fqx "$prefix/keep.txt" \
  || fail_test "ordinary file is missing"
print -r -- "$entries" | /usr/bin/grep -Fqx "$prefix/TODO.md" \
  || fail_test "global Git ignore leaked into the archive"
print -r -- "$entries" | /usr/bin/grep -Fqx "$prefix/nested/visible.txt" \
  || fail_test "nested visible file is missing"
print -r -- "$entries" | /usr/bin/grep -Fqx "$prefix/vendor/lib/source.txt" \
  || fail_test "nested repository working file is missing"

if print -r -- "$entries" | /usr/bin/grep -Fq "$prefix/vendor/lib/.git/"; then
  fail_test "nested .git directory was included"
fi
if print -r -- "$entries" | /usr/bin/grep -Fq "$prefix/.git/"; then
  fail_test "root .git directory was included"
fi
if print -r -- "$entries" | /usr/bin/grep -Fq "$prefix/build/"; then
  fail_test "top-level .gitignore rule was not applied"
fi
if print -r -- "$entries" | /usr/bin/grep -Fq "$prefix/nested/secret.txt"; then
  fail_test "nested .gitignore rule was not applied"
fi

ZIP_GITIGNORE_NO_UI=1 "$zipper" "$project"
[[ -f "$test_root/${project:t}-2.zip" ]] \
  || fail_test "numbered collision suffix was not created"

bad_project="$test_root/missing \"gitignore\" \\ folder"
/bin/mkdir -p "$bad_project"
if error_output="$(ZIP_GITIGNORE_NO_UI=1 "$zipper" "$bad_project" 2>&1)"; then
  fail_test "missing .gitignore unexpectedly succeeded"
fi
[[ "$error_output" == *"$bad_project"* ]] \
  || fail_test "quoted or backslashed error path was mangled"

print -- "PASS: gitignore-zip regression tests"
