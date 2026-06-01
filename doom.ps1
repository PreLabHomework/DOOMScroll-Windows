param(
    [Parameter(Position=0)] [string]$Command = "help",
    [Parameter(Position=1)] [string]$Arg1,
    [Parameter(Position=2)] [string]$Arg2
)

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigDir = Join-Path $Root "config"
$UrlsFile = Join-Path $ConfigDir "urls.txt"
$EnabledFile = Join-Path $ConfigDir "enabled"
$LogFile = Join-Path $ConfigDir "sessions.log"

function Ensure-Config {
    New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null

    if (!(Test-Path $UrlsFile)) {
@"
https://www.youtube.com/shorts
https://www.instagram.com/reels/
https://www.tiktok.com
https://reddit.com
"@ | Set-Content -Path $UrlsFile -Encoding UTF8
    }
}

function Show-Help {
@"
DOOMScroll Windows

Usage:
  .\doom.ps1 status
  .\doom.ps1 list
  .\doom.ps1 add <url>
  .\doom.ps1 remove <number>
  .\doom.ps1 disable <number>
  .\doom.ps1 enable <number>
  .\doom.ps1 toggle
  .\doom.ps1 on
  .\doom.ps1 off
  .\doom.ps1 log
  .\doom.ps1 stats
  .\doom.ps1 open-test
  .\doom.ps1 close-test
"@
}

function Get-UrlLines {
    if (!(Test-Path $UrlsFile)) { return @() }
    return @(Get-Content $UrlsFile)
}

function Get-ConfiguredUrlCount {
    $count = 0
    foreach ($line in Get-UrlLines) {
        $trimmed = $line.Trim()
        if ($trimmed -ne "" -and !$trimmed.StartsWith("#")) {
            $count++
        }
    }
    return $count
}

function Get-SessionSecondsFromLine($line) {
    if ($line -match "\|\s*([0-9.]+)\s*sec") {
        return [double]$matches[1]
    }

    $parts = $line.Split(",")
    if ($parts.Count -ge 3 -and ($parts[2].Trim() -as [double])) {
        return [double]$parts[2].Trim()
    }

    return 0.0
}

Ensure-Config

switch ($Command.ToLower()) {
    "help" {
        Show-Help
    }

    "status" {
        if (Test-Path $EnabledFile) {
            Write-Host "DOOMScroll is ON."
        } else {
            Write-Host "DOOMScroll is OFF."
        }

        $urlCount = Get-ConfiguredUrlCount
        Write-Host "Enabled URLs: $urlCount"
        Write-Host "Config: $ConfigDir"
    }

    "list" {
        $lines = Get-UrlLines

        if ($lines.Count -eq 0) {
            Write-Host "No URLs configured."
            break
        }

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if (!$line.Trim()) { continue }

            $status = if ($line.Trim().StartsWith("#")) { "disabled" } else { "enabled " }
            $url = $line.TrimStart("#").Trim()
            Write-Host ("{0,2}. [{1}] {2}" -f ($i + 1), $status, $url)
        }
    }

    "add" {
        if (!$Arg1) {
            Write-Host "Missing URL."
            break
        }

        Add-Content -Path $UrlsFile -Value $Arg1
        Write-Host "Added: $Arg1"
    }

    "remove" {
        if (!$Arg1 -or !($Arg1 -as [int])) {
            Write-Host "Give a URL number from list."
            break
        }

        $n = [int]$Arg1 - 1
        $lines = Get-UrlLines

        if ($n -lt 0 -or $n -ge $lines.Count) {
            Write-Host "Invalid number."
            break
        }

        $removed = $lines[$n]
        $new = for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($i -ne $n) { $lines[$i] }
        }

        $new | Set-Content $UrlsFile
        Write-Host "Removed: $removed"
    }

    "disable" {
        if (!$Arg1 -or !($Arg1 -as [int])) {
            Write-Host "Give a URL number from list."
            break
        }

        $n = [int]$Arg1 - 1
        $lines = Get-UrlLines

        if ($n -lt 0 -or $n -ge $lines.Count) {
            Write-Host "Invalid number."
            break
        }

        if (!$lines[$n].Trim().StartsWith("#")) {
            $lines[$n] = "#" + $lines[$n]
        }

        $lines | Set-Content $UrlsFile
        Write-Host "Disabled #$Arg1"
    }

    "enable" {
        if (!$Arg1 -or !($Arg1 -as [int])) {
            Write-Host "Give a URL number from list."
            break
        }

        $n = [int]$Arg1 - 1
        $lines = Get-UrlLines

        if ($n -lt 0 -or $n -ge $lines.Count) {
            Write-Host "Invalid number."
            break
        }

        $lines[$n] = $lines[$n].TrimStart("#").Trim()
        $lines | Set-Content $UrlsFile
        Write-Host "Enabled #$Arg1"
    }

    "toggle" {
        if (Test-Path $EnabledFile) {
            Remove-Item $EnabledFile
            Write-Host "DOOMScroll is OFF."
        } else {
            New-Item -ItemType File -Path $EnabledFile | Out-Null
            Write-Host "DOOMScroll is ON."
        }
    }

    "on" {
        New-Item -ItemType File -Path $EnabledFile -Force | Out-Null
        Write-Host "DOOMScroll is ON."
    }

    "off" {
        Remove-Item $EnabledFile -ErrorAction SilentlyContinue
        Write-Host "DOOMScroll is OFF."
    }

    "log" {
        if (Test-Path $LogFile) {
            Get-Content $LogFile -Tail 20
        } else {
            Write-Host "No sessions logged yet."
        }
    }

    "stats" {
        if (!(Test-Path $LogFile)) {
            Write-Host "No sessions logged yet."
            break
        }

        $seconds = 0.0
        $count = 0

        Get-Content $LogFile | ForEach-Object {
            $sessionSeconds = Get-SessionSecondsFromLine $_
            if ($sessionSeconds -gt 0) {
                $seconds += $sessionSeconds
                $count++
            }
        }

        $minutes = [Math]::Round($seconds / 60, 2)
        $secondsRounded = [Math]::Round($seconds, 2)

        Write-Host "Sessions logged: $count"
        Write-Host "Total doom time: $minutes minutes ($secondsRounded seconds)"
    }

    "open-test" {
        & (Join-Path $Root "scripts\open-media.ps1")
    }

    "close-test" {
        & (Join-Path $Root "scripts\close-media.ps1")
    }

    default {
        Show-Help
    }
}
