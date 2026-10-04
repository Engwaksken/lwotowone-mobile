param(
  [Parameter(Mandatory=$true)][string]$ApiBaseUrl,
  [switch]$RequireReleaseKey
)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
Set-Location $projectPath
$uri = $null
if (-not [Uri]::TryCreate($ApiBaseUrl, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https' -or -not $uri.AbsolutePath.EndsWith('/api') -or $uri.Query -or $uri.Fragment -or $uri.UserInfo) { throw 'Use an HTTPS API address ending in /api.' }
if ($uri.Host -match '(^|\.)example\.com$|your-domain') { throw 'Replace the placeholder with your actual Laravel API address.' }
if (-not (Test-Path 'android/key.properties')) {
  if ($RequireReleaseKey) { throw 'Add android/key.properties and your upload keystore before building for distribution.' }
  Write-Warning 'No release key configured. This APK will use debug signing for testing.'
}
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Flutter dependencies failed.' }
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed.' }
flutter test
if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
flutter build apk --release "--dart-define=API_BASE_URL=$ApiBaseUrl"
if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
Write-Output (Join-Path $projectPath 'build/app/outputs/flutter-apk/app-release.apk')
