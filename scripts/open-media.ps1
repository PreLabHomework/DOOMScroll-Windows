$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ConfigDir = Join-Path $RootDir "config"
$UrlsFile = Join-Path $ConfigDir "urls.txt"
$EnabledFile = Join-Path $ConfigDir "enabled"
$RuntimeDir = Join-Path $ConfigDir "runtime"
$PidFile = Join-Path $RuntimeDir "chrome-pids.txt"
$StartFile = Join-Path $RuntimeDir "session-start.txt"
$DebugLog = Join-Path $RuntimeDir "debug.log"

if (!(Test-Path $EnabledFile)) {
    exit
}

if (!(Test-Path $UrlsFile)) {
    exit
}

New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null

Remove-Item $PidFile -ErrorAction SilentlyContinue
Get-Date -Format "o" | Set-Content $StartFile
Add-Content $DebugLog "$(Get-Date -Format o) open-media started"

$urls = Get-Content $UrlsFile | Where-Object {
    $line = $_.Trim()
    $line -ne "" -and !$line.StartsWith("#")
}

if ($urls.Count -eq 0) {
    Add-Content $DebugLog "$(Get-Date -Format o) no URLs found"
    exit
}

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

Add-Type -AssemblyName System.Windows.Forms

$screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea

$halfWidth = [int]($screen.Width / 2)
$halfHeight = [int]($screen.Height / 2)

$positions = @(
    @{ X = $screen.Left; Y = $screen.Top; Width = $halfWidth; Height = $halfHeight },
    @{ X = $screen.Left + $halfWidth; Y = $screen.Top; Width = $halfWidth; Height = $halfHeight },
    @{ X = $screen.Left; Y = $screen.Top + $halfHeight; Width = $halfWidth; Height = $halfHeight },
    @{ X = $screen.Left + $halfWidth; Y = $screen.Top + $halfHeight; Width = $halfWidth; Height = $halfHeight }
)

$chromePaths = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe",
    "$env:LocalAppData\Google\Chrome\Application\chrome.exe"
)

$chrome = $chromePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if (!$chrome) {
    Add-Content $DebugLog "$(Get-Date -Format o) could not find chrome.exe"
    exit 1
}

$i = 0

foreach ($url in $urls) {
    $pos = $positions[$i % 4]
    $profileDir = Join-Path $RuntimeDir "chrome-profile-$i"

    Remove-Item $profileDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $profileDir | Out-Null

    $args = @(
        "--new-window",
        "--user-data-dir=$profileDir",
        "--no-first-run",
        "--no-default-browser-check",
        "--disable-sync",
        "--disable-features=SigninInterception,ChromeWhatsNewUI,OptimizationGuideModelDownloading",
        "--disable-popup-blocking",
        "--window-size=$($pos.Width),$($pos.Height)",
        "--window-position=$($pos.X),$($pos.Y)",
        $url
    )

    Add-Content $DebugLog "$(Get-Date -Format o) opening $url at $($pos.X),$($pos.Y)"

    $proc = Start-Process $chrome -ArgumentList $args -PassThru
    Add-Content $PidFile $proc.Id

    Start-Sleep -Milliseconds 1200

    try {
        $proc.Refresh()

        $attempts = 0
        while ($proc.MainWindowHandle -eq 0 -and $attempts -lt 30) {
            Start-Sleep -Milliseconds 200
            $proc.Refresh()
            $attempts++
        }

        if ($proc.MainWindowHandle -ne 0) {
            [Win32]::ShowWindow($proc.MainWindowHandle, 9) | Out-Null
            [Win32]::MoveWindow(
                $proc.MainWindowHandle,
                $pos.X,
                $pos.Y,
                $pos.Width,
                $pos.Height,
                $true
            ) | Out-Null
        }
    } catch {
        Add-Content $DebugLog "$(Get-Date -Format o) move failed for $url"
    }

    $i++
}