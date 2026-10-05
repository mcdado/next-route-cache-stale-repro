#!/usr/bin/env bash
# Simulates an in-place deploy: the build runs in ./ and its output is synced
# over the .next directory of a long-lived "server" checkout, the way rsync or
# deploy tools that upload changed files and delete removed ones do.
# Files the server wrote at runtime are not part of the build, so they survive.
set -euo pipefail
PORT=${PORT:-3999}
SERVER_DIR=../server

deploy() {
  npm run build >/dev/null
  mkdir -p "$SERVER_DIR"
  cp package.json next.config.ts "$SERVER_DIR"/
  [ -e "$SERVER_DIR/node_modules" ] || ln -s "$PWD/node_modules" "$SERVER_DIR/node_modules"
  rsync -a --delete --exclude=/cache --exclude=/server/route-cache .next/ "$SERVER_DIR/.next/"
}

check() {
  (cd "$SERVER_DIR" && exec npx next start -p "$PORT" >/dev/null 2>&1) &
  local pid=$!
  for _ in $(seq 1 50); do curl -sf "http://localhost:$PORT/" >/dev/null && break; sleep 0.2; done
  local html; html=$(curl -s "http://localhost:$PORT/")
  echo "  served:  $(grep -o 'Build v[0-9]' <<<"$html" | head -1)"
  local missing=0
  for chunk in $(grep -oE '/_next/static/[A-Za-z0-9_/.~-]+\.(js|css)' <<<"$html" | sort -u); do
    [ "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT$chunk")" = 200 ] || missing=$((missing + 1))
  done
  echo "  chunks referenced by the HTML that return 404: $missing"
  pkill -P $pid 2>/dev/null || true; kill $pid 2>/dev/null || true; wait $pid 2>/dev/null || true
}

rm -rf "$SERVER_DIR"
echo "Deploy build v1"; deploy; check
sed -i.bak 's/v1/v2/g' app/page.tsx app/Counter.tsx && rm -f app/*.bak
echo "Deploy build v2"; deploy; check
echo "  on disk: $(grep -o 'Build v[0-9]' "$SERVER_DIR/.next/server/app/index.html" | head -1) (.next/server/app/index.html)"
sed -i.bak 's/v2/v1/g' app/page.tsx app/Counter.tsx && rm -f app/*.bak
