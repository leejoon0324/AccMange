param([switch]$SkipChecks)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ($projectRoot -match '[^\x00-\x7F]') {
    # Some Windows Dart/Java tools fail on a non-ASCII working directory.
    $asciiRoot = Join-Path (Split-Path -Parent $projectRoot) 'twinlock-build'
    if (Test-Path -LiteralPath $asciiRoot) {
        $link = Get-Item -LiteralPath $asciiRoot -Force
        $linkTarget = @($link.Target)[0]
        if ($link.LinkType -ne 'Junction' -or $linkTarget -ne $projectRoot) {
            throw 'Build from an ASCII directory; the twinlock-build path is already used by another project.'
        }
    } else {
        New-Item -ItemType Junction -Path $asciiRoot -Target $projectRoot | Out-Null
    }
    $projectRoot = $asciiRoot
}
Set-Location -LiteralPath $projectRoot
$localFlutter = Join-Path $projectRoot '.toolchain/flutter/bin/flutter.bat'
$flutterCommand = if (Test-Path -LiteralPath $localFlutter) { $localFlutter } else { 'flutter' }
$localJava = Join-Path $projectRoot '.toolchain/java'
if (Test-Path -LiteralPath $localJava) {
    $env:JAVA_HOME = (Get-ChildItem -LiteralPath $localJava -Directory | Select-Object -First 1).FullName
    $env:Path = $env:JAVA_HOME + '\bin;' + $env:Path
}
$localSdk = Join-Path $projectRoot '.toolchain/android-sdk'
if (Test-Path -LiteralPath $localSdk) { $env:ANDROID_HOME = $localSdk }
$secretDir = Join-Path $projectRoot 'secrets'
$keystore = Join-Path $secretDir 'release-signing.jks'
$passwordFile = Join-Path $secretDir 'signing-password.txt'
if (!(Test-Path -LiteralPath $keystore)) {
    New-Item -ItemType Directory -Path $secretDir -Force | Out-Null
    $randomBytes = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($randomBytes)
    $signingPassword = [Convert]::ToBase64String($randomBytes)
    Set-Content -LiteralPath $passwordFile -Value $signingPassword -NoNewline -Encoding utf8
    $env:TWINLOCK_SIGN_PASSWORD = $signingPassword
    & keytool -genkeypair -v -keystore $keystore -alias twinlock -keyalg RSA -keysize 3072 -validity 10000 `
        -storepass:env TWINLOCK_SIGN_PASSWORD -keypass:env TWINLOCK_SIGN_PASSWORD `
        -dname 'CN=Twinlock, OU=Mobile, O=Twinlock, L=Local, ST=Local, C=CN'
    if ($LASTEXITCODE -ne 0) { throw 'Signing key generation failed' }
    Remove-Item Env:TWINLOCK_SIGN_PASSWORD
}
if (!(Test-Path -LiteralPath $passwordFile)) { throw 'Restore secrets/signing-password.txt for the existing signing key' }
$signingPassword = (Get-Content -LiteralPath $passwordFile -Raw).Trim()
$keystorePath = $keystore.Replace('\', '/')
$properties = "storePassword=$signingPassword`nkeyPassword=$signingPassword`nkeyAlias=twinlock`nstoreFile=$keystorePath`n"
Set-Content -LiteralPath (Join-Path $projectRoot 'android/key.properties') -Value $properties -Encoding utf8
& $flutterCommand pub get
if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed' }
if (!$SkipChecks) {
    & $flutterCommand analyze
    if ($LASTEXITCODE -ne 0) { throw 'Analysis failed' }
    & $flutterCommand test
    if ($LASTEXITCODE -ne 0) { throw 'Tests failed' }
}
& $flutterCommand build apk --release
if ($LASTEXITCODE -ne 0) { throw 'APK build failed' }
$outputDir = Join-Path $projectRoot 'dist'
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'build/app/outputs/flutter-apk/app-release.apk') `
    -Destination (Join-Path $outputDir 'Twinlock-1.0.0-android.apk') -Force
Write-Output 'APK saved to dist/Twinlock-1.0.0-android.apk'
Write-Output 'Keep the signing key and its password in secrets/ for future app updates.'
