# kbupdate-library scheduler

This Cloudflare Worker checks Microsoft's `wsusscn2.cab` metadata once per day and dispatches the `Refresh kbupdate-library candidate` workflow in the `kbupdate` repository whenever the catalog fingerprint changes.

The Worker never downloads the CAB. The Windows GitHub runner performs the large download, updates the SQLite database, rebuilds the `.dat` caches, validates the candidate, and uploads it as a 14-day workflow artifact. The workflow deliberately does not publish to the PowerShell Gallery yet; the existing Gallery database has been stale since May 2023 and needs a reviewed catch-up run first.

## Deploy

```powershell
npm install
npm run check
npx wrangler login
npx wrangler secret put GITHUB_TOKEN
npm run deploy:dry-run
npm run deploy
```

Use a fine-grained GitHub token limited to `potatoqualitee/kbupdate` with Actions write permission and Metadata read permission. Wrangler automatically provisions the `STATE` KV namespace during deployment. The token is declared as a required Worker secret and is never stored in this repository.

The daily trigger runs at 01:17 UTC. A successfully dispatched catalog fingerprint is stored in KV, so the same CAB does not create duplicate workflow runs. Failed GitHub API dispatches are not checkpointed and will be retried on the next cron invocation. If GitHub accepts a dispatch but the Windows job later fails, rerun that GitHub job manually; the Worker intentionally does not create duplicate runs for the same catalog.
