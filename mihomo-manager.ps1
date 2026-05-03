<#
.SYNOPSIS
    Mihomo 裸核控制脚本 (支持交互菜单 + 命令行参数，可手动提权)

.DESCRIPTION
    用于管理 Mihomo 代理核心的 PowerShell 脚本，支持启动、停止、重启、状态查看、配置重载、
    一键开关系统代理，并提供手动提升至管理员权限的功能。

.PARAMETER Action
    要执行的操作: start, stop, restart, status, reload, proxy-on, proxy-off, admin-start, elevate, help
    如果不提供参数，将进入交互菜单模式。

.EXAMPLE
    .\mihomo-manager.ps1
    进入交互菜单模式

.EXAMPLE
    .\mihomo-manager.ps1 proxy-on
    一键开启系统代理（指向 Mihomo 代理端口）

.EXAMPLE
    .\mihomo-manager.ps1 elevate
    将当前脚本提升为管理员权限并重新运行

.EXAMPLE
    .\mihomo-manager.ps1 admin-start
    以管理员权限启动 Mihomo（仅进程，不提升脚本）

.LINK
    https://github.com/xiongtee/mihomo-manager
#>

param(
    [Parameter(Position = 0)]
    [string]$Action = ""
)

# 设置控制台编码为 UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 有效的操作列表
$ValidActions = @("start", "stop", "restart", "status", "reload", "proxy-on", "proxy-off", "admin-start", "elevate", "help", "")

# ====================== 配置区域 ======================
$CorePath   = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$ExeName    = "mihomo-windows-amd64.exe"
$ConfigFile = "mihomo.yaml"
$ApiHost    = "127.0.0.1"
$ApiPort    = 9090
$ProxyHost  = "127.0.0.1"
$ProxyPort  = 7890

$FullExe     = Join-Path $CorePath $ExeName
$FullConfig  = Join-Path $CorePath $ConfigFile
$ProcessName = [IO.Path]::GetFileNameWithoutExtension($ExeName)
$ApiUrl      = "http://${ApiHost}:${ApiPort}"

function Get-MihomoSecretFromConfig {
    param([string]$ConfigPath)
    if (-not (Test-Path -LiteralPath $ConfigPath)) { return $null }
    try {
        foreach ($line in (Get-Content -LiteralPath $ConfigPath -Encoding UTF8 -ErrorAction Stop)) {
            if ($line -match "^\s*#") { continue }
            if ($line -match "^\s*secret\s*:\s*(.*?)\s*(?:\s+#.*)?$") {
                $value = $Matches[1].Trim()
                if ($value.StartsWith("'") -and $value.EndsWith("'") -and $value.Length -ge 2) {
                    $value = $value.Substring(1, $value.Length - 2)
                } elseif ($value.StartsWith('"') -and $value.EndsWith('"') -and $value.Length -ge 2) {
                    $value = $value.Substring(1, $value.Length - 2)
                }
                if ($value) { return $value }
            }
        }
    } catch { return $null }
    return $null
}

function Format-SecretForDisplay {
    param([AllowNull()][string]$Value, [ValidateSet("mask","full")][string]$Mode = "mask")
    if ([string]::IsNullOrEmpty($Value)) { return "<empty>" }
    if ($Mode -eq "full") { return $Value }
    if ($Value.Length -le 4) { return ("*" * $Value.Length) }
    return ($Value.Substring(0,2) + ("*" * ($Value.Length - 4)) + $Value.Substring($Value.Length - 2, 2))
}

# Secret 获取优先级: 环境变量 > mihomo.yaml > 默认值
$SecretDefault = "123456"
$SecretSource  = "default"
$Secret = $SecretDefault
if ($env:MIHOMO_SECRET) {
    $Secret = $env:MIHOMO_SECRET
    $SecretSource = "env"
} else {
    $SecretFromFile = Get-MihomoSecretFromConfig -ConfigPath $FullConfig
    if ($SecretFromFile) {
        $Secret = $SecretFromFile
        $SecretSource = "config"
    }
}

$SecretDebugMode = if ($env:MIHOMO_SECRET_DEBUG) { $env:MIHOMO_SECRET_DEBUG.Trim().ToLowerInvariant() } else { "" }
if ($SecretDebugMode -notin @("","0","false","off")) {
    $mode = if ($SecretDebugMode -eq "full") { "full" } else { "mask" }
    Write-Host ("[debug] Secret source: {0}, secret: {1}, config: {2}, exists: {3}" -f $SecretSource,
        (Format-SecretForDisplay -Value $Secret -Mode $mode), $FullConfig, (Test-Path $FullConfig)) -ForegroundColor DarkGray
}
# =====================================================

$Headers = if ($Secret) { @{ Authorization = "Bearer $Secret" } } else { @{} }

# ====================== 系统代理控制 ======================
function Get-SystemProxyStatus {
    try {
        $proxyEnable = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -ErrorAction Stop).ProxyEnable
        $proxyServer = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyServer -ErrorAction Stop).ProxyServer
        return ($proxyEnable -eq 1 -and $proxyServer -eq "$ProxyHost`:$ProxyPort")
    } catch { return $false }
}

function Enable-SystemProxy {
    Write-Host "正在开启系统代理..." -ForegroundColor Cyan
    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 1 -Type DWord
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyServer -Value "$ProxyHost`:$ProxyPort"
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyOverride -Value "<local>"
        Write-Host "系统代理已开启 → $ProxyHost`:$ProxyPort" -ForegroundColor Green
    } catch {
        Write-Host "开启失败: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Disable-SystemProxy {
    Write-Host "正在关闭系统代理..." -ForegroundColor Cyan
    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 0 -Type DWord
        Write-Host "系统代理已关闭" -ForegroundColor Green
    } catch {
        Write-Host "关闭失败: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ====================== 工具函数 ======================
function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Wait-ForCondition {
    param([scriptblock]$Condition, [int]$TimeoutSeconds=10, [int]$IntervalMs=300)
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        if (& $Condition) { $stopwatch.Stop(); return $true }
        Start-Sleep -Milliseconds $IntervalMs
    }
    $stopwatch.Stop(); return $false
}

function Get-MihomoProcess {
    Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
}

function Test-Api {
    try {
        Invoke-RestMethod "$ApiUrl/version" -Headers $Headers -TimeoutSec 5 -ErrorAction Stop | Out-Null
        return $true
    } catch { return $false }
}

function Test-Config {
    if (-not (Test-Path $FullConfig)) {
        Write-Host "配置文件不存在: $FullConfig" -ForegroundColor Red; return $false
    }
    if (-not (Test-Path $FullExe)) {
        Write-Host "可执行文件不存在: $FullExe" -ForegroundColor Red; return $false
    }
    try {
        $result = & $FullExe -t -d $CorePath -f $ConfigFile 2>&1
        if ($LASTEXITCODE -eq 0) { return $true }
        else {
            Write-Host "配置文件验证失败:" -ForegroundColor Red
            Write-Host $result -ForegroundColor Yellow; return $false
        }
    } catch {
        Write-Host "配置验证出错: $($_.Exception.Message)" -ForegroundColor Red; return $false
    }
}

function Show-Help {
    Write-Host @"

Mihomo Manager - 使用说明
========================

用法: .\mihomo-manager.ps1 [命令]

命令:
  start        启动 Mihomo
  stop         停止 Mihomo
  restart      重启 Mihomo
  status       查看运行状态
  reload       重载配置文件
  proxy-on     一键开启系统代理
  proxy-off    一键关闭系统代理
  admin-start  以管理员权限启动 Mihomo (进程)
  elevate      提升当前脚本为管理员权限
  help         显示此帮助信息

示例:
  .\mihomo-manager.ps1 start
  .\mihomo-manager.ps1 status
  .\mihomo-manager.ps1 proxy-on
  .\mihomo-manager.ps1 elevate
  .\mihomo-manager.ps1 admin-start

环境变量:
  MIHOMO_SECRET       设置 API 密钥 (可选)
  MIHOMO_SECRET_DEBUG 输出当前 Secret 获取结果 (可选): 1=mask, full=full

配置文件位置: $FullConfig

Secret 优先级: MIHOMO_SECRET > mihomo.yaml 的 secret > 默认值

"@ -ForegroundColor Cyan
}

# ====================== 权限提升函数 ======================
function Invoke-ElevateScript {
    Write-Host "正在以管理员身份重新启动脚本..." -ForegroundColor Cyan
    $argList = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$PSCommandPath`""
    )
    if ($Action) {
        $argList += $Action
    }
    Start-Process PowerShell -Verb RunAs -ArgumentList $argList
    exit
}

# ====================== 核心操作函数 ======================
function Start-Mihomo {
    param([switch]$RunAsAdmin)
    if (Get-MihomoProcess) {
        Write-Host "Mihomo 已经在运行 (PID $((Get-MihomoProcess).Id))" -ForegroundColor Yellow
        return
    }
    Write-Host "正在验证配置文件..." -ForegroundColor Cyan
    if (-not (Test-Config)) { return }

    $startArgs = @{
        FilePath         = $FullExe
        ArgumentList     = "-d", ".", "-f", $ConfigFile
        WorkingDirectory = $CorePath
        WindowStyle      = 'Hidden'
    }
    if ($RunAsAdmin) {
        if (Test-IsAdministrator) {
            Write-Host "当前已是管理员，直接启动..." -ForegroundColor Cyan
            Start-Process @startArgs
        } else {
            Write-Host "正在请求管理员权限以启动 Mihomo..." -ForegroundColor Cyan
            Start-Process @startArgs -Verb RunAs
        }
    } else {
        Write-Host "正在启动 Mihomo 裸核..." -ForegroundColor Cyan
        Start-Process @startArgs
    }

    $started = Wait-ForCondition -Condition { Get-MihomoProcess } -TimeoutSeconds 8 -IntervalMs 300
    if ($started) {
        $proc = Get-MihomoProcess
        Write-Host "启动成功！PID: $($proc.Id)" -ForegroundColor Green
        Write-Host "等待 API 就绪..." -ForegroundColor Cyan
        $apiReady = Wait-ForCondition -Condition { Test-Api } -TimeoutSeconds 15 -IntervalMs 1000
        if ($apiReady) {
            Write-Host "API 已就绪 → $ApiUrl" -ForegroundColor Green
        } else {
            Write-Host "API 未能在预期时间内就绪，请检查配置" -ForegroundColor Yellow
        }
    } else {
        Write-Host "启动失败！请检查路径和配置文件" -ForegroundColor Red
    }
}

function Stop-Mihomo {
    $proc = Get-MihomoProcess
    if (-not $proc) {
        Write-Host "Mihomo 当前未运行" -ForegroundColor Yellow; return
    }
    Write-Host "正在停止 Mihomo (PID $($proc.Id))..." -ForegroundColor Cyan
    try {
        Stop-Process -Id $proc.Id -Force -ErrorAction Stop
        $stopped = Wait-ForCondition -Condition { -not (Get-MihomoProcess) } -TimeoutSeconds 5 -IntervalMs 200
        if ($stopped) {
            Write-Host "已停止" -ForegroundColor Green
        } else {
            Write-Host "进程可能未完全退出" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "停止失败: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Restart-Mihomo {
    Write-Host "正在重启 Mihomo..." -ForegroundColor Cyan
    Stop-Mihomo
    Start-Sleep -Seconds 2
    Start-Mihomo
}

function Get-MihomoStatus {
    $proc = Get-MihomoProcess
    if ($proc) {
        $apiStatus = if (Test-Api) { "正常" } else { "不可达" }
        $uptime = (Get-Date) - $proc.StartTime
        $uptimeStr = "{0}天 {1}小时 {2}分钟" -f $uptime.Days, $uptime.Hours, $uptime.Minutes
        Write-Host ""
        Write-Host "Mihomo 正在运行" -ForegroundColor Green
        Write-Host "  PID        : $($proc.Id)"
        Write-Host "  启动时间   : $($proc.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))"
        Write-Host "  运行时长   : $uptimeStr"
        Write-Host "  内存占用   : $([math]::Round($proc.WorkingSet64 / 1MB, 2)) MB"
        Write-Host "  API 地址   : $ApiUrl"
        Write-Host "  API 状态   : $apiStatus"
        Write-Host "  配置文件   : $FullConfig"
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "Mihomo 未运行" -ForegroundColor Red
        Write-Host "  配置文件   : $FullConfig"
        Write-Host "  可执行文件 : $FullExe"
        Write-Host ""
    }
}

function Invoke-ConfigReload {
    if (-not (Test-Api)) {
        Write-Host "API 不可达，请先启动核心" -ForegroundColor Red; return
    }
    Write-Host "正在重载配置文件..." -ForegroundColor Cyan
    try {
        $body = @{} | ConvertTo-Json -Compress
        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
        Invoke-RestMethod "$ApiUrl/configs?force=true" -Method Put -Headers $Headers -Body $bodyBytes -ContentType "application/json; charset=utf-8" -TimeoutSec 10 | Out-Null
        Write-Host "配置重载成功！" -ForegroundColor Green
    } catch {
        Write-Host "重载失败: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ====================== 主逻辑 ======================
if ($Action) {
    $normalizedAction = $Action.ToLower()
    if ($normalizedAction -notin $ValidActions) {
        Write-Host "错误: 未知命令 '$Action'" -ForegroundColor Red
        Write-Host ""
        Show-Help
        exit 1
    }
    switch ($normalizedAction) {
        "start"       { Start-Mihomo }
        "stop"        { Stop-Mihomo }
        "restart"     { Restart-Mihomo }
        "status"      { Get-MihomoStatus }
        "reload"      { Invoke-ConfigReload }
        "proxy-on"    { Enable-SystemProxy }
        "proxy-off"   { Disable-SystemProxy }
        "admin-start" { Start-Mihomo -RunAsAdmin }
        "elevate"     { Invoke-ElevateScript }
        "help"        { Show-Help }
    }
} else {
    # 交互菜单模式
    while ($true) {
        Clear-Host
        Write-Host "===========================================" -ForegroundColor Cyan
        Write-Host "        Mihomo 裸核控制面板" -ForegroundColor White
        Write-Host "===========================================" -ForegroundColor Cyan
        Write-Host ""

        $proc = Get-MihomoProcess
        if ($proc) {
            Write-Host "  当前状态: " -NoNewline
            Write-Host "运行中 (PID $($proc.Id))" -ForegroundColor Green
        } else {
            Write-Host "  当前状态: " -NoNewline
            Write-Host "未运行" -ForegroundColor Red
        }

        $proxyStatus = Get-SystemProxyStatus
        Write-Host "  系统代理: " -NoNewline
        if ($proxyStatus) {
            Write-Host "开启 ($ProxyHost`:$ProxyPort)" -ForegroundColor Green
        } else {
            Write-Host "关闭" -ForegroundColor DarkGray
        }

        $isAdmin = Test-IsAdministrator
        Write-Host "  脚本权限: " -NoNewline
        if ($isAdmin) { Write-Host "管理员" -ForegroundColor Green } else { Write-Host "普通用户" -ForegroundColor DarkGray }

        Write-Host ""
        Write-Host "  [1] 启动 Mihomo"
        Write-Host "  [2] 停止 Mihomo"
        Write-Host "  [3] 重启 Mihomo"
        Write-Host "  [4] 查看状态"
        Write-Host "  [5] 重载配置"
        Write-Host "  [6] 验证配置"
        Write-Host "  [7] 帮助信息"
        Write-Host "  [8] 切换系统代理"
        Write-Host "  [9] 管理员启动 Mihomo"
        Write-Host "  [0] 获取管理员权限 (提升脚本)" -ForegroundColor DarkCyan
        Write-Host ""
        Write-Host "  [Q] 退出" -ForegroundColor Gray
        Write-Host ""

        $choice = Read-Host "请选择操作"
        switch ($choice.ToUpper()) {
            "1" { Start-Mihomo; Read-Host "`n按回车键继续..." }
            "2" { Stop-Mihomo; Read-Host "`n按回车键继续..." }
            "3" { Restart-Mihomo; Read-Host "`n按回车键继续..." }
            "4" { Get-MihomoStatus; Read-Host "`n按回车键继续..." }
            "5" { Invoke-ConfigReload; Read-Host "`n按回车键继续..." }
            "6" {
                Write-Host ""
                if (Test-Config) { Write-Host "配置文件验证通过！" -ForegroundColor Green }
                Read-Host "`n按回车键继续..."
            }
            "7" { Show-Help; Read-Host "`n按回车键继续..." }
            "8" {
                if (Get-SystemProxyStatus) { Disable-SystemProxy } else { Enable-SystemProxy }
                Read-Host "`n按回车键继续..."
            }
            "9" { Start-Mihomo -RunAsAdmin; Read-Host "`n按回车键继续..." }
            "0" {
                Invoke-ElevateScript
                # 函数内部会退出，无需再暂停
            }
            "Q" { Write-Host "再见！" -ForegroundColor Cyan; exit }
            default { Write-Host "无效选择，请重试" -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
        }
    }
}