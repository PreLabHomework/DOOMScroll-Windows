$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClaudeDir = Join-Path $HOME ".claude"
$SettingsFile = Join-Path $ClaudeDir "settings.json"
$BackupFile = Join-Path $ClaudeDir ("settings.backup-doomscroll-win-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss"))

New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Root "config") | Out-Null

$EnabledFile = Join-Path $Root "config\enabled"
$UrlsFile = Join-Path $Root "config\urls.txt"

if (!(Test-Path $EnabledFile)) {
    New-Item -ItemType File -Path $EnabledFile | Out-Null
}

if (!(Test-Path $UrlsFile)) {
@"
https://www.youtube.com/shorts
https://www.instagram.com/reels/
https://www.tiktok.com
https://reddit.com
"@ | Set-Content -Path $UrlsFile -Encoding UTF8
}

function ConvertTo-Hashtable($obj) {
    if ($null -eq $obj) { return @{} }

    if ($obj -is [System.Collections.IDictionary]) {
        $hash = @{}
        foreach ($key in $obj.Keys) {
            $hash[$key] = ConvertTo-Hashtable $obj[$key]
        }
        return $hash
    }

    if ($obj -is [System.Collections.IEnumerable] -and $obj -isnot [string] -and $obj -isnot [pscustomobject]) {
        return @($obj | ForEach-Object { ConvertTo-Hashtable $_ })
    }

    if ($obj -is [pscustomobject]) {
        $hash = @{}
        foreach ($p in $obj.PSObject.Properties) {
            $hash[$p.Name] = ConvertTo-Hashtable $p.Value
        }
        return $hash
    }

    return $obj
}

if (Test-Path $SettingsFile) {
    Copy-Item $SettingsFile $BackupFile
    $raw = Get-Content $SettingsFile -Raw

    if ($raw.Trim().Length -eq 0) {
        $settings = @{}
    } else {
        $settings = ConvertTo-Hashtable ($raw | ConvertFrom-Json)
    }
} else {
    $settings = @{}
}

if (!$settings.ContainsKey("hooks") -or $null -eq $settings["hooks"]) {
    $settings["hooks"] = @{}
}

$openScript = Join-Path $Root "scripts\open-media.ps1"
$closeScript = Join-Path $Root "scripts\close-media.ps1"

if (!(Test-Path $openScript)) {
    throw "Missing script: $openScript"
}

if (!(Test-Path $closeScript)) {
    throw "Missing script: $closeScript"
}

$openCommand = "powershell.exe -ExecutionPolicy Bypass -File `"$openScript`""
$closeCommand = "powershell.exe -ExecutionPolicy Bypass -File `"$closeScript`""

function Remove-DoomHook($arr) {
    return @($arr | Where-Object {
        $json = ($_ | ConvertTo-Json -Depth 10 -Compress)
        $json -notmatch "DOOMScroll" -and
        $json -notmatch "DoomPrompting" -and
        $json -notmatch "open-media\.ps1" -and
        $json -notmatch "close-media\.ps1"
    })
}

function New-ClaudeCommandHook($command) {
    return [ordered]@{
        matcher = ""
        hooks = @(
            [ordered]@{
                type = "command"
                command = $command
            }
        )
    }
}

$eventsToClean = @("UserPromptSubmit", "Stop", "StopFailure", "SessionEnd")

foreach ($event in $eventsToClean) {
    if (!$settings["hooks"].ContainsKey($event) -or $null -eq $settings["hooks"][$event]) {
        $settings["hooks"][$event] = @()
    }

    $settings["hooks"][$event] = @(Remove-DoomHook $settings["hooks"][$event])
}

$openHook = New-ClaudeCommandHook $openCommand
$closeHook = New-ClaudeCommandHook $closeCommand

# Claude requires each hook event to be an array of matcher objects.
# The @(... + @($hook)) pattern prevents PowerShell from collapsing a single hook into a plain object.
$settings["hooks"]["UserPromptSubmit"] = @(@($settings["hooks"]["UserPromptSubmit"]) + @($openHook))

foreach ($event in @("Stop", "StopFailure", "SessionEnd")) {
    $settings["hooks"][$event] = @(@($settings["hooks"][$event]) + @($closeHook))
}

$settings | ConvertTo-Json -Depth 20 | Set-Content $SettingsFile -Encoding UTF8

Write-Host "Installed DOOMScroll Windows hooks."
Write-Host "Settings: $SettingsFile"
if (Test-Path $BackupFile) {
    Write-Host "Backup: $BackupFile"
}
Write-Host "Installed hooks: UserPromptSubmit, Stop, StopFailure, SessionEnd"
Write-Host "Restart Claude Code."
