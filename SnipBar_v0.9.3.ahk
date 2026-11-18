#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
ListLines False
KeyHistory 0
SetWorkingDir A_ScriptDir
CoordMode "Mouse", "Screen"
CoordMode "ToolTip", "Screen"
SetStoreCapsLockMode(false)              ; never touch Caps Lock when sending Ctrl+C / Ctrl+V
try ProcessSetPriority("AboveNormal")    ; keeps the mouse hook snappy

; =====================================================================
;  SnipBar v0.9.3 - by Ahcene
;  A small bar that appears above selected text, anywhere in Windows.
;  Select text with the mouse -> the bar pops up -> click a button.
;  Tray icon (near the clock): right-click -> Settings / Pause / Exit.
;
;  Shortcuts
;    Ctrl+Alt+B         show the bar for the selected text (any app)
;    Ctrl+Alt+Shift+B   check / learn the text cursor (Adobe apps)
;    Esc                hide the bar
;
;  Settings, icons and the icon font are saved in
;    Documents\AHK SETTINGS\SnipBar
;
;  History
;    0.9.3  Settings buttons and tabs are plain rectangles (crisp edges).
;    0.9.2  Code clean-up. No more leftover marks when switching tabs.
;    0.9.1  Save keeps the settings open. Corner rounding slider.
;    0.9    Smooth drawing (no black corners), Design tab, opacity.
;    0.8    Symbols tab: add, remove and reorder symbols.
;    0.7    Custom icon font, dark / light mode, icon colors, new tray icon.
;    0.6    Settings folder in Documents, spelling check, Adobe support,
;           learned text cursors.
;    0.5    Only reacts to text selections, no more lag, tabbed settings.
; =====================================================================

APP_NAME    := "SnipBar"
APP_VERSION := "0.9.3"
APP_AUTHOR  := "Ahcene"

; =====================================================================
;  DEFAULTS  (everything below can be changed in Settings)
; =====================================================================
; ---------- Look of the bar ----------
ThemeDefaults := Map(
    "light", Map("bg", "F3F3F3", "icon", "2B2B2B", "hover", "DADADA", "dim", "6B6B6B"),
    "dark",  Map("bg", "000000", "icon", "FFFFFF", "hover", "4A4A4A", "dim", "9A9A9A"))
DefaultCustomBg   := "1C1C1C"
DefaultCustomIcon := "4DFF7F"
DefaultOpacity    := 92      ; background opacity in % (icons are always solid)
DefaultRounding   := 30      ; corner rounding in % (0 = sharp, 100 = fully round)
GlyphSize := 13              ; icon size (points)
BtnSize   := 34              ; size of each button (pixels at 100% scaling)
BtnGap    := 4               ; space between buttons
BarPad    := 5               ; space around the buttons inside the bar

; ---------- Colors of the Settings window (always dark) ----------
C_BG   := "161616"           ; window background
C_BG2  := "242424"           ; buttons / fields
C_BG3  := "323232"           ; hover
C_LINE := "2E2E2E"           ; separators
C_TXT  := "FFFFFF"           ; main text
C_DIM  := "9A9A9A"           ; secondary text
C_ACC  := "4DFF7F"           ; green accent (same as the logo)
C_ACC2 := "6BFF96"           ; green accent, hover

; ---------- Buttons of the bar ----------
;  g     = letter of the icon in the SnipBar icon font
;  glyph = fallback when the icon font cannot be loaded
Defs := [
    Map("key", "lower",     "label", "lowercase",                    "g", "M", "glyph", "aa",                    "icon", false),
    Map("key", "upper",     "label", "UPPERCASE",                    "g", "N", "glyph", "AA",                    "icon", false),
    Map("key", "paren",     "label", "Put between ( )",              "g", "O", "glyph", "( )",                   "icon", false),
    Map("key", "brace",     "label", "Put between { }",              "g", "P", "glyph", "{ }",                   "icon", false),
    Map("key", "bracket",   "label", "Put between [ ]",              "g", "Q", "glyph", "[ ]",                   "icon", false),
    Map("key", "symbols",   "label", "Special symbols",              "g", "A", "glyph", Chr(0x3A9),              "icon", false),
    Map("key", "spell",     "label", "Correct spelling and grammar", "g", "R", "glyph", Chr(0x2713) Chr(0x2713), "icon", false, "font", "sym"),
    Map("key", "google",    "label", "Search on Google",             "g", "T", "glyph", Chr(0xE721),             "icon", true),
    Map("key", "translate", "label", "Translate",                    "g", "S", "glyph", Chr(0xE774),             "icon", true),
    Map("key", "email",     "label", "Saved emails",                 "g", "U", "glyph", "@",                     "icon", false),
    Map("key", "copy",      "label", "Copy",                         "g", "V", "glyph", Chr(0xE8C8),             "icon", true)
]

; first-launch list of symbols (your own list is edited in Settings > Symbols)
DefaultSymbols := [Chr(0x2022), Chr(0x007C), Chr(0xC9), Chr(0xC8), Chr(0x152), Chr(0x153), Chr(0xC0), Chr(0xAE), Chr(0xB1)]

; translation languages (name, Google code)
Langs := [
    ["English", "en"], ["French", "fr"], ["Spanish", "es"], ["German", "de"],
    ["Italian", "it"], ["Portuguese", "pt"], ["Arabic", "ar"], ["Dutch", "nl"],
    ["Russian", "ru"], ["Turkish", "tr"], ["Chinese (Simplified)", "zh-CN"], ["Japanese", "ja"]
]

; spelling check languages (name, LanguageTool code)
SpellLangs := [
    ["Auto-detect", "auto"], ["English (US)", "en-US"], ["English (UK)", "en-GB"], ["French", "fr"],
    ["Spanish", "es"], ["German", "de-DE"], ["Italian", "it"], ["Portuguese (Portugal)", "pt-PT"],
    ["Portuguese (Brazil)", "pt-BR"], ["Dutch", "nl"], ["Russian", "ru-RU"], ["Arabic", "ar"]
]

HideChoices := ["3 seconds", "5 seconds", "7 seconds", "10 seconds", "15 seconds", "30 seconds"]
HideValues  := [3000, 5000, 7000, 10000, 15000, 30000]

; windows where the bar never appears (consoles, Explorer, desktop, Excel)
ExcludedClasses := ["ConsoleWindowClass", "CASCADIA_HOSTING_WINDOW_CLASS", "CabinetWClass", "Progman", "WorkerW", "XLMAIN"]

; Adobe programs draw their own cursors (see "Text cursor detection")
AdobeApps := Map("illustrator.exe", 1, "photoshop.exe", 1, "indesign.exe", 1, "incopy.exe", 1, "acrobat.exe", 1,
                 "acrord32.exe", 1, "afterfx.exe", 1, "adobe premiere pro.exe", 1, "animate.exe", 1, "xd.exe", 1)

; =====================================================================
;  FILES  -  everything SnipBar creates lives in Documents\AHK SETTINGS\SnipBar
; =====================================================================
DataDir     := A_MyDocuments "\AHK SETTINGS\SnipBar"
try DirCreate(DataDir)
IniFile     := DataDir "\SnipBar.ini"
IconFile    := DataDir "\SnipBar.ico"          ; green = active
IconOffFile := DataDir "\SnipBar_paused.ico"   ; red   = paused
GlyphFile   := DataDir "\SnipBar_glyphs.ttf"   ; icon font of the bar
StartupLink := A_Startup "\SnipBar.lnk"

; settings saved by v0.5 next to the script: bring them along once
if (!FileExist(IniFile) && FileExist(A_ScriptDir "\SnipBar.ini"))
    try FileCopy(A_ScriptDir "\SnipBar.ini", IniFile)

; the icons and the icon font are stored at the end of this script
WriteB64(IconFile, IconOnB64())
WriteB64(IconOffFile, IconOffB64())
WriteB64(GlyphFile, GlyphsB64())
try IniWrite(APP_VERSION, IniFile, "General", "Version")

; =====================================================================
;  SAVED SETTINGS
; =====================================================================
Enabled := Map(), Labels := Map()
for def in Defs {
    Enabled[def["key"]] := (IniRead(IniFile, "Buttons", def["key"], "1") = "1")
    Labels[def["key"]]  := def["label"]
}

ThemeMode := IniRead(IniFile, "Look", "Theme", "auto")
if !RegExMatch(ThemeMode, "^(auto|light|dark|custom)$")
    ThemeMode := "auto"
IconLight   := CleanHex(IniRead(IniFile, "Look", "IconLight", IniRead(IniFile, "General", "IconLight", "")), ThemeDefaults["light"]["icon"])
IconDark    := CleanHex(IniRead(IniFile, "Look", "IconDark", IniRead(IniFile, "General", "IconDark", "")), ThemeDefaults["dark"]["icon"])
CustomBg    := CleanHex(IniRead(IniFile, "Look", "CustomBg", ""), DefaultCustomBg)
CustomIcon  := CleanHex(IniRead(IniFile, "Look", "CustomIcon", ""), DefaultCustomIcon)
OpacityPct  := ReadPercent("Opacity", DefaultOpacity, 20)
RoundingPct := ReadPercent("Rounding", DefaultRounding, 0)

TargetLang := IniRead(IniFile, "General", "TargetLang", "en")
SpellLang  := IniRead(IniFile, "General", "SpellLang", "auto")
MyLangs    := IniRead(IniFile, "General", "MyLangs", "fr,en")
AutoHideMs := Integer(IniRead(IniFile, "General", "AutoHideMs", "7000"))

ExcludedApps := Map()                    ; apps chosen in Settings > General
for p in StrSplit(IniRead(IniFile, "General", "ExcludedApps", ""), ",", " `t") {
    if (p != "")
        ExcludedApps[StrLower(p)] := 1
}

LearnedCursors := Map()                  ; text cursors learned with Ctrl+Alt+Shift+B
Loop Integer(IniRead(IniFile, "TextCursors", "Count", "0")) {
    sig := IniRead(IniFile, "TextCursors", "C" A_Index, "")
    if (sig != "")
        LearnedCursors[sig] := 1
}

Symbols := LoadSymbols()
Emails := []
Loop Integer(IniRead(IniFile, "Emails", "Count", "0")) {
    e := IniRead(IniFile, "Emails", "E" A_Index, "")
    if (e != "")
        Emails.Push(e)
}

; =====================================================================
;  STATE
; =====================================================================
Scale := A_ScreenDPI / 96
Look := Map(), LightMode := false
Panels := Map()                          ; hwnd -> bar / popup drawn by PanelRender
famGlyph := 0, famUI := 0, famUIReg := 0, famSym := 0, famMDL2 := 0

bar := "", barP := "", barW := 0, barH := 0, barX := 0, barY := 0, barVisible := false, shownTick := 0
symGui := "", symP := "", symVisible := false, symShownTick := 0
selText := "", paused := false, busy := false, spellBusy := false
downX := 0, downY := 0, downWin := 0, downText := false, lastDownTick := 0, clickCount := 0, ignoreUp := false
cursorCache := Map()

; Settings window
settingsGui := "", setPanels := Map(), setTabBtns := Map(), setHot := Map(), setBgNow := Map(), setActiveTab := ""
setBoxes := Map(), setSaveBtn := "", setPreview := ""
setThemeSel := "", setThemePills := Map(), setColorFields := []
setIconLightEd := "", setIconDarkEd := "", setCustBgEd := "", setCustIconEd := ""
setOpacitySl := "", setOpacityTxt := "", setRoundSl := "", setRoundTxt := ""
setSymList := [], setSymLB := "", setSymEd := ""
setLangDD := "", setSpellDD := "", setMyLangsEd := "", setEmailEd := "", setStartCb := "", setHideDD := "", setExclEd := ""

; clipboard formats that a plain-text restore would lose
CF_HTML := DllCall("RegisterClipboardFormat", "str", "HTML Format", "uint")
CF_RTF  := DllCall("RegisterClipboardFormat", "str", "Rich Text Format", "uint")

; =====================================================================
;  STARTUP
; =====================================================================
if FileExist(IconFile)
    try TraySetIcon(IconFile)
A_IconTip := APP_NAME " " APP_VERSION
A_TrayMenu.Delete()
A_TrayMenu.Add("Settings", ShowSettings)
A_TrayMenu.Add("Pause", TogglePause)
A_TrayMenu.Add()
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Settings"

EnableDarkMode()
GdipInit()
LoadFamilies()
ApplyTheme()
OnMessage(0x1A, OnSettingChange)         ; Windows dark / light mode changed
OnMessage(0x202, OnPanelClick)           ; click on the bar or a popup
BuildBar()

; =====================================================================
;  HOTKEYS  (the two mouse ones run inside the mouse hook: keep them tiny)
; =====================================================================
~LButton:: {
    global downX, downY, downWin, downText, lastDownTick, clickCount, ignoreUp
    MouseGetPos(&x, &y, &win)
    if (symVisible && IsObject(symGui) && win = symGui.Hwnd) {
        ignoreUp := true
        return
    }
    if symVisible
        HideSymbols()
    if (barVisible && IsObject(bar) && win = bar.Hwnd)
        return
    if barVisible
        HideBar()
    if (A_TickCount - lastDownTick < 500 && Abs(x - downX) < 6 && Abs(y - downY) < 6)
        clickCount += 1
    else
        clickCount := 1
    lastDownTick := A_TickCount
    downX := x, downY := y, downWin := win
    downText := IsTextCursorNow(win)     ; standard I-beam, or Adobe's own text cursor
}

~LButton Up:: {
    global ignoreUp
    if ignoreUp {
        ignoreUp := false
        return
    }
    if (paused || busy)
        return
    MouseGetPos(&x, &y, &win)
    if (barVisible && IsObject(bar) && win = bar.Hwnd)
        return
    ; a text selection starts or ends on a text cursor. Dragging objects,
    ; marquees or files never shows one, so this test removes false pop-ups.
    if (!downText && !IsTextCursorNow(win))
        return
    if (win != downWin)
        return
    ; Alt-drag / Win-drag = moving or duplicating something, never text
    if (GetKeyState("Alt", "P") || GetKeyState("LWin", "P") || GetKeyState("RWin", "P"))
        return
    moved := (Abs(x - downX) > 6 || Abs(y - downY) > 6)
    if !(moved || clickCount >= 2)
        return
    SetTimer(TrySelection.Bind(x, y, win, false), IsAdobeWin(win) ? -150 : -70)   ; heavy work outside the hook
}

~Escape:: {
    HideBar()
    HideSymbols()
}

; select text, then press Ctrl+Alt+B to show the bar at the mouse (any app)
^!b:: {
    KeyWait("Ctrl")
    KeyWait("Alt")
    MouseGetPos(&mx, &my, &mwin)
    TrySelection(mx, my, mwin, true)
}

; hover the text cursor, press Ctrl+Alt+Shift+B, then RELEASE the keys and keep
; the mouse still (holding Ctrl changes Illustrator's cursor).
; Shows what SnipBar detects, saves cursor_test.bmp and offers to learn the cursor.
^!+b:: {
    global cursorCache
    ToolTip("SnipBar: release the keys and keep the mouse still...")
    KeyWait("Ctrl"), KeyWait("Alt"), KeyWait("Shift"), KeyWait("b")
    Sleep(400)                           ; let the app restore its normal cursor
    ToolTip()
    MouseGetPos(, , &mwin)
    try
        proc := WinGetProcessName(mwin)
    catch
        proc := "?"
    hc := CurrentCursor(&cflags)
    shape := Map("ibeam", false, "info", "no cursor", "sig", "")
    if hc {
        try shape := CursorShape(hc)
        try SaveCursorBmp(hc, DataDir "\cursor_test.bmp")
    }
    learned := (shape["sig"] != "" && LearnedCursors.Has(shape["sig"]))
    ToolTip("SnipBar check`nApp: " proc "   Adobe: " (IsAdobeWin(mwin) ? "yes" : "no")
        . "`nWindows cursor name: " A_Cursor "   visible: " ((cflags & 1) ? "yes" : "no")
        . "`nCursor shape: " shape["info"]
        . "`nLooks like text cursor: " (shape["ibeam"] ? "YES" : "no") "   learned: " (learned ? "YES" : "no")
        . "`nText caret active: " (CaretActive(mwin) ? "YES" : "no")
        . "`n=> Bar allowed here: " (IsTextCursorNow(mwin) ? "YES" : "no"))
    SetTimer(() => ToolTip(), -8000)
    if (A_Cursor != "IBeam" && IsAdobeWin(mwin) && shape["sig"] != "" && !shape["ibeam"] && !learned) {
        ans := MsgBox("Is the mouse cursor right now your TEXT cursor (Type tool)?`n`n"
            . "Yes = SnipBar remembers it and will appear when you select text with it.`n"
            . "No  = nothing is changed.", "SnipBar - learn text cursor", "YesNo Icon? 262144")
        if (ans = "Yes") {
            LearnedCursors[shape["sig"]] := 1
            IniDelete(IniFile, "TextCursors")
            n := 0
            for sig in LearnedCursors {
                n += 1
                IniWrite(sig, IniFile, "TextCursors", "C" n)
            }
            IniWrite(n, IniFile, "TextCursors", "Count")
            cursorCache := Map()
            ToolTip("SnipBar: text cursor learned. Try selecting text now.")
            SetTimer(() => ToolTip(), -3000)
        }
    }
}

; =====================================================================
;  SELECTION AND CLIPBOARD
; =====================================================================
TrySelection(x, y, win, manual := false) {
    global selText, busy
    if (busy || GetKeyState("LButton", "P"))
        return
    if !manual {
        try
            cls := WinGetClass(win)
        catch
            return
        for c in ExcludedClasses {
            if (cls = c)
                return
        }
        if (ExcludedApps.Count) {
            try
                proc := StrLower(WinGetProcessName(win))
            catch
                proc := ""
            if (proc != "" && ExcludedApps.Has(proc))
                return
        }
    }
    txt := CopySelection((manual || IsAdobeWin(win)) ? 800 : 300)   ; Adobe apps copy more slowly
    if (Trim(txt, " `t`r`n") = "")
        return
    selText := txt
    ShowBar(x, y)
}

; Copies the selection while disturbing the clipboard as little as possible.
CopySelection(waitMs) {
    global busy
    busy := true
    txt := "", savedText := "", savedAll := "", textOnly := false
    try {
        if ClipHasOnlyText() {
            savedText := A_Clipboard          ; cheap: just a string
            textOnly := true
        } else if (ClipHeavySize() > 8000000) {
            ; a big image / file list is on the clipboard - leave it alone
            busy := false
            return ""
        } else {
            savedAll := ClipboardAll()
        }
        A_Clipboard := ""
        Send("^{vk43}")                       ; Ctrl+C by key code, Caps Lock stays out of it
        if ClipWait(waitMs / 1000, 0)
            txt := A_Clipboard
    }
    if textOnly
        RestoreClip(savedText)
    else if IsObject(savedAll)
        RestoreClip(savedAll)
    busy := false
    return txt
}

ClipHasOnlyText() {
    if !DllCall("IsClipboardFormatAvailable", "uint", 13)      ; CF_UNICODETEXT
        return false
    for fmt in [2, 3, 8, 14, 15, 17, CF_HTML, CF_RTF]          ; bitmap, dib, files, rich text...
        if DllCall("IsClipboardFormatAvailable", "uint", fmt)
            return false
    return true
}

ClipHeavySize() {
    size := 0
    if !DllCall("OpenClipboard", "ptr", 0)
        return 0
    for fmt in [8, 17, 15, CF_HTML, CF_RTF] {
        if DllCall("IsClipboardFormatAvailable", "uint", fmt) {
            h := DllCall("GetClipboardData", "uint", fmt, "ptr")
            if h
                size += DllCall("GlobalSize", "ptr", h, "uptr")
        }
    }
    DllCall("CloseClipboard")
    return size
}

RestoreClip(saved) {
    Loop 5 {
        try {
            A_Clipboard := saved
            return
        } catch {
            Sleep(40)
        }
    }
}

PasteReplace(newText) {
    global busy
    busy := true
    savedText := "", savedAll := "", textOnly := false
    try {
        if ClipHasOnlyText() {
            savedText := A_Clipboard
            textOnly := true
        } else {
            savedAll := ClipboardAll()   ; the user clicked a button, so it is worth the cost here
        }
        A_Clipboard := newText
        if ClipWait(1)
            Send("^{vk56}")   ; Ctrl+V by key code
        Sleep(220)
    }
    if textOnly
        RestoreClip(savedText)
    else if IsObject(savedAll)
        RestoreClip(savedAll)
    busy := false
}

; =====================================================================
;  TEXT CURSOR DETECTION
;  Windows apps report the standard I-beam. Adobe apps draw their own cursors,
;  so for them SnipBar checks the cursor picture (tall, thin, wider at top and
;  bottom), the cursors you taught it, and a blinking text caret.
; =====================================================================
IsTextCursorNow(win) {
    if (A_Cursor = "IBeam")
        return true
    if !IsAdobeWin(win)
        return false
    return CursorLooksLikeIBeam() || CaretActive(win)
}

IsAdobeWin(win) {
    static cache := Map()
    if !win
        return false
    if cache.Has(win)
        return cache[win]
    try
        proc := StrLower(WinGetProcessName(win))
    catch
        proc := ""
    r := AdobeApps.Has(proc)
    if (cache.Count > 300)
        cache.Clear()
    cache[win] := r
    return r
}

; true when the window's thread shows a text caret (text editing mode)
CaretActive(win) {
    tid := DllCall("GetWindowThreadProcessId", "ptr", win, "ptr", 0, "uint")
    if !tid
        return false
    sz := 24 + 6 * A_PtrSize                      ; sizeof(GUITHREADINFO)
    gti := Buffer(sz, 0)
    NumPut("uint", sz, gti, 0)
    if !DllCall("GetGUIThreadInfo", "uint", tid, "ptr", gti)
        return false
    flags := NumGet(gti, 4, "uint")
    hCaret := NumGet(gti, 8 + 5 * A_PtrSize, "ptr")
    if !hCaret
        return false
    ; a real caret has a size; ignore empty leftovers
    l := NumGet(gti, 8 + 6 * A_PtrSize, "int"), t := NumGet(gti, 12 + 6 * A_PtrSize, "int")
    r := NumGet(gti, 16 + 6 * A_PtrSize, "int"), b := NumGet(gti, 20 + 6 * A_PtrSize, "int")
    return (b - t > 0) || (flags & 1)
}

CurrentCursor(&flags := 0) {
    ci := Buffer(16 + A_PtrSize, 0)
    NumPut("uint", ci.Size, ci, 0)
    if !DllCall("GetCursorInfo", "ptr", ci)
        return 0
    flags := NumGet(ci, 4, "uint")
    return NumGet(ci, 8, "ptr")
}

CursorLooksLikeIBeam() {
    h := CurrentCursor()
    if !h
        return false
    if cursorCache.Has(h)
        return cursorCache[h]
    r := false
    try {
        shape := CursorShape(h)
        r := shape["ibeam"] || LearnedCursors.Has(shape["sig"])
    }
    if (cursorCache.Count > 200)
        cursorCache.Clear()
    cursorCache[h] := r
    return r
}

; measures the visible part of a cursor and decides if it is an I-beam
CursorShape(hCur) {
    out := Map("ibeam", false, "info", "no picture", "sig", "")
    ii := Buffer(A_PtrSize = 8 ? 32 : 20, 0)
    if !DllCall("GetIconInfo", "ptr", hCur, "ptr", ii)
        return out
    o := (A_PtrSize = 8) ? 16 : 12
    hMask := NumGet(ii, o, "ptr")
    hColor := NumGet(ii, o + A_PtrSize, "ptr")
    try {
        bm := Buffer(A_PtrSize = 8 ? 32 : 24, 0)
        DllCall("GetObject", "ptr", hMask, "int", bm.Size, "ptr", bm)
        w := NumGet(bm, 4, "int")
        mh := NumGet(bm, 8, "int")
        ch := hColor ? mh : mh // 2              ; monochrome cursors stack AND + XOR masks
        if (w > 0 && ch > 0 && w <= 256 && ch <= 256) {
            mask := DibBits(hMask, w, mh)
            col := hColor ? DibBits(hColor, w, ch) : ""
            hasAlpha := false
            if hColor {
                Loop w * ch {
                    if NumGet(col, (A_Index - 1) * 4 + 3, "UChar") {
                        hasAlpha := true
                        break
                    }
                }
            }
            rowMin := [], rowMax := []
            top := -1, bot := -1, minX := w, maxX := -1
            visBuf := Buffer(w * ch, 0)                ; 1 = visible pixel, used as the cursor's fingerprint
            Loop ch {
                y := A_Index - 1
                rmin := w, rmax := -1
                Loop w {
                    x := A_Index - 1
                    i := (y * w + x) * 4
                    if hColor {
                        if hasAlpha
                            vis := NumGet(col, i + 3, "UChar") > 40
                        else
                            vis := (NumGet(mask, i, "UInt") & 0xFFFFFF) = 0
                    } else {
                        andBit := (NumGet(mask, i, "UInt") & 0xFFFFFF) != 0
                        xorBit := (NumGet(mask, ((y + ch) * w + x) * 4, "UInt") & 0xFFFFFF) != 0
                        vis := !andBit || xorBit
                    }
                    if vis {
                        NumPut("UChar", 1, visBuf, y * w + x)
                        if (x < rmin)
                            rmin := x
                        rmax := x
                    }
                }
                rowMin.Push(rmin)
                rowMax.Push(rmax)
                if (rmax >= 0) {
                    if (top < 0)
                        top := y
                    bot := y
                    minX := Min(minX, rmin)
                    maxX := Max(maxX, rmax)
                }
            }
            crc := DllCall("ntdll\RtlComputeCrc32", "uint", 0, "ptr", visBuf, "uint", w * ch, "uint")
            out["sig"] := w "x" ch "-" Format("{:08X}", crc)
            if (top >= 0) {
                bw := maxX - minX + 1
                bh := bot - top + 1
                ; ends: widest row among the first / last 2 rows (an arrow tip is narrow there)
                topW := 0, botW := 0
                Loop Min(2, bh) {
                    topW := Max(topW, RowWidth(rowMin, rowMax, top + A_Index - 1))
                    botW := Max(botW, RowWidth(rowMin, rowMax, bot - A_Index + 1))
                }
                ; middle 40% of the height: most rows must be thin (a small tick is allowed)
                m1 := top + Round(bh * 0.3), m2 := top + Round(bh * 0.7)
                thin := 0, total := 0
                y := m1
                while (y <= m2) {
                    total += 1
                    if (RowWidth(rowMin, rowMax, y) <= Max(4, bw * 0.45))
                        thin += 1
                    y += 1
                }
                ok := (bh >= 9 && bh >= ch * 0.25 && bw <= bh * 0.7
                    && topW >= bw * 0.6 && botW >= bw * 0.6
                    && total > 0 && thin >= total * 0.7)
                out["ibeam"] := ok
                out["info"] := "size " w "x" ch "  shape " bw "x" bh "  top " topW "  bottom " botW "  thin middle " thin "/" total
            }
        }
    }
    if hMask
        DllCall("DeleteObject", "ptr", hMask)
    if hColor
        DllCall("DeleteObject", "ptr", hColor)
    return out
}

RowWidth(rowMin, rowMax, y) {
    return (rowMax[y + 1] >= 0) ? rowMax[y + 1] - rowMin[y + 1] + 1 : 0
}

DibBits(hbm, w, h) {
    bi := Buffer(48, 0)
    NumPut("uint", 40, bi, 0)
    NumPut("int", w, bi, 4)
    NumPut("int", -h, bi, 8)                     ; top-down rows
    NumPut("ushort", 1, bi, 12)
    NumPut("ushort", 32, bi, 14)
    px := Buffer(w * h * 4, 0)
    hdc := DllCall("GetDC", "ptr", 0, "ptr")
    DllCall("GetDIBits", "ptr", hdc, "ptr", hbm, "uint", 0, "uint", h, "ptr", px, "ptr", bi, "uint", 0)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdc)
    return px
}

; saves the current cursor as a picture (gray background), for troubleshooting
SaveCursorBmp(hCur, path) {
    size := 64
    hdcS := DllCall("GetDC", "ptr", 0, "ptr")
    hdc := DllCall("CreateCompatibleDC", "ptr", hdcS, "ptr")
    bi := Buffer(40, 0)
    NumPut("uint", 40, bi, 0), NumPut("int", size, bi, 4), NumPut("int", -size, bi, 8)
    NumPut("ushort", 1, bi, 12), NumPut("ushort", 32, bi, 14)
    pBits := 0
    hbm := DllCall("CreateDIBSection", "ptr", hdc, "ptr", bi, "uint", 0, "ptr*", &pBits, "ptr", 0, "uint", 0, "ptr")
    old := DllCall("SelectObject", "ptr", hdc, "ptr", hbm, "ptr")
    Loop size * size
        NumPut("uint", 0xFF808080, pBits, (A_Index - 1) * 4)
    DllCall("DrawIconEx", "ptr", hdc, "int", 0, "int", 0, "ptr", hCur, "int", 0, "int", 0, "uint", 0, "ptr", 0, "uint", 3)
    try {
        f := FileOpen(path, "w")
        f.WriteUShort(0x4D42), f.WriteUInt(54 + size * size * 4), f.WriteUInt(0), f.WriteUInt(54)
        f.RawWrite(bi, 40)
        f.RawWrite(pBits, size * size * 4)
        f.Close()
    }
    DllCall("SelectObject", "ptr", hdc, "ptr", old)
    DllCall("DeleteObject", "ptr", hbm)
    DllCall("DeleteDC", "ptr", hdc)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdcS)
}

; =====================================================================
;  BUTTON ACTIONS
; =====================================================================
DoAction(key, *) {
    txt := selText
    HideBar()
    if (txt = "")
        return
    switch key {
        case "lower":
            PasteReplace(StrLower(txt))
        case "upper":
            PasteReplace(StrUpper(txt))
        case "paren":
            PasteReplace("(" . txt . ")")
        case "brace":
            PasteReplace("{" . txt . "}")
        case "bracket":
            PasteReplace("[" . txt . "]")
        case "symbols":
            if (Symbols.Length = 0) {
                ToolTip("No symbols yet - add some in SnipBar settings > Symbols")
                SetTimer(() => ToolTip(), -2500)
            } else
                ShowSymbols()
        case "spell":
            SpellCheck(txt)
        case "email":
            if (Emails.Length = 0) {
                ToolTip("No saved email yet - add some in SnipBar settings (tray icon)")
                SetTimer(() => ToolTip(), -2500)
            } else
                ShowEmails()
        case "google":
            Run("https://www.google.com/search?q=" . UrlEncode(Clean(txt)))
        case "translate":
            Run("https://translate.google.com/?sl=auto&tl=" . TargetLang . "&text=" . UrlEncode(Clean(txt)) . "&op=translate")
        case "copy":
            try A_Clipboard := txt
            ToolTip("Copied")
            SetTimer(() => ToolTip(), -900)
    }
}

Clean(txt) {
    t := Trim(RegExReplace(txt, "\s+", " "))
    return SubStr(t, 1, 1500)
}

UrlEncode(str) {
    buf := Buffer(StrPut(str, "UTF-8"))
    StrPut(str, buf, "UTF-8")
    out := ""
    Loop buf.Size - 1 {
        b := NumGet(buf, A_Index - 1, "UChar")
        if ((b >= 48 && b <= 57) || (b >= 65 && b <= 90) || (b >= 97 && b <= 122) || b = 45 || b = 46 || b = 95 || b = 126)
            out .= Chr(b)
        else
            out .= "%" . Format("{:02X}", b)
    }
    return out
}

; =====================================================================
;  LOOK AND THEME
; =====================================================================
IsLightMode() {
    try return RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme") = 1
    return false
}

; works out every color of the bar from the Design settings
ComputeLook(mode, iconL, iconD, custBg, custIcon, opacityPct, roundPct := 100) {
    if (mode = "auto")
        mode := IsLightMode() ? "light" : "dark"
    if (mode = "custom") {
        bg := custBg, ic := custIcon
        hover := MixHex(bg, ic, 0.22)
        dim := MixHex(bg, ic, 0.6)
    } else {
        if (mode != "light")
            mode := "dark"
        d := ThemeDefaults[mode]
        bg := d["bg"], hover := d["hover"], dim := d["dim"]
        ic := (mode = "light") ? iconL : iconD
    }
    alpha := Round(Max(20, Min(100, opacityPct)) * 2.55)
    return Map("mode", mode, "bg", bg, "icon", ic, "hover", hover, "dim", dim
             , "border", MixHex(bg, ic, 0.14), "alpha", alpha, "round", Max(0, Min(100, roundPct)) / 100)
}

ApplyTheme() {
    global Look, LightMode
    LightMode := IsLightMode()
    Look := ComputeLook(ThemeMode, IconLight, IconDark, CustomBg, CustomIcon, OpacityPct, RoundingPct)
}

; "RRGGBB" a, b, 0..1 -> color between a and b
MixHex(a, b, t) {
    ca := Integer("0x" a), cb := Integer("0x" b)
    out := 0
    for sh in [16, 8, 0] {
        x := (ca >> sh) & 0xFF, y := (cb >> sh) & 0xFF
        out |= Round(x + (y - x) * t) << sh
    }
    return Format("{:06X}", out)
}

ARGB(a, hex) {
    return (a << 24) | Integer("0x" hex)
}

OnSettingChange(wParam, lParam, msg, hwnd) {
    SetTimer(ThemeCheck, -400)          ; Windows sends this several times in a row
}

ThemeCheck() {
    if (ThemeMode != "auto" || IsLightMode() = LightMode)
        return
    HideBar()
    HideSymbols()
    ApplyTheme()
    BuildBar()
}

; =====================================================================
;  DRAWING (GDI+)
;  The bar and its popups are drawn as see-through pictures: smooth rounded
;  edges and a transparent background while the icons stay solid.
; =====================================================================
GdipInit() {
    static token := 0
    if token
        return
    DllCall("LoadLibrary", "str", "gdiplus", "ptr")
    si := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
    NumPut("uint", 1, si, 0)
    DllCall("gdiplus\GdiplusStartup", "ptr*", &token, "ptr", si, "ptr", 0)
}

FontFamily(name, coll := 0) {
    fam := 0
    r := DllCall("gdiplus\GdipCreateFontFamilyFromName", "wstr", name, "ptr", coll, "ptr*", &fam)
    return (r = 0) ? fam : 0
}

LoadFamilies() {
    global famGlyph, famUI, famUIReg, famSym, famMDL2
    famGlyph := 0
    if FileExist(GlyphFile) {
        coll := 0
        DllCall("gdiplus\GdipNewPrivateFontCollection", "ptr*", &coll)
        if coll && !DllCall("gdiplus\GdipPrivateAddFontFile", "ptr", coll, "wstr", GlyphFile)
            famGlyph := FontFamily("Glyphter", coll)
    }
    famUIReg := FontFamily("Segoe UI")
    famUI := FontFamily("Segoe UI Semibold")
    if !famUI
        famUI := famUIReg
    famSym := FontFamily("Segoe UI Symbol")
    if !famSym
        famSym := famUI
    famMDL2 := FontFamily("Segoe MDL2 Assets")
}

Pt(points) {                              ; font points -> pixels at this screen's scaling
    return points * A_ScreenDPI / 72
}

RoundPath(x, y, w, h, r) {
    p := 0
    DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &p)
    r := Min(r, w / 2, h / 2)
    if (r <= 0.5) {
        DllCall("gdiplus\GdipAddPathRectangle", "ptr", p, "float", x, "float", y, "float", w, "float", h)
        return p
    }
    d := r * 2
    DllCall("gdiplus\GdipAddPathArc", "ptr", p, "float", x, "float", y, "float", d, "float", d, "float", 180, "float", 90)
    DllCall("gdiplus\GdipAddPathArc", "ptr", p, "float", x + w - d, "float", y, "float", d, "float", d, "float", 270, "float", 90)
    DllCall("gdiplus\GdipAddPathArc", "ptr", p, "float", x + w - d, "float", y + h - d, "float", d, "float", d, "float", 0, "float", 90)
    DllCall("gdiplus\GdipAddPathArc", "ptr", p, "float", x, "float", y + h - d, "float", d, "float", d, "float", 90, "float", 90)
    DllCall("gdiplus\GdipClosePathFigure", "ptr", p)
    return p
}

FillRound(G, argb, x, y, w, h, r) {
    br := 0
    DllCall("gdiplus\GdipCreateSolidFill", "uint", argb, "ptr*", &br)
    p := RoundPath(x, y, w, h, r)
    DllCall("gdiplus\GdipFillPath", "ptr", G, "ptr", br, "ptr", p)
    DllCall("gdiplus\GdipDeletePath", "ptr", p)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
}

DrawRound(G, argb, x, y, w, h, r) {
    pen := 0
    DllCall("gdiplus\GdipCreatePen1", "uint", argb, "float", 1, "int", 2, "ptr*", &pen)
    p := RoundPath(x, y, w, h, r)
    DllCall("gdiplus\GdipDrawPath", "ptr", G, "ptr", pen, "ptr", p)
    DllCall("gdiplus\GdipDeletePath", "ptr", p)
    DllCall("gdiplus\GdipDeletePen", "ptr", pen)
}

MakeFont(fam, sizePx, style, &font, &fmt) {
    font := 0, fmt := 0
    DllCall("gdiplus\GdipCreateFont", "ptr", fam, "float", sizePx, "int", style, "int", 2, "ptr*", &font)
    DllCall("gdiplus\GdipCreateStringFormat", "int", 0x1000, "int", 0, "ptr*", &fmt)   ; one line
    DllCall("gdiplus\GdipSetStringFormatAlign", "ptr", fmt, "int", 1)                  ; centered
    DllCall("gdiplus\GdipSetStringFormatLineAlign", "ptr", fmt, "int", 1)
    DllCall("gdiplus\GdipSetStringFormatTrimming", "ptr", fmt, "int", 3)               ; "..." if too long
}

FreeFont(font, fmt) {
    if fmt
        DllCall("gdiplus\GdipDeleteStringFormat", "ptr", fmt)
    if font
        DllCall("gdiplus\GdipDeleteFont", "ptr", font)
}

DrawLabel(G, text, fam, sizePx, style, argb, x, y, w, h) {
    if (!fam || text = "")
        return
    MakeFont(fam, sizePx, style, &font, &fmt)
    br := 0
    DllCall("gdiplus\GdipCreateSolidFill", "uint", argb, "ptr*", &br)
    rc := Buffer(16)
    NumPut("float", x, rc, 0), NumPut("float", y, rc, 4), NumPut("float", w, rc, 8), NumPut("float", h, rc, 12)
    DllCall("gdiplus\GdipDrawString", "ptr", G, "wstr", text, "int", -1, "ptr", font, "ptr", rc, "ptr", fmt, "ptr", br)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
    FreeFont(font, fmt)
}

MeasureText(text, fam, sizePx, style := 0) {
    static G := 0, bmp := 0
    if !G {
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", 1, "int", 1, "int", 0, "int", 0x26200A, "ptr", 0, "ptr*", &bmp)
        DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", bmp, "ptr*", &G)
        DllCall("gdiplus\GdipSetTextRenderingHint", "ptr", G, "int", 4)
    }
    if (!fam || text = "")
        return 0
    MakeFont(fam, sizePx, style, &font, &fmt)
    rc := Buffer(16, 0)
    NumPut("float", 100000, rc, 8), NumPut("float", 1000, rc, 12)
    out := Buffer(16, 0)
    DllCall("gdiplus\GdipMeasureString", "ptr", G, "wstr", text, "int", -1, "ptr", font, "ptr", rc, "ptr", fmt, "ptr", out, "ptr", 0, "ptr", 0)
    FreeFont(font, fmt)
    return Ceil(NumGet(out, 8, "float"))
}

; =====================================================================
;  PANELS  (the bar and every popup are panels)
; =====================================================================
; ---------- Panels: the bar and every popup ----------
NewPanel(w, h, owner := 0) {
    g := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08080000" (owner ? " +Owner" owner : ""))
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", g.Hwnd, "int", 33, "int*", 1, "int", 4)            ; no Windows 11 corner rounding
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", g.Hwnd, "int", 34, "uint*", 0xFFFFFFFE, "int", 4)  ; no Windows 11 border
    p := Map("gui", g, "hwnd", g.Hwnd, "w", w, "h", h, "items", [], "hot", 0, "x", 0, "y", 0
           , "radius", h / 2, "look", Look)
    Panels[g.Hwnd] := p
    return p
}

; one button / label inside a panel. click = function to run, "" = not clickable
PanelItem(p, x, y, w, h, text, fam, sizePx, style := 0, click := "", r := 0, color := "") {
    it := Map("x", x, "y", y, "w", w, "h", h, "text", text, "fam", fam, "size", sizePx, "style", style
            , "click", click, "r", r ? r : h / 2, "color", color)
    p["items"].Push(it)
    return it
}

PanelShow(p, x, y) {
    p["x"] := x, p["y"] := y
    p["gui"].Show("NA x" x " y" y " w" p["w"] " h" p["h"])
    PanelRender(p)
}

PanelHide(p) {
    if IsObject(p)
        try p["gui"].Hide()
}

PanelDestroy(p) {
    if !IsObject(p)
        return
    if Panels.Has(p["hwnd"])
        Panels.Delete(p["hwnd"])
    try p["gui"].Destroy()
}

PanelMove(p, x, y) {
    if (x = p["x"] && y = p["y"])
        return
    p["x"] := x, p["y"] := y
    DllCall("SetWindowPos", "ptr", p["hwnd"], "ptr", 0, "int", x, "int", y, "int", 0, "int", 0, "uint", 0x15)
}

PanelHit(p, lx, ly) {
    for i, it in p["items"] {
        if (IsObject(it["click"]) && lx >= it["x"] && lx < it["x"] + it["w"] && ly >= it["y"] && ly < it["y"] + it["h"])
            return i
    }
    return 0
}

; hover: which button is under the mouse (0 = none). Redraws only when it changes.
PanelTrack(p) {
    MouseGetPos(&mx, &my, &win)
    over := (win = p["hwnd"])
    idx := over ? PanelHit(p, mx - p["x"], my - p["y"]) : 0
    if (idx != p["hot"]) {
        p["hot"] := idx
        PanelRender(p)
    }
    return over
}

PanelRender(p) {
    w := p["w"], h := p["h"], lk := p["look"]
    hdcS := DllCall("GetDC", "ptr", 0, "ptr")
    hdc := DllCall("CreateCompatibleDC", "ptr", hdcS, "ptr")
    bi := Buffer(40, 0)
    NumPut("uint", 40, bi, 0), NumPut("int", w, bi, 4), NumPut("int", -h, bi, 8)
    NumPut("ushort", 1, bi, 12), NumPut("ushort", 32, bi, 14)
    pBits := 0
    hbm := DllCall("CreateDIBSection", "ptr", hdc, "ptr", bi, "uint", 0, "ptr*", &pBits, "ptr", 0, "uint", 0, "ptr")
    obm := DllCall("SelectObject", "ptr", hdc, "ptr", hbm, "ptr")
    bmp := 0, G := 0
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", w, "int", h, "int", w * 4, "int", 0xE200B, "ptr", pBits, "ptr*", &bmp)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", bmp, "ptr*", &G)
    DllCall("gdiplus\GdipSetSmoothingMode", "ptr", G, "int", 4)
    DllCall("gdiplus\GdipSetTextRenderingHint", "ptr", G, "int", 4)

    a := lk["alpha"]
    k := lk["round"]                          ; corner rounding 0..1
    rad := p["radius"] * k
    FillRound(G, ARGB(a, lk["bg"]), 0, 0, w, h, rad)
    DrawRound(G, ARGB(a, lk["border"]), 0.5, 0.5, w - 1, h - 1, Max(0, rad - 0.5))
    for i, it in p["items"] {
        if (i = p["hot"])
            FillRound(G, ARGB(Min(255, a + 60), lk["hover"]), it["x"], it["y"], it["w"], it["h"], it["r"] * k)
        col := (it["color"] = "dim") ? lk["dim"] : lk["icon"]
        DrawLabel(G, it["text"], it["fam"], it["size"], it["style"], ARGB(255, col), it["x"], it["y"], it["w"], it["h"])
    }
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", G)
    DllCall("gdiplus\GdipDisposeImage", "ptr", bmp)

    pt := Buffer(8), sz := Buffer(8), src := Buffer(8, 0)
    NumPut("int", p["x"], pt, 0), NumPut("int", p["y"], pt, 4)
    NumPut("int", w, sz, 0), NumPut("int", h, sz, 4)
    DllCall("UpdateLayeredWindow", "ptr", p["hwnd"], "ptr", hdcS, "ptr", pt, "ptr", sz, "ptr", hdc
          , "ptr", src, "uint", 0, "uint*", 0x01FF0000, "uint", 2)
    DllCall("SelectObject", "ptr", hdc, "ptr", obm)
    DllCall("DeleteObject", "ptr", hbm)
    DllCall("DeleteDC", "ptr", hdc)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdcS)
}

; a click on any panel: run the button under the mouse
OnPanelClick(wParam, lParam, msg, hwnd) {
    if !Panels.Has(hwnd)
        return
    p := Panels[hwnd]
    idx := PanelHit(p, lParam & 0xFFFF, (lParam >> 16) & 0xFFFF)
    if idx
        SetTimer(p["items"][idx]["click"], -1)
    return 0
}

; =====================================================================
;  THE FLOATING BAR
; =====================================================================
GlyphFor(def, &fam, &size, &style) {
    style := 0
    if famGlyph {
        fam := famGlyph, size := Pt(GlyphSize)
    } else if (def["icon"] && famMDL2) {
        fam := famMDL2, size := Pt(12)
    } else if def.Has("font") {
        fam := famSym, size := Pt(11)
    } else {
        fam := famUI, size := Pt(11)
    }
    return famGlyph ? def["g"] : def["glyph"]
}

; builds a bar panel for the given buttons (also used by the preview in Settings)
MakeBarPanel(defs, owner := 0) {
    dia := Round(BtnSize * Scale)
    gap := Round(BtnGap * Scale)
    pad := Round(BarPad * Scale)
    w := defs.Length * dia + (defs.Length - 1) * gap + 2 * pad
    h := dia + 2 * pad
    p := NewPanel(w, h, owner)
    x := pad
    for def in defs {
        text := GlyphFor(def, &fam, &size, &style)
        it := PanelItem(p, x, pad, dia, dia, text, fam, size, style, owner ? "" : DoAction.Bind(def["key"]))
        it["key"] := def["key"]
        x += dia + gap
    }
    return p
}

BuildBar() {
    global bar, barP, barW, barH, barVisible
    barVisible := false
    ToolTip()
    if IsObject(barP)
        PanelDestroy(barP)
    bar := "", barP := ""
    active := []
    for def in Defs {
        if Enabled[def["key"]]
            active.Push(def)
    }
    if (active.Length = 0)
        return
    barP := MakeBarPanel(active)
    bar := barP["gui"]
    barW := barP["w"], barH := barP["h"]
}

ShowBar(mx, my) {
    global barVisible, shownTick, barX, barY
    if !IsObject(barP)
        return
    GetWorkAreaAt(mx, my, &wl, &wt, &wr, &wb)
    gap := Round(16 * Scale)
    px := mx - barW // 2
    py := my - barH - gap
    if (py < wt)
        py := my + gap * 2
    px := Max(wl + 4, Min(px, wr - barW - 4))
    py := Max(wt + 4, Min(py, wb - barH - 4))
    barX := px
    barY := py
    barP["hot"] := 0
    barP["look"] := Look
    PanelShow(barP, px, py)
    barVisible := true
    shownTick := A_TickCount
    SetTimer(HoverTick, 40)
}

HideBar() {
    global barVisible
    if !barVisible
        return
    barVisible := false
    SetTimer(HoverTick, 0)
    ToolTip()
    PanelHide(barP)
}

HoverTick() {
    if (!barVisible || !IsObject(barP)) {
        SetTimer(HoverTick, 0)
        return
    }
    before := barP["hot"]
    over := PanelTrack(barP)
    if (barP["hot"] != before) {
        if barP["hot"]
            ShowTip(barP["items"][barP["hot"]]["key"])
        else
            ToolTip()
    }
    if (!over && A_TickCount - shownTick > AutoHideMs)
        HideBar()
}

ShowTip(key) {
    text := Labels[key]
    if (key = "translate")
        text := "Translate to " LangName(TargetLang)
    ty := barY - Round(30 * Scale)
    if (ty < 0)
        ty := barY + barH + Round(8 * Scale)
    ToolTip(text, barX, ty)
}

LangName(code) {
    for l in Langs {
        if (l[2] = code)
            return l[1]
    }
    return code
}

GetWorkAreaAt(x, y, &l, &t, &r, &b) {
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &ml, &mt, &mr, &mb)
        if (x >= ml && x < mr && y >= mt && y < mb) {
            MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
            return
        }
    }
    MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
}

; =====================================================================
;  POPUPS  (symbols, saved emails, spelling result)
; =====================================================================
PopupStart(w, h, radius) {
    global symGui, symP
    HideSymbols()
    symP := NewPanel(w, h)
    symP["radius"] := radius
    symGui := symP["gui"]
    return symP
}

PopupShowAt(px, py) {
    global symVisible, symShownTick
    PanelShow(symP, px, py)
    symVisible := true
    symShownTick := A_TickCount
    SetTimer(SymHoverTick, 40)
}

; a symbol uses Segoe UI Symbol when it is not a plain letter / punctuation
SymFamily(sym) {
    return (Ord(sym) >= 0x2000) ? famSym : famUI
}

ShowSymbols() {
    n := Symbols.Length
    if (n = 0)
        return
    dia := Round(BtnSize * Scale)
    gap := Round(BtnGap * Scale)
    pad := Round(BarPad * Scale)
    perRow := 10                                  ; more than 10 symbols wrap to a new row
    cols := Min(n, perRow)
    rows := Ceil(n / perRow)
    w := cols * dia + (cols - 1) * gap + 2 * pad
    h := rows * dia + (rows - 1) * gap + 2 * pad
    p := PopupStart(w, h, Min(h, dia + 2 * pad) / 2)
    for i, sym in Symbols {
        sx := pad + Mod(i - 1, perRow) * (dia + gap)
        sy := pad + ((i - 1) // perRow) * (dia + gap)
        PanelItem(p, sx, sy, dia, dia, sym, SymFamily(sym), Pt(12), 0, PickSymbol.Bind(sym))
    }
    GetWorkAreaAt(barX, barY, &wl, &wt, &wr, &wb)
    px := Max(wl + 4, Min(barX + (barW - w) // 2, wr - w - 4))
    py := Max(wt + 4, Min(barY, wb - h - 4))
    PopupShowAt(px, py)
}

HideSymbols() {
    global symGui, symP, symVisible
    SetTimer(SymHoverTick, 0)
    symVisible := false
    if IsObject(symP)
        PanelDestroy(symP)
    symP := "", symGui := ""
}

SymHoverTick() {
    if (!symVisible || !IsObject(symP)) {
        SetTimer(SymHoverTick, 0)
        return
    }
    over := PanelTrack(symP)
    if (!over && A_TickCount - symShownTick > AutoHideMs)
        HideSymbols()
}

PickSymbol(sym, *) {
    HideSymbols()
    PasteReplace(sym)
}

ShowEmails() {
    n := Emails.Length
    dia := Round(BtnSize * Scale)
    gap := Round(BtnGap * Scale)
    pad := Round(BarPad * Scale)
    maxW := 0
    for e in Emails
        maxW := Max(maxW, MeasureText(e, famUI, Pt(10)))
    rowW := Min(Round(600 * Scale), Max(Round(150 * Scale), maxW + Round(36 * Scale)))
    w := rowW + 2 * pad
    h := n * dia + (n - 1) * gap + 2 * pad
    p := PopupStart(w, h, (dia + 2 * pad) / 2)
    y := pad
    for e in Emails {
        PanelItem(p, pad, y, rowW, dia, e, famUI, Pt(10), 0, PickSymbol.Bind(e))
        y += dia + gap
    }
    GetWorkAreaAt(barX, barY, &wl, &wt, &wr, &wb)
    px := Max(wl + 4, Min(barX + (barW - w) // 2, wr - w - 4))
    py := barY + barH - h
    if (py < wt)
        py := barY
    py := Max(wt + 4, Min(py, wb - h - 4))
    PopupShowAt(px, py)
}

; Popup with the corrected text. Click it to replace your selection.
ShowSpellPopup(fixed, count, langName) {
    dia := Round(BtnSize * Scale)
    gap := Round(BtnGap * Scale)
    pad := Round(BarPad * Scale)
    shown := Trim(RegExReplace(fixed, "\s+", " "))
    if (StrLen(shown) > 90)
        shown := SubStr(shown, 1, 90) "..."
    info := (langName != "" ? langName " - " : "") count (count = 1 ? " correction" : " corrections") " - click to apply"
    infoH := Round(20 * Scale)
    textW := Max(MeasureText(shown, famUI, Pt(10)), MeasureText(info, famUIReg, Pt(8)))
    rowW := Min(Round(620 * Scale), Max(Round(200 * Scale), textW + Round(40 * Scale)))
    w := rowW + 2 * pad
    h := pad + infoH + gap + dia + pad
    p := PopupStart(w, h, (dia + 2 * pad) / 2)
    PanelItem(p, pad, pad, rowW, infoH, info, famUIReg, Pt(8), 0, "", 0, "dim")
    PanelItem(p, pad, pad + infoH + gap, rowW, dia, shown, famUI, Pt(10), 0, PickSymbol.Bind(fixed))
    GetWorkAreaAt(barX, barY, &wl, &wt, &wr, &wb)
    px := Max(wl + 4, Min(barX + (barW - w) // 2, wr - w - 4))
    py := barY + barH - h
    if (py < wt)
        py := barY
    py := Max(wt + 4, Min(py, wb - h - 4))
    PopupShowAt(px, py)
}

; =====================================================================
;  SPELLING AND GRAMMAR  (LanguageTool public API, free)
; =====================================================================
SpellCheck(txt) {
    global spellBusy
    if spellBusy
        return
    src := StrReplace(txt, "`r`n", "`n")
    hadCRLF := (src != txt)
    tail := ""
    if (StrLen(src) > 18000) {            ; free API limit is 20 000 characters per request
        tail := SubStr(src, 18001)
        src := SubStr(src, 1, 18000)
    }
    if (Trim(src, " `t`n") = "")
        return
    spellBusy := true
    SpellToast("Checking...", 0)
    json := ""
    err := ""
    try
        json := LTRequest(src)
    catch as e
        err := e.Message
    spellBusy := false
    if (err != "") {
        SpellToast("Spell check failed: " err, 3500)
        return
    }
    try
        res := JsonParse(json)
    catch {
        SpellToast("Spell check failed: unreadable answer", 3000)
        return
    }
    langName := ""
    try langName := res["language"]["detectedLanguage"]["name"]
    if (langName = "")
        try langName := res["language"]["name"]

    fixed := src
    count := 0
    nextStart := StrLen(src) + 1
    try matches := res["matches"]
    catch
        matches := []
    i := matches.Length
    while (i >= 1) {                      ; from the end, so earlier offsets stay valid
        m := matches[i]
        i -= 1
        try {
            reps := m["replacements"]
            if (reps.Length = 0)
                continue
            off := Integer(m["offset"])
            len := Integer(m["length"])
            if (off + len > nextStart - 1)     ; overlapping match, skip
                continue
            fixed := SubStr(fixed, 1, off) . reps[1]["value"] . SubStr(fixed, off + len + 1)
            nextStart := off + 1
            count += 1
        }
    }
    if (count = 0 || fixed = src) {
        SpellToast("No mistake found" (langName != "" ? "  (" langName ")" : ""), 1800)
        return
    }
    fixed .= tail
    if hadCRLF
        fixed := StrReplace(fixed, "`n", "`r`n")
    SpellToast("", 0)
    ShowSpellPopup(fixed, count, langName)
}

LTRequest(text) {
    body := "text=" UrlEncode(text)
    if (SpellLang = "auto") {
        body .= "&language=auto&preferredVariants=" UrlEncode("en-US,de-DE,pt-PT,ca-ES")
        langs := CleanLangList(MyLangs)
        if (langs != "")
            body .= "&preferredLanguages=" UrlEncode(langs)
    } else
        body .= "&language=" SpellLang
    whr := ComObject("WinHttp.WinHttpRequest.5.1")
    whr.SetTimeouts(4000, 4000, 8000, 15000)
    whr.Open("POST", "https://api.languagetool.org/v2/check", true)    ; async: the PC never freezes
    whr.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded; charset=UTF-8")
    whr.Send(body)
    t0 := A_TickCount
    while !whr.WaitForResponse(0) {
        if (A_TickCount - t0 > 20000)
            throw Error("timeout")
        Sleep(30)
    }
    if (whr.Status = 429)
        throw Error("too many requests, wait a minute")
    if (whr.Status != 200)
        throw Error("server answered " whr.Status)
    return Utf8Body(whr)
}

; LanguageTool answers in UTF-8; ResponseText may decode it as ANSI (é -> Ã©)
Utf8Body(whr) {
    try {
        arr := whr.ResponseBody
        n := arr.MaxIndex() + 1
        if (n <= 0)
            return ""
        buf := Buffer(n)
        i := 0
        for b in arr {
            NumPut("UChar", b, buf, i)
            i += 1
        }
        return StrGet(buf, n, "UTF-8")
    }
    return whr.ResponseText
}

; "FR, en-GB ; es" -> "fr,en,es"  (the API only accepts codes without variants here)
CleanLangList(str) {
    out := ""
    seen := Map()
    for part in StrSplit(StrReplace(StrReplace(str, ";", ","), " ", ","), ",") {
        code := StrLower(Trim(StrSplit(part, "-")[1]))
        if (code = "" || !RegExMatch(code, "^[a-z]{2,3}$") || seen.Has(code))
            continue
        seen[code] := 1
        out .= (out = "" ? "" : ",") code
    }
    return out
}

SpellToast(text, ms) {
    ty := barY - Round(30 * Scale)
    if (ty < 0)
        ty := barY + barH + Round(8 * Scale)
    ToolTip(text, barX, ty)
    if (text != "" && ms > 0)
        SetTimer(() => ToolTip(), -ms)
}

; ---------- tiny JSON reader (objects -> Map, arrays -> Array) ----------
JsonParse(s) {
    p := 1
    return JVal(s, &p)
}

JWs(s, &p) {
    if RegExMatch(s, "A)\s+", &m, p)
        p += m.Len
}

JVal(s, &p) {
    JWs(s, &p)
    ch := SubStr(s, p, 1)
    if (ch = "{") {
        o := Map()
        p += 1
        JWs(s, &p)
        if (SubStr(s, p, 1) = "}") {
            p += 1
            return o
        }
        Loop {
            JWs(s, &p)
            k := JStr(s, &p)
            JWs(s, &p)
            p += 1                              ; the ':'
            o[k] := JVal(s, &p)
            JWs(s, &p)
            c := SubStr(s, p, 1)
            p += 1
            if (c != ",")
                break
        }
        return o
    }
    if (ch = "[") {
        a := []
        p += 1
        JWs(s, &p)
        if (SubStr(s, p, 1) = "]") {
            p += 1
            return a
        }
        Loop {
            a.Push(JVal(s, &p))
            JWs(s, &p)
            c := SubStr(s, p, 1)
            p += 1
            if (c != ",")
                break
        }
        return a
    }
    if (ch = '"')
        return JStr(s, &p)
    if RegExMatch(s, "A)-?\d+(\.\d+)?([eE][+-]?\d+)?", &m, p) {
        p += m.Len
        return m[0] + 0
    }
    if (SubStr(s, p, 4) = "true") {
        p += 4
        return 1
    }
    if (SubStr(s, p, 5) = "false") {
        p += 5
        return 0
    }
    p += 4                                      ; null
    return ""
}

JStr(s, &p) {
    p += 1                                      ; opening quote
    out := ""
    Loop {
        RegExMatch(s, 'A)[^"\\]*', &m, p)
        out .= m[0]
        p += m.Len
        c := SubStr(s, p, 1)
        if (c = '"') {
            p += 1
            return out
        }
        if (c = "")
            return out
        e := SubStr(s, p + 1, 1)
        p += 2
        switch e {
            case "n": out .= "`n"
            case "t": out .= "`t"
            case "r": out .= "`r"
            case "b": out .= "`b"
            case "f": out .= "`f"
            case "u":
                out .= Chr(Integer("0x" SubStr(s, p, 4)))
                p += 4
            default: out .= e
        }
    }
}

; =====================================================================
;  TRAY MENU AND START WITH WINDOWS
; =====================================================================
TogglePause(name, pos, menu) {
    global paused
    paused := !paused
    A_TrayMenu.ToggleCheck(name)
    if paused {
        HideBar()
        HideSymbols()
        ToolTip()
    }
    try TraySetIcon(paused ? IconOffFile : IconFile)
    A_IconTip := APP_NAME " " APP_VERSION (paused ? " (paused)" : "")
}

IsStartupOn() {
    return FileExist(StartupLink) ? true : false
}

SetStartup(on) {
    if on {
        target := A_IsCompiled ? A_ScriptFullPath : A_AhkPath
        args   := A_IsCompiled ? "" : '"' A_ScriptFullPath '"'
        icon   := FileExist(IconFile) ? IconFile : target
        try FileCreateShortcut(target, StartupLink, A_ScriptDir, args, APP_NAME, icon)
    } else if FileExist(StartupLink)
        try FileDelete(StartupLink)
}

; =====================================================================
;  SETTINGS WINDOW  (dark, one tab per topic)
; =====================================================================
ShowSettings(*) {
    global settingsGui, setPanels, setTabBtns, setHot, setBgNow, setActiveTab, setSaveBtn
    if IsObject(settingsGui) {           ; already open: just bring it to the front
        settingsGui.Show()
        return
    }
    HideBar()
    HideSymbols()
    setPanels := Map("buttons", [], "design", [], "symbols", [], "language", [], "emails", [], "general", [])
    setTabBtns := Map(), setHot := Map(), setBgNow := Map()

    ; 0x2000000 = the window never paints over its own controls (no flicker)
    g := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox +0x2000000", APP_NAME " settings")
    g.BackColor := C_BG
    g.MarginX := 0, g.MarginY := 0
    g.SetFont("s9", "Segoe UI")
    DarkTitle(g.Hwnd)

    ; header
    if FileExist(IconFile)
        g.AddPicture("x20 y16 w32 h32", IconFile)
    g.AddText("x62 y17 w300 h22", APP_NAME).SetFont("s13 bold c" C_TXT, "Segoe UI")
    g.AddText("x63 y39 w300 h16", "Text toolbar for Windows").SetFont("s8 c" C_DIM, "Segoe UI")

    ; tabs
    tx := 20
    for t in [["buttons", "Buttons"], ["design", "Design"], ["symbols", "Symbols"]
            , ["language", "Language"], ["emails", "Emails"], ["general", "General"]] {
        setTabBtns[t[1]] := AddPill(g, "", "x" tx " y72 w80 h30", t[2], SwitchTab.Bind(t[1]), "tab:" t[1])
        tx += 88
    }
    g.AddText("x20 y114 w520 h1 Background" C_LINE)

    TabButtons(g)
    TabDesign(g)
    TabSymbols(g)
    TabLanguage(g)
    TabEmails(g)
    TabGeneral(g)

    ; footer
    g.AddText("x20 y528 w520 h1 Background" C_LINE)
    g.AddText("x20 y542 w260 h30 +0x200", "v" APP_VERSION "   -   by " APP_AUTHOR).SetFont("s8 c" C_DIM, "Segoe UI")
    AddPill(g, "", "x330 y540 w100 h32", "Close", SettingsClosed)
    setSaveBtn := AddPill(g, "", "x440 y540 w100 h32", "Save", SaveSettings, "save")

    g.OnEvent("Close", SettingsClosed)
    g.OnEvent("Escape", SettingsClosed)
    settingsGui := g
    SwitchTab("buttons")
    g.Show("w560 h590")
    DarkTitle(g.Hwnd)
    SetTimer(SettingsHoverTick, 60)
}

TabButtons(g) {
    global setBoxes
    setBoxes := Map()
    AddPanelText(g, "buttons", "x20 y132 w500 h18", "Choose which buttons appear in the bar", C_DIM, "s9")
    for i, def in Defs {
        bx := 20 + ((i - 1) // 6) * 255          ; two columns of six
        by := 160 + Mod(i - 1, 6) * 28
        cb := g.AddCheckbox("x" bx " y" by " w245 h24", def["label"])
        cb.SetFont("s9 c" C_TXT, "Segoe UI")
        cb.Value := Enabled[def["key"]] ? 1 : 0
        DarkCtrl(cb.Hwnd)
        setBoxes[def["key"]] := cb
        setPanels["buttons"].Push(cb)
    }
}

TabDesign(g) {
    global setThemeSel, setThemePills, setColorFields
    global setIconLightEd, setIconDarkEd, setCustBgEd, setCustIconEd
    global setOpacitySl, setOpacityTxt, setRoundSl, setRoundTxt

    AddPanelText(g, "design", "x20 y132 w500 h18", "Theme", C_DIM, "s9")
    setThemeSel := ThemeMode
    setThemePills := Map()
    tx := 20
    for t in [["auto", "Automatic"], ["light", "Light"], ["dark", "Dark"], ["custom", "Custom"]] {
        setThemePills[t[1]] := AddPill(g, "design", "x" tx " y156 w122 h30", t[2], PickTheme.Bind(t[1]), "theme:" t[1])
        tx += 130
    }
    RefreshThemePills()
    AddPanelText(g, "design", "x20 y192 w520 h16", "Automatic follows the Windows dark / light mode.", C_DIM, "s8")

    AddPanelText(g, "design", "x20 y226 w380 h18", "Colors  (hex code, or click Pick)", C_DIM, "s9")
    AddPill(g, "design", "x420 y222 w100 h26", "Reset colors", ResetIconColors)
    setColorFields := []
    setIconLightEd := ColorRow(g, 252, "Light theme", "Icons", IconLight, ThemeDefaults["light"]["icon"])
    setIconDarkEd  := ColorRow(g, 284, "Dark theme", "Icons", IconDark, ThemeDefaults["dark"]["icon"])
    setCustBgEd    := ColorRow(g, 316, "Custom theme", "Background", CustomBg, DefaultCustomBg)
    setCustIconEd  := ColorRow(g, 348, "", "Icons", CustomIcon, DefaultCustomIcon)

    AddPanelText(g, "design", "x20 y388 w240 h18", "Background opacity", C_DIM, "s9")
    setOpacitySl  := AddSlider(g, "x14 y410 w206 h26 Range20-100", OpacityPct, OpacityMoved)
    setOpacityTxt := AddPanelText(g, "design", "x222 y410 w48 h24 +0x200", OpacityPct " %", C_TXT, "s9")
    AddPanelText(g, "design", "x290 y388 w240 h18", "Corner rounding", C_DIM, "s9")
    setRoundSl    := AddSlider(g, "x284 y410 w206 h26 Range0-100", RoundingPct, RoundingMoved)
    setRoundTxt   := AddPanelText(g, "design", "x492 y410 w48 h24 +0x200", RoundingPct " %", C_TXT, "s9")
    AddPanelText(g, "design", "x20 y438 w520 h16"
        , "Opacity: only the background, icons stay solid.    Rounding: 0% = sharp, 100% = fully round.", C_DIM, "s8")
    AddPanelText(g, "design", "x20 y456 w100 h16", "Preview", C_DIM, "s8")
}

TabSymbols(g) {
    global setSymList, setSymLB, setSymEd
    AddPanelText(g, "symbols", "x20 y132 w500 h18", "Symbols shown when you click the symbols button in the bar", C_DIM, "s9")
    setSymList := Symbols.Clone()
    ; 0x100 = the list fills its whole box (otherwise Windows leaves an unpainted strip)
    setSymLB := g.AddListBox("x20 y158 w300 h270 +0x100 -E0x200 Background" C_BG2, setSymList)
    setSymLB.SetFont("s13 c" C_TXT, "Segoe UI Semibold")
    DarkCtrl(setSymLB.Hwnd)
    setPanels["symbols"].Push(setSymLB)
    AddPill(g, "symbols", "x340 y158 w180 h32", "Move up", SymMove.Bind(-1))
    AddPill(g, "symbols", "x340 y198 w180 h32", "Move down", SymMove.Bind(1))
    AddPill(g, "symbols", "x340 y238 w180 h32", "Remove", SymRemove)
    setSymEd := g.AddEdit("x20 y440 w220 h28 -E0x200 Background" C_BG2, "")
    setSymEd.SetFont("s12 c" C_TXT, "Segoe UI")
    DarkCtrl(setSymEd.Hwnd)
    setPanels["symbols"].Push(setSymEd)
    AddPill(g, "symbols", "x250 y440 w70 h28", "Add", SymAdd)
    AddPanelText(g, "symbols", "x20 y476 w520 h34",
        "Type or paste one or more symbols (separate several with spaces), then click Add.`n"
        . "Tip: press  Win + .  (period) to open the Windows symbol picker.", C_DIM, "s8")
}

TabLanguage(g) {
    global setLangDD, setSpellDD, setMyLangsEd
    AddPanelText(g, "language", "x20 y132 w500 h18", "Translate the selected text into", C_DIM, "s9")
    setLangDD := AddDropDown(g, "language", "x20 y158 w260", Langs, TargetLang)
    AddPanelText(g, "language", "x20 y206 w260 h18", "Spelling and grammar check language", C_DIM, "s9")
    setSpellDD := AddDropDown(g, "language", "x20 y232 w260", SpellLangs, SpellLang)
    AddPanelText(g, "language", "x300 y206 w240 h18", "Languages I write in (auto-detect)", C_DIM, "s9")
    setMyLangsEd := g.AddEdit("x300 y232 w220 h24 -E0x200 Background" C_BG2, MyLangs)
    setMyLangsEd.SetFont("s9 c" C_TXT, "Consolas")
    DarkCtrl(setMyLangsEd.Hwnd)
    setPanels["language"].Push(setMyLangsEd)
    AddPanelText(g, "language", "x20 y274 w520 h70",
        "Short codes separated by commas, e.g.  fr,en  or  fr,en,es.  Auto-detect only picks`n"
        . "from these, so a short text like `"je suis decu`" is not taken for another language.`n`n"
        . "The checked text is sent to languagetool.org (free service, 20 checks per minute).", C_DIM, "s8")
}

TabEmails(g) {
    global setEmailEd
    AddPanelText(g, "emails", "x20 y132 w500 h18", "Saved emails (one per line)", C_DIM, "s9")
    text := ""
    for e in Emails
        text .= (text = "" ? "" : "`n") e
    setEmailEd := g.AddEdit("x20 y158 w500 r8 -E0x200 Background" C_BG2, text)
    setEmailEd.SetFont("s9 c" C_TXT, "Consolas")
    DarkCtrl(setEmailEd.Hwnd)
    setPanels["emails"].Push(setEmailEd)
    AddPanelText(g, "emails", "x20 y296 w500 h18", "Click the e-mail button in the bar to paste one of them.", C_DIM, "s8")
}

TabGeneral(g) {
    global setStartCb, setHideDD, setExclEd
    setStartCb := g.AddCheckbox("x20 y134 w360 h24", "Start with Windows")
    setStartCb.SetFont("s9 c" C_TXT, "Segoe UI")
    setStartCb.Value := IsStartupOn() ? 1 : 0
    DarkCtrl(setStartCb.Hwnd)
    setPanels["general"].Push(setStartCb)
    AddPill(g, "general", "x400 y132 w120 h28", "Open folder", (*) => Run(DataDir))

    AddPanelText(g, "general", "x20 y168 w500 h18", "Hide the bar by itself after", C_DIM, "s9")
    hide := []
    for i, v in HideValues
        hide.Push([HideChoices[i], v])
    setHideDD := AddDropDown(g, "general", "x20 y192 w160", hide, AutoHideMs, 3)

    AddPanelText(g, "general", "x20 y230 w500 h18", "Never show the bar in these apps (one per line)", C_DIM, "s9")
    text := ""
    for p in ExcludedApps
        text .= (text = "" ? "" : "`n") p
    setExclEd := g.AddEdit("x20 y254 w500 r4 -E0x200 Background" C_BG2, text)
    setExclEd.SetFont("s9 c" C_TXT, "Consolas")
    DarkCtrl(setExclEd.Hwnd)
    setPanels["general"].Push(setExclEd)
    AddPanelText(g, "general", "x20 y332 w500 h16",
        "Example: photoshop.exe    -    the bar already ignores anything that is not text.", C_DIM, "s8")

    AddPanelText(g, "general", "x20 y362 w520 h18", "Bar not showing up?", C_ACC, "s9 bold")
    AddPanelText(g, "general", "x20 y384 w520 h64",
        "-  In any app: select your text, then press  Ctrl+Alt+B  to show the bar.`n"
        . "-  Adobe apps (Illustrator...): pick the text tool, hover over text, press  Ctrl+Alt+Shift+B,`n"
        . "   release the keys and click Yes. SnipBar remembers that text cursor for good`n"
        . "   (do it again after an app update or a display scaling change).", C_DIM, "s8")
}

; ---------- small builders for the Settings window ----------
AddPanelText(g, panel, opts, text, color, size) {
    c := g.AddText(opts, text)
    c.SetFont(size " c" color, "Segoe UI")
    setPanels[panel].Push(c)
    return c
}

; a clickable label: tabs, theme choices and buttons.  panel "" = always visible
AddPill(g, panel, opts, text, handler, role := "btn") {
    isSave := (role = "save")
    c := g.AddText(opts " +0x200 Center Background" (isSave ? C_ACC : C_BG2), text)
    c.SetFont(isSave ? "s9 bold c" C_BG : "s9 c" C_TXT, "Segoe UI")
    c.OnEvent("Click", handler)
    setHot[c.Hwnd] := role
    setBgNow[c.Hwnd] := isSave ? C_ACC : C_BG2
    if (panel != "")
        setPanels[panel].Push(c)
    return c
}

; drop-down from a list of [name, value] pairs, with the saved value selected
AddDropDown(g, panel, opts, pairs, current, fallback := 1) {
    names := [], sel := fallback
    for i, pair in pairs {
        names.Push(pair[1])
        if (pair[2] = current)
            sel := i
    }
    dd := g.AddDropDownList(opts " Background" C_BG2, names)
    dd.SetFont("s9 c" C_TXT, "Segoe UI")
    dd.Choose(sel)
    DarkCtrl(dd.Hwnd, "DarkMode_CFD")
    setPanels[panel].Push(dd)
    return dd
}

AddSlider(g, opts, value, handler) {
    sl := g.AddSlider(opts " NoTicks Background" C_BG, value)
    DarkCtrl(sl.Hwnd)
    sl.OnEvent("Change", handler)
    setPanels["design"].Push(sl)
    return sl
}

; ---------- tabs, hover, close, save ----------
SwitchTab(name, *) {
    global setActiveTab
    setActiveTab := name
    for key, list in setPanels {
        for c in list
            c.Visible := (key = name)
    }
    for key, btn in setTabBtns {
        on := (key = name)
        btn.Opt("+Background" (on ? C_ACC : C_BG2))
        btn.SetFont(on ? "s9 bold c" C_BG : "s9 norm c" C_DIM, "Segoe UI")
        setBgNow[btn.Hwnd] := on ? C_ACC : C_BG2
    }
    ; repaint the whole window: rounded buttons of the hidden tab would
    ; otherwise leave their corners behind on screen
    DllCall("RedrawWindow", "ptr", settingsGui.Hwnd, "ptr", 0, "ptr", 0, "uint", 0x185)
    if (name = "design")
        RefreshPreview(true)
    else
        HidePreview()
}

SettingsHoverTick() {
    if !IsObject(settingsGui) {
        SetTimer(SettingsHoverTick, 0)
        return
    }
    MouseGetPos(, , &win, &hc, 2)
    try
        inGui := (win = settingsGui.Hwnd)
    catch {
        SetTimer(SettingsHoverTick, 0)
        return
    }
    PositionPreview()
    for hwnd, role in setHot {
        hovered := (inGui && hc = hwnd)
        if (SubStr(role, 1, 4) = "tab:")
            want := (SubStr(role, 5) = setActiveTab) ? C_ACC : (hovered ? C_BG3 : C_BG2)
        else if (SubStr(role, 1, 6) = "theme:")
            want := (SubStr(role, 7) = setThemeSel) ? C_ACC : (hovered ? C_BG3 : C_BG2)
        else if (role = "save")
            want := hovered ? C_ACC2 : C_ACC
        else
            want := hovered ? C_BG3 : C_BG2
        if (setBgNow[hwnd] != want) {
            setBgNow[hwnd] := want
            SetBg(hwnd, want)
        }
    }
}

SettingsClosed(*) {
    global settingsGui
    SetTimer(SettingsHoverTick, 0)
    HidePreview()
    if IsObject(settingsGui)
        try settingsGui.Destroy()
    settingsGui := ""
}

; applies and saves everything; the window stays open
SaveSettings(*) {
    global TargetLang, SpellLang, MyLangs, Emails, AutoHideMs, ExcludedApps, Symbols
    global ThemeMode, IconLight, IconDark, CustomBg, CustomIcon, OpacityPct, RoundingPct

    ; buttons
    for def in Defs {
        key := def["key"]
        Enabled[key] := (setBoxes[key].Value = 1)
        IniWrite(Enabled[key] ? "1" : "0", IniFile, "Buttons", key)
    }

    ; design
    ThemeMode   := setThemeSel
    IconLight   := CleanHex(setIconLightEd.Value, IconLight)
    IconDark    := CleanHex(setIconDarkEd.Value, IconDark)
    CustomBg    := CleanHex(setCustBgEd.Value, CustomBg)
    CustomIcon  := CleanHex(setCustIconEd.Value, CustomIcon)
    OpacityPct  := setOpacitySl.Value
    RoundingPct := setRoundSl.Value
    for k, v in Map("Theme", ThemeMode, "IconLight", IconLight, "IconDark", IconDark, "CustomBg", CustomBg
                  , "CustomIcon", CustomIcon, "Opacity", OpacityPct, "Rounding", RoundingPct)
        IniWrite(v, IniFile, "Look", k)

    ; symbols
    Symbols := setSymList.Clone()
    IniDelete(IniFile, "Symbols")
    IniWrite(Symbols.Length, IniFile, "Symbols", "Count")
    for i, s in Symbols
        IniWrite(EncodeSym(s), IniFile, "Symbols", "S" i)

    ; language
    TargetLang := Langs[setLangDD.Value][2]
    SpellLang  := SpellLangs[setSpellDD.Value][2]
    MyLangs    := CleanLangList(setMyLangsEd.Value)
    IniWrite(TargetLang, IniFile, "General", "TargetLang")
    IniWrite(SpellLang, IniFile, "General", "SpellLang")
    IniWrite(MyLangs, IniFile, "General", "MyLangs")

    ; emails
    Emails := []
    for line in StrSplit(setEmailEd.Value, "`n", " `t`r") {
        if (line != "")
            Emails.Push(line)
    }
    IniDelete(IniFile, "Emails")
    IniWrite(Emails.Length, IniFile, "Emails", "Count")
    for i, e in Emails
        IniWrite(e, IniFile, "Emails", "E" i)

    ; general
    startOn := (setStartCb.Value = 1)
    SetStartup(startOn)
    IniWrite(startOn ? "1" : "0", IniFile, "General", "StartWithWindows")
    AutoHideMs := HideValues[setHideDD.Value]
    IniWrite(AutoHideMs, IniFile, "General", "AutoHideMs")
    ExcludedApps := Map()
    list := ""
    for line in StrSplit(setExclEd.Value, "`n", " `t`r") {
        if (line = "")
            continue
        ExcludedApps[StrLower(line)] := 1
        list .= (list = "" ? "" : ",") StrLower(line)
    }
    IniWrite(list, IniFile, "General", "ExcludedApps")

    ApplyTheme()
    BuildBar()
    RefreshPreview(true)
    try setSaveBtn.Value := "Saved"
    SetTimer(RestoreSaveText, -1500)
}

RestoreSaveText() {
    try setSaveBtn.Value := "Save"
}

; =====================================================================
;  SETTINGS - SYMBOLS TAB
; =====================================================================
; ---------- Symbols tab: list editing ----------
SymFillList(sel := 0) {
    setSymLB.Delete()
    if setSymList.Length
        setSymLB.Add(setSymList)
    if (sel && sel <= setSymList.Length)
        setSymLB.Choose(sel)
}

SymAdd(*) {
    txt := Trim(setSymEd.Value, " `t`r`n")
    if (txt = "")
        return
    last := 0
    for tok in StrSplit(txt, [" ", "`t", "`r", "`n"]) {
        if (tok = "")
            continue
        pos := 0
        for i, s in setSymList {
            if (s == tok) {                      ; already in the list: just select it
                pos := i
                break
            }
        }
        if !pos {
            setSymList.Push(tok)
            setSymLB.Add([tok])
            pos := setSymList.Length
        }
        last := pos
    }
    setSymEd.Value := ""
    if last
        setSymLB.Choose(last)
    setSymEd.Focus()
}

SymRemove(*) {
    i := setSymLB.Value
    if !i
        return
    setSymList.RemoveAt(i)
    setSymLB.Delete(i)
    if setSymList.Length
        setSymLB.Choose(Min(i, setSymList.Length))
}

SymMove(dir, *) {
    i := setSymLB.Value
    j := i + dir
    if (!i || j < 1 || j > setSymList.Length)
        return
    tmp := setSymList[i]
    setSymList[i] := setSymList[j]
    setSymList[j] := tmp
    SymFillList(j)
}

; =====================================================================
;  SETTINGS - DESIGN TAB
; =====================================================================
; ---------- Design tab ----------
; one line: [Theme name] [part] # [hex] [color square] [Pick]
ColorRow(g, y, label1, label2, value, defaultHex) {
    if (label1 != "")
        AddPanelText(g, "design", "x20 y" y " w104 h24 +0x200", label1, C_TXT, "s9")
    AddPanelText(g, "design", "x128 y" y " w82 h24 +0x200", label2, C_DIM, "s9")
    AddPanelText(g, "design", "x212 y" y " w12 h24 +0x200", "#", C_DIM, "s9")
    ed := g.AddEdit("x224 y" y " w76 h24 -E0x200 Limit7 Uppercase Background" C_BG2, value)
    ed.SetFont("s9 c" C_TXT, "Consolas")
    DarkCtrl(ed.Hwnd)
    sw := g.AddText("x308 y" y " w24 h24 Background" value)
    ed.OnEvent("Change", ColorEdited.Bind(ed, sw))
    setPanels["design"].Push(ed, sw)
    AddPill(g, "design", "x340 y" y " w64 h24", "Pick", PickColor.Bind(ed, sw))
    setColorFields.Push([ed, sw, defaultHex])
    return ed
}

ColorEdited(ed, sw, *) {
    UpdateSwatch(ed, sw)
    RefreshPreview()
}

; Windows color picker
PickColor(ed, sw, *) {
    static custom := Buffer(64, 0)
    P := A_PtrSize
    size := (P = 8) ? 72 : 36
    oRgb := (P = 8) ? 24 : 12, oCust := (P = 8) ? 32 : 16, oFlags := (P = 8) ? 40 : 20
    hex := CleanHex(ed.Value, "FFFFFF")
    c := Integer("0x" hex)
    cc := Buffer(size, 0)
    NumPut("uint", size, cc, 0)
    NumPut("ptr", settingsGui.Hwnd, cc, P)
    NumPut("uint", ((c & 0xFF) << 16) | (c & 0xFF00) | ((c >> 16) & 0xFF), cc, oRgb)   ; RGB -> BGR
    NumPut("ptr", custom.Ptr, cc, oCust)
    NumPut("uint", 0x3, cc, oFlags)                                                   ; start color + full dialog
    if !DllCall("comdlg32\ChooseColorW", "ptr", cc)
        return
    bgr := NumGet(cc, oRgb, "uint")
    ed.Value := Format("{:02X}{:02X}{:02X}", bgr & 0xFF, (bgr >> 8) & 0xFF, (bgr >> 16) & 0xFF)
    UpdateSwatch(ed, sw)
    RefreshPreview()
}

PickTheme(name, *) {
    global setThemeSel
    setThemeSel := name
    RefreshThemePills()
    RefreshPreview()
}

RefreshThemePills() {
    for key, c in setThemePills {
        on := (key = setThemeSel)
        c.Opt("+Background" (on ? C_ACC : C_BG2))
        c.SetFont((on ? "s9 bold c" C_BG : "s9 norm c" C_TXT), "Segoe UI")
        setBgNow[c.Hwnd] := on ? C_ACC : C_BG2
        c.Redraw()
    }
}

OpacityMoved(*) {
    setOpacityTxt.Value := setOpacitySl.Value " %"
    RefreshPreview()
}

RoundingMoved(*) {
    setRoundTxt.Value := setRoundSl.Value " %"
    RefreshPreview()
}

; the colors as they are in the Settings window right now (not saved yet)
FormLook() {
    return ComputeLook(setThemeSel
        , CleanHex(setIconLightEd.Value, IconLight), CleanHex(setIconDarkEd.Value, IconDark)
        , CleanHex(setCustBgEd.Value, CustomBg), CleanHex(setCustIconEd.Value, CustomIcon)
        , setOpacitySl.Value, setRoundSl.Value)
}

; live preview of the bar, drawn on top of the Settings window (Design tab only)
RefreshPreview(rebuild := false) {
    global setPreview
    if (!IsObject(settingsGui) || setActiveTab != "design") {
        HidePreview()
        return
    }
    if (rebuild || !IsObject(setPreview)) {
        HidePreview()
        active := []
        for def in Defs {
            if setBoxes[def["key"]].Value
                active.Push(def)
        }
        if (active.Length = 0)
            return
        setPreview := MakeBarPanel(active, settingsGui.Hwnd)
        setPreview["look"] := FormLook()
        PositionPreview(true)
        return
    }
    setPreview["look"] := FormLook()
    PanelRender(setPreview)
}

PositionPreview(first := false) {
    if (!IsObject(setPreview) || !IsObject(settingsGui))
        return
    pt := Buffer(8, 0)
    DllCall("ClientToScreen", "ptr", settingsGui.Hwnd, "ptr", pt)
    k := A_ScreenDPI / 96                         ; the Settings window follows Windows scaling
    x := NumGet(pt, 0, "int") + Round(280 * k) - setPreview["w"] // 2
    y := NumGet(pt, 4, "int") + Round(498 * k) - setPreview["h"] // 2
    if first
        PanelShow(setPreview, x, y)
    else
        PanelMove(setPreview, x, y)
}

HidePreview() {
    global setPreview
    if IsObject(setPreview)
        PanelDestroy(setPreview)
    setPreview := ""
}

ResetIconColors(*) {
    for f in setColorFields {
        f[1].Value := f[3]
        UpdateSwatch(f[1], f[2])
    }
    RefreshPreview()
}

; "#2b2b2b" / "2B2B2B" / "fff" -> "2B2B2B" / "FFFFFF"; anything else -> fallback
CleanHex(str, fallback) {
    h := StrUpper(Trim(StrReplace(str, "#", "")))
    if RegExMatch(h, "^[0-9A-F]{3}$")
        h := SubStr(h, 1, 1) SubStr(h, 1, 1) SubStr(h, 2, 1) SubStr(h, 2, 1) SubStr(h, 3, 1) SubStr(h, 3, 1)
    return RegExMatch(h, "^[0-9A-F]{6}$") ? h : fallback
}

; the little square next to a hex field shows the color while you type
UpdateSwatch(ed, sw, *) {
    h := CleanHex(ed.Value, "")
    if (h = "")
        return
    sw.Opt("+Background" h)
    sw.Redraw()
}

; =====================================================================
;  DARK WINDOW HELPERS
; =====================================================================
EnableDarkMode() {
    try {
        ux := DllCall("GetModuleHandle", "str", "uxtheme", "ptr")
        if !ux
            ux := DllCall("LoadLibrary", "str", "uxtheme", "ptr")
        fn := DllCall("GetProcAddress", "ptr", ux, "ptr", 135, "ptr")   ; SetPreferredAppMode
        if fn
            DllCall(fn, "int", 2)                                       ; 2 = force dark
    }
}

DarkTitle(hwnd) {
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 20, "int*", 1, "int", 4)
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 19, "int*", 1, "int", 4)
}

DarkCtrl(hwnd, theme := "DarkMode_Explorer") {
    try DllCall("uxtheme\SetWindowTheme", "ptr", hwnd, "str", theme, "ptr", 0)
}

SetBg(hwnd, color) {
    c := GuiCtrlFromHwnd(hwnd)
    if !c
        return
    c.Opt("+Background" color)
    c.Redraw()
}

; =====================================================================
;  SAVED DATA AND FILES
; =====================================================================
; ---------- Symbols: saved in SnipBar.ini as hex code points (safe for any character) ----------
ReadPercent(key, default, lowest) {
    v := IniRead(IniFile, "Look", key, default)
    return IsInteger(v) ? Max(lowest, Min(100, Integer(v))) : default
}

; symbols are saved as hex code points, so any character survives the ini file
LoadSymbols() {
    cnt := IniRead(IniFile, "Symbols", "Count", "")
    if !IsInteger(cnt)
        return DefaultSymbols.Clone()
    out := []
    Loop Integer(cnt) {
        s := DecodeSym(IniRead(IniFile, "Symbols", "S" A_Index, ""))
        if (s != "")
            out.Push(s)
    }
    return out
}

EncodeSym(s) {
    out := "", i := 1, n := StrLen(s)
    while (i <= n) {
        cp := Ord(SubStr(s, i, 2))               ; handles symbols outside the basic range too
        out .= (out = "" ? "" : ",") Format("{:X}", cp)
        i += (cp > 0xFFFF) ? 2 : 1
    }
    return out
}

DecodeSym(str) {
    out := ""
    for part in StrSplit(str, ",", " `t") {
        if RegExMatch(part, "^[0-9A-Fa-f]{1,6}$") {
            cp := Integer("0x" part)
            if (cp > 0 && cp <= 0x10FFFF)
                out .= Chr(cp)
        }
    }
    return out
}

WriteB64(path, b64) {
    b64 := RegExReplace(b64, "\s")
    n := 0
    if !DllCall("crypt32\CryptStringToBinaryW", "str", b64, "uint", 0, "uint", 1, "ptr", 0, "uint*", &n, "ptr", 0, "ptr", 0)
        return
    buf := Buffer(n)
    if !DllCall("crypt32\CryptStringToBinaryW", "str", b64, "uint", 0, "uint", 1, "ptr", buf, "uint*", &n, "ptr", 0, "ptr", 0)
        return
    ; already up to date? (same bytes = nothing to write)
    if (FileExist(path) && FileGetSize(path) = n) {
        try {
            old := FileRead(path, "RAW")
            if (DllCall("ntdll\RtlCompareMemory", "ptr", old, "ptr", buf, "uptr", n, "uptr") = n)
                return
        }
    }
    try {
        f := FileOpen(path, "w")
        f.RawWrite(buf, n)
        f.Close()
    }
}

; =====================================================================
;  EMBEDDED FILES  (tray icons + icon font)
; =====================================================================
IconOnB64() {
    return "
(
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
)"
}

IconOffB64() {
    return "
(
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
)"
}

GlyphsB64() {
    return "
(
AAEAAAAKAIAAAwAgT1MvMlbFY0oAAAEoAAAAVmNtYXBI4D24AAAB3AAAAUpnbHlmlPlXzgAAA1gAABQgaGVhZDFIu40AAADQAAAA
NmhoZWEIbwQHAAAArAAAACRobXR4XAAAAAAAAYAAAABcbG9jYTsAP9gAAAMoAAAAMG1heHABLQCwAAABCAAAACBuYW1l1YxlJAAA
F3gAAAJtcG9zdAunC48AABnoAAAAaAABAAAEAAAAAFwEAAAA/+8EEQABAAAAAAAAAAAAAAAAAAAAFwABAAAAAQAA1imBal8PPPUA
CwQAAAAAAOccO08AAAAA5xw7T//w//AEAQQCAAAACAACAAAAAAAAAAEAAAAXAKQADAAAAAAAAgAAAAoACgAAAP8AAAAAAAAAAQQA
AZAABQAIAokCzAAAAI8CiQLMAAAB6wAyAQgAAAIABQMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAUGZFZABAAEEAVgQAAAAAXAQCABAA
AAABAAAAAAAABAAAAAQAAAAEAAAABAAAAAQAAAAEAAAABAAAAAQAAAAEAAAABAAAAAQAAAAEAAAABAAAAAQAAAAEAAAABAAAAAQA
AAAEAAAABAAAAAQAAAAEAAAABAAAAAQAAAAAAAADAAAAAwAAABwAAQAAAAAARAADAAEAAAAcAAQAKAAAAAYABAABAAIAAABW//8A
AAAAAEH//wAA/8AAAQAAAAAAAAAAAQYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAQIDBAUGBwgJCgsMDQ4PEBESExQVFgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAYADCAPYBrgKEAyID
xgR0BQIFOgW6BfYGhAb8B0gHxAgSCDgI8gmaCdQKEAABAAAAAAQBBAEAPgAAJSIrATY3NjcmACcGAAcUFxYXIw4BFBY7AT4BNzQm
Jy4BJyY1PgE3HgEXFAcOAQ8BDgEHHQEeATsBMjY0JicwA74IMjkmIG8BBv7f2dr+3wVvICZzHCYmHNopNgEWFBFEJVME1qGg1gRT
ID4SChIVAwU1JtocJiYchiUoj57aASEFBf7f2p6PKCUBJTkmATYpGCoODDsta3Ch1gQE1qFwayg3DQgMIxYLCiYwJjklAQAAAAAC
//D/8AQBBAEAKgBAAAABJiIPASMmIg8BBhQXMQEOAR0BBwYWPwEzMjY3ATEWMj8BNjQnNTc2NCcwARYfAQEGKwEiDwEGLgI/ATY9
ATQ3A8s4kjhkARxHGx4aGv6nEBJBHFY/eCMXKREBWhxHGx4aGmQ1Nf40CUJK/qcMDy0KCIEFBgcCA0YFCwPLNjZkGhoeG0cc/qYR
KRcjeD9WHEESEAFZGhoeG0ccAWQ4kjj+ygpBS/6mCwVGAgEHBgWBCAotDwwAAgAAAAAEAAQAABMAHQAAAR4BFxEhDgEHESEuAScR
PgE3ITATBg8BNT4BNzMwA0dPaAL+8k9oAv6AT2gCAmhPAo6gFpatATkq9QQAAmhP/oACaE/+8gJoTwKOT2gC/XIWl6z1KjkBAAAH
AAAAAAQBBAAAFQArAEEAVwBlAHMAgQAAEw4BBxUOASImPQE+ATczHgEUBisBMBEuASc1LgEiBh0BHgEXMz4BNCYrATABLgEnIyIm
NDY3Mx4BFxUOASImJzUwAz4BNzU+ATIWFxUOAQcjLgE0NjsBMAEyFhQGByMuATQ2NzMwNzIWFAYHISImNDY3ITA1HgEUBgchIiY0
NjchMKcbJAEBHSsdAV5HjRUdHRWNGyQBAR0rHQFeR40VHR0VjQLzASQbjRUdHRWNR14CAR0rHQFAGyQBAR0rHQECXkeNFR0dFY3+
uxUdGRPTFh0ZFNPMFh0ZFP5hFh0ZFAGfFh0ZFP5hFh0ZFAGfA5oBJBuNFh0dFo1GXgIBHCwd/MwBJBuNFh0dFo1GXgIBHCwdAvQb
JAEdLBwBAl5GjRYdHRaN/QwBJBuNFh0dFo1GXgIBHCwdAQAdKhwDAR0pHAPNHSocAx0qHAPNAR0pHAMdKhwDAAAAAAwAAAAABAAE
AQAHABkAKwAzAEUAVwBfAHEAgwCLAJsAowAAASIrARUzNTAlPgE3Mx4BFxUOAQcjLgEnNTA3DgEdARQWOwEyNj0BNCYnIzATMjsB
FSM1MCc+ATczHgEXFQ4BByMuASc1MDcOAR0BFBYXMz4BPQE0JicjMAEiKwEVMzUwJw4BBxUeARczPgE3NS4BJyMwBzQ2NzMeAR0B
FAYrASImPQEwAzI7ARUjNTAFIisBFSMVMzUzFTM1IzUwMTQ9ATMVIzABHAcxOXH+5AJQPKs8UQEBUTyrPFACjgwQEAyrDBAQDKsd
BzI4casCUDyrPFEBAVE8qzxQAo4MEBAMqwwQEAyrAscHMjhxjjxRAQFRPKs8UAICUDyrHBAMqwwQEAyrDBByCkROnAErCT9HnJyP
nJycnANWcnIcPVABAVA9qj1QAgJQPaodARAMqgwREQyqDBAB/Y5ychw9UAICUD2qPVABAVA9qh0BEAyqDBABARAMqgwQAQIAcnKq
AVA9qj1QAgJQPao9UAGODBABARAMqgwREQyq/ladnZ2OnJycnI4KRE+dAAAABgAAAAAEAAP8ABUAKwBBAFYAYQBtAAATIgYHFRQG
IiYnNT4BNzMeARQGByMwBS4BKwEuATQ2NzMeARcVDgEiJj0BMAM+ATc1NDYyFhcVDgEHIyImNDY7ATABIisBDgEHERQXNzYyHwE2
NxEuAScVLgE0NjIWFAYHMAEiJzc2Mh8BBiMhMMEaIwEcKhwBAltEiRUcHBWJAtwBIxqJFRwcFYlEWwIBHCocPhojARwqHAECW0SJ
FRwcFYn+OhBwgEFWAhWzI1wjsxUBAldBFh0dLB0dFv8AKyOzDB4MsyMr/wADmCMbiBUcHBWIRVsCARwqHAE+GyMBHCocAQJbRYgV
HBwViP0lASMaiBUcHBWIRFsCHCscAbkCV0H/ACsjsyIisyMrAQBBVwLNARwrHR0rHAH+mhWzCwuzFQAAAAYAAAAABAEEAAAVACsA
QQBXAGUAcAAAEw4BBxUOASImPQE+ATczHgEUBisBMBEuASc1LgEiBh0BHgEXMz4BNCYrATABLgEnIyImNDY3Mx4BFxUOASImJzUw
Az4BNzU+ATIWFxUOAQcjLgE0NjsBMCU+ATcuAScOAQceARcwAT4BNCYiBhQWFzCnGyQBAR0rHQFeR40VHR0VjRskAQEdKx0BXkeN
FR0dFY0C8wEkG40VHR0VjUdeAgEdKx0BQBskAQEdKx0BAl5HjRUdHRWN/rtOZwICZ05OaAICaE7+7SArK0ErKyEDmgEkG40WHR0W
jUZeAgEcLB38zAEkG40WHR0WjUZeAgEcLB0C9BskAR0sHAECXkaNFh0dFo39DAEkG40WHR0WjUZeAgEcLB3QAmdOTmgCAmhOTmcC
AX4BK0ErK0ErAQAAAAAFAAAAAAQBBAAAFQArAEEAVwB9AAATDgEHFQ4BIiY9AT4BNzMeARQGKwEwES4BJzUuASIGHQEeARczPgE0
JisBMAEuAScjIiY0NjczHgEXFQ4BIiYnNTADPgE3NT4BMhYXFQ4BByMuATQ2OwEwATQ2NyEeAR0BFAYiJj0BIxEzMhYUBgcjLgE0
NjsBESMVFAYiJjWnGyQBAR0rHQFeR40VHR0VjRskAQEdKx0BXkeNFR0dFY0C8wEkG40VHR0VjUdeAgEdKx0BQBskAQEdKx0BAl5H
jRUdHRWN/ZodFgGzFh0dLB1zQBUdHRXnFR0dFUBzHSwdA5oBJBuNFh0dFo1GXgIBHCwd/MwBJBuNFh0dFo1GXgIBHCwdAvQbJAEd
LBwBAl5GjRYdHRaN/QwBJBuNFh0dFo1GXgIBHCwdAmcWHAEBHBZNFh0dFhr+zB0sHAEBHCwdATQaFh0dFgAFAAAAAAPABAAAIwAz
AEMAUwBjAAABMhYfAQ4BBxUOASImJzUuASc1NDYyFh8BHgEfAT4BNzU0NjMBHgEXEQ4BBy4BJxE+ATcwBSIrASImNDY7ATIWFAYj
MBUiKwEiJjQ2NzMeARQGIzAHIisBIiY0NjczHgEUBiMwAucPFQIBA7SJARUgFAOGsggWHxUCAQKRbiVvlwcWEP7AV3QCAnRXV3MC
AnNXAfINWGUQFhYQyhAWFhANWGUQFhYQyhAWFhBCCDxEEBYWEIgQFhYQAjMTDh+Mvw11EBYTDnoMuYcmEBYTDh9vlgcBA5FuJRAW
Ac0CdFf+zVd0AgJ0VwEzV3QCkRYhFhYhFosWIRYBARYhFoIWIRYBARYhFgAAAAIAAAAABAADZwARAB8AABE+ATchHgEXEQ4BByEu
AScRMAEmLwERNzYWFxEOAScwAl5GAU1HXgICXkf+s0ZeAgN0C0lTpy9aAwNaLwLAR14CAl5H/oBGXgICXkYBgP4dBzM5AWBzHi84
/k04Lx0AAAACAAAAAAQABAEAKQBSAAABHgEXERUOAQchIy4BNDY3IT4BNxEnLgEnISMOAQcRFQ4BIiY1ET4BNyEBMjsBHwMWHwMT
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
FBoaFF+JEhUSiV8UGhoUOFMQmxQaGhSbEFM4FBoaFF+JEgAAAAn//wAABAAEAAATABwAJAAyAD8ATABWAGAAbAAAEwYUFx4BNxcW
Mj4BLwE2JicmIgcBBgcXFhc+ATchFh8BNj8BIwMWFAcGIicmNDc2MhcwJSIrAR4BBzM2NTQvATMWFRQPATM2NTQnIzADHgEfATMu
AS8CDgEHFhchLgEnBw4BBzM+ARc+AT8BSkpKQ69M2gwgFgII3DoKRE7JTQKjER8IEANPeyf+Qwc0Og8MA5OWMzM1ijUzMzWKNQE6
DFNeKBcSiwkDAU0DBQPxFwr5ayIwDgPrKaJuFZEyWBgkIAEEFls1kXWuLDMsYjIMKBoOAmlNyU5BDzHZDBccDNxNuUdKSv6yZE0J
Fxkld04IMzouOA8BFjWKNTMzNYo1MzM2OYVCSVEnJhkyNEA8HklRNDIBhDSTWhZsniYHFQKihwwVlLUDFSOjcRwZBEh5LhcAAAIA
AAAABAEDzgALAB0AAAE2MhcFFhcFJTY3JQEGFREeARchPgE3ESYnAQYnAQHEHEEcAY0GBv4r/ioGBgGN/j8CAV5HArNHXgIBAv4U
ERL+FAO8ERH4AwX39wQE+P6+Cwz+d0deAQFeRwGJDAz+/QkJAQIAAgAAAAAEAAQBABAAIgAAAR4BFzMOAQchLgEnET4BNzMlHgEX
EQ4BByEuAScRPgE3ITABOQKJZ2MIZkv+5E9oAgJoT4ACDk9oAgJoT/7kT2gCAmhPARwBnWeIA0lgAQFpTgGrT2gC4wJoTv5VT2gC
AmhPAatOaAIAAAASAN4AAQAAAAAAAAAVAAAAAQAAAAAAAQAIABUAAQAAAAAAAgAHAB0AAQAAAAAAAwAIACQAAQAAAAAABAAIACwA
AQAAAAAABQALADQAAQAAAAAABgAIAD8AAQAAAAAACgArAEcAAQAAAAAACwATAHIAAwABBAkAAAAqAIUAAwABBAkAAQAQAK8AAwAB
BAkAAgAOAL8AAwABBAkAAwAQAM0AAwABBAkABAAQAN0AAwABBAkABQAWAO0AAwABBAkABgAQAQMAAwABBAkACgBWARMAAwABBAkA
CwAmAWlHZW5lcmF0ZWQgYnkgR2x5cGh0ZXJHbHlwaHRlclJlZ3VsYXJHbHlwaHRlckdseXBodGVyVmVyc2lvbiAxLjBHbHlwaHRl
ckdlbmVyYXRlZCBieSBzdmcydHRmIGZyb20gRm9udGVsbG8gcHJvamVjdC5odHRwOi8vZm9udGVsbG8uY29tAEcAZQBuAGUAcgBh
AHQAZQBkACAAYgB5ACAARwBsAHkAcABoAHQAZQByAEcAbAB5AHAAaAB0AGUAcgBSAGUAZwB1AGwAYQByAEcAbAB5AHAAaAB0AGUA
cgBHAGwAeQBwAGgAdABlAHIAVgBlAHIAcwBpAG8AbgAgADEALgAwAEcAbAB5AHAAaAB0AGUAcgBHAGUAbgBlAHIAYQB0AGUAZAAg
AGIAeQAgAHMAdgBnADIAdAB0AGYAIABmAHIAbwBtACAARgBvAG4AdABlAGwAbABvACAAcAByAG8AagBlAGMAdAAuAGgAdAB0AHAA
OgAvAC8AZgBvAG4AdABlAGwAbABvAC4AYwBvAG0AAAAAAgAAAAAAAAAKAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAXAAABAgEDAQQB
BQEGAQcBCAEJAQoBCwEMAQ0BDgEPARABEQESARMBFAEVARYBFwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==
)"
}
