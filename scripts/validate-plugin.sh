#!/bin/bash

set -euo pipefail

root="${1:-.}"
manifest="$root/manifest.json"

fail() {
  echo "validate-plugin: $*" >&2
  exit 1
}

command -v jq >/dev/null || fail "jq is required"

[[ -f $manifest ]] || fail "missing manifest.json"
jq -e . "$manifest" >/dev/null || fail "manifest.json is not valid JSON"
jq -e '.schemaVersion == 1' "$manifest" >/dev/null || fail "schemaVersion must be the number 1"

for field in id name version kinds entryPoints; do
  jq -e --arg f "$field" 'has($f)' "$manifest" >/dev/null || fail "manifest is missing '$field'"
done

id=$(jq -r '.id' "$manifest")
[[ $id =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ && $id != *".."* ]] || fail "invalid plugin id '$id'"
[[ $id != omarchy.* ]] || fail "plugin id '$id' uses the reserved omarchy.* namespace"

jq -e '.version | type == "string" and test("^[0-9]+\\.[0-9]+\\.[0-9]+$")' "$manifest" >/dev/null ||
  fail "version must be MAJOR.MINOR.PATCH"
jq -e '(.kinds | type) == "array" and (.kinds | length) > 0' "$manifest" >/dev/null ||
  fail "kinds must be a non-empty array"
jq -e '(.entryPoints | type) == "object"' "$manifest" >/dev/null || fail "entryPoints must be an object"
jq -e '
  if ((.barWidget? | type) == "object" and (.barWidget | has("defaultSection"))) then
    .barWidget.defaultSection as $section
    | (["left", "center", "right"] | index($section)) != null
  else
    true
  end
' "$manifest" >/dev/null || fail "barWidget.defaultSection must be left, center, or right"

while IFS= read -r entry_json; do
  entry=$(jq -r '.' <<<"$entry_json")
  [[ -n $entry && $entry != *$'\n'* ]] || fail "entry point path is empty or multi-line"
  [[ $entry != /* && $entry != *".."* ]] || fail "entry point must be a safe relative path: '$entry'"
  [[ -f "$root/$entry" ]] || fail "entry point file not found: '$entry'"
done < <(jq -c '.entryPoints | to_entries[] | .value' "$manifest")

for pair in bar:bar bar-widget:barWidget menu:menu overlay:overlay panel:panel service:service; do
  kind="${pair%%:*}"
  key="${pair##*:}"
  jq -e --arg kind "$kind" '(.kinds | index($kind)) != null' "$manifest" >/dev/null || continue
  jq -e --arg key "$key" '.entryPoints | has($key)' "$manifest" >/dev/null ||
    fail "kind '$kind' requires entryPoints.$key"
done

link=$(find "$root" -name .git -prune -o -type l -print -quit)
[[ -z $link ]] || fail "symlinks are not allowed: $link"

unexpected=$(find "$root" -name .git -prune -o -name __pycache__ -prune -o -type f -perm /111 -print |
  grep -v -e '/omdesky_runner.py$' -e '/scripts/validate-plugin.sh$' || true)
[[ -z $unexpected ]] || fail "unexpected executable files: $unexpected"

if grep -rnE 'execDetached|"(ba)?sh",[[:space:]]*"-c"|sh -c' --include='*.qml' --include='*.js' "$root" >/dev/null; then
  fail "QML and JavaScript must not start processes through a shell"
fi

grep -q '^#!/usr/bin/python3$' "$root/omdesky_runner.py" || fail "helper must use /usr/bin/python3"
grep -qE '\bshell=True\b|os\.system|os\.popen|\beval\(|\bexec\(' "$root/omdesky_runner.py" &&
  fail "helper must not use a shell or evaluate code"

python3 -I -c 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read())' "$root/omdesky_runner.py"

echo "validate-plugin: $id is valid"
