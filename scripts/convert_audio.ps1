# Prerequisites: Load WinRT assemblies
Add-Type -AssemblyName System.Runtime.WindowsRuntime

function Convert-Mp3ToWav {
    param([string]$InputPath, [string]$OutputPath)
    
    $inputPath = Resolve-Path $InputPath
    $outputPath = [System.IO.Path]::GetFullPath($OutputPath)
    $outputDir = [System.IO.Path]::GetDirectoryName($outputPath)
    $outputName = [System.IO.Path]::GetFileName($outputPath)

    if (Test-Path $outputPath) {
        Write-Host "Skipping: $outputPath already exists."
        return
    }

    Write-Host "Converting: $inputPath `u2192 $outputPath"

    # Initialize Transcoder
    $transcoder = New-Object Windows.Media.Transcoding.MediaTranscoder

    # Open Source File (Async)
    $inputTask = [Windows.Storage.StorageFile]::GetFileFromPathAsync($inputPath)
    while ($inputTask.Status -eq 'Started') { Start-Sleep -m 10 }
    $source = $inputTask.GetResults()

    # Create Destination File (Async)
    $folderTask = [Windows.Storage.StorageFolder]::GetFolderFromPathAsync($outputDir)
    while ($folderTask.Status -eq 'Started') { Start-Sleep -m 10 }
    $destFile = $folderTask.GetResults().CreateFileAsync($outputName, 1).GetResults() # 1 = ReplaceExisting

    # Set Profile to WAV (High Quality)
    $profile = [Windows.Media.MediaProperties.MediaEncodingProfile]::CreateWav(0) # 0 = High

    # Prepare and Execute Transcode
    $prepareTask = $transcoder.PrepareFileTranscodeAsync($source, $destFile, $profile)
    while ($prepareTask.Status -eq 'Started') { Start-Sleep -m 10 }
    $prepare = $prepareTask.GetResults()

    if ($prepare.CanTranscode) {
        $transcodeTask = $prepare.TranscodeAsync()
        while ($transcodeTask.Status -eq 'Started') { Start-Sleep -m 100 }
        $transcodeTask.GetResults()
        Write-Host "Success: $OutputPath created."
    } else {
        Write-Error "Conversion failed for ${inputPath}: $($prepare.FailureReason)"
    }
}

$soundsDir = "e:\anitigravity\dominoes\flutter_app\assets\sounds"
$mp3Files = Get-ChildItem -Path $soundsDir -Filter *.mp3

foreach ($file in $mp3Files) {
    $wavFile = Join-Path $soundsDir ($file.BaseName + ".wav")
    try {
        Convert-Mp3ToWav -InputPath $file.FullName -OutputPath $wavFile
    } catch {
        Write-Error "Failed to convert $($file.Name): $($_.Exception.Message)"
    }
}
