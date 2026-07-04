# RydMatch Load Testing

This suite exercises the three highest-risk Supabase paths with authenticated, synthetic riders:

- discovery RPC reads;
- matched-rider chat history reads;
- five-second live-location upserts.

It uses k6 and refuses to target the production Supabase project unless it is explicitly unlocked.

## Test environment

Use a separate staging Supabase project with the same migrations and indexes as production. Never use real users or copy production passwords into fixtures.

1. Create dedicated synthetic Auth users.
2. Create valid matched conversations for those users.
3. Add each user as an active participant in live-ride sessions with location sharing enabled. Keep each ride within the app participant limit.
4. Copy `load-tests/accounts.example.json` to `load-tests/accounts.json` and fill in synthetic details. The real file is gitignored.
5. Install k6 and open a new PowerShell window.

## Run a smoke test

```powershell
cd C:\Users\imran\Documents\rydmatch-app
$env:SUPABASE_URL='https://YOUR-STAGING-PROJECT.supabase.co'
$env:SUPABASE_ANON_KEY='YOUR-STAGING-ANON-KEY'
.\scripts\run_load_tests.ps1 -Profile Smoke -Environment staging
```

Progress through `Baseline` and `Scale`. Do not jump directly to 10,000 simulated riders. Increase traffic in stages while watching Supabase Database, API, Realtime, CPU, memory, connections, slow queries, and errors.

## Profiles

| Profile | Discovery | Chat | Live location | Duration |
| --- | ---: | ---: | ---: | ---: |
| Smoke | 2 VUs | 1 VU | 1 VU | 30 sec |
| Baseline | 20 VUs | 10 VUs | 10 VUs | 3 min |
| Scale | 100 VUs | 50 VUs | 50 VUs | 5 min |

The local `Scale` profile is a checkpoint, not a 10,000-user proof. Run 1,000-10,000-user tests from distributed or cloud generators after lower stages pass and Supabase capacity is sized.

## Pass criteria

- HTTP and operation error rates stay below 1%.
- Discovery p95 stays below 750 ms.
- Chat-history p95 stays below 500 ms.
- Live-location write p95 stays below 500 ms.
- Database connections, CPU, memory, and Realtime channels retain headroom.
- No sustained lock waits, timeouts, RLS failures, or duplicate-message spikes.

Results are written to `load-tests/results/latest-summary.json` and gitignored. Keep selected summaries as CI artifacts rather than committing them.

## Capacity note

At a five-second location interval, 10,000 simultaneously sharing riders can produce roughly 2,000 current-location writes per second, before history samples, reads, and Realtime fan-out. That target requires staged testing, Supabase plan sizing, and distributed generators.

## Production lock

Both the runner and k6 script block the known production project. This escape hatch is for an approved maintenance window only:

```powershell
.\scripts\run_load_tests.ps1 -Profile Smoke -Environment production -AllowProduction
```

Do not use `Baseline` or `Scale` against production while customers are active.
