# Trusted inventory boundary — Task 1

User-approved backend extension. No deployment is included in this task.

## Runtime contract

- Node.js 22; Firebase callable v2; region `us-central1`.
- `confirmImport`, `confirmExport`, `confirmDamage`, `completeCheck` accept
  JSON produced by the Flutter models, not Firestore Timestamp objects.
- Authenticated Firebase UID is the actor. Caller `performedBy`, names,
  count differences and createdBy/reportedBy are not authorization inputs.
- Each callable checks Firebase Auth disabled state, then reads the current
  `users/{uid}` role/isActive inside the stock transaction. Every read precedes
  every write; receipts and movement IDs are create-only; replay is rejected.
- Server reads current stock and verifies quantities, allocations, lot identity,
  expiry, quality holds, prices/totals and stale counts. Snapshot labels and
  ledger before/after/delta are constructed by the server.
- Up to 200 allocations/count items per operation (under the 500-write atomic
  limit); finite quantities/prices are bounded to 1e12. No transaction splitting.
- New batch codes use SHA-256 of trimmed/lowercase code for a stable reservation.
  A legacy batch-code lookup scans the collection inside the transaction only
  when a reservation is missing. Large existing warehouses need a reviewed
  reservation-index migration; never auto-rewrite live stock.

## Security Rules and compatibility

Clients, including admins, cannot write batches/receipts/checks/ledger/code
reservations directly. Admin SDK bypasses rules, so validation lives in the
callables. Only location-field patches to an active existing location remain
allowed from the client. They cannot alter stock or lot identity. Capacity
checking/async success feedback for moves remains existing logic (Task 3).

`CallableInventoryTransactions` is the production bootstrap adapter.
`InventoryTransactionRepository` remains only as the legacy/test adapter for
the existing read-before-write and planner regression suite. It is not a
fallback and its direct writes are denied by the new rules.

The old client SQLite-to-Firestore stock migration is also intentionally denied.
Task 2 must replace that route with an explicitly authorized, validated import
workflow. Do not weaken the rules to restore direct migration.

## Emulator verification (no production access)

Install dependencies with `npm ci` in `functions/` and `test/firestore_rules/`.
Use Node 22 and Java 21+ (only process-local JAVA_HOME/PATH if needed).
From the repository root:

```powershell
$env:FUNCTIONS_DISCOVERY_TIMEOUT='60'
firebase emulators:exec --config firebase.inventory-test.json --project demo-smart-rice-auth --only firestore,auth,functions "npm --prefix functions test && node --test test/firestore_rules/auth.rules.test.mjs"
```

Tests refuse to start unless the demo project and exact loopback Firestore/Auth
endpoints are set. They invoke real callable HTTP endpoints with Auth emulator
ID tokens; they never use production accounts or service account keys.

Flutter serializes transaction dates in UTC with an explicit timezone; the
server rejects ambiguous timezone-free dates. This preserves timestamps when
supplementing a legacy lot entered in local time. SDK services initialize in
`onInit`, following [Firebase initialization guidance](https://firebase.google.com/docs/functions/tips#avoid_deployment_timeouts_during_initialization).

## Release gate — not deployed

This source checkout requires a coordinated Functions + Rules + app release.
Do not install the new app as a production transaction client before the four
functions exist. It deliberately reports callable errors, with no local/direct
fallback. Obtain explicit approval for the exact project and resources before
any deployment. Existing production rules are unchanged by local tests.

App Check/rate limiting, production load/IAM/billing validation and live-device
E2E have not been verified here. No promise is made about physical stock truth:
authorized staff can still report a count/import; the server guarantees the
authorization, validated atomic accounting and traceable actor, not a physical
inspection or managerial approval workflow.
