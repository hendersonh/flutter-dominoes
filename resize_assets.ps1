Add-Type -AssemblyName System.Drawing

$assetsDir = "e:\anitigravity\dominoes\store_assets"
$finalDir = "e:\anitigravity\dominoes\store_assets\final_resized"
New-Item -ItemType Directory -Path $finalDir -Force | Out-Null

Write-Host "Cropping Feature Graphic..."
$fgPath = "$assetsDir\feature_graphic_6lov_partners.png"
if (Test-Path $fgPath) {
    $img = [System.Drawing.Image]::FromFile($fgPath)
    $bmp = New-Object System.Drawing.Bitmap(1024, 500)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    
    $srcY = [math]::Max(0, [math]::Round(($img.Height - 500)/2))
    $srcRect = New-Object System.Drawing.Rectangle(0, $srcY, 1024, 500)
    $destRect = New-Object System.Drawing.Rectangle(0, 0, 1024, 500)
    
    $g.DrawImage($img, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $bmp.Save("$finalDir\feature_graphic_1024x500.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    $img.Dispose()
    Write-Host "Saved feature_graphic_1024x500.png"
} else {
    Write-Host "Could not find $fgPath"
}

Write-Host "Resizing App Icon..."
$iconPath = "$assetsDir\app_icon_512.png"
if (Test-Path $iconPath) {
    $img = [System.Drawing.Image]::FromFile($iconPath)
    $bmp = New-Object System.Drawing.Bitmap(512, 512)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.DrawImage($img, 0, 0, 512, 512)
    $bmp.Save("$finalDir\app_icon_512x512.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    $img.Dispose()
    Write-Host "Saved app_icon_512x512.png"
}

Write-Host "Padding screenshots to 1080x1920 (9:16)..."
function Resize-Screenshot($inName, $outName) {
    $inPath = "$assetsDir\$inName"
    if (-not (Test-Path $inPath)) { 
        Write-Host "Failed to find $inName"
        return 
    }
    $img = [System.Drawing.Image]::FromFile($inPath)
    # Target: 1080x1920
    $bmp = New-Object System.Drawing.Bitmap(1080, 1920)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    
    # 0x0f172a is a dark slate background color, looks better than pure black
    $bgColor = [System.Drawing.Color]::FromArgb(255, 15, 23, 42)
    $g.Clear($bgColor)
    
    # Scale width based on height to maintain purely original aspect ratio inside the 16:9 canvas
    $targetHeight = 1920
    $targetWidth = [math]::Round($img.Width * ($targetHeight / $img.Height))
    $xOffset = [math]::Round((1080 - $targetWidth) / 2)
    
    $g.DrawImage($img, $xOffset, 0, $targetWidth, $targetHeight)
    $bmp.Save("$finalDir\$outName", [System.Drawing.Imaging.ImageFormat]::Png)
    
    $g.Dispose()
    $bmp.Dispose()
    $img.Dispose()
    Write-Host "Saved $outName"
}

Resize-Screenshot "screenshot_main_menu.png" "screenshot_1.png"
Resize-Screenshot "screenshot_match_setup.png" "screenshot_2.png"
Resize-Screenshot "screenshot_solo_gameplay.png" "screenshot_3.png"
Resize-Screenshot "screenshot_partners_gameplay.png" "screenshot_4.png"
Resize-Screenshot "screenshot_snake_board.png" "screenshot_5.png"

Write-Host "Done!"
