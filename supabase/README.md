# Supabase backend

This folder contains the PostgreSQL schema, hosted migrations, SQL contracts,
local migration templates and Edge Functions. Flutter uses Supabase Auth,
profile, CRUD, realtime and inventory transaction adapters outside demo mode.
The Paris project is `tzvftlwcdupzrtzbugxt` (`eu-west-3`).

The app uses only the public project URL and publishable key. Never put a secret
or service-role key in Flutter, source control, build logs or screenshots.
Android release builds are guarded by `tool/build_supabase_release.ps1`.

## Local database workflow

1. Install the Supabase CLI and Docker Desktop, then start Docker.
2. Run `npx supabase start --exclude studio,edge-runtime,logflare,vector,imgproxy,supavisor,postgres-meta` from the repository root.
3. Apply the local schema with `npx supabase db reset`.
4. Run SQL contracts with `npx supabase test db`.
5. Keep local URLs, keys and test credentials outside tracked files.

## Flutter integration tests

The optional repository integration test runs only against a disposable local
Supabase stack and a local test account:

```powershell
$env:RUN_SUPABASE_LOCAL_TESTS='1'
$env:SUPABASE_URL='http://127.0.0.1:54321'
$env:SUPABASE_PUBLISHABLE_KEY='<local-publishable-key>'
$env:SUPABASE_TEST_EMAIL='<local-test-admin-email>'
$env:SUPABASE_TEST_PASSWORD='<local-test-admin-password>'
flutter test test/supabase_local_integration_test.dart
```

It covers Auth/profile, RLS-protected CRUD and realtime, location moves, and the
four transactional stock operations. Never point it at production.

## Access model

- New Auth users receive a disabled `staff` profile through a database trigger.
- An active admin must be provisioned out of band for the first account.
- RLS controls profile and operational data access; guarded PostgreSQL RPCs
  perform stock mutations atomically and preserve ledger invariants.
- Active admins can confirm another staff member's email through the
  `admin-confirm-email` Edge Function. It validates the caller's JWT and active
  admin profile before using the server-side Auth Admin API. The UI asks for
  confirmation because this action bypasses mailbox confirmation.
- The ledger is append-only to application clients.

## Historical data

Current inventory history is incomplete. See `MIGRATION_DATA_STATUS.md` for the
known missing lots, opening balances and movement references. Do not treat demo
records or receipt totals as authoritative stock.

Before a production release, verify hosted access policies, transaction
behavior, backup restoration and monitoring. Confirm the application ID,
release signing and privacy disclosures before uploading to Play Store.
