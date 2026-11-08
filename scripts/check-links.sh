#!/usr/bin/env bash
# Check local Markdown links in the README and docs. External URLs are not
# fetched (CI has a separate concern for network flakiness); missing files and
# obviously broken relative paths fail the build.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail=0
check_file() {
  local file=$1 target path
  while IFS= read -r target; do
    target=${target%% *}
    target=${target#<}
    target=${target%>}
    case "$target" in
      '' | '#'* | http://* | https://* | mailto:* | tel:*) continue ;;
    esac
    path=${target%%#*}
    [[ -z "$path" || "$path" == /* ]] && continue
    if [[ ! -e "$(dirname "$file")/$path" ]]; then
      printf 'BROKEN: %s -> %s\n' "$file" "$target" >&2
      return 1
    fi
  done < <(grep -oE '\]\([^)]+\)' "$file" 2>/dev/null | sed 's/^](//; s/)$//')
  return 0
}

files=(README.md CONTRIBUTING.md SECURITY.md)
while IFS= read -r f; do files+=("$f"); done < <(find docs -name '*.md' -type f | sort)

for f in "${files[@]}"; do
  [[ -f "$f" ]] || continue
  check_file "$f" || fail=1
done

if ((fail)); then
  echo 'link check failed' >&2
  exit 1
fi
echo "link check passed (${#files[@]} files)"
