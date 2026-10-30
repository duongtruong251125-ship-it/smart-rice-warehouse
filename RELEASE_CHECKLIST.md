# Google Play release checklist

## Android signing

Release variants require a private upload keystore. Keep it outside version
control and back it up securely. Create `android/key.properties` locally with:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

Place the keystore at `android/upload-keystore.jks`, or set `storeFile` to a
path relative to the `android/` directory. Both the keystore and
`android/key.properties` are ignored by Git. Do not put their values in source,
CI logs, screenshots, or chat.

Build the Play upload bundle with the guarded Supabase release script. Set the
project's publishable key in the local environment first; never pass a secret or
service-role key to the app:

```powershell
$env:SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_...'
.\tool\build_supabase_release.ps1
```

The bundle is written to `build/app/outputs/bundle/release/app-release.aab`.
Enable Play App Signing in Play Console and retain a separate backup of the
upload key. Increment `version` in `pubspec.yaml` for every uploaded release.

## Before production submission

- Choose the final, unique Android application ID and update the Android
  namespace, Play listing, and any provider configuration that depends on it.
- Resolve the incomplete historical business-data migration before treating the
  Supabase dataset as authoritative:
  the source export has no authoritative batches, stock movements, snapshots or batch
  code reservations; historical receipts and damage records have unresolved
  batch references. Do not infer inventory from demo records or receipt totals.
- Confirm Supabase Auth account access, RLS policies, production transaction
  behavior, backups, and monitoring for the final package ID before release.
- Provide a privacy policy in the app and Play listing; accurately complete the
  Data safety and data deletion declarations.
- Because the app has in-app registration, provide account deletion both in the
  app and through a discoverable web resource, unless distributing it as an
  eligible permanently private enterprise app.
- Complete the Play listing, content rating, app access instructions, and
  reviewer credentials. Use a dedicated, working reviewer account.
- Test the signed release on supported Android versions and devices, including
  sign-in, inventory transactions, camera/QR, OCR, export, and printing.
- Configure `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` locally before running
  the release script. The application selects Supabase by default outside demo
  mode.
- For newly created personal Play Console accounts subject to the testing
  policy, complete the required closed test before requesting production access.
