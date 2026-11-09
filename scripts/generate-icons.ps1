$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Add-Type -AssemblyName System.Drawing
$bitmap = New-Object System.Drawing.Bitmap 1024,1024
$g = [System.Drawing.Graphics]::FromImage($bitmap)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.ColorTranslator]::FromHtml('#9AECCB'))
$ink = [System.Drawing.ColorTranslator]::FromHtml('#0D131C')
$pen = New-Object System.Drawing.Pen $ink, 58
$pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddLines([System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new(512,248), [System.Drawing.PointF]::new(748,340),
    [System.Drawing.PointF]::new(722,584), [System.Drawing.PointF]::new(636,704),
    [System.Drawing.PointF]::new(512,790), [System.Drawing.PointF]::new(388,704),
    [System.Drawing.PointF]::new(302,584), [System.Drawing.PointF]::new(276,340),
    [System.Drawing.PointF]::new(512,248)))
$g.DrawPath($pen, $path)
$brush = New-Object System.Drawing.SolidBrush $ink
foreach ($x in @(432,592)) { $g.FillEllipse($brush,$x-35,428,70,70); $g.DrawLine($pen,$x,470,$x,580) }
New-Item -ItemType Directory -Path (Join-Path $projectRoot 'assets') -Force | Out-Null
$bitmap.Save((Join-Path $projectRoot 'assets/app-icon.png'), [System.Drawing.Imaging.ImageFormat]::Png)
function Save-Icon([string]$target, [int]$size) {
    $small = New-Object System.Drawing.Bitmap $size,$size
    $sg = [System.Drawing.Graphics]::FromImage($small)
    $sg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $sg.DrawImage($bitmap,0,0,$size,$size)
    $small.Save((Join-Path $projectRoot $target), [System.Drawing.Imaging.ImageFormat]::Png)
    $sg.Dispose(); $small.Dispose()
}
foreach ($entry in @{mdpi=48;hdpi=72;xhdpi=96;xxhdpi=144;xxxhdpi=192}.GetEnumerator()) {
    Save-Icon ('android/app/src/main/res/mipmap-'+$entry.Key+'/ic_launcher.png') $entry.Value
}
$contents = Get-Content -LiteralPath (Join-Path $projectRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json') -Raw | ConvertFrom-Json
foreach ($entry in $contents.images) {
    $size = [double]($entry.size.Split('x')[0]) * [double]($entry.scale.Replace('x',''))
    Save-Icon ('ios/Runner/Assets.xcassets/AppIcon.appiconset/'+$entry.filename) ([int]$size)
}
Save-Icon 'web/favicon.png' 48
Save-Icon 'web/icons/Icon-192.png' 192
Save-Icon 'web/icons/Icon-512.png' 512
Save-Icon 'web/icons/Icon-maskable-192.png' 192
Save-Icon 'web/icons/Icon-maskable-512.png' 512
$g.Dispose(); $path.Dispose(); $pen.Dispose(); $brush.Dispose(); $bitmap.Dispose()
Write-Output 'Android, iOS and web icons generated.'
