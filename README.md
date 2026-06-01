# DOOMScroll Windows

A Windows PowerShell version of DoomPrompting.

DOOMScroll opens distracting Chrome windows when you submit a Claude Code prompt, then closes them when Claude finishes responding.

This project is a Windows port inspired by the original macOS DoomPrompting project.

## What it does

1. You submit a prompt in Claude Code.
2. Chrome opens distraction windows such as YouTube Shorts, Instagram Reels, TikTok, and Reddit.
3. Claude finishes responding.
4. The distraction windows close automatically.

This version uses a separate temporary Chrome profile so it should not close your normal Chrome tabs.

## Requirements

- Windows 10 or Windows 11
- Google Chrome
- Claude Code
- PowerShell

## Project structure

Your repository should look like this:

```text
DOOMScroll-Windows/
  README.md
  install.ps1
  uninstall.ps1
  doom.ps1
  scripts/
    open-media.ps1
    close-media.ps1
  config/
    urls.txt
    enabled
```

The `enabled` file is intentionally empty. It acts as an on/off flag.

```text
config/enabled exists = DOOMScroll is ON
config/enabled missing = DOOMScroll is OFF
```

## Installation

Clone this repository or download it as a zip.

Open PowerShell in the project folder and run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install.ps1
```

Then restart Claude Code.

The installer adds Claude Code hooks to:

```text
%USERPROFILE%\.claude\settings.json
```

The hooks are:

```text
UserPromptSubmit -> scripts/open-media.ps1
Stop -> scripts/close-media.ps1
```

## Test before using

After installing, test that the media windows open and close correctly:

```powershell
.\doom.ps1 open-test
.\doom.ps1 close-test
```

If the first command opens Chrome windows and the second command closes them, the setup is working.

## Commands

Show all URLs:

```powershell
.\doom.ps1 list
```

Add a new URL:

```powershell
.\doom.ps1 add https://example.com
```

Disable a URL by number:

```powershell
.\doom.ps1 disable 2
```

Re-enable a URL by number:

```powershell
.\doom.ps1 enable 2
```

Remove a URL by number:

```powershell
.\doom.ps1 remove 2
```

Turn DOOMScroll on or off globally:

```powershell
.\doom.ps1 toggle
```

Show recent sessions:

```powershell
.\doom.ps1 log
```

Show total tracked time:

```powershell
.\doom.ps1 stats
```

Manually test opening windows:

```powershell
.\doom.ps1 open-test
```

Manually test closing windows:

```powershell
.\doom.ps1 close-test
```

## Configuration

URLs are stored in:

```text
config/urls.txt
```

Default URLs:

```text
https://www.youtube.com/shorts
https://www.instagram.com/reels/
https://www.tiktok.com
https://reddit.com
```

To disable a URL manually, comment it out with `#`:

```text
#https://reddit.com
```

To re-enable it, remove the `#`.

## Enable or disable

DOOMScroll is enabled when this file exists:

```text
config/enabled
```

Use this command to switch it on or off:

```powershell
.\doom.ps1 toggle
```

You can also manually disable it by deleting:

```text
config/enabled
```

and manually enable it again by recreating that empty file.

## How it works

When you submit a prompt in Claude Code, Claude runs the `UserPromptSubmit` hook. DOOMScroll uses that hook to run:

```text
scripts/open-media.ps1
```

That script opens the URLs from:

```text
config/urls.txt
```

When Claude finishes responding, Claude runs the `Stop` hook. DOOMScroll uses that hook to run:

```text
scripts/close-media.ps1
```

That script closes the Chrome windows created by DOOMScroll.

## Safety note

This project opens Chrome using a separate temporary profile. It is designed to close only the Chrome instance it created, not your regular Chrome session.

Still, test with:

```powershell
.\doom.ps1 open-test
.\doom.ps1 close-test
```

before relying on it.

## Troubleshooting

### PowerShell says scripts are blocked

Run this in the project folder:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Then run the command again.

### Chrome does not open

Make sure Google Chrome is installed.

If Chrome is installed but still does not open, open `scripts/open-media.ps1` and check whether the script can find `chrome.exe`.

### Windows opens the URLs in my normal browser instead of Chrome

Make sure Google Chrome is installed and available as `chrome.exe`.

### Claude Code does not trigger DOOMScroll

Restart Claude Code after running:

```powershell
.\install.ps1
```

Then check that this file exists:

```text
%USERPROFILE%\.claude\settings.json
```

and contains DOOMScroll hook entries.

### The windows open but do not close

Run this manually:

```powershell
.\doom.ps1 close-test
```

If that works manually but not through Claude Code, reinstall the hooks:

```powershell
.\install.ps1
```

Then restart Claude Code.

## Uninstall

Run:

```powershell
.\uninstall.ps1
```

This removes the DOOMScroll hooks from Claude Code settings.

It does not delete your repository folder.

## Credits

Inspired by the original DoomPrompting project by JerryWu0430.

This version is a Windows PowerShell port.
