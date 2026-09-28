#Requires AutoHotkey v2.0
#SingleInstance Force
;@Ahk2Exe-SetName YP Macro
;@Ahk2Exe-SetDescription YP Macro
;@Ahk2Exe-SetVersion 1.2.0.0
;@Ahk2Exe-SetMainIcon YPMacro.ico
; ==============================================================================
;  YP Macro  v1.2  -  키보드/마우스 매크로   (AutoHotkey v2 스크립트)
;
;  메인 창은 G Macro ver 2.0 과 같은 배치:
;    - 메뉴:  파일 | 시작 | 설정 | 정보
;    - 왼쪽 이벤트 목록(첫 줄은 항상 "1. 시작"), 오른쪽 [키보드] [마우스] [시간] [지우기]
;    - 아래 (추가 / 삽입) 선택과 [반복] 체크
;    - 추가 = 맨 끝에 붙임,  삽입 = 선택한 줄 바로 아래에 끼워 넣음
;    - 줄 더블클릭 = 수정,  우클릭 = 수정/지우기/위로/아래로,  Delete 키 = 지우기
;  기본 단축키:  F9 = 시작,  F10 = 중지,  F8 = 마우스 캡처(현재 좌표를 이동 이벤트로 추가)
;    - 중지 키는 실행 중이 아닐 때 눌러도 "매크로가 눌러 둔 키/버튼"을 전부 떼어 준다.
;  설정과 마지막 목록은 레지스트리(HKEY_CURRENT_USER\Software\YP Macro)에 저장한다. exe 옆에 파일을 만들지 않는다.
;  (v1.1 까지 exe 옆에 만들던 YPMacro.ini / YPMacro_last.gmx, 옛 이름의 GMacroStyle.* 가 있으면
;   처음 실행 때 레지스트리로 옮기고 그 파일은 지운다.)
; ==============================================================================

SetWorkingDir(A_ScriptDir)
CoordMode("Mouse", "Screen")
CoordMode("ToolTip", "Screen")
SetMouseDelay(-1)
SetKeyDelay(-1, -1)
SetDefaultMouseSpeed(0)
SendMode("Event")               ; 기본 전송 방식. Input 은 보낼 때마다 키보드 훅을 잠깐 떼어서 중지 단축키를 놓칠 수 있다.
DllCall("winmm\timeBeginPeriod", "UInt", 1)     ; Sleep 정밀도를 1ms 단위로

APP_TITLE  := "YP Macro"
APP_VER    := "1.2"
REG_KEY    := "HKEY_CURRENT_USER\Software\YP Macro"   ; 설정 + 마지막 목록 저장 위치
FILE_MAGIC := "GMACROSTYLE1"                           ; [저장]/[불러오기] 하는 매크로 파일(.gmx) 형식은 그대로
CLICK_HOLD := 30        ; 마우스 클릭 시 버튼을 누르고 있는 시간(ms)

App := { events: [], running: false, stopReq: false, capturing: false
       , hk: Map(), hkEnabled: false, stopKey: { vk: 0, mods: [] }, held: Map(), statusTick: 0
       , dlg: "", dlgKind: "", dlgCtl: "", dlgCleanup: ""
       , pid: DllCall("GetCurrentProcessId", "UInt") }
ui  := {}
win := ""

ImportLegacyFiles()
LoadSettings()
BuildGui()
SetupTray()
RegisterHotkeys(App.hkStart, App.hkStop, App.hkPos)
LoadLastList()
OnExit(ExitHandler)
SetRunTitle()

; v1.1 까지 exe 옆에 만들던 설정/목록 파일을 레지스트리로 옮기고, 옮긴 파일은 지운다.
;  - YPMacro.ini / YPMacro_last.gmx      : 있으면 항상 가져온다 (레지스트리 값을 덮어씀)
;  - GMacroStyle.ini / GMacroStyle_last.gmx (옛 이름) : 레지스트리가 아직 비어 있을 때만 가져온다
ImportLegacyFiles() {
    for set in [ ["YPMacro.ini", "YPMacro_last.gmx", true], ["GMacroStyle.ini", "GMacroStyle_last.gmx", false] ] {
        ini  := A_ScriptDir "\" set[1]
        last := A_ScriptDir "\" set[2]
        if !(FileExist(ini) || FileExist(last))
            continue
        if (!set[3] && RegHasData())
            continue
        if FileExist(ini) {
            static iniKeys := [ ["Hotkeys", "Start", "HotkeyStart"], ["Hotkeys", "Stop", "HotkeyStop"], ["Hotkeys", "Pos", "HotkeyPos"]
                , ["Options", "Repeat", "Repeat"], ["Options", "RepeatCount", "RepeatCount"], ["Options", "Insert", "Insert"]
                , ["Options", "Gap", "Gap"], ["Options", "StartDelay", "StartDelay"], ["Options", "KeyHold", "KeyHold"]
                , ["Options", "StartFromSel", "StartFromSel"], ["Options", "OnTop", "OnTop"], ["Options", "Beep", "Beep"]
                , ["Options", "AutoAddPos", "AutoAddPos"], ["Options", "SendMode", "SendMode"] ]
            ok := true
            for m in iniKeys {
                if (!set[3] && m[3] = "SendMode")          ; 옛 버전의 전송 방식(Input)은 가져오지 않는다
                    continue
                try {
                    v := IniRead(ini, m[1], m[2], "")
                    if (v != "")
                        CfgWrite(m[3], v)
                } catch
                    ok := false
            }
            if ok
                try FileDelete(ini)
        }
        if FileExist(last) {
            try {
                txt := FileRead(last, "UTF-8")
                lines := StrSplit(txt, "`n", "`r")
                if (lines.Length && Trim(lines[1]) = FILE_MAGIC) {
                    lines.RemoveAt(1)
                    body := ""
                    for line in lines
                        if (Trim(line, " `t") != "")
                            body .= line "`n"
                    WriteLastList(RTrim(body, "`n"))
                    FileDelete(last)
                }
            }
        }
    }
}

; 레지스트리에 이미 저장된 설정/목록이 있는지
RegHasData() {
    for name in ["HotkeyStart", "LastList"] {
        try {
            RegRead(REG_KEY, name)
            return true
        }
    }
    return false
}

CfgRead(name, default) {
    try return RegRead(REG_KEY, name)
    return default
}

CfgWrite(name, value) {
    RegWrite(value, "REG_SZ", REG_KEY, name)
}

; 목록에서 Delete 키 = 지우기.  (전역 단축키 대신 이 창의 메시지로만 처리한다:
;  #HotIf 콜백 방식은 키를 누를 때마다 훅이 메인 스레드의 답을 기다려서, 매크로 실행 중에는 키보드 전체가 멈출 수 있다)
OnMessage(0x0100, OnKeyDownMsg)     ; WM_KEYDOWN
OnKeyDownMsg(wParam, lParam, msg, hwnd) {
    if (hwnd = ui.lb.Hwnd && wParam = 0x2E && !App.running) {     ; VK_DELETE
        DeleteSel()
        return 0
    }
}

; 트레이 메뉴는 [창 열기] [종료] 만 둔다 (기본 메뉴의 일시정지/중단 항목은 이 프로그램에 필요 없음)
SetupTray() {
    A_IconTip := APP_TITLE
    tray := A_TrayMenu
    tray.Delete()
    tray.Add("창 열기", (*) => ShowMainWindow())
    tray.Add("종료", (*) => ExitApp())
    tray.Default := "창 열기"
    tray.ClickCount := 1
}

ShowMainWindow() {
    win.Show("Restore")
    try WinActivate("ahk_id " win.Hwnd)
}


; ==============================================================================
;  설정 읽기/쓰기
; ==============================================================================
LoadSettings() {
    App.hkStart      := CfgRead("HotkeyStart", "F9")
    App.hkStop       := CfgRead("HotkeyStop",  "F10")
    App.hkPos        := CfgRead("HotkeyPos",   "F8")
    App.repeatOn     := CfgRead("Repeat", "1") = "1"
    App.repeatCnt    := ToInt(CfgRead("RepeatCount", "0"), 0)
    App.insertMode   := CfgRead("Insert", "0") = "1"
    App.gap          := ToInt(CfgRead("Gap", "0"), 0)
    App.startDelay   := ToInt(CfgRead("StartDelay", "0"), 0)
    App.keyHold      := ToInt(CfgRead("KeyHold", "50"), 50)
    App.startFromSel := CfgRead("StartFromSel", "0") = "1"
    App.onTop        := CfgRead("OnTop", "1") = "1"
    App.beep         := CfgRead("Beep", "1") = "1"
    App.autoAddPos   := CfgRead("AutoAddPos", "1") = "1"
    App.sendMode     := CfgRead("SendMode", "Event")
    if !(App.sendMode = "Input" || App.sendMode = "Event")
        App.sendMode := "Event"
}

SaveSettings() {
    App.repeatOn   := ui.cbRepeat.Value = 1
    App.insertMode := ui.rInsert.Value = 1
    try {
        CfgWrite("HotkeyStart",  App.hkStart)
        CfgWrite("HotkeyStop",   App.hkStop)
        CfgWrite("HotkeyPos",    App.hkPos)
        CfgWrite("Repeat",       App.repeatOn ? 1 : 0)
        CfgWrite("RepeatCount",  App.repeatCnt)
        CfgWrite("Insert",       App.insertMode ? 1 : 0)
        CfgWrite("Gap",          App.gap)
        CfgWrite("StartDelay",   App.startDelay)
        CfgWrite("KeyHold",      App.keyHold)
        CfgWrite("StartFromSel", App.startFromSel ? 1 : 0)
        CfgWrite("OnTop",        App.onTop ? 1 : 0)
        CfgWrite("Beep",         App.beep ? 1 : 0)
        CfgWrite("AutoAddPos",   App.autoAddPos ? 1 : 0)
        CfgWrite("SendMode",     App.sendMode)
    }
}

ExitHandler(*) {
    App.stopReq := true
    try ReleaseAll()
    try SaveSettings()
    try SaveLastList()
    DllCall("winmm\timeEndPeriod", "UInt", 1)
    return 0
}

; ==============================================================================
;  메인 창
; ==============================================================================
BuildGui() {
    global win
    win := Gui("+MinimizeBox -MaximizeBox", APP_TITLE)
    win.SetFont("s9", "Malgun Gothic")
    win.OnEvent("Close", (*) => ExitApp())

    ; ---- 메뉴:  파일 | 시작 | 설정 | 정보 -----------------------------------
    ui.mFile := Menu()
    ui.mFile.Add("새로 만들기", (*) => ClearAll())
    ui.mFile.Add("불러오기...", (*) => LoadDialog())
    ui.mFile.Add("저장...", (*) => SaveDialog())
    ui.mFile.Add()
    ui.mFile.Add("종료", (*) => ExitApp())
    ui.mRun := Menu()
    ui.startName := "시작"
    ui.stopName  := "중지"
    ui.mRun.Add(ui.startName, (*) => StartMacro(true))
    ui.mRun.Add(ui.stopName, (*) => StopMacro())
    ui.mSet := Menu()
    ui.mSet.Add("키보드 설정...", (*) => ShowKeyboardSettings())
    ui.mSet.Add("마우스 설정...", (*) => ShowMouseSettings())
    ui.mSet.Add("기타 설정...", (*) => ShowEtcSettings())
    ui.mBar := MenuBar()
    ui.mBar.Add("파일", ui.mFile)
    ui.mBar.Add("시작", ui.mRun)
    ui.mBar.Add("설정", ui.mSet)
    ui.mBar.Add("정보", (*) => ShowAbout())
    win.MenuBar := ui.mBar

    ; ---- 이벤트 목록 (첫 줄 "1. 시작" 은 고정) --------------------------------
    ui.lb := win.AddListBox("x8 y8 w176 h142 0x100")        ; 0x100 = 높이를 줄 단위로 자르지 않음
    ui.lb.OnEvent("DoubleClick", (*) => EditRow(ui.lb.Value))
    ui.lb.OnEvent("ContextMenu", ListContextMenu)

    ; ---- 오른쪽 버튼 4개 -----------------------------------------------------
    win.AddButton("x194 y12 w70 h27", "키보드").OnEvent("Click", (*) => ShowKeyDialog())
    win.AddButton("x194 y47 w70 h27", "마우스").OnEvent("Click", (*) => ShowMouseDialog())
    win.AddButton("x194 y82 w70 h27", "시간").OnEvent("Click", (*) => ShowTimeDialog())
    win.AddButton("x194 y117 w70 h27", "지우기").OnEvent("Click", (*) => DeleteSel())

    ; ---- 아래:  (추가 / 삽입)  [반복] ----------------------------------------
    ui.rAppend := win.AddRadio("x12 y158 w50 h20 Group", "추가")
    ui.rInsert := win.AddRadio("x64 y158 w50 h20", "삽입")
    ui.cbRepeat := win.AddCheckBox("x122 y158 w56 h20", "반복")
    ui.rAppend.Value := App.insertMode ? 0 : 1
    ui.rInsert.Value := App.insertMode ? 1 : 0
    ui.cbRepeat.Value := App.repeatOn

    ; 목록 우클릭 메뉴
    ui.ctx := Menu()
    ui.ctx.Add("수정", (*) => EditRow(ui.lb.Value))
    ui.ctx.Add("지우기", (*) => DeleteSel())
    ui.ctx.Add()
    ui.ctx.Add("위로", (*) => MoveSel(-1))
    ui.ctx.Add("아래로", (*) => MoveSel(1))
    ui.ctx.Add()
    ui.ctx.Add("모두 지우기", (*) => ClearAll())

    win.Opt((App.onTop ? "+" : "-") "AlwaysOnTop")
    RefreshList(1)
    win.Show("w272 h186")
}

ListContextMenu(lb, item, isRightClick, x, y) {
    if App.running
        return
    if isRightClick
        SelectRowAt(lb, x, y)            ; 우클릭한 줄을 먼저 선택
    ui.ctx.Show()
}

; 창 기준 좌표 (x, y) 아래에 있는 목록 줄을 선택한다 (LB_ITEMFROMPOINT). 선택한 줄 번호, 없으면 0.
SelectRowAt(lb, x, y) {
    lb.GetPos(&cx, &cy)
    lx := Max(0, x - cx - 2)
    ly := Max(0, y - cy - 2)
    r := SendMessage(0x01A9, 0, (ly << 16) | (lx & 0xFFFF), lb)
    if (r >> 16)
        return 0
    lb.Choose((r & 0xFFFF) + 1)
    return (r & 0xFFFF) + 1
}

; 짧은 안내를 창 아래쪽에 말풍선으로 잠깐 보여 준다 (원본처럼 상태 표시줄은 없음)
Notify(msg, ms := 2500) {
    try {
        win.GetPos(&wx, &wy, &ww, &wh)
        ToolTip(msg, wx + 8, wy + wh - 4)
        SetTimer(() => ToolTip(), -ms)
    }
}

; 제목 표시줄에 상태 표시.  대기: "이름  ver x.x  [대기중]",  실행 중: "[실행중 n회]  이름"
SetRunTitle(state := "") {
    if (state = "")
        win.Title := APP_TITLE "  v" APP_VER "  [대기중]"
    else
        win.Title := "[" state "]  " APP_TITLE
}

HotkeyHelp() {
    return "시작 " HotkeyLabel(App.hkStart) "   중지 " HotkeyLabel(App.hkStop) "   마우스 캡처 " HotkeyLabel(App.hkPos)
}

; "^!F9" 같은 단축키 문자열을 "Ctrl+Alt+F9" 로
HotkeyLabel(hk) {
    out := ""
    loop parse hk {
        switch A_LoopField {
            case "^": out .= "Ctrl+"
            case "!": out .= "Alt+"
            case "+": out .= "Shift+"
            case "#": out .= "Win+"
            default:  return out SubStr(hk, A_Index)
        }
    }
    return out
}

Warn(msg, owner := "") {
    o := owner ? owner : win
    o.Opt("+OwnDialogs")
    MsgBox(msg, APP_TITLE, "Icon!")
    return false
}

; 라디오 묶음에서 idx 번째만 켠다
SelectRadio(radios, idx) {
    for i, r in radios
        r.Value := (i = idx) ? 1 : 0
}

; [시작] 메뉴의 항목 이름에 단축키를 표시하고, 실행 상태에 따라 활성/비활성
UpdateRunState() {
    newStart := "시작 (" HotkeyLabel(App.hkStart) ")"
    newStop  := "중지 (" HotkeyLabel(App.hkStop) ")"
    if (ui.startName != newStart) {
        ui.mRun.Rename(ui.startName, newStart)
        ui.startName := newStart
    }
    if (ui.stopName != newStop) {
        ui.mRun.Rename(ui.stopName, newStop)
        ui.stopName := newStop
    }
    if App.running {
        ui.mRun.Disable(ui.startName)
        ui.mRun.Enable(ui.stopName)
    } else {
        ui.mRun.Enable(ui.startName)
        ui.mRun.Disable(ui.stopName)
    }
}

ShowAbout() {
    win.Opt("+OwnDialogs")
    MsgBox(APP_TITLE "  v" APP_VER "`n`n"
        . "G Macro ver 2.0 의 화면과 사용 방식을 따라 만든 키보드/마우스 매크로입니다.`n"
        . "(원본 G Macro 와 파일(.gmc) 호환은 되지 않습니다.)`n`n"
        . HotkeyHelp() "`n`n"
        . "AutoHotkey v" A_AhkVersion " 기반", "정보", "Iconi")
}

; ==============================================================================
;  단축키
; ==============================================================================
RegisterHotkeys(newStart, newStop, newPos, owner := "") {
    if (newStart = "" || newStop = "" || newPos = "")
        return Warn("단축키가 비어 있습니다.", owner)
    if (newStart = newStop || newStart = newPos || newStop = newPos)
        return Warn("시작 / 중지 / 마우스 캡처 단축키가 서로 겹칩니다.", owner)

    ; "*" = 다른 조합키가 눌려 있어도 반응.  이게 없으면 매크로가 Shift/Ctrl/Alt 를 누른 채일 때
    ;       중지 키가 "Shift+F10" 으로 보여서 반응하지 않고, 매크로가 멈추지 않는다.
    ; "$" = 훅 방식 (매크로가 보내는 키에는 반응하지 않도록)
    ; #HotIf 조건은 일부러 쓰지 않는다 - 훅이 키를 볼 때마다 메인 스레드에 물어보고 기다리는 구조라서
    ; 매크로가 바쁘면 시스템 키보드 입력이 통째로 멈추고 중지 키도 버려진다. 대신 설정 창이 열린 동안만 끈다.
    for , oldKey in App.hk
        try Hotkey("*$" oldKey, "Off")
    App.hk := Map()
    try {
        Hotkey("*$" newStart, (*) => StartMacro(false), "On")
        App.hk["start"] := newStart
        Hotkey("*$" newStop, (*) => StopMacro(), "On")
        App.hk["stop"] := newStop
        Hotkey("*$" newPos, (*) => CapturePos(), "On")
        App.hk["pos"] := newPos
    } catch as err {
        return Warn("단축키 등록 실패: " err.Message, owner)
    }
    App.hkEnabled := true

    App.hkStart := newStart
    App.hkStop  := newStop
    App.hkPos   := newPos
    App.stopKey := ParseHotkey(newStop)
    UpdateRunState()
    return true
}

; 단축키를 잠시 끄거나 다시 켠다 (단축키 입력칸이 있는 설정 창이 열린 동안, [키 잡기] 동안).
SetHotkeysEnabled(on) {
    for , key in App.hk
        try Hotkey("*$" key, on ? "On" : "Off")
    App.hkEnabled := on ? true : false
}

; "^!F10" 같은 단축키 문자열을 가상 키 코드로:  { vk: 주 키, mods: [함께 눌려 있어야 하는 조합키 vk...] }
ParseHotkey(hk) {
    r := { vk: 0, mods: [] }
    loop parse hk {
        switch A_LoopField {
            case "^": r.mods.Push(0x11)          ; VK_CONTROL
            case "+": r.mods.Push(0x10)          ; VK_SHIFT
            case "!": r.mods.Push(0x12)          ; VK_MENU (Alt)
            case "#": r.mods.Push(0x5B)          ; VK_LWIN (오른쪽 Win 은 StopKeyDown 에서 같이 본다)
            case "*", "~", "$", "<", ">":        ; 접두어는 무시
            default:                             ; 여기서부터가 키 이름
                r.vk := GetKeyVK(SubStr(hk, A_Index))
                return r
        }
    }
    return r
}

; 중지 단축키가 지금 실제로 눌려 있는지 훅 없이 직접 읽는다 (GetAsyncKeyState).
; 훅이 밀리거나 빠진 상황에서도 매크로 루프가 스스로 멈출 수 있게 하는 2중 안전장치.
StopKeyDown() {
    sk := App.stopKey
    if !sk.vk
        return false
    if !(DllCall("GetAsyncKeyState", "Int", sk.vk, "Short") & 0x8001)
        return false
    for m in sk.mods {
        if (m = 0x5B) {
            if !((DllCall("GetAsyncKeyState", "Int", 0x5B, "Short") | DllCall("GetAsyncKeyState", "Int", 0x5C, "Short")) & 0x8000)
                return false
        } else if !(DllCall("GetAsyncKeyState", "Int", m, "Short") & 0x8000)
            return false
    }
    return true
}

; "그 사이에 눌렸음" 비트를 비운다 (매크로 시작 직전에 호출).
ClearStopKeyState() {
    if App.stopKey.vk
        DllCall("GetAsyncKeyState", "Int", App.stopKey.vk, "Short")
}

; ==============================================================================
;  대화상자 공통
; ==============================================================================
OpenDialog(title, kind) {
    d := Gui("+Owner" win.Hwnd " -MinimizeBox -MaximizeBox", title)
    d.SetFont("s9", "Malgun Gothic")
    d.OnEvent("Close", (g) => CloseDialog(g))
    d.OnEvent("Escape", (g) => CloseDialog(g))
    win.Opt("+Disabled")
    App.dlg := d
    App.dlgKind := kind
    App.dlgCtl := ""
    App.dlgCleanup := ""
    if (kind = "set-key" || kind = "set-mouse")      ; 단축키 입력칸이 있는 창: 그 키 자체를 입력받아야 하므로
        SetHotkeysEnabled(false)
    return d
}

ShowDialog(d, w, h) {
    win.GetPos(&wx, &wy, &ww, &wh)
    x := Max(0, wx + (ww - w - 16) // 2)
    y := Max(0, wy + (wh - h - 38) // 2 + 10)
    d.Show("x" x " y" y " w" w " h" h)
}

CloseDialog(d) {
    if App.dlgCleanup
        try App.dlgCleanup.Call()
    App.dlg := ""
    App.dlgKind := ""
    App.dlgCtl := ""
    App.dlgCleanup := ""
    win.Opt("-Disabled")        ; 주인 창을 먼저 살린 뒤 닫아야 포커스가 다른 프로그램으로 안 튄다
    d.Destroy()
    try WinActivate("ahk_id " win.Hwnd)
    if !App.hkEnabled
        SetHotkeysEnabled(true)
    return true
}

CanOpenDialog() {
    return !(App.running || App.dlg)
}

; ------------------------------------------------------------------------------
;  [키보드] 이벤트
; ------------------------------------------------------------------------------
ShowKeyDialog(editIdx := 0) {
    if !CanOpenDialog()
        return
    ev := editIdx ? App.events[editIdx] : ""
    d := OpenDialog(editIdx ? "키보드 이벤트 수정" : "키보드 이벤트", "key")
    c := {}
    c.rKey  := d.AddRadio("x14 y14 w76 Group Checked", "키 입력")
    c.rText := d.AddRadio("x96 y14 w90", "문장 입력")
    d.AddText("x14 y47 w36", "키")
    c.edKey := d.AddEdit("x52 y44 w120")
    c.btnCap := d.AddButton("x178 y43 w84 h24", "키 잡기")
    d.AddText("x14 y79 w36", "방식")
    c.rTap  := d.AddRadio("x52 y79 w90 Group Checked", "누르고 떼기")
    c.rDown := d.AddRadio("x146 y79 w80", "누른 상태")
    c.rUp   := d.AddRadio("x230 y79 w70", "뗀 상태")
    d.AddText("x14 y111 w36", "문장")
    c.edText := d.AddEdit("x52 y108 w248")
    c.btnOk := d.AddButton("x138 y144 w78 h26 Default", "확인")
    c.btnCancel := d.AddButton("x222 y144 w78 h26", "취소")
    App.dlgCtl := c

    if ev {
        if (ev.type = "TEXT") {
            SelectRadio([c.rKey, c.rText], 2)
            c.edText.Value := ev.text
        } else {
            c.edKey.Value := ev.key
            SelectRadio([c.rTap, c.rDown, c.rUp], ev.mode = "down" ? 2 : ev.mode = "up" ? 3 : 1)
        }
    }

    Sync(*) {
        isKey := c.rKey.Value
        for ctl in [c.edKey, c.btnCap, c.rTap, c.rDown, c.rUp]
            ctl.Enabled := isKey
        c.edText.Enabled := !isKey
    }
    OnOk(*) {
        if c.rText.Value {
            txt := c.edText.Value
            if (txt = "")
                return Warn("입력할 문장을 적으세요.", d)
            newEv := { type: "TEXT", text: StrReplace(txt, "`t", " ") }
        } else {
            k := Trim(c.edKey.Value)
            if !ValidKey(k)
                return Warn("키 이름이 올바르지 않습니다.`n[키 잡기]를 누른 뒤 원하는 키를 누르세요.", d)
            mode := c.rTap.Value ? "tap" : c.rDown.Value ? "down" : "up"
            hold := (ev && ev.type = "KEY") ? ev.hold : App.keyHold
            newEv := { type: "KEY", key: k, mode: mode, hold: hold }
        }
        CloseDialog(d)
        CommitEvent(editIdx, newEv)
    }
    c.rKey.OnEvent("Click", Sync)
    c.rText.OnEvent("Click", Sync)
    c.btnCap.OnEvent("Click", (*) => CaptureKeyInto(c.btnCap, c.edKey))
    c.btnOk.OnEvent("Click", OnOk)
    c.btnCancel.OnEvent("Click", (*) => CloseDialog(d))
    Sync()
    ShowDialog(d, 314, 182)
}

CaptureKeyInto(btn, edit) {
    if App.running || App.capturing
        return
    App.capturing := true
    wasOn := App.hkEnabled
    SetHotkeysEnabled(false)                 ; 단축키로 쓰는 키도 잡을 수 있게
    oldText := btn.Text
    btn.Text := "키를 누르세요"
    btn.Enabled := false
    ih := InputHook("L0 T5")
    ih.KeyOpt("{All}", "ES")
    ih.Start()
    ih.Wait()
    try {
        if (ih.EndReason = "EndKey")
            edit.Value := ih.EndKey
        btn.Text := oldText
        btn.Enabled := true
    }
    if wasOn
        SetHotkeysEnabled(true)
    App.capturing := false
}

; ------------------------------------------------------------------------------
;  [마우스] 이벤트
; ------------------------------------------------------------------------------
MouseChoices() {
    ; 라디오 순서와 같은 순서:  [버튼, 방식]
    static list := [ ["", "move"]
        , ["Left", "click"],  ["Left", "down"],  ["Left", "up"]
        , ["Right", "click"], ["Right", "down"], ["Right", "up"]
        , ["Middle", "click"], ["WheelUp", "click"], ["WheelDown", "click"] ]
    return list
}

ShowMouseDialog(editIdx := 0, presetX := "", presetY := "") {
    if !CanOpenDialog()
        return
    ev := editIdx ? App.events[editIdx] : ""
    d := OpenDialog(editIdx ? "마우스 이벤트 수정" : "마우스 이벤트", "mouse")
    c := {}
    ; 라디오는 한 그룹이 되도록 연달아 추가한다 (사이에 다른 컨트롤이 끼면 그룹이 나뉨)
    labels := ["이동", "왼쪽 클릭", "왼쪽 누른 상태", "왼쪽 뗀 상태"
             , "오른쪽 클릭", "오른쪽 누른 상태", "오른쪽 뗀 상태"
             , "가운데 클릭", "휠 위로", "휠 아래로"]
    pos := ["x14 y16 w56"
          , "x14 y56 w116", "x14 y82 w116", "x14 y108 w116"
          , "x134 y56 w124", "x134 y82 w124", "x134 y108 w124"
          , "x262 y56 w100", "x262 y82 w100", "x262 y108 w100"]
    c.radios := []
    for i, label in labels
        c.radios.Push(d.AddRadio(pos[i] (i = 1 ? " Group Checked" : ""), label))
    d.AddText("x78 y18 w14", "X")
    c.edX := d.AddEdit("x94 y14 w58", presetX)
    d.AddText("x160 y18 w14", "Y")
    c.edY := d.AddEdit("x176 y14 w58", presetY)
    c.cbRel := d.AddCheckBox("x246 y16 w120", "상대 이동(게임 시점)")
    d.AddText("x14 y40 w352 h1 0x10")           ; 가로 구분선
    d.AddText("x14 y136 w352 h1 0x10")
    c.txPos := d.AddText("x14 y146 w352", "현재 커서 위치: -")
    c.btnOk := d.AddButton("x204 y170 w78 h26 Default", "확인")
    c.btnCancel := d.AddButton("x288 y170 w78 h26", "취소")
    App.dlgCtl := c

    if ev {
        if (ev.type = "MOVE") {
            c.edX.Value := ev.x
            c.edY.Value := ev.y
            c.cbRel.Value := ev.rel ? 1 : 0
        } else {
            mode := ev.mode = "double" ? "click" : ev.mode
            for i, ch in MouseChoices()
                if (ch[1] = ev.btn && (ch[2] = mode || InStr(ev.btn, "Wheel")))
                    SelectRadio(c.radios, i)
        }
    }

    Sync(*) {
        isMove := c.radios[1].Value
        c.edX.Enabled := isMove
        c.edY.Enabled := isMove
        c.cbRel.Enabled := isMove
    }
    Tick() {
        try {
            MouseGetPos(&mx, &my)
            c.txPos.Text := "현재 커서 위치: " mx ", " my "      ·   " HotkeyLabel(App.hkPos) " = 이 위치를 캡처"
        }
    }
    OnOk(*) {
        sel := 1
        for i, r in c.radios
            if r.Value
                sel := i
        if (sel = 1) {
            x := Trim(c.edX.Value)
            y := Trim(c.edY.Value)
            if !(IsInteger(x) && IsInteger(y))
                return Warn("X, Y 에 정수를 입력하세요.`n(" HotkeyLabel(App.hkPos) " 를 누르면 현재 커서 위치가 들어갑니다.)", d)
            newEv := { type: "MOVE", x: Integer(x), y: Integer(y), rel: (c.cbRel.Value = 1) }
        } else {
            ch := MouseChoices()[sel]
            newEv := { type: "MOUSE", btn: ch[1], mode: ch[2] }
        }
        CloseDialog(d)
        CommitEvent(editIdx, newEv)
    }
    for r in c.radios
        r.OnEvent("Click", Sync)
    c.btnOk.OnEvent("Click", OnOk)
    c.btnCancel.OnEvent("Click", (*) => CloseDialog(d))
    Sync()
    SetTimer(Tick, 80)
    App.dlgCleanup := () => SetTimer(Tick, 0)
    ShowDialog(d, 380, 208)
}

; 마우스 캡처 단축키: 현재 커서 위치를 "이동" 이벤트로
CapturePos() {
    if App.running
        return
    MouseGetPos(&mx, &my)
    if (App.dlgKind = "mouse" && App.dlgCtl) {
        c := App.dlgCtl
        SelectRadio(c.radios, 1)
        c.edX.Enabled := true, c.edY.Enabled := true, c.cbRel.Enabled := true
        c.edX.Value := mx
        c.edY.Value := my
        c.cbRel.Value := 0
    }
    if App.autoAddPos {
        AddEvent({ type: "MOVE", x: mx, y: my, rel: false })
    } else if !App.dlg {
        ShowMouseDialog(0, mx, my)
    }
    if App.beep
        SoundBeep(1500, 40)
}

; ------------------------------------------------------------------------------
;  [시간] 이벤트
; ------------------------------------------------------------------------------
ShowTimeDialog(editIdx := 0) {
    if !CanOpenDialog()
        return
    ev := editIdx ? App.events[editIdx] : ""
    d := OpenDialog(editIdx ? "시간 지연 수정" : "시간 지연", "time")
    c := {}
    d.AddText("x14 y19 w60", "지연 시간")
    c.edSec := d.AddEdit("x78 y16 w80", ev ? SecText(ev.ms) : "1.000")
    d.AddText("x164 y19 w80", "초")
    d.AddText("x14 y46 w230 cGray", "0.001초 ~ 3600초   (예: 0.5 = 0.5초)")
    c.btnOk := d.AddButton("x82 y74 w78 h26 Default", "확인")
    c.btnCancel := d.AddButton("x166 y74 w78 h26", "취소")
    App.dlgCtl := c

    OnOk(*) {
        ms := SecToMs(c.edSec.Value)
        if (ms < 1 || ms > 3600000)
            return Warn("0.001 ~ 3600 사이의 초 단위 숫자를 입력하세요.", d)
        CloseDialog(d)
        CommitEvent(editIdx, { type: "DELAY", ms: ms })
    }
    c.btnOk.OnEvent("Click", OnOk)
    c.btnCancel.OnEvent("Click", (*) => CloseDialog(d))
    ShowDialog(d, 258, 112)
    c.edSec.Focus()
    SendMessage(0xB1, 0, -1, c.edSec)      ; EM_SETSEL: 전체 선택
}

SecText(ms) {
    return Format("{:.3f}", ms / 1000)
}

; "0.5" 같은 초 단위 입력을 ms 정수로. 잘못된 입력이면 -1.
SecToMs(v) {
    v := Trim(v)
    if (v = "" || !IsNumber(v))
        return -1
    return Round(v * 1000)
}

; ------------------------------------------------------------------------------
;  설정 대화상자
; ------------------------------------------------------------------------------
ShowKeyboardSettings() {
    if !CanOpenDialog()
        return
    d := OpenDialog("키보드 설정", "set-key")
    c := {}
    d.AddText("x14 y19 w90", "시작 단축키")
    c.hkStart := d.AddHotkey("x108 y16 w120", App.hkStart)
    d.AddText("x14 y51 w90", "중지 단축키")
    c.hkStop := d.AddHotkey("x108 y48 w120", App.hkStop)
    c.btnOk := d.AddButton("x66 y84 w78 h26 Default", "확인")
    c.btnCancel := d.AddButton("x150 y84 w78 h26", "취소")
    App.dlgCtl := c
    OnOk(*) {
        if RegisterHotkeys(c.hkStart.Value, c.hkStop.Value, App.hkPos, d)
            CloseDialog(d)
    }
    c.btnOk.OnEvent("Click", OnOk)
    c.btnCancel.OnEvent("Click", (*) => CloseDialog(d))
    ShowDialog(d, 242, 122)
}

ShowMouseSettings() {
    if !CanOpenDialog()
        return
    d := OpenDialog("마우스 설정", "set-mouse")
    c := {}
    d.AddText("x14 y19 w110", "마우스 캡처 단축키")
    c.hkPos := d.AddHotkey("x128 y16 w120", App.hkPos)
    c.cbAuto := d.AddCheckBox("x14 y48 w240", "캡처하면 목록에 바로 추가")
    c.cbAuto.Value := App.autoAddPos
    c.btnOk := d.AddButton("x86 y80 w78 h26 Default", "확인")
    c.btnCancel := d.AddButton("x170 y80 w78 h26", "취소")
    App.dlgCtl := c
    OnOk(*) {
        if RegisterHotkeys(App.hkStart, App.hkStop, c.hkPos.Value, d) {
            App.autoAddPos := c.cbAuto.Value = 1
            CloseDialog(d)
        }
    }
    c.btnOk.OnEvent("Click", OnOk)
    c.btnCancel.OnEvent("Click", (*) => CloseDialog(d))
    ShowDialog(d, 262, 118)
}

ShowEtcSettings() {
    if !CanOpenDialog()
        return
    d := OpenDialog("기타 설정", "set-etc")
    c := {}
    d.AddText("x14 y19 w130", "이벤트 시작 시 지연")
    c.edStart := d.AddEdit("x150 y16 w70", SecText(App.startDelay))
    d.AddText("x226 y19 w20", "초")
    d.AddText("x14 y49 w130", "이벤트 간격 지연")
    c.edGap := d.AddEdit("x150 y46 w70", SecText(App.gap))
    d.AddText("x226 y49 w20", "초")
    d.AddText("x14 y79 w130", "반복 횟수 (0 = 무한)")
    c.edRepeat := d.AddEdit("x150 y76 w70 Number", App.repeatCnt)
    d.AddText("x226 y79 w20", "회")
    d.AddText("x14 y109 w130", "키 누르는 시간")
    c.edHold := d.AddEdit("x150 y106 w70 Number", App.keyHold)
    d.AddText("x226 y109 w24", "ms")
    d.AddText("x14 y139 w130", "입력 전송 방식")
    c.ddSend := d.AddDropDownList("x150 y135 w70", ["Input", "Event"])
    c.ddSend.Choose(App.sendMode = "Event" ? 2 : 1)
    d.AddText("x14 y166 w236 h1 0x10")
    c.cbFromSel := d.AddCheckBox("x14 y176 w236", "선택한 줄부터 시작")
    c.cbFromSel.Value := App.startFromSel
    c.cbTop := d.AddCheckBox("x14 y200 w236", "창을 항상 위에 표시")
    c.cbTop.Value := App.onTop
    c.cbBeep := d.AddCheckBox("x14 y224 w236", "시작 / 중지 / 캡처 때 효과음")
    c.cbBeep.Value := App.beep
    c.btnOk := d.AddButton("x88 y256 w78 h26 Default", "확인")
    c.btnCancel := d.AddButton("x172 y256 w78 h26", "취소")
    App.dlgCtl := c
    OnOk(*) {
        sd := SecToMs(c.edStart.Value)
        gp := SecToMs(c.edGap.Value)
        if (sd < 0 || sd > 3600000 || gp < 0 || gp > 3600000)
            return Warn("지연 시간은 0 ~ 3600 사이의 초 단위 숫자로 입력하세요.", d)
        App.startDelay   := sd
        App.gap          := gp
        App.repeatCnt    := ToInt(c.edRepeat.Value, 0)
        App.keyHold      := Max(1, ToInt(c.edHold.Value, 50))
        App.sendMode     := c.ddSend.Text
        App.startFromSel := c.cbFromSel.Value = 1
        App.onTop        := c.cbTop.Value = 1
        App.beep         := c.cbBeep.Value = 1
        win.Opt((App.onTop ? "+" : "-") "AlwaysOnTop")
        CloseDialog(d)
    }
    c.btnOk.OnEvent("Click", OnOk)
    c.btnCancel.OnEvent("Click", (*) => CloseDialog(d))
    ShowDialog(d, 264, 294)
}

; ==============================================================================
;  이벤트 목록 편집
; ==============================================================================
ValidKey(k) {
    return (k != "" && GetKeyName(k) != "") ? true : false
}

ToInt(v, def) {
    v := Trim(v)
    return IsInteger(v) ? Integer(v) : def
}

InList(v, list) {
    for item in StrSplit(list, ",")
        if (item = v)
            return true
    return false
}

CommitEvent(idx, ev) {
    if idx {                             ; idx = 수정할 이벤트 번호 (0 이면 새로 추가)
        App.events[idx] := ev
        RefreshList(idx + 1)
    } else {
        AddEvent(ev)
    }
}

; 목록의 1번 줄은 항상 "시작" 이므로  [목록 줄 번호] = [이벤트 번호] + 1.
; 추가 = 맨 끝에 붙임.  삽입 = 선택한 줄 바로 아래에 끼워 넣음("1. 시작"을 선택하면 맨 위).
AddEvent(ev) {
    if App.running
        return
    row := ui.lb.Value
    if (ui.rInsert.Value && row >= 1) {
        App.events.InsertAt(row, ev)
        RefreshList(row + 1)
    } else {
        App.events.Push(ev)
        RefreshList(App.events.Length + 1)
    }
}

EditRow(row) {
    if (row < 2 || App.running)          ; 1번 줄("시작")은 수정 대상이 아님
        return
    idx := row - 1
    switch App.events[idx].type {
        case "KEY", "TEXT":   ShowKeyDialog(idx)
        case "MOUSE", "MOVE": ShowMouseDialog(idx)
        case "DELAY":         ShowTimeDialog(idx)
    }
}

Describe(ev) {
    switch ev.type {
        case "KEY":
            if (ev.mode = "tap")
                return "키보드(" ev.key ")"
            return "키보드 " (ev.mode = "down" ? "누름(" : "뗌(") ev.key ")"
        case "TEXT":
            return "문장(" ev.text ")"
        case "MOUSE":
            if InStr(ev.btn, "Wheel")
                return ev.btn = "WheelUp" ? "휠 위로" : "휠 아래로"
            b := ev.btn = "Left" ? "왼쪽" : ev.btn = "Right" ? "오른쪽" : "가운데"
            m := ev.mode = "click" ? "클릭" : ev.mode = "double" ? "더블클릭" : ev.mode = "down" ? "누른 상태" : "뗀 상태"
            return b " " m
        case "MOVE":
            return (ev.rel ? "상대 이동(" : "커서 이동(") ev.x "," ev.y ")"
        case "DELAY":
            return "시간 지연(" SecText(ev.ms) "초)"
    }
    return ""
}

RefreshList(sel := 1) {               ; sel = 선택할 목록 줄 번호 (1 = "시작")
    items := ["1.  시작"]
    for i, ev in App.events
        items.Push((i + 1) ".  " Describe(ev))
    lb := ui.lb
    lb.Opt("-Redraw")
    lb.Delete()
    lb.Add(items)
    lb.Opt("+Redraw")
    if (sel < 1 || sel > items.Length)
        sel := 1
    lb.Choose(sel)
}

MoveSel(dir) {
    if App.running
        return
    idx := ui.lb.Value - 1
    dst := idx + dir
    if (idx < 1 || dst < 1 || dst > App.events.Length)
        return
    tmp := App.events[idx]
    App.events[idx] := App.events[dst]
    App.events[dst] := tmp
    RefreshList(dst + 1)
}

DeleteSel() {
    if App.running
        return
    row := ui.lb.Value
    if (row < 2)                         ; "시작" 줄은 지울 수 없음
        return
    App.events.RemoveAt(row - 1)
    RefreshList(Min(row, App.events.Length + 1))
}

ClearAll() {
    if App.running || App.dlg || App.events.Length = 0
        return
    win.Opt("+OwnDialogs")
    if (MsgBox("이벤트를 모두 지울까요?", APP_TITLE, "YesNo Icon?") != "Yes")
        return
    App.events := []
    RefreshList(1)
}

; ==============================================================================
;  실행 엔진
; ==============================================================================
; 고해상도 시계(ms). A_TickCount 는 약 15ms 단위로만 변해서 짧은 지연에 못 쓴다.
NowMs() {
    static freq := 0
    if !freq
        DllCall("QueryPerformanceFrequency", "Int64*", &freq)
    DllCall("QueryPerformanceCounter", "Int64*", &cnt := 0)
    return cnt * 1000.0 / freq
}

; ms 만큼 대기. 긴 구간은 일반 Sleep(단축키/GUI 처리됨), 마지막 25ms 는 1ms 단위로 정밀하게.
; interruptible = true 면 중지 요청 시 즉시 빠져나오며 false 를 돌려준다.
WaitMs(ms, interruptible) {
    endT := NowMs() + ms
    loop {
        if (interruptible && StopKeyDown())
            App.stopReq := true
        if (interruptible && App.stopReq)
            return false
        remain := endT - NowMs()
        if (remain <= 0)
            break
        if (remain > 25)
            Sleep(10)
        else
            DllCall("Sleep", "UInt", 1)
    }
    return true
}

SleepX(ms) {
    return (ms > 0) ? WaitMs(ms, true) : !App.stopReq
}

; ---- 키/버튼 누름과 뗌은 반드시 이 네 함수로만 한다. ----
; App.held 에 "지금 매크로가 눌러 둔 것"이 기록되고, 중지/종료 때 ReleaseAll() 이 전부 떼어 준다.
HoldKey(k) {
    if App.held.Has("K" k)               ; 이미 누르고 있으면 다시 보내지 않는다 (반복 때 같은 키가 초당 수백 번 눌리는 것 방지)
        return
    App.held["K" k] := k
    Send("{Blind}{" k " down}")
}
FreeKey(k) {
    Send("{Blind}{" k " up}")
    if App.held.Has("K" k)
        App.held.Delete("K" k)
}
HoldBtn(b) {
    if App.held.Has("M" b)
        return
    App.held["M" b] := b
    Click(b " Down")
}
FreeBtn(b) {
    Click(b " Up")
    if App.held.Has("M" b)
        App.held.Delete("M" b)
}

RunEvent(ev) {
    switch ev.type {
        case "KEY":
            k := ev.key
            if (ev.mode = "down")
                HoldKey(k)
            else if (ev.mode = "up")
                FreeKey(k)
            else {
                HoldKey(k)
                WaitMs(ev.hold, true)          ; 중지돼도 아래에서 반드시 뗀다
                FreeKey(k)
            }
        case "TEXT":
            SendText(ev.text)
        case "MOUSE":
            b := ev.btn
            if InStr(b, "Wheel") {
                Click(b)
            } else if (ev.mode = "down") {
                HoldBtn(b)
            } else if (ev.mode = "up") {
                FreeBtn(b)
            } else {
                HoldBtn(b)
                WaitMs(CLICK_HOLD, false)
                FreeBtn(b)
                if (ev.mode = "double") {
                    WaitMs(60, false)
                    HoldBtn(b)
                    WaitMs(CLICK_HOLD, false)
                    FreeBtn(b)
                }
            }
        case "MOVE":
            if ev.rel
                DllCall("mouse_event", "UInt", 0x0001, "Int", ev.x, "Int", ev.y, "UInt", 0, "UPtr", 0)
            else
                MouseMove(ev.x, ev.y, 0)
        case "DELAY":
            SleepX(ev.ms)
    }
}

; 매크로가 눌러 둔 키/버튼을 전부 뗀다. 중지 단축키, 실행 종료, 프로그램 종료 때 호출된다.
;  1) App.held 에 기록된 것 (매크로가 지금 누르고 있는 것)
;  2) 목록에 나오는 모든 키와 마우스 버튼 - 기록을 놓쳤더라도 안전하게 한 번 더
;  3) 조합키 중 "논리적으로는 눌림인데 물리적으로는 안 눌림" 인 것
;     (= 프로그램이 눌러 둔 채 남은 것. 사용자가 실제로 누르고 있는 키는 건드리지 않는다)
; 이미 떼어진 키에 '떼기'를 다시 보내는 것은 아무 영향이 없다.
ReleaseAll() {
    done := Map()
    for id, v in App.held.Clone() {
        if (SubStr(id, 1, 1) = "K")
            Send("{Blind}{" v " up}")
        else
            Click(v " Up")
        done[id] := true
    }
    App.held := Map()
    for ev in App.events {
        if (ev.type = "KEY" && !done.Has("K" ev.key)) {
            Send("{Blind}{" ev.key " up}")
            done["K" ev.key] := true
        } else if (ev.type = "MOUSE" && !InStr(ev.btn, "Wheel") && !done.Has("M" ev.btn)) {
            Click(ev.btn " Up")
            done["M" ev.btn] := true
        }
    }
    for k in ["LShift", "RShift", "LControl", "RControl", "LAlt", "RAlt", "LWin", "RWin"]
        if (!done.Has("K" k) && GetKeyState(k) && !GetKeyState(k, "P"))
            Send("{Blind}{" k " up}")
}

; fromMenu = true (메뉴의 [시작]으로 실행) 이면 대상 창으로 넘어갈 시간을 최소 3초 준다.
StartMacro(fromMenu := false) {
    if App.running
        return
    if App.dlg {
        Notify("열려 있는 창을 먼저 닫으세요.")
        return
    }
    if (App.events.Length = 0) {
        Notify("목록이 비어 있습니다.`n[키보드] [마우스] [시간] 으로 이벤트를 추가하세요.")
        return
    }
    App.repeatOn := ui.cbRepeat.Value = 1
    App.running := true
    App.stopReq := false
    App.held := Map()
    UpdateRunState()
    SendMode(App.sendMode)

    ClearStopKeyState()
    evs   := App.events.Clone()
    loops := App.repeatOn ? App.repeatCnt : 1      ; 0 = 무한
    first := 1
    if App.startFromSel {
        selRow := ui.lb.Value            ; 1 = "시작" 줄 → 처음부터
        if (selRow >= 2 && selRow - 1 <= evs.Length)
            first := selRow - 1
    }
    count := 0
    try {
        waitMs := App.startDelay
        if (fromMenu && waitMs < 3000)
            waitMs := 3000
        if (waitMs > 0) {
            endT := A_TickCount + waitMs
            while (A_TickCount < endT && !App.stopReq) {
                SetRunTitle(Ceil((endT - A_TickCount) / 1000) "초 후 시작")
                Sleep(50)
                if StopKeyDown()
                    App.stopReq := true
            }
        }
        if (!App.stopReq && App.beep)
            SoundBeep(1000, 60)

        while !App.stopReq {
            count += 1
            if (count = 1)
                SetRunTitle("실행중 1회")
            q0 := NowMs()
            t0 := A_TickCount
            if (t0 - App.statusTick >= 250) {
                App.statusTick := t0
                SetRunTitle("실행중 " count "회")
            }
            for i, ev in evs {
                if (count = 1 && i < first)     ; "선택한 줄부터 시작"은 첫 바퀴에만 적용
                    continue
                if StopKeyDown()
                    App.stopReq := true
                if App.stopReq
                    break
                RunEvent(ev)
                if (App.gap > 0 && ev.type != "DELAY")
                    SleepX(App.gap)
            }
            if (loops && count >= loops)
                break
            if (NowMs() - q0 < 2)
                Sleep(1)                     ; 지연이 전혀 없는 목록: CPU 를 다 먹지 않고, 단축키/메시지가 처리될 틈을 준다
            else
                Sleep(-1)                    ; 밀린 메시지(중지 단축키 등) 처리
        }
    } finally {
        ReleaseAll()
        App.running := false
        App.stopReq := false
        UpdateRunState()
        if App.beep
            SoundBeep(600, 60)
        SetRunTitle()
    }
}

; 중지. 실행 중이 아니어도 눌린 채 남은 키/버튼을 떼어 준다 (중지 단축키 = "전부 떼기" 로도 쓸 수 있게).
StopMacro() {
    if App.running
        App.stopReq := true
    ReleaseAll()
    SetTimer(ReleaseAllLater, -100)          ; 혹시 놓친 것이 있을까 봐 잠시 뒤 한 번 더
}

ReleaseAllLater() {
    if !App.running
        ReleaseAll()
}

; ==============================================================================
;  저장 / 불러오기   ([파일] 메뉴로 사용자가 고른 곳에만 .gmx 파일을 만든다. 형식은 v1.0 과 같음)
; ==============================================================================
Serialize(ev) {
    t := "`t"
    switch ev.type {
        case "KEY":   return "KEY" t ev.key t ev.mode t ev.hold
        case "TEXT":  return "TEXT" t RegExReplace(ev.text, "[\t\r\n]", " ")
        case "MOUSE": return "MOUSE" t ev.btn t ev.mode
        case "MOVE":  return "MOVE" t ev.x t ev.y t (ev.rel ? 1 : 0)
        case "DELAY": return "DELAY" t ev.ms
    }
    return ""
}

ParseLine(line) {
    p := StrSplit(line, "`t")
    if (p.Length < 2)
        return 0
    switch p[1] {
        case "KEY":
            if (p.Length >= 4 && ValidKey(p[2]) && InList(p[3], "tap,down,up") && IsInteger(p[4]))
                return { type: "KEY", key: p[2], mode: p[3], hold: Integer(p[4]) }
        case "TEXT":
            if (p[2] != "")
                return { type: "TEXT", text: p[2] }
        case "MOUSE":
            if (p.Length >= 3 && InList(p[2], "Left,Right,Middle,WheelUp,WheelDown") && InList(p[3], "click,double,down,up"))
                return { type: "MOUSE", btn: p[2], mode: p[3] }
        case "MOVE":
            if (p.Length >= 4 && IsInteger(p[2]) && IsInteger(p[3]))
                return { type: "MOVE", x: Integer(p[2]), y: Integer(p[3]), rel: (p[4] = "1") }
        case "DELAY":
            if (IsInteger(p[2]) && Integer(p[2]) >= 0)
                return { type: "DELAY", ms: Integer(p[2]) }
    }
    return 0
}

; 이벤트 목록을 줄 단위 텍스트로 (머리글 없음)
EventLines() {
    txt := ""
    for ev in App.events
        txt .= Serialize(ev) "`n"
    return txt
}

; 줄 배열 → { events, bad }   (빈 줄은 건너뜀)
ParseEventLines(lines) {
    evs := []
    bad := 0
    for line in lines {
        if (Trim(line, " `t") = "")
            continue
        ev := ParseLine(line)
        if ev
            evs.Push(ev)
        else
            bad += 1
    }
    return { events: evs, bad: bad }
}

; ---- 마지막 목록: 레지스트리의 LastList 값 (여러 줄 문자열) ----
WriteLastList(body) {
    if (body = "") {
        try RegDelete(REG_KEY, "LastList")
    } else
        RegWrite(body, "REG_MULTI_SZ", REG_KEY, "LastList")
}

SaveLastList() {
    WriteLastList(RTrim(EventLines(), "`n"))
}

LoadLastList() {
    try
        txt := RegRead(REG_KEY, "LastList")
    catch
        return
    App.events := ParseEventLines(StrSplit(txt, "`n", "`r")).events
    RefreshList(1)
}

SaveMacroFile(path, quiet := false) {
    txt := FILE_MAGIC "`n" EventLines()
    try {
        f := FileOpen(path, "w", "UTF-8")
        f.Write(txt)
        f.Close()
    } catch as err {
        if !quiet
            Warn("저장 실패: " err.Message)
        return false
    }
    return true
}

LoadMacroFile(path, quiet := false) {
    if !FileExist(path)
        return false
    try {
        txt := FileRead(path, "UTF-8")
    } catch as err {
        if !quiet
            Warn("파일을 읽지 못했습니다: " err.Message)
        return false
    }
    lines := StrSplit(txt, "`n", "`r")
    if (lines.Length = 0 || Trim(lines[1]) != FILE_MAGIC) {
        if !quiet
            Warn("이 프로그램으로 저장한 매크로 파일이 아닙니다.`n(G Macro 의 .gmc 파일은 읽을 수 없습니다.)")
        return false
    }
    lines.RemoveAt(1)
    r := ParseEventLines(lines)
    App.events := r.events
    RefreshList(1)
    if (!quiet)
        Notify("불러옴: 이벤트 " r.events.Length "개" (r.bad ? "  (해석 못 한 줄 " r.bad "개 건너뜀)" : ""))
    return true
}

SaveDialog() {
    if !CanOpenDialog()
        return
    win.Opt("+OwnDialogs")
    path := FileSelect("S16", A_ScriptDir "\macro.gmx", "매크로 저장", "매크로 파일 (*.gmx)")
    if (path = "")
        return
    if !RegExMatch(path, "i)\.gmx$")
        path .= ".gmx"
    if SaveMacroFile(path)
        Notify("저장됨: " path)
}

LoadDialog() {
    if !CanOpenDialog()
        return
    win.Opt("+OwnDialogs")
    path := FileSelect(1, A_ScriptDir, "매크로 불러오기", "매크로 파일 (*.gmx)")
    if (path != "")
        LoadMacroFile(path)
}
