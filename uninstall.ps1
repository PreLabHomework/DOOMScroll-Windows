$ErrorActionPreference = "Stop"

$ClaudeDir = Join-Path $HOME ".claude"
$SettingsFile = Join-Path $ClaudeDir "settings.json"
$BackupFile = Join-Path $ClaudeDir ("settings.backup-before-doomscroll-uninstall-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss"))

if (!(Test-Path $SettingsFile)) {
    Write-Host "No Claude settings file found."
    exit 0
}

Copy-Item $SettingsFile $BackupFile

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

$raw = Get-Content $SettingsFile -Raw

if ($raw.Trim().Length -eq 0) {
    Write-Host "Claude settings file is empty. Nothing to remove."
    exit 0
}

$settings = ConvertTo-Hashtable ($raw | ConvertFrom-Json)

if ($settings.ContainsKey("hooks") -and $null -ne $settings["hooks"]) {
    foreach ($event in @("UserPromptSubmit", "Stop", "StopFailure", "SessionEnd")) {
        if ($settings["hooks"].ContainsKey($event) -and $null -ne $settings["hooks"][$event]) {
            $settings["hooks"][$event] = @($settings["hooks"][$event] | Where-Object {
                $json = ($_ | ConvertTo-Json -Depth 10 -Compress)
                $json -notmatch "DOOMScroll" -and
                $json -notmatch "DoomPrompting" -and
                $json -notmatch "open-media\.ps1" -and
                $json -notmatch "close-media\.ps1"
            })
        }
    }
}

$settings | ConvertTo-Json -Depth 20 | Set-Content $SettingsFile -Encoding UTF8

Write-Host "Removed DOOMScroll Windows hooks."
Write-Host "Backup: $BackupFile"
Write-Host "Restart Claude Code."
