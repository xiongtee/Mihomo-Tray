#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ====================== 配置 ======================
ExeName      := "mihomo-windows-amd64.exe"
ConfigFile   := "mihomo.yaml"
ProcessName  := "mihomo-windows-amd64.exe"

ProxyHost := "127.0.0.1"
ProxyPort := "7890"

ScriptDir := A_ScriptDir
FullExe := ScriptDir "\\" ExeName

; ====================== 状态 ======================
CurrentMode := "none"
TunState := false

; ====================== UI ======================
MenuProxy := ""
MenuTun   := ""

; ====================== 提示 ======================
Tip(t, m := "", i := "IconI") {
    TrayTip(t, m, i)
    SetTimer(() => TrayTip(), -1000)
}

; ====================== Core ======================
CoreRunning() {
    return ProcessExist(ProcessName)
}

StartCore() {
    if CoreRunning()
        return true

    cmd := Format('"{}" -d "{}" -f "{}"', FullExe, ScriptDir, ConfigFile)

    try Run(cmd, ScriptDir, "Hide")
    catch {
        Tip("错误", "core启动失败", "Icon!")
        return false
    }

    return true
}

StopCore() {
    pid := ProcessExist(ProcessName)
    if !pid
        return true

    try ProcessClose(pid)
    Sleep 600
    return !ProcessExist(ProcessName)
}

EnsureCore() {
    return CoreRunning() || StartCore()
}

; ====================== Proxy ======================
ProxyOn() {
    global ProxyHost, ProxyPort

    RegWrite(1, "REG_DWORD",
        "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings",
        "ProxyEnable")

    RegWrite(ProxyHost ":" ProxyPort, "REG_SZ",
        "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings",
        "ProxyServer")
}

ProxyOff() {
    RegWrite(0, "REG_DWORD",
        "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings",
        "ProxyEnable")
}

ProxyState() {
    try return RegRead(
        "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings",
        "ProxyEnable"
    ) = 1
    return false
}

RefreshProxy() {
    DllCall("wininet\InternetSetOptionW", "ptr", 0, "uint", 39, "ptr", 0, "uint", 0)
    DllCall("wininet\InternetSetOptionW", "ptr", 0, "uint", 37, "ptr", 0, "uint", 0)
}

; ====================== TUN ======================
SetTun(enable := true) {
    global TunState
    TunState := enable
    return true
}

; ====================== 安全切换 ======================
SafeProxy(enable) {
    global CurrentMode

    old := ProxyState()

    if enable
        ProxyOn()
    else
        ProxyOff()

    RefreshProxy()
    Sleep 120

    if ProxyState() != enable {
        if old
            ProxyOn()
        else
            ProxyOff()

        Tip("警告", "代理失败已回滚", "Icon!")
        return false
    }

    CurrentMode := enable ? "proxy" : "none"
    return true
}

SafeTun(enable) {
    global CurrentMode, TunState

    TunState := enable
    CurrentMode := enable ? "tun" : "none"
    return true
}

; ====================== 动作 ======================
SetProxyMode() {
    if !EnsureCore()
        return

    SafeTun(false)
    SafeProxy(true)

    UpdateUI()
    Tip("模式", "系统代理")
}

SetTunMode() {
    if !EnsureCore()
        return

    SafeProxy(false)
    SafeTun(true)

    UpdateUI()
    Tip("模式", "TUN")
}

StopAll() {
    global CurrentMode, TunState

    SafeTun(false)
    SafeProxy(false)
    StopCore()

    CurrentMode := "none"
    TunState := false

    UpdateUI()
    Tip("核心", "已关闭")
}

ExitAll() {
    SafeTun(false)
    SafeProxy(false)
    StopCore()
    ExitApp()
}

ReloadConfig() {
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.SetTimeouts(1200, 1200, 1200, 1200)
        whr.Open("PUT", "http://127.0.0.1:9090/configs?force=true", false)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.Send("{}")

        if (whr.Status = 200 || whr.Status = 204)
            Tip("配置", "重载成功")
        else
            Tip("配置", "失败", "Icon!")
    }
    catch {
        Tip("配置", "API不可达", "Icon!")
    }
}

; ====================== ⭐ UI（修复核心） ======================
BuildMenu() {
    global MenuProxy, MenuTun, Tray, CurrentMode

    Tray.Delete()

    proxyText := (CurrentMode = "proxy") ? "系统代理|开" : "系统代理|关"
    tunText   := (CurrentMode = "tun")   ? "TUN模式|开"   : "TUN模式|关"

    MenuProxy := proxyText
    MenuTun   := tunText

    Tray.Add(MenuProxy, (*) => SetProxyMode())
    Tray.Add(MenuTun,   (*) => SetTunMode())
    Tray.Add()
    Tray.Add("关闭核心", (*) => StopAll())
    Tray.Add("重载配置", (*) => ReloadConfig())
    Tray.Add()
    Tray.Add("退出", (*) => ExitAll())
}

UpdateUI(*) {
    BuildMenu()
}

; ====================== 初始化 ======================
InitState() {
    global CurrentMode

    if ProxyState()
        CurrentMode := "proxy"
    else
        CurrentMode := "none"

    BuildMenu()
}

Tray := A_TrayMenu
InitState()

TraySetIcon("shell32.dll", 14)
A_IconTip := "Mihomo v4-lite"

OnExit((*) => ProxyOff())

return