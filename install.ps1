$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClaudeDir = Join-Path $HOME ".claude"
$SettingsFile = Join-Path $ClaudeDir "settings.json"
$BackupFile = Join-Path $ClaudeDir ("settings.backup-doomprompting-win-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss"))

New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Root "config") | Out-Null
if (!(Test-Path (Join-Path $Root "config\enabled"))) { New-Item -ItemType File -Path (Join-Path $Root "config\enabled") | Out-Null }
if (!(Test-Path (Join-Path $Root "config\urls.txt"))) {
@"
https://www.youtube.com/shorts
https://www.instagram.com/reels/
https://www.tiktok.com
https://reddit.com
"@ | Set-Content -Path (Join-Path $Root "config\urls.txt") -Encoding UTF8
}

function ConvertTo-Hashtable($obj) {
    if ($null -eq $obj) { return @{} }
    if ($obj -is [System.Collections.IEnumerable] -and $obj -isnot [string] -and $obj -isnot [pscustomobject]) {
        return @($obj | ForEach-Object { ConvertTo-Hashtable $_ })
    }
    if ($obj -is [pscustomobject]) {
        $hash = @{}
        foreach ($p in $obj.PSObject.Properties) { $hash[$p.Name] = ConvertTo-Hashtable $p.Value }
        return $hash
    }
    return $obj
}

if (Test-Path $SettingsFile) {
    Copy-Item $SettingsFile $BackupFile
    $settings = ConvertTo-Hashtable (Get-Content $SettingsFile -Raw | ConvertFrom-Json)
} else {
    $settings = @{}
}

if (!$settings.ContainsKey("hooks")) { $settings["hooks"] = @{} }
foreach ($event in @("UserPromptSubmit", "Stop")) {
    if (!$settings["hooks"].ContainsKey($event) -or $null -eq $settings["hooks"][$event]) { $settings["hooks"][$event] = @() }
}

$openScript = (Join-Path $Root "scripts\open-media.ps1").Replace("\", "\\")
$closeScript = (Join-Path $Root "scripts\close-media.ps1").Replace("\", "\\")
$openCommand = "powershell.exe -ExecutionPolicy Bypass -File `"$openScript`""
$closeCommand = "powershell.exe -ExecutionPolicy Bypass -File `"$closeScript`""

function Remove-DoomHook($arr) {
    return @($arr | Where-Object {
        $json = ($_ | ConvertTo-Json -Depth 10 -Compress)
        $json -notmatch "DoomPrompting" -and $json -notmatch "open-media\.ps1" -and $json -notmatch "close-media\.ps1"
    })
}

$settings["hooks"]["UserPromptSubmit"] = Remove-DoomHook $settings["hooks"]["UserPromptSubmit"]
$settings["hooks"]["Stop"] = Remove-DoomHook $settings["hooks"]["Stop"]

$settings["hooks"]["UserPromptSubmit"] += @{
    matcher = ""
    hooks = @(@{ type = "command"; command = $openCommand })
}
$settings["hooks"]["Stop"] += @{
    matcher = ""
    hooks = @(@{ type = "command"; command = $closeCommand })
}

$settings | ConvertTo-Json -Depth 20 | Set-Content $SettingsFile -Encoding UTF8

Write-Host "Installed DoomPrompting Windows hooks."
Write-Host "Settings: $SettingsFile"
if (Test-Path $BackupFile) { Write-Host "Backup: $BackupFile" }
Write-Host "Restart Claude Code."
