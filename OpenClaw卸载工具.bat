@echo off
chcp 65001 >nul

set "PSFILE=%TEMP%\oc_cleanup.ps1"
powershell -NoProfile -Command "Get-Content -Path '%~f0' | Select-Object -Skip 20 | Set-Content -Path '%PSFILE%' -Encoding UTF8"
if %errorLevel% neq 0 (
    echo [错误] 无法创建临时文件
    pause
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PSFILE%" "%~f0"
set "EXITCODE=%errorLevel%"
del "%PSFILE%" >nul 2>&1
echo.
echo 按任意键退出...
pause >nul
exit /b %EXITCODE%


:: 以下为 PowerShell 脚本主体，请勿修改
param($OriginalBatPath)

#requires -RunAsAdministrator

$SelfPath = $MyInvocation.MyCommand.Path

Clear-Host
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  OpenClaw 彻底卸载工具" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "按任意键开始清理，或关闭窗口取消..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Write-Host ""
Write-Host ">>> [1/8] 终止相关进程..." -ForegroundColor Yellow
@("node", "WeMailNode", "WeMailNode_x64", "openclaw") | ForEach-Object {
    Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force
}
Start-Sleep -Seconds 2
Write-Host "  完成" -ForegroundColor Green

Write-Host ">>> [2/8] 卸载 npm 全局包..." -ForegroundColor Yellow
$npm = Get-Command npm -ErrorAction SilentlyContinue
if ($npm) {
    npm uninstall -g openclaw 2>$null
    Write-Host "  完成" -ForegroundColor Green
} else {
    Write-Host "  未检测到 npm，跳过" -ForegroundColor Gray
}

Write-Host ">>> [3/8] 删除 .openclaw 配置目录..." -ForegroundColor Yellow
$ocDir = "$env:USERPROFILE\.openclaw"
if (Test-Path $ocDir) {
    try {
        takeown /f $ocDir /r /d y 2>&1 | Out-Null
        icacls $ocDir /grant Administrators:F /t /q 2>&1 | Out-Null
        Remove-Item -Path $ocDir -Recurse -Force -ErrorAction Stop
        Write-Host "  删除成功" -ForegroundColor Green
    } catch {
        Write-Host "  部分文件被锁定，注册开机清理..." -ForegroundColor Yellow
        $cmd = "cmd.exe /c rmdir /s /q `"$ocDir`""
        [Microsoft.Win32.Registry]::SetValue("HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce", "CleanOC", $cmd, [Microsoft.Win32.RegistryValueKind]::String)
        Write-Host "  已注册，下次登录自动删除" -ForegroundColor Green
    }
} else {
    Write-Host "  目录不存在，跳过" -ForegroundColor Gray
}

Write-Host ">>> [4/8] 删除计划任务..." -ForegroundColor Yellow
@("OpenClaw Gateway", "OpenClaw Daily News") | ForEach-Object {
    $existing = Get-ScheduledTask -TaskName $_ -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $_ -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "  已删除: $_" -ForegroundColor Green
    } else {
        Write-Host "  - $_ 不存在" -ForegroundColor Gray
    }
}

Write-Host ">>> [5/8] 清理注册表..." -ForegroundColor Yellow
$regPaths = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
)
$regValues = @("OpenClaw", "OpenClawGateway")
foreach ($path in $regPaths) {
    foreach ($val in $regValues) {
        $existing = Get-ItemProperty -Path $path -Name $val -ErrorAction SilentlyContinue
        if ($existing) { Remove-ItemProperty -Path $path -Name $val -ErrorAction SilentlyContinue }
    }
}
Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name "CleanOC" -ErrorAction SilentlyContinue
Write-Host "  完成" -ForegroundColor Green

Write-Host ">>> [6/8] 清理启动文件夹..." -ForegroundColor Yellow
$startup = [Environment]::GetFolderPath("Startup")
$startupAll = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
@("OpenClaw.lnk", "OpenClawGateway.lnk") | ForEach-Object {
    $lnk = $_
    @($startup, $startupAll) | ForEach-Object {
        $p = Join-Path $_ $lnk
        if (Test-Path $p) { Remove-Item -Path $p -Force -ErrorAction SilentlyContinue }
    }
}
Write-Host "  完成" -ForegroundColor Green

Write-Host ">>> [7/8] 清理 npm 全局残留..." -ForegroundColor Yellow
if ($npm) {
    $npmRoot = npm root -g 2>$null
    if ($npmRoot -and $npmRoot.Trim().Length -gt 0) {
        $npmRoot = $npmRoot.Trim()
        if (Test-Path "$npmRoot\openclaw") { Remove-Item -Path "$npmRoot\openclaw" -Recurse -Force -ErrorAction SilentlyContinue }
    }
    $npmBin = npm bin -g 2>$null
    if ($npmBin -and $npmBin.Trim().Length -gt 0) {
        $npmBin = $npmBin.Trim()
        @("openclaw.cmd", "openclaw", "openclaw.ps1", "acpx.cmd", "acpx") | ForEach-Object {
            $p = "$npmBin\$_"
            if (Test-Path $p) { Remove-Item -Path $p -Force -ErrorAction SilentlyContinue }
        }
    }
    Write-Host "  完成" -ForegroundColor Green
} else {
    Write-Host "  跳过" -ForegroundColor Gray
}

Write-Host ">>> [8/8] 清理 AppData 及残留扫描..." -ForegroundColor Yellow
@("$env:LOCALAPPDATA\openclaw", "$env:APPDATA\openclaw") | ForEach-Object {
    if (Test-Path $_) { Remove-Item -Path $_ -Recurse -Force -ErrorAction SilentlyContinue }
}
Write-Host "  正在全局扫描残留..." -ForegroundColor Yellow
$residues = Get-ChildItem -Path $env:USERPROFILE -Filter "*openclaw*" -Recurse -ErrorAction SilentlyContinue | Where-Object {
    $_.FullName -ne $SelfPath -and $_.FullName -ne $OriginalBatPath -and $_.FullName -notlike "*\AppData\Local\Temp\*"
}
$deleted = 0
foreach ($item in $residues) {
    try { Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop; $deleted++ } catch {}
}
Write-Host "  完成（删除 $deleted 个残留项）" -ForegroundColor Green

# Verification
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  ★ 验证：7 项检查" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$allClean = $true

$v1 = "通过"
if ($npm) { $list = npm list -g openclaw 2>$null; if ($list -match "openclaw") { $v1 = "残留"; $allClean = $false } }
Write-Host "  [1/7] npm 全局包 ........ $v1" -ForegroundColor $(if ($v1 -eq "通过") { "Green" } else { "Red" })

$v2 = if (Test-Path "$env:USERPROFILE\.openclaw") { $allClean = $false; "残留" } else { "通过" }
Write-Host "  [2/7] .openclaw 目录 .... $v2" -ForegroundColor $(if ($v2 -eq "通过") { "Green" } else { "Red" })

$v3 = "通过"
$existingTasks = Get-ScheduledTask -TaskName "OpenClaw*", "QClaw*" -ErrorAction SilentlyContinue
if ($existingTasks) { $v3 = "残留"; $allClean = $false }
Write-Host "  [3/7] 计划任务 ......... $v3" -ForegroundColor $(if ($v3 -eq "通过") { "Green" } else { "Red" })

$v4 = "通过"
$regItems = @(
    @{P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"; N="OpenClaw"},
    @{P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"; N="OpenClawGateway"},
    @{P="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; N="OpenClaw"},
    @{P="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; N="OpenClawGateway"}
)
foreach ($r in $regItems) {
    $val = Get-ItemProperty -Path $r.P -Name $r.N -ErrorAction SilentlyContinue
    if ($val -and $val.$($r.N)) { $v4 = "残留"; $allClean = $false }
}
Write-Host "  [4/7] 注册表启动项 ..... $v4" -ForegroundColor $(if ($v4 -eq "通过") { "Green" } else { "Red" })

$v5 = "通过"
@("OpenClaw.lnk", "OpenClawGateway.lnk") | ForEach-Object {
    if (Test-Path (Join-Path $startup $_)) { $v5 = "残留"; $allClean = $false }
    if (Test-Path (Join-Path $startupAll $_)) { $v5 = "残留"; $allClean = $false }
}
Write-Host "  [5/7] 启动文件夹 ....... $v5" -ForegroundColor $(if ($v5 -eq "通过") { "Green" } else { "Red" })

$v6 = "通过"
if ($npmBin -and $npmBin.Trim().Length -gt 0) {
    $npmBin = $npmBin.Trim()
    @("openclaw.cmd", "openclaw", "acpx.cmd") | ForEach-Object {
        $p = "$npmBin\$_"
        if (Test-Path $p) { $v6 = "残留"; $allClean = $false }
    }
}
Write-Host "  [6/7] npm 命令残留 ...... $v6" -ForegroundColor $(if ($v6 -eq "通过") { "Green" } else { "Red" })

$v7 = "通过"
if (Test-Path "$env:LOCALAPPDATA\openclaw") { $v7 = "残留"; $allClean = $false }
if (Test-Path "$env:APPDATA\openclaw") { $v7 = "残留"; $allClean = $false }
Write-Host "  [7/7] AppData 残留 ...... $v7" -ForegroundColor $(if ($v7 -eq "通过") { "Green" } else { "Red" })

Write-Host ""
if ($allClean) {
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  OpenClaw 已彻底卸载！" -ForegroundColor Green
    Write-Host "  全部 7 项通过，无任何残留。" -ForegroundColor Green
    Write-Host "  建议重启电脑完成最终清理。" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
} else {
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "  仍有残留项，请重启电脑后重试。" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "  手动清理（管理员 PowerShell）：" -ForegroundColor Yellow
    Write-Host "  Remove-Item -Path `"$env:USERPROFILE\.openclaw`" -Recurse -Force" -ForegroundColor Gray
}
