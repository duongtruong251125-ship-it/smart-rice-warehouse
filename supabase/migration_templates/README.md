# Authoritative inventory data for migration

If the original system can export data, provide its unmodified export instead
of retyping it. Otherwise, use the CSV templates in this folder. Do not put
passwords, API keys, service-role keys, password hashes, or login tokens in the
files.

## `batches.csv`

Include only real batches from the authoritative inventory source. Preserve
source IDs and codes exactly. `quantity` is the current quantity at the
`as_of_date`, not the original imported quantity. Dates use `YYYY-MM-DD` and
decimal values use a dot. `status` must be one of `available`, `lowStock`,
`expired`, or `qualityHold`.

`rice_id`, `supplier_id`, and `warehouse_location_id` should match the
corresponding source records when known. Leave an unknown ID blank and include
the source name; do not invent IDs. The migration validator will report
unresolved links.

## `stock_movements.csv`

Include this file if the source has a real movement ledger. Keep every source
movement ID, reference, and timestamp. The signed quantity rule is
`quantity_after = quantity_before + quantity_delta`: imports are positive,
exports and confirmed damage are negative. `type` must be one of `import`,
`export`, `damage`, `inventoryCheck`, `adjustment`, or `migration`.

If only a current stock snapshot is available, leave the movement file empty.
The migration can represent each batch quantity as a clearly labelled
`migration` opening balance at the snapshot date, but it cannot recreate
missing historical movements or claim those opening balances are the original
import transactions.

You may provide an XLSX/JSON/CSV export in place of these templates. Keep the
original file unchanged; mapping and validation happen on a copy before any
Supabase write.

## Previously approved temporary fixture

The `temporary_opening_stock_*.csv` files were derived from
`functions/fixtures/temporary_opening_stock_2026-10-29.json`: 3 rice products,
3 batches, 3 opening movements, and 3 batch-code reservations (1,200 kg total).
They use the trace marker `tmp-opening-stock-2026-10-29` and remain separate
from the authoritative inventory templates. The fixture was imported into the
hosted Supabase project as migration run `tmp-opening-stock-2026-10-29` and
verified at 1,200 kg. `apply_temporary_opening_stock.sql` is idempotent;
`remove_temporary_opening_stock.sql` is guarded and must only be run when the
owner retires the temporary records before release.
