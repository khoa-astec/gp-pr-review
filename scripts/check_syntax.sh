#!/usr/bin/env bash
# check_syntax.sh <file>... — syntax-check PHP and JS/TS files without a full build.
# PHP: local `php -l`, or the official php Docker image when php isn't installed.
# JS/TS: esbuild transformSync, found in the project's node_modules (set ESBUILD_PATH to override).
set -u
status=0

find_esbuild() {
  if [ -n "${ESBUILD_PATH:-}" ]; then echo "$ESBUILD_PATH"; return; fi
  local d
  for d in node_modules/esbuild node_modules/.pnpm/esbuild@*/node_modules/esbuild */node_modules/.pnpm/esbuild@*/node_modules/esbuild; do
    [ -d "$d" ] && { (cd "$d" && pwd -W 2>/dev/null || pwd); return; }
  done
}

for f in "$@"; do
  case "$f" in
    *.php)
      if command -v php >/dev/null 2>&1; then
        out=$(php -l "$f" 2>&1)
      else
        dir=$(cd "$(dirname "$f")" && pwd -W 2>/dev/null || pwd)
        out=$(MSYS_NO_PATHCONV=1 docker run --rm -v "$dir:/app" -w /app php:8.2-cli php -l "$(basename "$f")" 2>&1)
      fi
      echo "$out" | tail -1
      echo "$out" | grep -q "No syntax errors" || status=1
      ;;
    *.js|*.jsx|*.ts|*.tsx)
      esb=$(find_esbuild)
      if [ -z "$esb" ]; then echo "SKIP $f (esbuild not found; set ESBUILD_PATH)"; continue; fi
      node -e "const fs=require('fs');const p=process.argv[1];const l=p.split('.').pop();try{require(process.argv[2]).transformSync(fs.readFileSync(p,'utf8'),{loader:l});console.log('OK '+p)}catch(e){console.log('FAIL '+p+': '+(e.errors?e.errors.map(x=>x.text).join('; '):e.message));process.exit(1)}" "$f" "$esb" || status=1
      ;;
    *) echo "SKIP $f" ;;
  esac
done
exit $status
