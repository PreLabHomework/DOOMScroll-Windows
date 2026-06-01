$ErrorActionPreference = "Stop"
$ClaudeDir = Join-Path $HOME ".claude"
$SettingsFile = Join-Path $ClaudeDir "settings.json"
$BackupFile = Join-Path $ClaudeDir ("settings.backup-before-doomprompting-uninstall-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss"))

if (!(Test-Path $SettingsFile)) { Write-Host "No Claude settings file found."; exit 0 }
Copy-Item $SettingsFile $BackupFile

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

$settings = ConvertTo-Hashtable (Get-Content $SettingsFile -Raw | ConvertFrom-Json)
if ($settings.ContainsKey("hooks")) {
    foreach ($event in @("UserPromptSubmit", "Stop")) {
        if ($settings["hooks"].ContainsKey($event)) {
            $settings["hooks"][$event] = @($settings["hooks"][$event] | Where-Object {
                $json = ($_ | ConvertTo-Json -Depth 10 -Compress)
                $json -notmatch "DoomPrompting" -and $json -notmatch "open-media\.ps1" -and $json -notmatch "close-media\.ps1"
            })
        }
    }
}

$settings | ConvertTo-Json -Depth 20 | Set-Content $SettingsFile -Encoding UTF8
Write-Host "Removed DoomPrompting Windows hooks."
Write-Host "Backup: $BackupFile"
