# Stale `route-cache` entries survive an in-place deploy

Since Next.js 16.3.8, `next start` persists responses for prerendered routes in
`.next/server/route-cache/`. The entry key is derived from the source route and
pathname only, so it is identical across builds. When a new build is synced over
an existing `.next` directory (rsync, or deploy tools that upload changed files
and delete removed ones), the old entries survive and take precedence over the
new build's prerender in `.next/server/app/`.

The server then serves the previous build's HTML, which references static chunks
that no longer exist.

## Run

```bash
npm install
./repro.sh
```

`repro.sh` builds the app, syncs `.next` into `../server`, starts `next start`
there and requests `/`. It then changes the page from "v1" to "v2", builds and
syncs again, restarts the server and requests `/` again.

## Result

| Version           | Served after deploying v2 | Chunks returning 404 |
| ----------------- | ------------------------- | -------------------- |
| 16.3.7            | Build v2                  | 0                    |
| 16.3.8            | Build v1                  | 1                    |
| 16.4.0-canary.60  | Build v1                  | 1                    |

In the failing versions `.next/server/app/index.html` on disk contains "Build v2".
Deleting `.next/server/route-cache` before starting the server fixes it.
