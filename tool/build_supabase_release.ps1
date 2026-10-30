$ErrorActionPreference = 'Stop'

$supabaseUrl = if ($env:SUPABASE_URL) {
    $env:SUPABASE_URL.Trim()
} else {
    'https://tzvftlwcdupzrtzbugxt.supabase.co'
}
$publishableKey = $env:SUPABASE_PUBLISHABLE_KEY

if (-not $publishableKey -or -not $publishableKey.StartsWith('sb_publishable_')) {
    throw 'Set SUPABASE_PUBLISHABLE_KEY to the project publishable key; never use a secret/service-role key in the app.'
}

& flutter build appbundle --release `
    --dart-define=USE_SUPABASE=true `
    "--dart-define=SUPABASE_URL=$supabaseUrl" `
    "--dart-define=SUPABASE_PUBLISHABLE_KEY=$publishableKey"

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
