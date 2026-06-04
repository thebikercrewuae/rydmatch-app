# Release Readiness

Run the local release preflight before pushing a release:

```powershell
cd C:\Users\imran\Documents\rydmatch-app
.\scripts\release_preflight.ps1
```

Include deployed Supabase function checks:

```powershell
.\scripts\release_preflight.ps1 -CheckSupabase
```

Require release environment variables to exist locally:

```powershell
.\scripts\release_preflight.ps1 -RequireEnvironment
```

The normal local check treats missing environment variables as warnings because
release secrets usually live only in Codemagic. Codemagic runs the stricter
`scripts/validate_release_config.sh` check and fails when a required release
variable is missing.

## Automated Checks

- Required repository files and directories exist
- App version uses `x.y.z+buildNumber`
- Required Codemagic release variables are configured
- Strava redirect URI and Android callback agree
- Critical Supabase Edge Functions exist and can optionally be verified remotely
- Old `rocket.new` links are absent
- Flutter analysis passes
- Flutter tests run when test files exist
- Release keystore is restored and verified
- Android App Bundle build retries transient Maven download failures

## Current Warning

The project does not yet contain automated Flutter tests. The release checks
warn about this but do not block a build until initial smoke tests are added.
