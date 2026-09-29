#Requires AutoHotkey v2.0
#SingleInstance Force
;@Ahk2Exe-SetName YPMacro
;@Ahk2Exe-SetDescription YPMacro
;@Ahk2Exe-SetVersion 1.6.0.0
;@Ahk2Exe-SetMainIcon YPMacro.ico
;@Ahk2Exe-AddResource YPMFile.ico, 300
; ==============================================================================
;  YPMacro  v1.6  -  키보드/마우스 매크로   (AutoHotkey v2 스크립트)
;
;  메인 창은 G Macro ver 2.0 과 같은 배치:
;    - 메뉴:  파일 | 시작 | 설정 | 정보
;    - 왼쪽 이벤트 목록(첫 줄은 항상 "1. 시작"), 오른쪽 [키보드] [마우스] [시간] [지우기]
;    - 아래 (추가 / 삽입) 선택과 [반복] 체크
;    - 추가 = 맨 끝에 붙임,  삽입 = 선택한 줄 바로 아래에 끼워 넣음
;    - 줄 더블클릭 = 수정,  우클릭 = 수정/지우기/위로/아래로,  Delete 키 = 지우기
;  기본 단축키:  F9 = 시작,  F10 = 중지,  F8 = 마우스 캡처(현재 좌표를 이동 이벤트로 추가)
;  테마:  설정 → 테마 (기본 / 다크 / 라떼 / 해커).  G Macro 의 .gmc 파일은 [파일 → 불러오기]로 읽을 수 있다.
;  저장 파일은 .ypm:  [key w down], [delay 0.5], ... 형식의 영어 글 파일이라 메모장으로 직접 써도 된다 (아래 "저장 / 불러오기" 참고).
;    - 중지 키는 실행 중이 아닐 때 눌러도 "매크로가 눌러 둔 키/버튼"을 전부 떼어 준다.
;  설정과 마지막 목록은 레지스트리(HKEY_CURRENT_USER\Software\YPMacro)에 저장한다. exe 옆에 파일을 만들지 않는다.
;  (v1.2 까지 쓰던 키 이름 "YP Macro" 에 값이 있으면 처음 실행 때 새 키로 옮기고 옛 키는 지운다.)
;  (v1.1 까지 exe 옆에 만들던 YPMacro.ini / YPMacro_last.gmx, 옛 이름의 GMacroStyle.* 가 있으면
;   처음 실행 때 레지스트리로 옮기고 그 파일은 지운다.)
; ==============================================================================

SetWorkingDir(A_ScriptDir)
CoordMode("Mouse", "Screen")
CoordMode("ToolTip", "Screen")
CoordMode("Menu", "Screen")
SetMouseDelay(-1)
SetKeyDelay(-1, -1)
SetDefaultMouseSpeed(0)
SendMode("Event")               ; 기본 전송 방식. Input 은 보낼 때마다 키보드 훅을 잠깐 떼어서 중지 단축키를 놓칠 수 있다.
DllCall("winmm\timeBeginPeriod", "UInt", 1)     ; Sleep 정밀도를 1ms 단위로

APP_TITLE  := "YPMacro"
APP_VER    := "1.6"
APP_DATE   := "2026-09-29"                              ; 정보 창의 최종 수정일
APP_AUTHOR := "LEE YOUNGPYO"
APP_URL    := "https://github.com/Archi142857/yp-macro"
REG_KEY    := "HKEY_CURRENT_USER\Software\YPMacro"    ; 설정 + 마지막 목록 저장 위치
REG_KEY_OLD := "HKEY_CURRENT_USER\Software\YP Macro"  ; v1.2 까지 쓰던 위치 (처음 실행 때 새 키로 옮긴다)
FILE_MAGIC := "GMACROSTYLE1"                           ; v1.4 까지 저장하던 .gmx 파일의 첫 줄 (불러오기만)
CLICK_HOLD := 30        ; 마우스 클릭 시 버튼을 누르고 있는 시간(ms)

App := { events: [], running: false, stopReq: false, capturing: false
       , hk: Map(), hkEnabled: false, stopKey: { vk: 0, mods: [] }, held: Map(), statusTick: 0
       , dlg: "", dlgKind: "", dlgCtl: "", dlgCleanup: ""
       , theme: "default", T: "", defBtn: Map(), dimCtl: Map(), linkCtl: Map()
       , pid: DllCall("GetCurrentProcessId", "UInt") }
ui  := {}
win := ""

; ---- 테마 (색은 0xRRGGBB) ----
;  "기본" 은 G Macro 처럼: 윈도우 고전 모양 컨트롤(입체 버튼, 오목한 목록) + 굴림 9pt + 시스템 색.
;  다크·라떼는 기본과 글꼴·모양이 같고 색만 다르다 (style "bevel" = 입체 버튼을 테마 색으로 그림).
;  해커만 글꼴(VS Code 기본 글꼴 Consolas)과 모양(style "flat" = 테두리만 있는 납작한 버튼)이 다르다.
;  bg 창 배경 / menuBg 메뉴 줄 / panel 목록·입력칸 / text 글자 / dim 흐린 글자 / line 선
;  btn 버튼 면 / btnHi·btnLo·btnDk 입체 버튼의 밝은 선·그림자·진한 그림자 / btnLine 납작한 버튼 테두리
;  btnDown·btnDownText 누른 버튼(납작한 버튼) / btnText 버튼 글자 / sel·selText 목록에서 고른 줄
;  accent 링크·강조 / hover·hoverText 메뉴를 연 동안 / dark = 제목 표시줄·팝업 메뉴를 어둡게
THEME_ORDER := ["default", "dark", "latte", "hacker"]
THEMES := Map(
    "default", { name: "기본" },
    "latte",   { name: "라떼", font: "", style: "bevel", dark: false
               , bg: 0xF2EBDD, menuBg: 0xFAF5EC, panel: 0xFFFCF6, text: 0x3B3228, dim: 0x8E8272, line: 0xD6C9B4
               , btn: 0xEBE2D1, btnHi: 0xFFFCF5, btnLo: 0xBBAB91, btnDk: 0x6F6150, btnText: 0x3B3228
               , btnLine: 0xBBAB91, btnDown: 0xE0D4BF, btnDownText: 0x3B3228
               , sel: 0xB08A57, selText: 0xFFFFFF, accent: 0x8A5A2B, hover: 0xE3D5BD, hoverText: 0x3B3228 },
    "dark",    { name: "다크", font: "", style: "bevel", dark: true
               , bg: 0x2D2D30, menuBg: 0x252526, panel: 0x1E1E1E, text: 0xE6E6E6, dim: 0x8C8C8C, line: 0x46464B
               , btn: 0x3C3C3F, btnHi: 0x5F5F63, btnLo: 0x262628, btnDk: 0x0F0F10, btnText: 0xF0F0F0
               , btnLine: 0x5F5F63, btnDown: 0x4A4A4E, btnDownText: 0xFFFFFF
               , sel: 0x264F78, selText: 0xFFFFFF, accent: 0x3794FF, hover: 0x3E3E42, hoverText: 0xFFFFFF },
    "hacker",  { name: "해커", font: "Consolas", style: "flat", dark: true
               , bg: 0x000000, menuBg: 0x000000, panel: 0x000000, text: 0x00FF41, dim: 0x00A12A, line: 0x00A12A
               , btn: 0x000000, btnHi: 0x00A12A, btnLo: 0x00A12A, btnDk: 0x00A12A, btnText: 0x00FF41
               , btnLine: 0x00A12A, btnDown: 0x00FF41, btnDownText: 0x000000
               , sel: 0x00FF41, selText: 0x000000, accent: 0x00FF41, hover: 0x00FF41, hoverText: 0x000000 })

OnMessage(0x002B, OnDrawItem)       ; WM_DRAWITEM     테마 색으로 버튼과 목록 줄 그리기
OnMessage(0x002C, OnMeasureItem)    ; WM_MEASUREITEM  목록 줄 높이 (목록을 만들 때 오므로 BuildGui 보다 먼저)
OnMessage(0x0020, OnSetCursor)      ; WM_SETCURSOR    정보 창의 링크 위에서 손 모양 커서

MoveOldRegKey()
ImportLegacyFiles()
LoadSettings()
BuildGui()
SetupTray()
RegisterHotkeys(App.hkStart, App.hkStop, App.hkPos)
LoadLastList()
OnExit(ExitHandler)
SetRunTitle()
RegisterYpmType()                                       ; 예전에 연결했으면 지금 exe 경로로 맞춘다
if (A_Args.Length && FileExist(A_Args[1]))              ; .ypm 파일을 더블클릭해서 실행했을 때
    LoadMacroFile(A_Args[1])

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

; v1.2 까지는 레지스트리 키 이름이 "YP Macro"(띄어쓰기 있음) 였다.
; 옛 키에 값이 있으면 새 키로 옮기고(새 키에 이미 설정이 있으면 옮기지 않음), 옛 키는 지운다.
MoveOldRegKey() {
    vals := []
    try {
        Loop Reg, REG_KEY_OLD, "V"
            vals.Push({ name: A_LoopRegName, type: A_LoopRegType, value: RegRead() })
    }
    if (vals.Length = 0)
        return
    if !RegHasData()
        for v in vals
            try RegWrite(v.value, v.type, REG_KEY, v.name)
    try RegDeleteKey(REG_KEY_OLD)
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
    if !IsSet(App)                                          ; 프로그램이 끝나는 중
        return
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
    App.closeAfterAdd := CfgRead("CloseAfterAdd", "1") = "1"
    App.theme        := CfgRead("Theme", "default")
    if (App.theme = "light")                                ; v1.5 의 라이트 = 지금의 라떼
        App.theme := "latte"
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
        CfgWrite("CloseAfterAdd", App.closeAfterAdd ? 1 : 0)
        CfgWrite("Theme",        App.theme)
    }
}

ExitHandler(*) {
    App.stopReq := true
    try ReleaseAll()
    try SaveSettings()
    try SaveLastList()
    ; 프로그램이 끝나는 동안에도 창 메시지(커서 모양, 다시 그리기)가 오는데, 그때는 전역 변수가 이미 정리돼서
    ; 처리기가 App 을 읽다가 오류 창이 뜬다. 처리기를 먼저 떼고, 창도 여기서 없앤다.
    for msg, fn in Map(0x002B, OnDrawItem, 0x002C, OnMeasureItem, 0x0020, OnSetCursor, 0x0100, OnKeyDownMsg)
        OnMessage(msg, fn, 0)
    if App.dlgCleanup
        try App.dlgCleanup.Call()
    try win.Destroy()
    DllCall("winmm\timeEndPeriod", "UInt", 1)
    return 0
}

; ==============================================================================
;  메인 창
; ==============================================================================
BuildGui() {
    global win
    win := Gui("+MinimizeBox -MaximizeBox", APP_TITLE)
    win.SetFont("s9", ClassicFace())                        ; 테마 글꼴은 ApplyTheme → ThemeControls 에서 맞춘다
    win.OnEvent("Close", (*) => ExitApp())
    win.OnEvent("DropFiles", OnDropFiles)

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
    ui.mTheme := Menu()
    for key in THEME_ORDER
        ui.mTheme.Add(THEMES[key].name, PickTheme.Bind(key), "Radio")
    ui.mSet := Menu()
    ui.mSet.Add("키보드 설정...", (*) => ShowKeyboardSettings())
    ui.mSet.Add("마우스 설정...", (*) => ShowMouseSettings())
    ui.mSet.Add("기타 설정...", (*) => ShowEtcSettings())
    ui.mSet.Add()
    ui.mSet.Add("테마", ui.mTheme)
    ui.mBar := MenuBar()
    ui.mBar.Add("파일", ui.mFile)
    ui.mBar.Add("시작", ui.mRun)
    ui.mBar.Add("설정", ui.mSet)
    ui.mInfo := Menu()
    ui.mInfo.Add("YPMacro 정보...", (*) => ShowAbout())
    ui.mInfo.Add()
    ui.mInfo.Add("버그 신고...", (*) => OpenIssue("bug"))
    ui.mInfo.Add("기능 제안...", (*) => OpenIssue("feature"))
    ui.mInfo.Add("홈페이지 (GitHub)", (*) => Run(APP_URL))
    ui.mBar.Add("정보", ui.mInfo)

    ; ---- 테마용 메뉴 줄: 기본 테마가 아닐 때 윈도우 메뉴 막대 대신 보인다 (메뉴 막대는 색을 바꿀 수 없어서) ----
    ui.menuRow := []
    for i, name in ["파일", "시작", "설정", "정보"] {
        mi := win.AddText("x" (i = 1 ? 0 : 4 + (i - 1) * 38) " y0 w" (i = 1 ? 42 : 38) " h22 Center 0x200 Hidden", name)   ; 0x200 = 세로 가운데
        mi.OnEvent("Click", MenuRowClick.Bind(i))
        ui.menuRow.Push(mi)
    }
    ui.menuFill := win.AddText("x156 y0 w100 h22 Hidden")              ; 메뉴 줄의 나머지 부분
    ui.menuLine := win.AddText("x0 y22 w256 h1 Hidden")

    ; ---- 이벤트 목록 (첫 줄 "1. 시작" 은 고정).  테마 색으로 그리려고 줄을 직접 그린다 ----
    ; 0x100 = 높이를 줄 단위로 자르지 않음,  0x10 = 줄을 직접 그림(고정 높이),  0x40 = 글자 목록 유지
    ; 크기와 위치는 G Macro 창에서 잰 값 (창 안쪽 256 x 187)
    ui.lb := win.AddListBox("x14 y15 w158 h141 0x150")
    ui.lb.OnEvent("DoubleClick", (*) => EditRow(ui.lb.Value))
    ui.lb.OnEvent("ContextMenu", ListContextMenu)

    ; ---- 오른쪽 버튼 4개 -----------------------------------------------------
    b1 := win.AddButton("x180 y17 w68 h29", "키보드")
    b2 := win.AddButton("x180 y53 w68 h29", "마우스")
    b3 := win.AddButton("x180 y89 w68 h29", "시간")
    b4 := win.AddButton("x180 y125 w68 h29", "지우기")
    b1.OnEvent("Click", (*) => ShowKeyDialog())
    b2.OnEvent("Click", (*) => ShowMouseDialog())
    b3.OnEvent("Click", (*) => ShowTimeDialog())
    b4.OnEvent("Click", (*) => DeleteSel())

    ; ---- 아래:  (추가 / 삽입)  [반복] ----------------------------------------
    ui.rAppend := win.AddRadio("x15 y163 w48 h18 Group", "추가")
    ui.rInsert := win.AddRadio("x65 y163 w50 h18", "삽입")
    ui.cbRepeat := win.AddCheckBox("x120 y163 w56 h18", "반복")
    ui.rAppend.Value := App.insertMode ? 0 : 1
    ui.rInsert.Value := App.insertMode ? 1 : 0
    ui.cbRepeat.Value := App.repeatOn

    ; 테마 메뉴 줄이 보일 때는 아래 컨트롤들을 그 높이만큼 내린다: [컨트롤, x, y]
    ui.layout := [[ui.lb, 14, 15], [b1, 180, 17], [b2, 180, 53], [b3, 180, 89], [b4, 180, 125]
                , [ui.rAppend, 15, 163], [ui.rInsert, 65, 163], [ui.cbRepeat, 120, 163]]

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
    ApplyTheme(App.theme, true)
    win.Show("w256 h" MainHeight())
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

; ==============================================================================
;  테마  (설정 → 테마).  "기본" 은 윈도우 기본 모양 그대로, 나머지는 THEMES 의 색으로 직접 칠한다.
;   - 버튼: owner-draw 로 바꿔서 직접 그림 (기본 테마로 돌아오면 원래 버튼으로)
;   - 목록: 처음부터 owner-draw 목록이라 테마 색 / 윈도우 기본색으로 줄을 그림
;   - 라디오·체크박스: 어두운 테마에서는 옛날 모양(-Theme)으로 그려야 글자색이 먹는다
;   - 메뉴 막대는 색을 바꿀 수 없어서, 테마를 쓰는 동안은 같은 모양의 글자 메뉴 줄로 바꿔 보여 준다
;   - 제목 표시줄 색(윈도우 11)과 팝업 메뉴 어둡게(윈도우 10 1903 이상)는 되는 곳에서만
; ==============================================================================
PickTheme(key, *) {
    ApplyTheme(key)
    try CfgWrite("Theme", key)
}

; 메인 창에 테마를 적용한다. init = 창을 처음 만들 때 (아직 보이기 전)
ApplyTheme(key, init := false) {
    if !THEMES.Has(key)
        key := "default"
    App.theme := key
    App.T := T := (key = "default") ? "" : THEMES[key]
    SetMenuDarkMode(T && T.dark)
    for k in THEME_ORDER {
        if (k = key)
            ui.mTheme.Check(THEMES[k].name)
        else
            ui.mTheme.Uncheck(THEMES[k].name)
    }
    win.BackColor := T ? Hex6(T.bg) : "Default"
    win.MenuBar := T ? "" : ui.mBar
    ThemeControls(win)
    for mi in ui.menuRow {                                  ; 메뉴 줄: 해커는 테마 글꼴, 나머지는 윈도우 메뉴 막대 글꼴
        mi.Visible := T ? true : false
        if T {
            mi.SetFont("c" Hex6(T.text), T.style = "flat" ? T.font : MenuFace())
            mi.Opt("Background" Hex6(T.menuBg))
        }
    }
    ui.menuFill.Visible := T ? true : false
    ui.menuLine.Visible := T ? true : false
    if T {
        ui.menuFill.Opt("Background" Hex6(T.menuBg))
        ui.menuLine.Opt("Background" Hex6(T.line))
    }
    dy := T ? 23 : 0
    for item in ui.layout
        item[1].Move(item[2], item[3] + dy)
    SetTitleBarColors(win.Hwnd)
    if !init {
        win.Show("w256 h" MainHeight() " NA")
        RedrawAll(win.Hwnd)
    }
}

MainHeight() => App.T ? 210 : 187

; 창 안의 컨트롤 색과 글꼴을 현재 테마에 맞춘다 (메인 창과 모든 대화상자 공통). 글자 크기와 굵기는 그대로 둔다.
ThemeControls(g) {
    T := App.T
    face := (T && T.font != "") ? T.font : ClassicFace()   ; 해커 말고는 기본 테마와 같은 글꼴
    fg := T ? Hex6(T.text) : "Default"
    lines := []
    for hwnd, ctrl in g {
        switch ctrl.Type {
            case "Button":
                ctrl.SetFont(, face)
                SetOwnerDrawButton(ctrl, T ? true : false)      ; 테마에서는 직접 그림
                SetClassic(hwnd)                                ; 기본 테마: G Macro 처럼 입체 버튼
            case "ListBox":
                ctrl.SetFont("c" fg, face)
                ctrl.Opt(T ? "Background" Hex6(T.panel) : "BackgroundDefault")
                SetClassic(hwnd)                                ; 오목한 고전 테두리
                if (ctrl = ui.lb)
                    UpdateListItemHeight()
            case "Radio", "CheckBox":
                SetClassic(hwnd)                                ; 고전 모양이어야 글자색이 먹는다
                ctrl.SetFont("c" fg, face)
                ctrl.Opt(T ? "Background" Hex6(T.bg) : "BackgroundDefault")
            case "Text":
                if ((ControlGetStyle(hwnd) & 0x1F) = 0x10) {        ; 가로 구분선(SS_ETCHEDHORZ)은 아래에서 테마 색 선으로 바꾼다
                    lines.Push(ctrl)
                    continue
                }
                if App.linkCtl.Has(hwnd)
                    c := T ? Hex6(T.accent) : "0066CC"
                else if App.dimCtl.Has(hwnd)
                    c := T ? Hex6(T.dim) : "Gray"
                else
                    c := fg
                ctrl.SetFont("c" c, face)
                ctrl.Opt(T ? "Background" Hex6(T.bg) : "BackgroundDefault")
            case "Edit", "DDL", "ComboBox":
                ctrl.SetFont("c" fg, face)
                ctrl.Opt(T ? "Background" Hex6(T.panel) : "BackgroundDefault")
                SetClassic(hwnd)
            case "Hotkey":
                ctrl.SetFont(, face)
        }
    }
    if T {                                                  ; 대화상자에만 있고, 대화상자는 열 때마다 새로 만든다
        for ctrl in lines {
            ctrl.GetPos(&x, &y, &w)
            ctrl.Visible := false
            g.AddText("x" x " y" y " w" w " h1 Background" Hex6(T.line))
        }
    }
}

; 버튼을 테마 색으로 직접 그리게(BS_OWNERDRAW) 하거나 원래 버튼으로 되돌린다
SetOwnerDrawButton(ctrl, on) {
    style := ControlGetStyle(ctrl.Hwnd)
    kind := style & 0xF
    if on {
        if (kind = 0xB)
            return
        if (kind = 1)                                       ; BS_DEFPUSHBUTTON: 테두리를 강조색으로
            App.defBtn[ctrl.Hwnd] := true
        newKind := 0xB
    } else {
        if (kind != 0xB)
            return
        newKind := App.defBtn.Has(ctrl.Hwnd) ? 1 : 0
    }
    SendMessage(0x00F4, (style & 0xFFF0) | newKind, 1, ctrl.Hwnd)      ; BM_SETSTYLE + 다시 그리기
}

OnDrawItem(wParam, lParam, msg, hwnd) {
    if !IsSet(App)                                          ; 프로그램이 끝나는 중
        return
    kind := NumGet(lParam, 0, "UInt")
    if (kind != 2 && kind != 4)                             ; ODT_LISTBOX, ODT_BUTTON 만
        return
    o := (A_PtrSize = 8) ? 24 : 20                          ; DRAWITEMSTRUCT 의 hwndItem 위치
    item  := NumGet(lParam, 8, "UInt")
    state := NumGet(lParam, 16, "UInt")
    ctl   := NumGet(lParam, o, "Ptr")
    dc    := NumGet(lParam, o + A_PtrSize, "Ptr")
    prc   := lParam + o + 2 * A_PtrSize                     ; rcItem (RECT) 주소
    if (kind = 4)
        DrawThemedButton(ctl, dc, prc, state)
    else
        DrawListItem(ctl, dc, prc, item, state)
    return true
}

OnMeasureItem(wParam, lParam, msg, hwnd) {
    if (NumGet(lParam, 0, "UInt") = 2) {                    ; 목록: 임시 높이. 만든 뒤 UpdateListItemHeight 가 글꼴에 맞춘다
        NumPut("UInt", Round(16 * A_ScreenDPI / 96), lParam, 16)
        return true
    }
}

OnSetCursor(wParam, lParam, msg, hwnd) {
    if !IsSet(App)                                          ; 프로그램이 끝나는 중
        return
    if App.linkCtl.Has(wParam) {
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", 32649, "Ptr"))     ; IDC_HAND
        return true
    }
}

DrawThemedButton(ctl, dc, prc, state) {
    T := App.T
    if !T
        return
    x1 := NumGet(prc, 0, "Int"), y1 := NumGet(prc, 4, "Int"), x2 := NumGet(prc, 8, "Int"), y2 := NumGet(prc, 12, "Int")
    down := state & 0x1
    focus := (state & 0x10) && !(state & 0x200)             ; 키보드로 포커스를 옮겼을 때만 표시
    if (T.style = "bevel") {
        ; 윈도우 고전 입체 버튼(G Macro 의 버튼)과 같은 모양을 테마 색으로. 기본 버튼·포커스 버튼은 진한 테두리가 한 겹 더.
        FillRectXY(dc, x1, y1, x2, y2, T.btn)
        if (App.defBtn.Has(ctl) || (state & 0x10)) {
            FrameXY(dc, x1, y1, x2, y2, T.btnDk)
            x1 += 1, y1 += 1, x2 -= 1, y2 -= 1
        }
        if down {
            FrameXY(dc, x1, y1, x2, y2, T.btnLo)            ; 눌림: 납작한 그림자 테두리
        } else {
            FillRectXY(dc, x1, y1, x2 - 1, y1 + 1, T.btnHi)             ; 위, 왼쪽 밝은 선
            FillRectXY(dc, x1, y1, x1 + 1, y2 - 1, T.btnHi)
            FillRectXY(dc, x1, y2 - 1, x2, y2, T.btnDk)                 ; 아래, 오른쪽 진한 그림자
            FillRectXY(dc, x2 - 1, y1, x2, y2, T.btnDk)
            FillRectXY(dc, x1 + 1, y2 - 2, x2 - 1, y2 - 1, T.btnLo)     ; 안쪽 그림자
            FillRectXY(dc, x2 - 2, y1 + 1, x2 - 1, y2 - 1, T.btnLo)
        }
        fg := (state & 0x4) ? T.dim : T.btnText
        off := down ? 1 : 0                                 ; 누르면 글자가 한 칸 내려간다
    } else {
        ; 해커: 테두리만 있는 납작한 버튼, 누르면 색이 뒤집힌다
        FillRectXY(dc, x1, y1, x2, y2, down ? T.btnDown : T.btn)
        FrameXY(dc, x1, y1, x2, y2, App.defBtn.Has(ctl) ? T.accent : T.btnLine)
        fg := (state & 0x4) ? T.dim : down ? T.btnDownText : T.btnText
        off := 0
    }
    tr := Buffer(16)
    NumPut("Int", NumGet(prc, 0, "Int") + off, "Int", NumGet(prc, 4, "Int") + off
         , "Int", NumGet(prc, 8, "Int") + off, "Int", NumGet(prc, 12, "Int") + off, tr)
    of := DllCall("SelectObject", "Ptr", dc, "Ptr", SendMessage(0x0031, 0, 0, ctl), "Ptr")     ; WM_GETFONT
    DllCall("SetBkMode", "Ptr", dc, "Int", 1)                                                ; TRANSPARENT
    DllCall("SetTextColor", "Ptr", dc, "UInt", BGR(fg))
    DllCall("DrawText", "Ptr", dc, "Str", ControlGetText(ctl), "Int", -1, "Ptr", tr, "UInt", 0x25)    ; 가운데, 한 줄
    DllCall("SelectObject", "Ptr", dc, "Ptr", of)
    if focus {
        fx1 := NumGet(prc, 0, "Int") + 4, fy1 := NumGet(prc, 4, "Int") + 4
        fx2 := NumGet(prc, 8, "Int") - 4, fy2 := NumGet(prc, 12, "Int") - 4
        if (T.style = "bevel") {                            ; 고전 버튼처럼 점선
            fr := Buffer(16)
            NumPut("Int", fx1, "Int", fy1, "Int", fx2, "Int", fy2, fr)
            DllCall("DrawFocusRect", "Ptr", dc, "Ptr", fr)
        } else
            FrameXY(dc, fx1, fy1, fx2, fy2, down ? T.btnDownText : T.accent)
    }
}

FillRectXY(dc, x1, y1, x2, y2, rgb) {
    r := Buffer(16)
    NumPut("Int", x1, "Int", y1, "Int", x2, "Int", y2, r)
    br := DllCall("CreateSolidBrush", "UInt", BGR(rgb), "Ptr")
    DllCall("FillRect", "Ptr", dc, "Ptr", r, "Ptr", br)
    DllCall("DeleteObject", "Ptr", br)
}

FrameXY(dc, x1, y1, x2, y2, rgb) {
    r := Buffer(16)
    NumPut("Int", x1, "Int", y1, "Int", x2, "Int", y2, r)
    br := DllCall("CreateSolidBrush", "UInt", BGR(rgb), "Ptr")
    DllCall("FrameRect", "Ptr", dc, "Ptr", r, "Ptr", br)
    DllCall("DeleteObject", "Ptr", br)
}

DrawListItem(ctl, dc, prc, item, state) {
    T := App.T
    sel := state & 0x1
    if T {
        bg := BGR(sel ? T.sel : T.panel)
        fg := BGR(sel ? T.selText : T.text)
    } else {                                                ; 기본 테마: 윈도우 목록과 같은 색
        bg := DllCall("GetSysColor", "Int", sel ? 13 : 5, "UInt")
        fg := DllCall("GetSysColor", "Int", sel ? 14 : 8, "UInt")
    }
    br := DllCall("CreateSolidBrush", "UInt", bg, "Ptr")
    DllCall("FillRect", "Ptr", dc, "Ptr", prc, "Ptr", br)
    DllCall("DeleteObject", "Ptr", br)
    if (item != 0xFFFFFFFF) {
        len := SendMessage(0x018A, item, 0, ctl)            ; LB_GETTEXTLEN
        buf := Buffer((len + 1) * 2, 0)
        SendMessage(0x0189, item, buf.Ptr, ctl)             ; LB_GETTEXT
        tr := Buffer(16)
        NumPut("Int", NumGet(prc, 0, "Int") + 3, "Int", NumGet(prc, 4, "Int"), "Int", NumGet(prc, 8, "Int") - 2, "Int", NumGet(prc, 12, "Int"), tr)
        of := DllCall("SelectObject", "Ptr", dc, "Ptr", SendMessage(0x0031, 0, 0, ctl), "Ptr")
        DllCall("SetBkMode", "Ptr", dc, "Int", 1)
        DllCall("SetTextColor", "Ptr", dc, "UInt", fg)
        DllCall("DrawText", "Ptr", dc, "Ptr", buf, "Int", -1, "Ptr", tr, "UInt", 0x8824)     ; 한 줄, 세로 가운데, & 그대로, 넘치면 …
        DllCall("SelectObject", "Ptr", dc, "Ptr", of)
    }
    if ((!T || T.style = "bevel") && (state & 0x10) && !(state & 0x200))
        DllCall("DrawFocusRect", "Ptr", dc, "Ptr", prc)
}

; 목록 줄 높이를 지금 글꼴에 맞춘다 (윈도우 목록과 같게 = G Macro 와 같게. 해커만 2px 여유)
UpdateListItemHeight() {
    lb := ui.lb.Hwnd
    dc := DllCall("GetDC", "Ptr", lb, "Ptr")
    of := DllCall("SelectObject", "Ptr", dc, "Ptr", SendMessage(0x0031, 0, 0, lb), "Ptr")
    tm := Buffer(64, 0)
    DllCall("GetTextMetrics", "Ptr", dc, "Ptr", tm)
    DllCall("SelectObject", "Ptr", dc, "Ptr", of)
    DllCall("ReleaseDC", "Ptr", lb, "Ptr", dc)
    SendMessage(0x01A0, 0, NumGet(tm, 0, "Int") + ((App.T && App.T.style = "flat") ? 2 : 0), lb)      ; LB_SETITEMHEIGHT
}

; 테마 메뉴 줄의 [파일] [시작] [설정] [정보]
MenuRowClick(i, ctrl, *) {
    T := App.T
    if T {                                                  ; 메뉴가 열려 있는 동안 강조
        ctrl.Opt("Background" Hex6(T.hover))
        ctrl.SetFont("c" Hex6(T.hoverText))
    }
    WinGetPos(&x, &y, &w, &h, ctrl.Hwnd)
    m := [ui.mFile, ui.mRun, ui.mSet, ui.mInfo][i]
    m.Show(x, y + h)
    if (T && T = App.T) {                                   ; 메뉴에서 테마를 바꿨으면 ApplyTheme 가 이미 칠했다
        ctrl.Opt("Background" Hex6(T.menuBg))
        ctrl.SetFont("c" Hex6(T.text))
    }
}

; 제목 표시줄: 어두운 테마면 어둡게(윈도우 10 20H1 이상), 테마 색으로 칠하기(윈도우 11). 안 되는 곳에서는 그냥 넘어간다.
SetTitleBarColors(hwnd) {
    T := App.T
    dark := (T && T.dark) ? 1 : 0
    if DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 20, "Int*", &dark, "UInt", 4)
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 19, "Int*", &dark, "UInt", 4)
    for attr, c in Map(35, T ? BGR(T.bg) : 0xFFFFFFFF, 36, T ? BGR(T.text) : 0xFFFFFFFF, 34, T ? BGR(T.line) : 0xFFFFFFFF)
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", attr, "UInt*", &c, "UInt", 4)   ; 캡션 / 제목 글자 / 테두리
}

; 팝업 메뉴(드롭다운, 우클릭, 트레이)를 어둡게. 윈도우 10 1903 이상의 uxtheme 비공개 함수(135, 136)라 없으면 넘어간다.
SetMenuDarkMode(dark) {
    static pSet := 0, pFlush := 0, tried := false
    if !tried {
        tried := true
        if (VerCompare(A_OSVersion, "10.0.18362") >= 0) {
            hUx := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
            if !hUx
                hUx := DllCall("LoadLibrary", "Str", "uxtheme", "Ptr")
            if hUx {
                pSet := DllCall("GetProcAddress", "Ptr", hUx, "Ptr", 135, "Ptr")
                pFlush := DllCall("GetProcAddress", "Ptr", hUx, "Ptr", 136, "Ptr")
            }
        }
    }
    if (pSet && pFlush) {
        DllCall(pSet, "Int", dark ? 2 : 0)                  ; 2 = 항상 어둡게, 0 = 기본
        DllCall(pFlush)
    }
}

; 컨트롤의 윈도우 테마를 끈다 → 고전 모양(G Macro 와 같은 입체 테두리)으로 그려지고, 라디오·체크박스에 글자색이 먹는다.
; (AHK 의 Opt("-Theme") 는 컨트롤을 만들 때만 적용되고 만든 뒤에는 아무 효과가 없어서 직접 부른다)
SetClassic(hwnd) => DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", "", "Str", "")

; 윈도우 메뉴 막대 글꼴 이름. 테마 메뉴 줄을 기본 테마의 메뉴 막대와 같은 글꼴로 보이게 한다.
MenuFace() {
    static face := ""
    if (face = "") {
        ncm := Buffer(504, 0)                               ; NONCLIENTMETRICSW
        NumPut("UInt", 504, ncm, 0)
        if DllCall("SystemParametersInfo", "UInt", 0x29, "UInt", 504, "Ptr", ncm, "UInt", 0)   ; SPI_GETNONCLIENTMETRICS
            face := StrGet(ncm.Ptr + 252, 32, "UTF-16")     ; lfMenuFont.lfFaceName
        if (face = "")
            face := "Malgun Gothic"
    }
    return face
}

RedrawAll(hwnd) => DllCall("RedrawWindow", "Ptr", hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0485)    ; 지우고 다시, 테두리·자식 포함

; 기본 테마 글꼴: G Macro 와 같은 굴림. 굴림이 없는 윈도우(한국어 추가 글꼴 없음)에서는 맑은 고딕.
ClassicFace() {
    static face := ""
    if (face = "")
        face := FontExists("Gulim") ? "Gulim" : "Malgun Gothic"
    return face
}

; 글꼴을 만들어 실제로 골라진 이름을 본다. 없는 글꼴이면 윈도우가 다른 글꼴로 바꿔 준다.
FontExists(name) {
    dc := DllCall("GetDC", "Ptr", 0, "Ptr")
    hf := DllCall("CreateFont", "Int", -12, "Int", 0, "Int", 0, "Int", 0, "Int", 400, "UInt", 0, "UInt", 0, "UInt", 0
        , "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "Str", name, "Ptr")          ; DEFAULT_CHARSET
    of := DllCall("SelectObject", "Ptr", dc, "Ptr", hf, "Ptr")
    buf := Buffer(128, 0)
    DllCall("GetTextFace", "Ptr", dc, "Int", 64, "Ptr", buf)
    DllCall("SelectObject", "Ptr", dc, "Ptr", of)
    DllCall("DeleteObject", "Ptr", hf)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", dc)
    face := StrGet(buf)
    return InStr(face, name) || (name = "Gulim" && InStr(face, "굴림"))
}
BGR(c) => ((c & 0xFF) << 16) | (c & 0xFF00) | ((c >> 16) & 0xFF)
Hex6(c) => Format("{:06X}", c)

FillRectColor(dc, prc, rgb) {
    br := DllCall("CreateSolidBrush", "UInt", BGR(rgb), "Ptr")
    DllCall("FillRect", "Ptr", dc, "Ptr", prc, "Ptr", br)
    DllCall("DeleteObject", "Ptr", br)
}

; 흐린 글자 / 링크로 표시해 두면 ThemeControls 가 그 색으로 칠한다
MarkDim(ctrl) {
    App.dimCtl[ctrl.Hwnd] := true
    return ctrl
}
MarkLink(ctrl) {
    App.linkCtl[ctrl.Hwnd] := true
    return ctrl
}

; 짧은 안내를 창 아래쪽에 말풍선으로 잠깐 보여 준다 (원본처럼 상태 표시줄은 없음)
Notify(msg, ms := 2500) {
    try {
        win.GetPos(&wx, &wy, &ww, &wh)
        ToolTip(msg, wx + 8, wy + wh - 4)
        SetTimer(() => ToolTip(), -ms)
    }
}

; 제목 표시줄에 상태 표시. 창이 좁아서 잘리지 않게 짧게 쓴다.
;  대기: "YPMacro v1.3",  실행 중: "실행중 12회" / "실행중 35만회",  시작 전: "3초 후 시작"
SetRunTitle(state := "") {
    win.Title := (state = "") ? APP_TITLE " v" APP_VER : state
}

; 반복 횟수를 제목에 들어갈 만큼 짧게:  9999 → "9999",  352817 → "35만",  123456789 → "1억"
CountLabel(n) {
    if (n < 10000)
        return String(n)
    if (n < 100000000)
        return (n // 10000) "만"
    return (n // 100000000) "억"
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

; [정보] 창: 프로그램 / 개발자 정보.  왼쪽에 아이콘, 오른쪽에 정보.
ShowAbout() {
    if !CanOpenDialog()
        return
    d := OpenDialog(APP_TITLE " 정보", "about")
    c := {}
    try d.AddPicture("x18 y18 w48 h48 Icon1", A_IsCompiled ? A_ScriptFullPath : A_ScriptDir "\YPMacro.ico")
    d.SetFont("s13 bold")
    d.AddText("x84 y14 w258", APP_TITLE "  v" APP_VER)
    d.SetFont("s9 norm")
    MarkDim(d.AddText("x84 y42 w258", "목록으로 만드는 키보드/마우스 매크로"))
    d.AddText("x84 y70 w258", "개발자:  " APP_AUTHOR)
    d.SetFont("underline")
    lnk := MarkLink(d.AddText("x84 y90 w258", RegExReplace(APP_URL, "^https://")))
    d.SetFont("norm")
    lnk.OnEvent("Click", (*) => Run(APP_URL))
    d.AddText("x84 y110 w258", "최종 수정일:  " APP_DATE)
    d.AddText("x84 y130 w258", "라이선스:  MIT License")
    d.AddText("x18 y158 w324 h1 0x10")                     ; 가로 구분선
    MarkDim(d.AddText("x18 y168 w324", "단축키:  " HotkeyHelp()))
    MarkDim(d.AddText("x18 y188 w324", "설정은 이 PC에만 저장되며 밖으로 보내지 않습니다."))
    d.SetFont("underline")
    fb := MarkLink(d.AddText("x18 y208 w324", "버그 신고 · 기능 제안"))
    d.SetFont("norm")
    fb.OnEvent("Click", (*) => OpenIssue())
    MarkDim(d.AddText("x18 y228 w324", "(c) 2026 " APP_AUTHOR "  ·  AHK v" A_AhkVersion))
    c.btnOk := d.AddButton("x141 y258 w78 h26 Default", "확인")
    c.btnOk.OnEvent("Click", (*) => CloseDialog(d))
    ShowDialog(d, 360, 296)
}

; 버그 신고 / 기능 제안: GitHub 이슈 양식을 브라우저로 연다. 버그 신고는 버전·윈도우·테마를 미리 채워 둔다.
OpenIssue(kind := "") {
    if (kind = "")
        url := APP_URL "/issues/new/choose"
    else if (kind = "bug")
        url := APP_URL "/issues/new?template=bug_report.yml&version=" UriEncode("v" APP_VER)
             . "&os=" UriEncode(WindowsLabel()) "&theme=" UriEncode(THEMES[App.theme].name)
    else
        url := APP_URL "/issues/new?template=feature_request.yml"
    try Run(url)
    catch
        Warn("브라우저를 열지 못했습니다. 아래 주소로 들어가 주세요.`n`n" url)
}

WindowsLabel() {
    v := StrSplit(A_OSVersion, ".")
    if (v.Length < 3 || Integer(v[1]) < 10)
        return "Windows " A_OSVersion
    return (Integer(v[3]) >= 22000 ? "Windows 11" : "Windows 10") " (" A_OSVersion ")"
}

; 주소에 넣을 수 있게 UTF-8 로 %XX 인코딩
UriEncode(s) {
    buf := Buffer(StrPut(s, "UTF-8"))
    StrPut(s, buf, "UTF-8")
    out := ""
    loop buf.Size - 1 {
        b := NumGet(buf, A_Index - 1, "UChar")
        if (b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A) || b = 0x2D || b = 0x2E || b = 0x5F || b = 0x7E
            out .= Chr(b)
        else
            out .= Format("%{:02X}", b)
    }
    return out
}

; ==============================================================================
;  단축키
; ==============================================================================
; quiet = 알림 창을 띄우지 않고 false 만 돌려준다 (까닭은 App.hkError).
RegisterHotkeys(newStart, newStop, newPos, owner := "", quiet := false) {
    HkFail(msg) {
        App.hkError := msg
        return quiet ? false : Warn(msg, owner)
    }
    if (newStart = "" || newStop = "" || newPos = "")
        return HkFail("단축키가 비어 있습니다.")
    if (newStart = newStop || newStart = newPos || newStop = newPos)
        return HkFail("시작 / 중지 / 마우스 캡처 단축키가 서로 겹칩니다.")

    ; "*" = 다른 조합키가 눌려 있어도 반응.  이게 없으면 매크로가 Shift/Ctrl/Alt 를 누른 채일 때
    ;       중지 키가 "Shift+F10" 으로 보여서 반응하지 않고, 매크로가 멈추지 않는다.
    ; "$" = 훅 방식 (매크로가 보내는 키에는 반응하지 않도록)
    ; #HotIf 조건은 일부러 쓰지 않는다 - 훅이 키를 볼 때마다 메인 스레드에 물어보고 기다리는 구조라서
    ; 매크로가 바쁘면 시스템 키보드 입력이 통째로 멈추고 중지 키도 버려진다. 대신 설정 창이 열린 동안만 끈다.
    Unbind() {
        for , oldKey in App.hk
            try Hotkey("*$" oldKey, "Off")
        App.hk := Map()
    }
    Bind(s, p, c) {
        Hotkey("*$" s, (*) => StartMacro(false), "On"), App.hk["start"] := s
        Hotkey("*$" p, (*) => StopMacro(), "On"),       App.hk["stop"] := p
        Hotkey("*$" c, (*) => CapturePos(), "On"),      App.hk["pos"] := c
    }
    Unbind()
    try {
        Bind(newStart, newStop, newPos)
    } catch as err {
        Unbind()                                            ; 쓰던 단축키로 되돌린다
        if (App.hkStart != "" && (App.hkStart != newStart || App.hkStop != newStop || App.hkPos != newPos))
            try Bind(App.hkStart, App.hkStop, App.hkPos)
        return HkFail("단축키 등록 실패: " err.Message)
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
    d.SetFont("s9", App.T ? App.T.font : ClassicFace())
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
    if App.T
        d.BackColor := Hex6(App.T.bg)
    ThemeControls(d)
    SetTitleBarColors(d.Hwnd)
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
    for hwnd in d                                           ; 테마용 표시 정리
        for m in [App.defBtn, App.dimCtl, App.linkCtl]
            if m.Has(hwnd)
                m.Delete(hwnd)
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
        FinishEventDialog(d, editIdx, newEv)
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
    d.AddText("x76 y18 w14", "X")
    c.edX := d.AddEdit("x90 y14 w52", presetX)
    d.AddText("x150 y18 w14", "Y")
    c.edY := d.AddEdit("x164 y14 w52", presetY)
    c.cbRel := d.AddCheckBox("x226 y16 w150", "상대 이동(게임 시점)")
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
        FinishEventDialog(d, editIdx, newEv)
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
    MarkDim(d.AddText("x14 y46 w230 cGray", "0.001초 ~ 3600초   (예: 0.5 = 0.5초)"))
    c.btnOk := d.AddButton("x82 y74 w78 h26 Default", "확인")
    c.btnCancel := d.AddButton("x166 y74 w78 h26", "취소")
    App.dlgCtl := c

    OnOk(*) {
        ms := SecToMs(c.edSec.Value)
        if (ms < 1 || ms > 3600000)
            return Warn("0.001 ~ 3600 사이의 초 단위 숫자를 입력하세요.", d)
        FinishEventDialog(d, editIdx, { type: "DELAY", ms: ms })
        if (!editIdx && !App.closeAfterAdd) {
            c.edSec.Focus()
            SendMessage(0xB1, 0, -1, c.edSec)
        }
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
    c.cbClose := d.AddCheckBox("x14 y200 w236", "이벤트 추가 후 창 닫기")
    c.cbClose.Value := App.closeAfterAdd
    c.cbTop := d.AddCheckBox("x14 y224 w236", "창을 항상 위에 표시")
    c.cbTop.Value := App.onTop
    c.cbBeep := d.AddCheckBox("x14 y248 w236", "시작 / 중지 / 캡처 때 효과음")
    c.cbBeep.Value := App.beep
    c.btnOk := d.AddButton("x88 y280 w78 h26 Default", "확인")
    c.btnCancel := d.AddButton("x172 y280 w78 h26", "취소")
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
        App.closeAfterAdd := c.cbClose.Value = 1
        App.onTop        := c.cbTop.Value = 1
        App.beep         := c.cbBeep.Value = 1
        win.Opt((App.onTop ? "+" : "-") "AlwaysOnTop")
        CloseDialog(d)
    }
    c.btnOk.OnEvent("Click", OnOk)
    c.btnCancel.OnEvent("Click", (*) => CloseDialog(d))
    ShowDialog(d, 264, 318)
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

; 이벤트 창의 [확인]: 목록에 넣고 창을 닫는다. "이벤트 추가 후 창 닫기"를 끄면 새로 추가할 때는 창을 열어 둔다.
FinishEventDialog(d, editIdx, ev) {
    keepOpen := !editIdx && !App.closeAfterAdd
    if !keepOpen
        CloseDialog(d)
    CommitEvent(editIdx, ev)
    if keepOpen
        Notify("추가됨: " Describe(ev), 1200)
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
                SetRunTitle("실행중 " CountLabel(count) "회")
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
;  저장 / 불러오기   ([파일] 메뉴로 사용자가 고른 곳에만 .ypm 파일을 만든다. 예전 .gmx 와 G Macro .gmc 는 불러오기만)
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

; ---- .ypm 매크로 파일:  [동작], [동작], ...   (UTF-8 글 파일. 메모장으로 직접 써도 된다) ----
;  [ ] 하나가 동작 하나이고 쉼표로 구분한다. 대괄호 밖의 글(줄바꿈, 설명)은 무시한다. 파일 내용은 영어로 쓴다.
;  맨 앞 설정 한 줄(없어도 됨):
;    [settings theme=dark start=F9 stop=F10 capture=F8 repeat=on loops=0 startdelay=0 interval=0 keyhold=50ms mode=event]
;  [key w]  [key w down]  [key w up]  [key a 80ms]  [key ctrl+c]  [text Hello]
;  [left click]  [right doubleclick]  [left down]  [left up]  [middle click]  [wheel up]  [wheel down]
;  [move 800 465]  [moveby 10 -5]  [delay 0.5]  [delay 500ms]
;  v1.5 에서 저장한 한국어 파일([키 w 누름], [지연 0.5] ...)도 그대로 읽는다.
;  대괄호 안에서 ] 는 \], \ 는 \\ 로 쓴다 (text 에 넣을 때만 필요).
SaveMacroFile(path, quiet := false) {
    parts := [YpmSettingsLine()]
    for ev in App.events
        if ((a := YpmAction(ev)) != "")
            parts.Push(a)
    txt := ""
    for i, a in parts
        txt .= a (i < parts.Length ? ",`r`n" : "`r`n")
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

; 지금 설정 → "[settings ...]" 한 줄
YpmSettingsLine() {
    return "[settings theme=" App.theme " start=" HotkeyLabel(App.hkStart) " stop=" HotkeyLabel(App.hkStop)
         . " capture=" HotkeyLabel(App.hkPos) " repeat=" (ui.cbRepeat.Value ? "on" : "off") " loops=" App.repeatCnt
         . " startdelay=" SecShort(App.startDelay) " interval=" SecShort(App.gap) " keyhold=" App.keyHold "ms"
         . " mode=" StrLower(App.sendMode) "]"
}

SecShort(ms) => RTrim(RTrim(Format("{:.3f}", ms / 1000), "0"), ".")

; 이벤트 하나 → 동작 글자 하나 "[...]"
YpmAction(ev) {
    switch ev.type {
        case "KEY":
            s := "key " ev.key (ev.mode = "down" ? " down" : ev.mode = "up" ? " up" : "")
            if (ev.mode = "tap" && ev.hold != App.keyHold)
                s .= " " ev.hold "ms"
        case "TEXT":
            s := "text " ev.text
        case "MOUSE":
            if InStr(ev.btn, "Wheel")
                s := "wheel " (ev.btn = "WheelUp" ? "up" : "down")
            else
                s := StrLower(ev.btn) " " (ev.mode = "double" ? "doubleclick" : ev.mode)
        case "MOVE":
            s := (ev.rel ? "moveby " : "move ") ev.x " " ev.y
        case "DELAY":
            s := "delay " SecShort(ev.ms)
        default:
            return ""
    }
    return "[" StrReplace(StrReplace(s, "\", "\\"), "]", "\]") "]"
}

; .ypm 글 → { events, bad: [해석하지 못한 동작 글자들], settings: Map, badSettings: [잘못된 설정] }
ParseYpm(txt) {
    evs := [], bad := [], settings := Map(), badSettings := []
    len := StrLen(txt), i := 1
    while (i <= len) {
        if (SubStr(txt, i, 1) != "[") {                     ; 대괄호 밖은 건너뛴다
            i += 1
            continue
        }
        body := "", j := i + 1, closed := false
        while (j <= len) {
            c := SubStr(txt, j, 1)
            if (c = "\" && j < len && InStr("\]", SubStr(txt, j + 1, 1))) {    ; \] → ],  \\ → \
                body .= SubStr(txt, j + 1, 1)
                j += 2
                continue
            }
            if (c = "]") {
                closed := true
                break
            }
            body .= c
            j += 1
        }
        if !closed {
            bad.Push("[" SubStr(body, 1, 30) "  (닫는 ] 없음)")
            break
        }
        if RegExMatch(body, "is)^\s*(settings?|설정)(\s+(.*))?$", &sm)
            ParseYpmSettings(sm[3], settings, badSettings)
        else if (r := ParseYpmAction(body)) {
            for ev in r
                evs.Push(ev)
        } else
            bad.Push("[" body "]")
        i := j + 1
    }
    return { events: evs, bad: bad, settings: settings, badSettings: badSettings }
}

; "theme=dark start=F9 ..." → settings 에 알맞은 값으로 넣는다. 잘못된 항목은 bad 에.
ParseYpmSettings(text, settings, bad) {
    for tok in StrSplit(Trim(text), [" ", "`t", "`r", "`n", ","]) {
        if (tok = "")
            continue
        if !RegExMatch(tok, "^([^=:]+)[=:](.*)$", &kv) {
            bad.Push(tok)
            continue
        }
        k := StrLower(Trim(kv[1])), v := Trim(kv[2]), lv := StrLower(v), val := ""
        switch k {
            case "theme":
                val := ThemeKeyFrom(v)
            case "start", "stop", "capture":
                val := HotkeyFromLabel(v)
            case "repeat":
                val := (lv = "on" || lv = "true" || lv = "1" || lv = "yes") ? 1 : (lv = "off" || lv = "false" || lv = "0" || lv = "no") ? 0 : ""
            case "loops":
                val := IsInteger(v) && Integer(v) >= 0 ? Integer(v) : ""
            case "startdelay", "interval":
                val := DurationMs(v, 1000)
            case "keyhold":
                val := DurationMs(v, 1)
                if (val = 0)
                    val := ""
            case "mode":
                val := (lv = "event") ? "Event" : (lv = "input") ? "Input" : ""
            default:
                bad.Push(tok "  (알 수 없는 설정)")
                continue
        }
        if (val = "")
            bad.Push(tok "  (잘못된 값)")
        else
            settings[k] := val
    }
}

; "0.5" / "0.5s" / "500ms" → ms.  숫자만 있으면 unit(1000 = 초, 1 = ms)으로 본다. 잘못되면 "".
DurationMs(v, unit) {
    if !RegExMatch(v, "i)^(\d+(?:\.\d+)?)\s*(ms|s|초)?$", &n)
        return ""
    ms := (StrLower(n[2]) = "ms") ? Round(n[1]) : (n[2] != "") ? Round(n[1] * 1000) : Round(n[1] * unit)
    return (ms <= 3600000) ? ms : ""
}

; 테마 이름(영어 키 / 한글 이름) → 테마 키.  v1.5 의 light 는 라떼.
ThemeKeyFrom(v) {
    lv := StrLower(v)
    if (lv = "light")
        return "latte"
    for key in THEME_ORDER
        if (lv = key || v = THEMES[key].name)
            return key
    return ""
}

; "Ctrl+Alt+F9" → "^!F9".  키 하나("F9")나 AHK 형식("^+F9")도 받는다. 잘못되면 "".
HotkeyFromLabel(s) {
    s := Trim(s)
    if (s = "")
        return ""
    parts := StrSplit(s, "+")
    if (parts.Length >= 2) {                                ; "Ctrl+Alt+F9"
        key := parts.Pop()
        mods := "", ok := (key != "")
        for m in parts {
            switch StrLower(m) {
                case "ctrl", "control": mods .= "^"
                case "alt":             mods .= "!"
                case "shift":           mods .= "+"
                case "win":             mods .= "#"
                default:                ok := false
            }
        }
        if (ok && GetKeyName(key) != "")
            return mods key
    }
    k := RegExReplace(s, "^[\^!+#]+")                       ; "F9", "^+F9"
    return (k != "" && GetKeyName(k) != "") ? s : ""
}

; 파일에 들어 있던 설정을 적용한다. 적용하지 못한 것을 글로 돌려준다.
ApplyYpmSettings(st, &applied := 0) {
    problems := "", applied := st.Count
    if (st.Has("start") || st.Has("stop") || st.Has("capture")) {
        ns := st.Has("start") ? st["start"] : App.hkStart
        np := st.Has("stop") ? st["stop"] : App.hkStop
        nc := st.Has("capture") ? st["capture"] : App.hkPos
        if (ns != App.hkStart || np != App.hkStop || nc != App.hkPos) && !RegisterHotkeys(ns, np, nc, "", true) {
            problems .= "`n    단축키: " RTrim(App.hkError, ".") " (지금 단축키를 그대로 씁니다)"
            applied -= st.Has("start") + st.Has("stop") + st.Has("capture")
        }
    }
    if st.Has("repeat")
        ui.cbRepeat.Value := App.repeatOn := st["repeat"]
    if st.Has("loops")
        App.repeatCnt := st["loops"]
    if st.Has("startdelay")
        App.startDelay := st["startdelay"]
    if st.Has("interval")
        App.gap := st["interval"]
    if st.Has("keyhold")
        App.keyHold := st["keyhold"]
    if st.Has("mode")
        App.sendMode := st["mode"]
    if (st.Has("theme") && st["theme"] != App.theme)
        ApplyTheme(st["theme"])
    SaveSettings()
    return problems
}

; 동작 하나 "key w down" → 이벤트 배열 (조합키는 여러 개), 알 수 없으면 0.  v1.5 의 한국어 동작도 받는다.
ParseYpmAction(body) {
    static btns := Map("left", "Left", "right", "Right", "middle", "Middle", "왼쪽", "Left", "오른쪽", "Right", "가운데", "Middle")
    static acts := Map("click", "click", "doubleclick", "double", "double", "double", "dblclick", "double", "down", "down", "up", "up"
                     , "클릭", "click", "더블클릭", "double", "누름", "down", "뗌", "up")
    if !RegExMatch(Trim(body, " `t`r`n"), "s)^(\S+)\s*(.*)$", &m)
        return 0
    kw := StrLower(m[1]), rest := Trim(m[2], " `t`r`n")
    switch kw {
        case "key", "키":
            return YpmKey(rest)
        case "text", "문장":
            return (rest != "") ? [{ type: "TEXT", text: RegExReplace(rest, "[\t\r\n]+", " ") }] : 0
        case "left", "right", "middle", "왼쪽", "오른쪽", "가운데":
            a := StrLower(rest = "" ? "click" : rest)
            return acts.Has(a) ? [{ type: "MOUSE", btn: btns[kw], mode: acts[a] }] : 0
        case "wheel", "휠":
            a := StrLower(rest)
            if (a = "up" || a = "위")
                return [{ type: "MOUSE", btn: "WheelUp", mode: "click" }]
            if (a = "down" || a = "아래")
                return [{ type: "MOUSE", btn: "WheelDown", mode: "click" }]
            return 0
        case "move", "moveby", "moverel", "이동", "상대이동":
            if !RegExMatch(rest, "i)^(-?\d+)\s*[ ,]\s*(-?\d+)\s*(rel|상대)?$", &n)
                return 0
            return [{ type: "MOVE", x: Integer(n[1]), y: Integer(n[2])
                    , rel: (kw = "moveby" || kw = "moverel" || kw = "상대이동" || n[3] != "") }]
        case "delay", "wait", "지연", "대기":
            ms := DurationMs(rest, 1000)
            return (ms != "") ? [{ type: "DELAY", ms: ms }] : 0
    }
    return 0
}

; [키 ...] 의 내용: "w", "w 누름", "w 뗌", "a 80ms", "Ctrl+C"
YpmKey(rest) {
    words := []
    for w in StrSplit(rest, [" ", "`t"])
        if (w != "")
            words.Push(w)
    if !words.Length
        return 0
    keys := []
    for k in (words[1] = "+" ? ["+"] : StrSplit(words[1], "+")) {
        k := KeyAlias(k)
        if (StrLen(k) = 1)
            k := StrLower(k)                                ; 대문자 한 글자(C)는 Shift 가 섞여 보내지므로 소문자로
        if !ValidKey(k)
            return 0
        keys.Push(k)
    }
    mode := "tap", hold := App.keyHold
    loop words.Length - 1 {
        w := StrLower(words[A_Index + 1])
        if (w = "누름" || w = "down")
            mode := "down"
        else if (w = "뗌" || w = "up")
            mode := "up"
        else if RegExMatch(w, "^(\d+)ms$", &h)
            hold := Integer(h[1])
        else
            return 0
    }
    if (keys.Length = 1)
        return [{ type: "KEY", key: keys[1], mode: mode, hold: hold }]
    if (mode != "tap")
        return 0
    evs := []                                               ; 조합키: 앞의 키들을 누른 채로 마지막 키를 눌렀다 뗀다
    loop keys.Length - 1
        evs.Push({ type: "KEY", key: keys[A_Index], mode: "down", hold: hold })
    evs.Push({ type: "KEY", key: keys[keys.Length], mode: "tap", hold: hold })
    loop keys.Length - 1
        evs.Push({ type: "KEY", key: keys[keys.Length - A_Index], mode: "up", hold: hold })
    return evs
}

; 손으로 쓰기 쉽게 한글 키 이름도 받는다
KeyAlias(k) {
    static m := Map("스페이스", "Space", "엔터", "Enter", "탭", "Tab", "쉬프트", "Shift", "시프트", "Shift"
                  , "컨트롤", "Ctrl", "알트", "Alt", "윈도우", "LWin", "백스페이스", "Backspace", "삭제", "Delete"
                  , "위", "Up", "아래", "Down", "왼쪽", "Left", "오른쪽", "Right", "한영", "vk15", "한자", "vk19")
    return m.Has(k) ? m[k] : k
}

; 글 파일 읽기: UTF-8 이 아니면(메모장에서 ANSI 로 저장한 경우 등) 한국어 코드 페이지로 다시 읽는다
ReadTextFile(path) {
    txt := FileRead(path, "UTF-8")
    if InStr(txt, Chr(0xFFFD))
        txt := FileRead(path, "CP949")
    return txt
}

LoadMacroFile(path, quiet := false) {
    if !FileExist(path)
        return false
    if IsGmcFile(path)
        return LoadGmcFile(path, quiet)
    if RegExMatch(path, "i)\.gmc$") {
        if !quiet
            Warn("읽을 수 없는 G Macro 파일입니다.`n(G Macro Second Edition v2.0 으로 저장한 .gmc 파일만 읽을 수 있습니다.)")
        return false
    }
    try {
        txt := ReadTextFile(path)
    } catch as err {
        if !quiet
            Warn("파일을 읽지 못했습니다: " err.Message)
        return false
    }
    lines := StrSplit(txt, "`n", "`r")
    if (lines.Length && Trim(lines[1]) = FILE_MAGIC) {      ; v1.4 까지의 .gmx
        lines.RemoveAt(1)
        r := ParseEventLines(lines)
        badList := []
        loop r.bad
            badList.Push("(알 수 없는 줄)")
    } else {
        r := ParseYpm(txt)
        badList := r.bad
        if (r.events.Length = 0 && badList.Length = 0 && !r.settings.Count && !RegExMatch(path, "i)\.ypm$")) {
            if !quiet
                Warn("매크로 파일이 아닙니다.`n(.ypm, 예전 .gmx, G Macro 의 .gmc 파일을 읽을 수 있습니다.)")
            return false
        }
    }
    App.events := r.events
    RefreshList(1)
    applied := 0
    problems := (r.HasProp("settings") && r.settings.Count) ? ApplyYpmSettings(r.settings, &applied) : ""
    if r.HasProp("badSettings")
        problems .= ShortList(r.badSettings)
    if quiet
        return true
    if (problems = "" && !badList.Length) {
        Notify("불러옴: 동작 " r.events.Length "개" (applied ? " · 설정도 적용" : ""))
        return true
    }
    ; 알릴 것이 있으면 창 하나에 모아서 보여 준다
    msg := "동작 " r.events.Length "개를 불러왔습니다." (applied ? " 파일에 저장된 설정도 적용했습니다." : "")
    if (problems != "")
        msg .= "`n`n적용하지 못한 설정:" problems
    if badList.Length
        msg .= "`n`n알아볼 수 없어서 건너뛴 동작 " badList.Length "개:" ShortList(badList)
             . "`n`n쓰는 법 예:  [key w down], [left click], [move 800 465], [delay 0.5], [text Hello]"
    win.Opt("+OwnDialogs")
    MsgBox(msg, APP_TITLE, "Icon!")
    return true
}

; 목록 → 들여 쓴 여러 줄 (max 개까지만)
ShortList(list, max := 5) {
    out := ""
    for i, b in list
        if (i <= max)
            out .= "`n    " b
    if (list.Length > max)
        out .= "`n    … 외 " (list.Length - max) "개"
    return out
}

SaveDialog() {
    if !CanOpenDialog()
        return
    win.Opt("+OwnDialogs")
    path := FileSelect("S16", A_ScriptDir "\macro.ypm", "매크로 저장", "YPMacro Script (*.ypm)")
    if (path = "")
        return
    if !RegExMatch(path, "i)\.ypm$")
        path .= ".ypm"
    if SaveMacroFile(path) {
        RegisterYpmType(true)                               ; .ypm 을 메모지 아이콘으로 보이고 더블클릭으로 열리게
        Notify("저장됨: " path)
    }
}

; .ypm 파일을 YPMacro 로 열고, 탐색기에서 메모지 아이콘으로 보이게 한다 (현재 사용자만, 관리자 권한 필요 없음).
; 처음 저장할 때 연결하고, 그 뒤로는 실행할 때마다 연결된 경로를 지금 실행 중인 exe 로 맞춘다 (새 버전으로 바꿨을 때).
RegisterYpmType(first := false) {
    base := "HKEY_CURRENT_USER\Software\Classes\"
    name := "YPMacro Script"                                  ; 파일 형식 이름 (속성 창, 탐색기 "유형")
    cmd := A_IsCompiled ? '"' A_ScriptFullPath '" "%1"' : '"' A_AhkPath '" "' A_ScriptFullPath '" "%1"'
    icon := A_IsCompiled ? A_ScriptFullPath ",-300" : A_ScriptDir "\YPMFile.ico"
    cur := RegReadOr(base "YPMacro.Macro\shell\open\command")
    if (cur = "" && !first)                                 ; 아직 한 번도 저장하지 않음
        return
    if (cur = cmd && RegReadOr(base "YPMacro.Macro") = name && RegReadOr(base "YPMacro.Macro\DefaultIcon") = icon)
        return
    try {
        RegWrite("YPMacro.Macro", "REG_SZ", base ".ypm")
        RegWrite(name, "REG_SZ", base "YPMacro.Macro")
        RegWrite(icon, "REG_SZ", base "YPMacro.Macro\DefaultIcon")
        RegWrite(cmd, "REG_SZ", base "YPMacro.Macro\shell\open\command")
        DllCall("shell32\SHChangeNotify", "Int", 0x08000000, "UInt", 0, "Ptr", 0, "Ptr", 0)   ; 탐색기 아이콘 새로 고침
    }
}

RegReadOr(key, value := "") {
    try return RegRead(key, value)
    return ""
}

OnDropFiles(g, ctrl, files, *) {                            ; 창에 파일을 끌어다 놓으면 불러오기
    if !(App.running || App.dlg)
        LoadMacroFile(files[1])
}

LoadDialog() {
    if !CanOpenDialog()
        return
    win.Opt("+OwnDialogs")
    path := FileSelect(1, A_ScriptDir, "매크로 불러오기", "매크로 파일 (*.ypm; *.gmx; *.gmc)")
    if (path != "")
        LoadMacroFile(path)
}

; ------------------------------------------------------------------------------
;  G Macro(.gmc) 파일 불러오기.  G Macro Second Edition v2.0 형식이며, 저장은 .gmx 로만 한다.
;  구조: [UInt 줄 수 + 1] 다음에 79바이트짜리 줄이 이어진다. 첫 줄은 "시작"이고, 값에 시작 지연(초)이 들어 있다.
;    +0  char[25] 이름(CP949)    +25 Int 키 코드(VK)    +29 Int 키 방식 (0 한번누름, 1 눌림, 2 뗌)
;    +33 char[30] 목록 글자       +63 Int 종류           +67 Double 값 (지연 초 / 이동 X)    +75 Int 값2 (이동 Y)
;  종류: 1 키보드  2 커서 이동  3 왼쪽 클릭  4 왼쪽 누른상태  5 뗀 상태  6 시간 지연  7 오른쪽 클릭  8 오른쪽 누른상태
; ------------------------------------------------------------------------------
IsGmcFile(path) {
    try {
        size := FileGetSize(path)
        if (size < 83 || Mod(size - 4, 79) != 0)
            return false
        f := FileOpen(path, "r")
        cnt := f.ReadUInt()
        f.Close()
        return cnt = (size - 4) // 79 + 1
    }
    return false
}

ReadGmc(path) {
    buf := FileRead(path, "RAW")
    n := (buf.Size - 4) // 79                    ; "시작" 줄 포함
    kinds := []
    loop n
        kinds.Push(NumGet(buf, 4 + (A_Index - 1) * 79 + 63, "Int"))
    evs := []
    bad := 0
    loop n - 1 {
        i := A_Index + 1                         ; 1번 줄("시작")은 건너뛴다
        p := 4 + (i - 1) * 79
        switch kinds[i] {
            case 1:
                key := GetKeyName(Format("vk{:02X}", NumGet(buf, p + 25, "UInt") & 0xFF))
                act := NumGet(buf, p + 29, "Int")
                if (key = "" || act < 0 || act > 2) {
                    bad += 1
                    continue
                }
                evs.Push({ type: "KEY", key: key, mode: ["tap", "down", "up"][act + 1], hold: App.keyHold })
            case 2: evs.Push({ type: "MOVE", x: Round(NumGet(buf, p + 67, "Double")), y: NumGet(buf, p + 75, "Int"), rel: false })
            case 3: evs.Push({ type: "MOUSE", btn: "Left", mode: "click" })
            case 4: evs.Push({ type: "MOUSE", btn: "Left", mode: "down" })
            case 5: evs.Push({ type: "MOUSE", btn: GmcReleaseBtn(kinds, i), mode: "up" })
            case 6:
                sec := NumGet(buf, p + 67, "Double")
                if !(sec >= 0 && sec <= 3600) {
                    bad += 1
                    continue
                }
                evs.Push({ type: "DELAY", ms: Round(sec * 1000) })
            case 7: evs.Push({ type: "MOUSE", btn: "Right", mode: "click" })
            case 8: evs.Push({ type: "MOUSE", btn: "Right", mode: "down" })
            default: bad += 1
        }
    }
    sd := NumGet(buf, 4 + 67, "Double")
    return { events: evs, bad: bad, startDelay: (sd >= 0 && sd <= 3600) ? Round(sd * 1000) : -1 }
}

; G Macro 의 "뗀 상태"(종류 5)에는 어느 버튼인지가 없다.
; 목록에서 바로 앞의 "누른상태"를 찾아(맨 앞을 지나면 뒤쪽까지 한 바퀴) 그 버튼을 뗀다. 없으면 왼쪽.
GmcReleaseBtn(kinds, i) {
    j := i
    loop kinds.Length - 1 {
        j := (j > 2) ? j - 1 : kinds.Length
        if (kinds[j] = 8)
            return "Right"
        if (kinds[j] = 4)
            return "Left"
    }
    return "Left"
}

LoadGmcFile(path, quiet := false) {
    try {
        r := ReadGmc(path)
    } catch as err {
        if !quiet
            Warn("파일을 읽지 못했습니다: " err.Message)
        return false
    }
    App.events := r.events
    RefreshList(1)
    if quiet
        return true
    msg := "G Macro 파일에서 이벤트 " r.events.Length "개를 불러왔습니다."
    if r.bad
        msg .= "`n(읽지 못한 줄 " r.bad "개는 건너뛰었습니다.)"
    ; G Macro 는 이벤트마다 0.1초 간격(기본값)을 두고, 시작 지연은 파일에 저장한다. 같은 속도로 돌도록 맞출지 묻는다.
    wantStart := (r.startDelay >= 0) ? r.startDelay : App.startDelay
    diff := ""
    if (App.gap != 100)
        diff .= "`n  -  이벤트 간격 지연:  " SecText(App.gap) "초 → 0.100초 (G Macro 기본값)"
    if (App.startDelay != wantStart)
        diff .= "`n  -  이벤트 시작 시 지연:  " SecText(App.startDelay) "초 → " SecText(wantStart) "초 (이 파일의 값)"
    if (diff = "") {
        Notify(msg)
        return true
    }
    win.Opt("+OwnDialogs")
    if (MsgBox(msg "`n`nG Macro 와 같은 속도로 돌도록 설정도 바꿀까요?" diff, APP_TITLE, "YesNo Iconi") = "Yes") {
        App.gap := 100
        App.startDelay := wantStart
        SaveSettings()
    }
    return true
}
