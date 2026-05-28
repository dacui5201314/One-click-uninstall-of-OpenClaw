# One-click Uninstall of OpenClaw / OpenClaw 一键卸载工具

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A single-click batch script that **completely removes OpenClaw** (including npm packages, config files, scheduled tasks,
registry entries, startup shortcuts, and AppData residues) from a Windows system.

> **OpenClaw** is an AI agent framework. This tool handles its clean removal when you no longer need it.

---

## Features / 功能

- ✅ **Kill related processes** — terminates Node.js, WeMailNode, and OpenClaw processes
- ✅ **Uninstall npm global package** — automatically detects and removes `openclaw` from npm
- ✅ **Delete config & data directory** — removes `%USERPROFILE%\.openclaw\` (with locked-file fallback via RunOnce)
- ✅ **Remove scheduled tasks** — cleans up `OpenClaw Gateway` and `OpenClaw Daily News` tasks
- ✅ **Clean registry** — removes Run/RunOnce startup entries
- ✅ **Delete startup folder shortcuts** — removes `OpenClaw.lnk` and `OpenClawGateway.lnk`
- ✅ **Clean npm bin residues** — removes CLI shims (`openclaw.cmd`, `acpx.cmd`, etc.)
- ✅ **Scan AppData** — removes `%LOCALAPPDATA%\openclaw` and `%APPDATA%\openclaw`
- ✅ **Full-system residue scan** — searches your user profile for any remaining OpenClaw files
- ✅ **7-point verification** — checks everything was cleaned, shows a clear pass/fail report

---

## How to Use / 使用方法

### Requirements

- Windows 10 or later
- **Run as Administrator** (right-click → "Run as administrator")

### Steps

1. [Download the latest release](https://github.com/dacui5201314/One-click-uninstall-of-OpenClaw/releases) or clone this repo
2. Right-click `OpenClaw卸载工具.bat` → **Run as administrator**
3. Press any key to start cleanup
4. Wait for the verification report — all 7 items should show ✅ **通过** (PASS)
5. Restart your computer if prompted

> ⚠️ If some files are locked (e.g. SQLite WAL files held by a system process), the tool registers a RunOnce cleanup script that runs automatically on your **next Windows login**. Just reboot once.

---

## What It Checks / 验证项目

| # | Check | Description |
|---|-------|-------------|
| 1 | npm global package | `openclaw` removed from `npm list -g` |
| 2 | `.openclaw` directory | Config & data directory deleted |
| 3 | Scheduled tasks | No `OpenClaw*` or `QClaw*` tasks remain |
| 4 | Registry startup entries | Run keys cleaned |
| 5 | Startup folder | No OpenClaw shortcuts |
| 6 | npm CLI shims | No `openclaw.cmd` or `acpx.cmd` |
| 7 | AppData residues | `%LOCALAPPDATA%\openclaw` / `%APPDATA%\openclaw` removed |

---

## Troubleshooting / 故障排除

| Issue | Solution |
|-------|----------|
| "Access denied" | Make sure you right-click → **Run as administrator** |
| "File in use"  | Reboot and run again, or the RunOnce fallback handles it |
| Startup popup about `start-hidden.vbs` | Run this tool — it creates a placeholder to suppress the error |
| `rmdir` errors in PowerShell | Use cmd.exe: `rmdir /s /q %USERPROFILE%\.openclaw` |

---

## Manual Cleanup / 手动清理

If you prefer to do it manually (no script):

**cmd.exe (Admin):**
```cmd
npm uninstall -g openclaw
rmdir /s /q %USERPROFILE%\.openclaw
schtasks /Delete /TN "OpenClaw Gateway" /F
schtasks /Delete /TN "OpenClaw Daily News" /F
```

**PowerShell (Admin):**
```powershell
npm uninstall -g openclaw
Remove-Item -Path "$env:USERPROFILE\.openclaw" -Recurse -Force
Unregister-ScheduledTask -TaskName "OpenClaw Gateway" -Confirm:$false
Unregister-ScheduledTask -TaskName "OpenClaw Daily News" -Confirm:$false
```

---

## License

MIT
