$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ConfigDir = Join-Path $RootDir "config"
$RuntimeDir = Join-Path $ConfigDir "runtime"
$PidFile = Join-Path $RuntimeDir "chrome-pids.txt"
$StartFile = Join-Path $RuntimeDir "session-start.txt"
$SessionsLog = Join-Path $ConfigDir "sessions.log"
$DebugLog = Join-Path $RuntimeDir "debug.log"

New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null
Add-Content $DebugLog "$(Get-Date -Format o) close-media started"

if (Test-Path $StartFile) {
    try {
        $start = Get-Date (Get-Content $StartFile)
        $end = Get-Date
        $duration = [int]($end - $start).TotalSeconds
        Add-Content $SessionsLog "$($start.ToString("o")),$($end.ToString("o")),$duration"
    } catch {
        Add-Content $DebugLog "$(Get-Date -Format o) failed to log session"
    }
}

# First close tracked PIDs
if (Test-Path $PidFile) {
    Get-Content $PidFile | ForEach-Object {
        try {
            Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue
            Add-Content $DebugLog "$(Get-Date -Format o) closed tracked PID $_"
        } catch {
            Add-Content $DebugLog "$(Get-Date -Format o) failed to close tracked PID $_"
        }
    }

    Remove-Item $PidFile -ErrorAction SilentlyContinue
}

# Then close any leftover Chrome process using one of our temporary profiles
try {
    Get-CimInstance Win32_Process |
    Where-Object {
        $_.Name -eq "chrome.exe" -and
        $_.CommandLine -like "*chrome-profile-*"
    } |
    ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        Add-Content $DebugLog "$(Get-Date -Format o) closed leftover chrome PID $($_.ProcessId)"
    }
} catch {
    Add-Content $DebugLog "$(Get-Date -Format o) failed WMI leftover cleanup"
}

Start-Sleep -Milliseconds 500

# Clean temporary Chrome profiles
Get-ChildItem $RuntimeDir -Directory -Filter "chrome-profile-*" -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
}

Remove-Item $StartFile -ErrorAction SilentlyContinue