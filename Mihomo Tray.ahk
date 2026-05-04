; ============================================================
; Mihomo Tray Manager - AutoHotkey v2（托盘版·自动管理员）
; 功能：一键切换系统代理 / TUN 模式，验证/重载配置，开机自启
;       所有反馈均通过托盘气泡提示，关键错误保留弹窗
;       脚本默认以管理员身份启动，确保 TUN 模式关闭稳定可靠
; 编译：使用 Ahk2Exe.exe 将本脚本编译为 .exe 即可。
; ============================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ====================== 自动请求管理员权限 ======================
_IsAdmin() => DllCall("shell32\IsUserAnAdmin", "Int")

if (!_IsAdmin()) {
    params := ""
    for i, arg in A_Args
        params .= " " arg
    Run("*RunAs " A_ScriptFullPath params, A_ScriptDir)
    ExitApp
}

; ====================== 配置区域 ======================
ScriptDir := A_ScriptDir
if (SubStr(ScriptDir, -1) != "\")
    ScriptDir .= "\"
ScriptDirClean := RTrim(ScriptDir, "\")

ExeName      := "mihomo-windows-amd64.exe"
ConfigFile   := "mihomo.yaml"
ApiHost      := "127.0.0.1"
ApiPort      := "9090"
ProxyHost    := "127.0.0.1"
ProxyPort    := "7890"

FullExe      := ScriptDir . ExeName
FullConfig   := ScriptDir . ConfigFile
ProcessName  := StrSplit(ExeName, ".")[1]
ApiUrl       := "http://" ApiHost ":" ApiPort

; ====================== Secret 读取 ======================
Global SecretDefault := "123456"
Global Secret := ""
Global SecretSource := "default"

ReadSecretFromYaml(filePath) {
    if not FileExist(filePath)
        return ""
    Loop Read, filePath {
        line := Trim(A_LoopReadLine)
        if (SubStr(line, 1, 1) = "#")
            continue
        if RegExMatch(line, "^\s*secret\s*:\s*(.*?)\s*(?:\s+#.*)?$", &m) {
            val := Trim(m[1])
            if ((SubStr(val, 1, 1) = "'" and SubStr(val, -1) = "'") or
                (SubStr(val, 1, 1) = '"' and SubStr(val, -1) = '"'))
                val := SubStr(val, 2, -1)
            if (val != "")
                return val
        }
    }
    return ""
}

GetSecret() {
    Global Secret, SecretSource, SecretDefault, FullConfig
    envSecret := EnvGet("MIHOMO_SECRET")
    if (envSecret != "") {
        Secret := envSecret
        SecretSource := "env"
    } else {
        yamlSecret := ReadSecretFromYaml(FullConfig)
        if (yamlSecret != "") {
            Secret := yamlSecret
            SecretSource := "config"
        } else {
            Secret := SecretDefault
            SecretSource := "default"
        }
    }
    return Secret
}
GetSecret()

; ====================== 通用托盘提示 ======================
_ShowTip(title, text := "", icon := "IconI", timeout := 3000) {
    TrayTip(title, text, icon)
    Sleep(timeout)
    TrayTip()
}

; ====================== 工具函数 ======================
IsAdmin() => _IsAdmin()

HttpRequest(url, method := "GET", headers := "") {
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open(method, url, false)
        if headers != ""
            whr.SetRequestHeader("Authorization", headers)
        whr.Send()
        return whr.Status
    } catch {
        return 0
    }
}

TestApi() {
    Global Secret
    headers := Secret ? "Bearer " Secret : ""
    return HttpRequest(ApiUrl "/version", "GET", headers) = 200
}

IsMihomoRunning() {
    Global ProcessName
    try {
        for proc in ComObjGet("winmgmts:").ExecQuery("Select ProcessId from Win32_Process Where Name = '" ProcessName ".exe'")
            return true
    }
    return false
}

GetMihomoPID() {
    Global ProcessName
    try {
        for proc in ComObjGet("winmgmts:").ExecQuery("Select ProcessId from Win32_Process Where Name = '" ProcessName ".exe'")
            return proc.ProcessId
    }
    return 0
}

RunCmdCapture(cmd, workingDir := "", &exitCode := 0) {
    tempFile := A_Temp "\mihomo_out.tmp"
    escapedCmd := StrReplace(cmd, '"', '""')
    fullCmd := A_ComSpec ' /c "' escapedCmd ' > "' tempFile '" 2>&1"'
    RunWait(fullCmd, workingDir, "Hide", &exitCode)
    output := ""
    if FileExist(tempFile) {
        output := FileRead(tempFile)
        try FileDelete(tempFile)
    } else {
        output := "(输出文件未生成，可能命令未执行)"
    }
    return output
}

TestConfig() {
    Global FullConfig, FullExe, ScriptDirClean, ConfigFile
    if not FileExist(FullConfig) {
        _ShowTip("错误", "配置文件不存在", "Icon!")
        return false
    }
    if not FileExist(FullExe) {
        _ShowTip("错误", "可执行文件不存在", "Icon!")
        return false
    }
    cmd := '"' FullExe '" -t -d "' ScriptDirClean '" -f "' ConfigFile '"'
    output := RunCmdCapture(cmd, ScriptDirClean, &exitCode)
    if InStr(output, "test is successful")
        return true
    if exitCode = 0
        return true
    _ShowTip("验证失败", "退出码: " exitCode, "Icon!")
    return false
}

WaitForProcessStart(timeout := 8, intervalMs := 300) {
    start := A_TickCount
    while (A_TickCount - start < timeout * 1000) {
        if IsMihomoRunning()
            return true
        Sleep intervalMs
    }
    return false
}

WaitForProcessStop(timeout := 5, intervalMs := 200) {
    start := A_TickCount
    while (A_TickCount - start < timeout * 1000) {
        if !IsMihomoRunning()
            return true
        Sleep intervalMs
    }
    return false
}

; ====================== 系统代理控制 ======================
GetProxyStatus() {
    Global ProxyHost, ProxyPort
    try {
        proxyEnable := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings", "ProxyEnable")
        proxyServer := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings", "ProxyServer")
        return (proxyEnable = 1 && proxyServer = ProxyHost ":" ProxyPort)
    } catch {
        return false
    }
}

EnableProxy() {
    Global ProxyHost, ProxyPort
    try {
        RegWrite(1, "REG_DWORD", "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings", "ProxyEnable")
        RegWrite(ProxyHost ":" ProxyPort, "REG_SZ", "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings", "ProxyServer")
        RegWrite("<local>", "REG_SZ", "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings", "ProxyOverride")
        return true
    } catch {
        return false
    }
}

DisableProxy() {
    try {
        RegWrite(0, "REG_DWORD", "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings", "ProxyEnable")
        return true
    } catch {
        return false
    }
}

; ====================== 模式状态判断 ======================
IsSystemProxyMode() {
    return IsMihomoRunning() && GetProxyStatus()
}

IsTunMode() {
    return IsMihomoRunning() && !GetProxyStatus()
}

; ====================== 核心操作 ======================
StartMihomo(runAsAdmin := false) {
    Global FullExe, ScriptDirClean, ConfigFile
    if not TestConfig()
        return false
    cmd := '"' FullExe '" -d "' ScriptDirClean '" -f "' ConfigFile '"'
    if runAsAdmin
        Run(cmd, ScriptDirClean, "Hide")
    else
        Run(cmd, ScriptDirClean, "Hide")
    if WaitForProcessStart() {
        Sleep 2000
        return true
    }
    MsgBox("启动失败，请检查配置或权限", "严重错误", "Icon!")
    return false
}

StopMihomo(forceAdmin := false) {
    if not IsMihomoRunning()
        return true
    pid := GetMihomoPID()
    if IsAdmin() {
        ProcessClose(pid)
    } else {
        RunWait("taskkill /F /PID " pid, , "Hide")
        if !WaitForProcessStop(2, 100) {
            if forceAdmin {
                RunWait('*RunAs ' A_ComSpec ' /c "taskkill /F /PID ' pid '"', , "Hide")
            } else {
                _ShowTip("权限不足", "停止进程需要管理员权限", "Icon!")
                return false
            }
        }
    }
    if WaitForProcessStop()
        return true
    _ShowTip("警告", "进程可能未完全退出", "Icon!")
    return false
}

; ====================== 模式切换 ======================
ToggleSystemProxyMode() {
    if IsSystemProxyMode() {
        if StopMihomo(false) {
            DisableProxy()
            UpdateMenuChecks()               ; ← 先更新菜单
            _ShowTip("系统代理", "已关闭")
        } else {
            _ShowTip("错误", "关闭失败，内核仍在运行", "Icon!")
        }
    } else {
        if IsMihomoRunning() {
            if !StopMihomo() {
                MsgBox("无法停止现有进程，切换取消", "错误", "Icon!")
                return
            }
            Sleep 500
        }
        if StartMihomo(false) {
            EnableProxy()
            UpdateMenuChecks()               ; ← 先更新菜单
            _ShowTip("系统代理", "已开启")
        }
    }
    UpdateMenuChecks()   ; 保留分支外的调用，以防万一
}

ToggleTunMode() {
    if IsTunMode() {
        if StopMihomo(true) {
            UpdateMenuChecks()               ; ← 先更新
            _ShowTip("TUN 模式", "已关闭")
        } else {
            _ShowTip("错误", "关闭失败，内核仍在运行", "Icon!")
        }
    } else {
        if IsMihomoRunning() {
            if !StopMihomo() {
                MsgBox("无法停止现有进程，切换取消", "错误", "Icon!")
                return
            }
            Sleep 500
        }
        if StartMihomo(true) {
            DisableProxy()
            UpdateMenuChecks()               ; ← 先更新
            _ShowTip("TUN 模式", "已开启")
        }
    }
    UpdateMenuChecks()
}

ToggleAutoStart() {
    Global ScriptDir
    if IsAutoStartEnabled() {
        FileDelete(StartupLnk)
        UpdateMenuChecks()                  ; ← 先更新
        _ShowTip("开机自启", "已关闭")
    } else {
        FileCreateShortcut(A_ScriptFullPath, StartupLnk, ScriptDir, "", "Mihomo 托盘管理")
        UpdateMenuChecks()                  ; ← 先更新
        _ShowTip("开机自启", "已开启")
    }
    UpdateMenuChecks()
}

; ====================== 重载配置 ======================
ReloadConfig() {
    Global Secret, ApiUrl
    if not TestApi() {
        _ShowTip("重载失败", "API 不可达，请先启动 Mihomo", "Icon!")
        return
    }
    headers := Secret ? "Bearer " Secret : ""
    url := ApiUrl "/configs?force=true"
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("PUT", url, false)
        if headers
            whr.SetRequestHeader("Authorization", headers)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.Send("{}")
        if whr.Status = 204 or whr.Status = 200
            _ShowTip("重载成功", "配置已重载")
        else
            _ShowTip("重载失败", "HTTP " whr.Status, "Icon!")
    } catch {
        _ShowTip("重载出错", "请求发生异常", "Icon!")
    }
}

; ====================== 开机自启 ======================
StartupLnk := A_Startup "\MihomoTray.lnk"

IsAutoStartEnabled() => FileExist(StartupLnk)

; ====================== 托盘菜单 ======================
TrayMenu := A_TrayMenu
TrayMenu.Delete

Global SysProxyMenuName  := "√ 系统代理"
Global TunMenuName       := "× TUN模式"
Global AutoStartMenuName := "× 开机自启"

TrayMenu.Add(SysProxyMenuName, (*) => ToggleSystemProxyMode())
TrayMenu.Add(TunMenuName, (*) => ToggleTunMode())
TrayMenu.Add()
TrayMenu.Add("🔁 重载配置", (*) => ReloadConfig())
TrayMenu.Add("ℹ️ 验证配置", (*) => (TestConfig() ? _ShowTip("验证通过", "配置文件正确") : ""))
TrayMenu.Add()
TrayMenu.Add(AutoStartMenuName, (*) => ToggleAutoStart())
TrayMenu.Add()
TrayMenu.Add("❌ 退出", (*) => ExitApp())

SetTimer(UpdateMenuChecks, 200)

UpdateMenuChecks() {
    Global SysProxyMenuName, TunMenuName, AutoStartMenuName

    sysNew := (IsSystemProxyMode() ? "√ " : "× ") "系统代理"
    if (SysProxyMenuName != sysNew) {
        Try TrayMenu.Rename(SysProxyMenuName, sysNew)
        SysProxyMenuName := sysNew
    }

    tunNew := (IsTunMode() ? "√ " : "× ") "TUN模式"
    if (TunMenuName != tunNew) {
        Try TrayMenu.Rename(TunMenuName, tunNew)
        TunMenuName := tunNew
    }

    autoNew := (IsAutoStartEnabled() ? "√ " : "× ") "开机自启"
    if (AutoStartMenuName != autoNew) {
        Try TrayMenu.Rename(AutoStartMenuName, autoNew)
        AutoStartMenuName := autoNew
    }

    Try TrayMenu.Default := SysProxyMenuName
}

TraySetIcon("shell32.dll", 14)
A_IconTip := "Mihomo Manager"

_ShowTip("Mihomo 托盘管理器已启动", "右键托盘图标切换模式")

return