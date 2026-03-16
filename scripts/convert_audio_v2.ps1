$ffmpegPath = "e:\anitigravity\dominoes\temp\ffmpeg\ffmpeg-8.0.1-essentials_build\bin\ffmpeg.exe"
$soundsDir = "e:\anitigravity\dominoes\flutter_app\assets\sounds"
$mp3Files = Get-ChildItem -Path $soundsDir -Filter *.mp3

foreach ($file in $mp3Files) {
    $wavFile = Join-Path $soundsDir ($file.BaseName + ".wav")
    Write-Host "Processing: $($file.Name) `u2192 $($file.BaseName).wav"
    
    if (Test-Path $wavFile) {
        Write-Host "Skipping: $wavFile already exists."
        continue
    }

    $args = @("-i", $file.FullName, "-acodec", "pcm_s16le", "-ar", "44100", $wavFile)
    & $ffmpegPath $args
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully converted: $($file.Name)"
    } else {
        Write-Error "Failed to convert: $($file.Name)"
    }
}
