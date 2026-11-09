$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $projectRoot 'dist'
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$zipPath = Join-Path $outputDir 'Twinlock-1.0.0-ios-project.zip'
Add-Type -AssemblyName System.IO.Compression
$stream = [System.IO.File]::Open($zipPath, [System.IO.FileMode]::Create)
$archive = [System.IO.Compression.ZipArchive]::new($stream, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    $files = @()
    foreach ($folder in @('lib','test','docs','assets','scripts','android','ios','web','.github')) {
        $files += Get-ChildItem -LiteralPath (Join-Path $projectRoot $folder) -File -Recurse -Force
    }
    foreach ($name in @('pubspec.yaml','pubspec.lock','analysis_options.yaml','README.md','.gitignore','.gitattributes','.metadata')) {
        $candidate = Join-Path $projectRoot $name
        if (Test-Path -LiteralPath $candidate) { $files += Get-Item -LiteralPath $candidate -Force }
    }
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($projectRoot.Length + 1).Replace('\','/')
        if ($relative -match '(^|/)(\.gradle|build|Pods|\.symlinks|ephemeral|\.swiftpm)/' -or
            $file.Name -in @('local.properties','key.properties','Generated.xcconfig','flutter_export_environment.sh') -or
            $file.Extension -in @('.jks','.keystore','.p12','.pfx','.p8','.pem','.key','.mobileprovision','.iml','.log') -or
            $file.Name -like 'GeneratedPluginRegistrant.*') { continue }
        $entry = $archive.CreateEntry('Twinlock/'+$relative, [System.IO.Compression.CompressionLevel]::Optimal)
        $destination = $entry.Open()
        $source = [System.IO.File]::OpenRead($file.FullName)
        try { $source.CopyTo($destination) } finally { $source.Dispose(); $destination.Dispose() }
    }
} finally { $archive.Dispose(); $stream.Dispose() }
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/使用说明.md') -Destination (Join-Path $outputDir '使用说明.md') -Force
Write-Output ('Source project saved: '+$zipPath)
