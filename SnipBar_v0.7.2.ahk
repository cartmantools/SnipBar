#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
ListLines False
KeyHistory 0
SetWorkingDir A_ScriptDir
CoordMode "Mouse", "Screen"
CoordMode "ToolTip", "Screen"
SetStoreCapsLockMode(false)   ; stops the script from touching Caps Lock
SetWinDelay(-1)
SetControlDelay(-1)
try ProcessSetPriority("AboveNormal")   ; keeps the mouse hook snappy

; =====================================================================
;  SnipBar - a small glass bar that appears above selected TEXT
;  Select text with the mouse -> the bar pops up -> click a button.
;  Right-click the tray icon (near the clock) -> Settings.
;
;  v0.6 - by Ahcene
;  What changed in 0.7.2:
;   * New app icon (green = active, red = paused).
;  What changed in 0.7.1:
;   * Buttons tab: choose the icon color with a hex code, one for dark mode
;     (default FFFFFF) and one for light mode (default 2B2B2B).
;  What changed in 0.7:
;   * New icons (custom glyph font, stored inside this script and loaded
;     privately - nothing is installed in Windows).
;   * The bar follows Windows dark / light mode, live:
;     dark = white icons on dark glass, light = #2B2B2B icons on light glass.
;  What changed in 0.6.5:
;   * General tab: tips for apps where the bar does not show by itself.
;  What changed in 0.6.4:
;   * SnipBar can LEARN a text cursor: hover it, press Ctrl+Alt+Shift+B,
;     release the keys, answer Yes. Needed for Illustrator, whose Type tool
;     cursor is not a standard I-beam. Learned cursors are kept in SnipBar.ini.
;   * The checker now measures the cursor after you release the keys
;     (holding Ctrl in Illustrator temporarily switches to the Selection tool).
;  What changed in 0.6.3:
;   * Illustrator: its text cursor is recognised with a looser shape test,
;     plus a second signal (the blinking text caret while you edit text).
;   * Ctrl+Alt+Shift+B shows more details and saves cursor_test.bmp.
;  What changed in 0.6.2:
;   * Works again in Illustrator, Photoshop, InDesign... Adobe draws its own
;     text cursor, which Windows does not report as an I-beam, so v0.5-0.6.1
;     ignored every selection there. The cursor shape is now checked instead,
;     so the bar still never appears when you drag objects or marquees.
;   * Ctrl+Alt+Shift+B: shows whether the text cursor is detected (for testing).
;  What changed in 0.6.1:
;   * Spell check: accents are read correctly (deçu -> déçu, not dÃ©Ã§u).
;   * Auto-detect is guided by "Languages I write in" (default: fr, en),
;     so short text is no longer mistaken for Romanian, Catalan...
;  What changed in 0.6:
;   * Settings + icons now live in  Documents\AHK SETTINGS\SnipBar
;     (created automatically at launch, like ContexTool).
;   * New button: spelling + grammar correction (LanguageTool, free).
;   * Green tray icon when active, red when paused.
;  What changed in 0.5:
;   * The bar only reacts to real text selections (text cursor required
;     when the drag STARTS). No more pop-ups while dragging objects in
;     Illustrator / Photoshop / InDesign.
;   * The mouse hook no longer talks to other windows, so no more lag
;     in heavy apps (the old version sent a blocking message to the
;     window under the mouse on every single click).
;   * The clipboard is no longer fully copied and restored on every
;     selection. Big images stay untouched instead of freezing the PC.
;   * Dark, tabbed settings window + "Start with Windows".
; =====================================================================

APP_NAME    := "SnipBar"
APP_VERSION := "0.7.2"
APP_AUTHOR  := "Ahcene"

; ---------- Look of the floating bar (you can change these) ----------
GlassStyle := "blur"       ; "blur" = frosted glass (recommended) | "acrylic" = Windows acrylic
; The bar follows Windows dark / light mode by itself. Colors for each mode:
;   tint  = glass color, first 2 digits = opacity (00 = very clear glass, FF = solid)
;   bg    = bar background   hover = circle under the mouse   icon = icon color
DarkLook  := Map("tint", 0x66161616, "bg", "000000", "hover", "4A4A4A", "icon", "FFFFFF", "dim", "9A9A9A")
LightLook := Map("tint", 0xCCF3F3F3, "bg", "F3F3F3", "hover", "DADADA", "icon", "2B2B2B", "dim", "6B6B6B")
GlyphSize  := 13           ; size of the new icons
DefaultIconDark  := DarkLook["icon"]
DefaultIconLight := LightLook["icon"]
; current colors (set from the looks above by ApplyTheme)
GlassTint := 0x66161616, BarBg := "000000", HoverColor := "4A4A4A", IconColor := "FFFFFF", DimColor := "9A9A9A", LightMode := false
BtnSize    := 34           ; diameter of each round icon (pixels)
BtnGap     := 4            ; space between icons
BarPad     := 5            ; space around icons inside the bar

; ---------- Colors of the settings window (dark theme) ----------
C_BG   := "161616"   ; window background
C_BG2  := "242424"   ; buttons / fields
C_BG3  := "323232"   ; hover
C_LINE := "2E2E2E"   ; separators
C_TXT  := "FFFFFF"   ; main text
C_DIM  := "9A9A9A"   ; secondary text
C_ACC  := "4DFF7F"   ; green accent (same as the logo)
C_ACC2 := "6BFF96"   ; green accent, hover

; ---------- Window classes where the bar must NOT appear ----------
ExcludedClasses := ["ConsoleWindowClass", "CASCADIA_HOSTING_WINDOW_CLASS", "CabinetWClass", "Progman", "WorkerW", "XLMAIN"]

; ---------- Adobe programs (they draw their own cursors) ----------
AdobeApps := Map("illustrator.exe", 1, "photoshop.exe", 1, "indesign.exe", 1, "incopy.exe", 1, "acrobat.exe", 1,
                 "acrord32.exe", 1, "afterfx.exe", 1, "adobe premiere pro.exe", 1, "animate.exe", 1, "xd.exe", 1)

; ---------- Buttons ----------
Defs := [
    Map("key", "lower",     "label", "lowercase",         "glyph", "aa",         "icon", false, "g", "M"),
    Map("key", "upper",     "label", "UPPERCASE",         "glyph", "AA",         "icon", false, "g", "N"),
    Map("key", "paren",     "label", "Put between ( )",   "glyph", "( )",        "icon", false, "g", "O"),
    Map("key", "brace",     "label", "Put between { }",   "glyph", "{ }",        "icon", false, "g", "P"),
    Map("key", "bracket",   "label", "Put between [ ]",   "glyph", "[ ]",        "icon", false, "g", "Q"),
    Map("key", "symbols",   "label", "Special symbols",   "glyph", Chr(0x3A9),   "icon", false, "g", "A"),
    Map("key", "spell",     "label", "Correct spelling and grammar", "glyph", Chr(0x2713) Chr(0x2713), "icon", false, "font", "Segoe UI Symbol", "g", "R"),
    Map("key", "google",    "label", "Search on Google",  "glyph", Chr(0xE721),  "icon", true, "g", "T"),
    Map("key", "translate", "label", "Translate",         "glyph", Chr(0xE774),  "icon", true, "g", "S"),
    Map("key", "email",     "label", "Saved emails",      "glyph", "@",          "icon", false, "g", "U"),
    Map("key", "copy",      "label", "Copy",              "glyph", Chr(0xE8C8),  "icon", true, "g", "V")
]

; ---------- Special symbols (shown when you click the symbols button) ----------
Symbols := [Chr(0x2022), Chr(0x007C), Chr(0xC9), Chr(0xC8), Chr(0x152), Chr(0x153), Chr(0x00C0), Chr(0x00AE), Chr(0x00B1)]

; ---------- Translation languages (name, Google code) ----------
Langs := [
    ["English", "en"], ["French", "fr"], ["Spanish", "es"], ["German", "de"],
    ["Italian", "it"], ["Portuguese", "pt"], ["Arabic", "ar"], ["Dutch", "nl"],
    ["Russian", "ru"], ["Turkish", "tr"], ["Chinese (Simplified)", "zh-CN"], ["Japanese", "ja"]
]

; ---------- Spell check languages (name, LanguageTool code) ----------
SpellLangs := [
    ["Auto-detect", "auto"], ["English (US)", "en-US"], ["English (UK)", "en-GB"], ["French", "fr"],
    ["Spanish", "es"], ["German", "de-DE"], ["Italian", "it"], ["Portuguese (Portugal)", "pt-PT"],
    ["Portuguese (Brazil)", "pt-BR"], ["Dutch", "nl"], ["Russian", "ru-RU"], ["Arabic", "ar"]
]

HideChoices := ["3 seconds", "5 seconds", "7 seconds", "10 seconds", "15 seconds", "30 seconds"]
HideValues  := [3000, 5000, 7000, 10000, 15000, 30000]

; ---------- Files ----------
; Everything the script creates goes to  Documents\AHK SETTINGS\SnipBar
DataDir     := A_MyDocuments "\AHK SETTINGS\SnipBar"
try DirCreate(DataDir)
IniFile     := DataDir "\SnipBar.ini"
IconFile    := DataDir "\SnipBar.ico"          ; green = active
IconOffFile := DataDir "\SnipBar_paused.ico"   ; red   = paused
StartupLink := A_Startup "\SnipBar.lnk"

; settings saved by v0.5 next to the script: bring them along once
if (!FileExist(IniFile) && FileExist(A_ScriptDir "\SnipBar.ini"))
    try FileCopy(A_ScriptDir "\SnipBar.ini", IniFile)
WriteB64(IconFile, IconOnB64())
WriteB64(IconOffFile, IconOffB64())

; new icons: a small font kept inside this script, loaded for SnipBar only
GlyphFile := DataDir "\SnipBar_glyphs.ttf"
WriteB64(GlyphFile, GlyphsB64())
GlyphsOK := false
if FileExist(GlyphFile)
    GlyphsOK := DllCall("gdi32\AddFontResourceEx", "str", GlyphFile, "uint", 0x10, "ptr", 0) > 0
try IniWrite(APP_VERSION, IniFile, "General", "Version")

; ---------- Saved settings ----------
Enabled := Map()
Labels  := Map()
for def in Defs {
    Enabled[def["key"]] := (IniRead(IniFile, "Buttons", def["key"], "1") = "1")
    Labels[def["key"]]  := def["label"]
}
TargetLang := IniRead(IniFile, "General", "TargetLang", "en")
DarkLook["icon"]  := CleanHex(IniRead(IniFile, "General", "IconDark", ""), DefaultIconDark)
LightLook["icon"] := CleanHex(IniRead(IniFile, "General", "IconLight", ""), DefaultIconLight)
AutoHideMs := Integer(IniRead(IniFile, "General", "AutoHideMs", "7000"))
SpellLang  := IniRead(IniFile, "General", "SpellLang", "auto")
MyLangs    := IniRead(IniFile, "General", "MyLangs", "fr,en")

; Apps where the bar is never shown (one process name per line in settings)
ExcludedApps := Map()
for p in StrSplit(IniRead(IniFile, "General", "ExcludedApps", ""), ",", " `t")
    if (p != "")
        ExcludedApps[StrLower(p)] := 1

; ---------- Text cursors learned with Ctrl+Alt+Shift+B ----------
LearnedCursors := Map()
Loop Integer(IniRead(IniFile, "TextCursors", "Count", "0")) {
    sig := IniRead(IniFile, "TextCursors", "C" A_Index, "")
    if (sig != "")
        LearnedCursors[sig] := 1
}
cursorCache := Map()

; ---------- Saved emails ----------
Emails := []
Loop Integer(IniRead(IniFile, "Emails", "Count", "0")) {
    e := IniRead(IniFile, "Emails", "E" A_Index, "")
    if (e != "")
        Emails.Push(e)
}

; ---------- State ----------
Scale := A_ScreenDPI / 96
bar := "", settingsGui := "", symGui := ""
barW := 0, barH := 0, barX := 0, barY := 0
barVisible := false, shownTick := 0
selText := "", hoverH := 0, ctrlKeys := Map()
paused := false, busy := false
downX := 0, downY := 0, downWin := 0, downText := false, lastDownTick := 0, clickCount := 0
symVisible := false, symCtrls := Map(), symHover := 0, symShownTick := 0, ignoreUp := false
setPanels := Map(), setTabBtns := Map(), setHot := Map(), setBgNow := Map()
setActiveTab := "buttons", setBoxes := Map()
spellBusy := false
setIconDarkEd := "", setIconLightEd := "", setDarkSw := "", setLightSw := "", setMyLangsEd := "", setSpellDD := "", setLangDD := "", setEmailEd := "", setStartCb := "", setHideDD := "", setExclEd := ""

; Clipboard format ids we must not destroy with a plain-text restore
CF_HTML := DllCall("RegisterClipboardFormat", "str", "HTML Format", "uint")
CF_RTF  := DllCall("RegisterClipboardFormat", "str", "Rich Text Format", "uint")

; ---------- Tray ----------
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
ApplyTheme()
OnMessage(0x1A, OnSettingChange)      ; Windows tells us when dark / light mode changes
BuildBar()

; =====================================================================
;  Mouse detection  (these two run inside the mouse hook: keep them tiny)
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
    downX := x
    downY := y
    downWin := win
    downText := IsTextCursorNow(win)   ; standard I-beam, or Adobe's own text cursor
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
    ; a text selection starts or ends on a text cursor - this single test
    ; removes every false pop-up in Illustrator, Photoshop, InDesign...
    ; (dragging objects, marquees or files never shows the I-beam cursor)
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
    ; everything heavy happens later, outside the hook
    SetTimer(TrySelection.Bind(x, y, win, false), IsAdobeWin(win) ? -150 : -70)
}

~Escape:: {
    HideBar()
    HideSymbols()
}

; Manual shortcut: select text, then press Ctrl+Alt+B to show the bar at the mouse
^!b:: {
    KeyWait("Ctrl")
    KeyWait("Alt")
    MouseGetPos(&mx, &my, &mwin)
    TrySelection(mx, my, mwin, true)
}

; Testing help + learning: hover the text cursor, press Ctrl+Alt+Shift+B,
; then RELEASE the keys and keep the mouse still (holding Ctrl changes
; Illustrator's cursor). Also saves cursor_test.bmp in the SnipBar folder.
^!+b:: {
    global cursorCache
    ToolTip("SnipBar: release the keys and keep the mouse still...")
    KeyWait("Ctrl"), KeyWait("Alt"), KeyWait("Shift"), KeyWait("b")
    Sleep(400)                                   ; let the app restore its normal cursor
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
            n := 0
            IniDelete(IniFile, "TextCursors")
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
;  Getting the selected text
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

; =====================================================================
;  Text-cursor detection
;  Windows apps report the standard I-beam. Adobe apps draw their own
;  cursors, so for them SnipBar uses two other signals:
;   1. the cursor picture: tall, thin, wider at the top and bottom
;      (arrows, crosshairs, hands and resize arrows never match)
;   2. a blinking text caret in the app = you are editing text
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
;  Dark / light mode
; =====================================================================
IsLightMode() {
    try return RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme") = 1
    return false
}

ApplyTheme() {
    global GlassTint, BarBg, HoverColor, IconColor, DimColor, LightMode
    LightMode := IsLightMode()
    look := LightMode ? LightLook : DarkLook
    GlassTint  := look["tint"]
    BarBg      := look["bg"]
    HoverColor := look["hover"]
    IconColor  := look["icon"]
    DimColor   := look["dim"]
}

OnSettingChange(wParam, lParam, msg, hwnd) {
    SetTimer(ThemeCheck, -400)          ; Windows sends this several times in a row
}

ThemeCheck() {
    if (IsLightMode() = LightMode)
        return
    HideBar()
    HideSymbols()
    ApplyTheme()
    BuildBar()
}

; =====================================================================
;  The floating bar
; =====================================================================
BuildBar() {
    global bar, barW, barH, ctrlKeys, hoverH, barVisible
    barVisible := false
    hoverH := 0
    ToolTip()
    if IsObject(bar) {
        try bar.Destroy()
    }
    bar := ""
    ctrlKeys := Map()
    active := []
    for def in Defs {
        if Enabled[def["key"]]
            active.Push(def)
    }
    if (active.Length = 0)
        return
    dia := Round(BtnSize * Scale)
    gap := Round(BtnGap * Scale)
    pad := Round(BarPad * Scale)
    barW := active.Length * dia + (active.Length - 1) * gap + 2 * pad
    barH := dia + 2 * pad
    bar := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000")
    bar.MarginX := 0
    bar.MarginY := 0
    bar.BackColor := BarBg
    x := pad
    for def in active {
        c := bar.AddText("x" x " y" pad " w" dia " h" dia " +0x100 +0x200 Center Background" BarBg, GlyphsOK ? def["g"] : def["glyph"])
        if GlyphsOK
            c.SetFont("s" GlyphSize " norm c" IconColor, "Glyphter")
        else if def["icon"]
            c.SetFont("s12 c" IconColor, "Segoe MDL2 Assets")
        else if def.Has("font")
            c.SetFont("s11 c" IconColor, def["font"])
        else
            c.SetFont("s11 c" IconColor, "Segoe UI Semibold")
        c.OnEvent("Click", DoAction.Bind(def["key"]))
        ctrlKeys[c.Hwnd] := def["key"]
        rgn := DllCall("CreateEllipticRgn", "int", 0, "int", 0, "int", dia + 1, "int", dia + 1, "ptr")
        DllCall("SetWindowRgn", "ptr", c.Hwnd, "ptr", rgn, "int", true)
        x += dia + gap
    }
    bar.Show("Hide w" barW " h" barH)
}

ShowBar(mx, my) {
    global barVisible, shownTick, barX, barY
    if !IsObject(bar)
        return
    ResetHighlights()
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
    bar.Show("NA x" px " y" py " w" barW " h" barH)
    ApplyGlass(bar.Hwnd)
    rgn := DllCall("CreateRoundRectRgn", "int", 0, "int", 0, "int", barW + 1, "int", barH + 1, "int", barH, "int", barH, "ptr")
    DllCall("SetWindowRgn", "ptr", bar.Hwnd, "ptr", rgn, "int", true)
    barVisible := true
    shownTick := A_TickCount
    SetTimer(HoverTick, 50)
}

HideBar() {
    global barVisible, hoverH
    if !barVisible
        return
    barVisible := false
    hoverH := 0
    SetTimer(HoverTick, 0)
    ToolTip()
    ResetHighlights()
    if IsObject(bar)
        bar.Hide()
}

ResetHighlights() {
    for h, k in ctrlKeys
        SetBg(h, BarBg)
}

SetBg(hwnd, color) {
    c := GuiCtrlFromHwnd(hwnd)
    if !c
        return
    c.Opt("+Background" color)
    c.Redraw()
}

HoverTick() {
    global hoverH
    if !barVisible {
        SetTimer(HoverTick, 0)
        return
    }
    MouseGetPos(, , &win, &hc, 2)
    over := (win = bar.Hwnd)
    newH := (over && ctrlKeys.Has(hc)) ? hc : 0
    if (newH != hoverH) {
        if hoverH
            SetBg(hoverH, BarBg)
        if newH {
            SetBg(newH, HoverColor)
            ShowTip(ctrlKeys[newH])
        } else
            ToolTip()
        hoverH := newH
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

ApplyGlass(hwnd) {
    state := (GlassStyle = "acrylic") ? 4 : 3
    flags := (state = 3) ? 2 : 0
    accent := Buffer(16, 0)
    NumPut("int", state, accent, 0)
    NumPut("int", flags, accent, 4)
    NumPut("uint", GlassTint, accent, 8)
    NumPut("int", 0, accent, 12)
    data := Buffer(3 * A_PtrSize, 0)
    NumPut("int", 19, data, 0)
    NumPut("ptr", accent.Ptr, data, A_PtrSize)
    NumPut("ptr", accent.Size, data, 2 * A_PtrSize)
    try DllCall("user32\SetWindowCompositionAttribute", "ptr", hwnd, "ptr", data)
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 33, "int*", 2, "int", 4)
}

; =====================================================================
;  Special symbols popup
; =====================================================================
ShowSymbols() {
    global symGui, symVisible, symCtrls, symHover, symShownTick
    HideSymbols()
    symCtrls := Map()
    symHover := 0
    n := Symbols.Length
    dia := Round(BtnSize * Scale)
    gap := Round(BtnGap * Scale)
    pad := Round(BarPad * Scale)
    w := n * dia + (n - 1) * gap + 2 * pad
    h := dia + 2 * pad
    symGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000")
    symGui.MarginX := 0
    symGui.MarginY := 0
    symGui.BackColor := BarBg
    x := pad
    for sym in Symbols {
        c := symGui.AddText("x" x " y" pad " w" dia " h" dia " +0x100 +0x200 Center Background" BarBg, sym)
        c.SetFont("s12 c" IconColor, "Segoe UI Semibold")
        c.OnEvent("Click", PickSymbol.Bind(sym))
        symCtrls[c.Hwnd] := sym
        rgn := DllCall("CreateEllipticRgn", "int", 0, "int", 0, "int", dia + 1, "int", dia + 1, "ptr")
        DllCall("SetWindowRgn", "ptr", c.Hwnd, "ptr", rgn, "int", true)
        x += dia + gap
    }
    GetWorkAreaAt(barX, barY, &wl, &wt, &wr, &wb)
    px := Max(wl + 4, Min(barX + (barW - w) // 2, wr - w - 4))
    py := Max(wt + 4, Min(barY, wb - h - 4))
    symGui.Show("NA x" px " y" py " w" w " h" h)
    ApplyGlass(symGui.Hwnd)
    rgn := DllCall("CreateRoundRectRgn", "int", 0, "int", 0, "int", w + 1, "int", h + 1, "int", h, "int", h, "ptr")
    DllCall("SetWindowRgn", "ptr", symGui.Hwnd, "ptr", rgn, "int", true)
    symVisible := true
    symShownTick := A_TickCount
    SetTimer(SymHoverTick, 50)
}

HideSymbols() {
    global symGui, symVisible, symHover
    SetTimer(SymHoverTick, 0)
    symVisible := false
    symHover := 0
    if IsObject(symGui) {
        try symGui.Destroy()
    }
    symGui := ""
}

SymHoverTick() {
    global symHover
    if (!symVisible || !IsObject(symGui)) {
        SetTimer(SymHoverTick, 0)
        return
    }
    MouseGetPos(, , &win, &hc, 2)
    over := (win = symGui.Hwnd)
    newH := (over && symCtrls.Has(hc)) ? hc : 0
    if (newH != symHover) {
        if symHover
            SetBg(symHover, BarBg)
        if newH
            SetBg(newH, HoverColor)
        symHover := newH
    }
    if (!over && A_TickCount - symShownTick > AutoHideMs)
        HideSymbols()
}

PickSymbol(sym, *) {
    HideSymbols()
    PasteReplace(sym)
}

; =====================================================================
;  Saved emails popup
; =====================================================================
ShowEmails() {
    global symGui, symVisible, symCtrls, symHover, symShownTick
    HideSymbols()
    symCtrls := Map()
    symHover := 0
    n := Emails.Length
    dia := Round(BtnSize * Scale)
    gap := Round(BtnGap * Scale)
    pad := Round(BarPad * Scale)
    maxLen := 0
    for e in Emails
        maxLen := Max(maxLen, StrLen(e))
    rowW := Max(Round(150 * Scale), Round((maxLen * 8.2 + 32) * Scale))
    w := rowW + 2 * pad
    h := n * dia + (n - 1) * gap + 2 * pad
    symGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000")
    symGui.MarginX := 0
    symGui.MarginY := 0
    symGui.BackColor := BarBg
    y := pad
    for e in Emails {
        c := symGui.AddText("x" pad " y" y " w" rowW " h" dia " +0x100 +0x200 Center Background" BarBg, e)
        c.SetFont("s10 c" IconColor, "Segoe UI Semibold")
        c.OnEvent("Click", PickSymbol.Bind(e))
        symCtrls[c.Hwnd] := e
        rgn := DllCall("CreateRoundRectRgn", "int", 0, "int", 0, "int", rowW + 1, "int", dia + 1, "int", dia, "int", dia, "ptr")
        DllCall("SetWindowRgn", "ptr", c.Hwnd, "ptr", rgn, "int", true)
        y += dia + gap
    }
    GetWorkAreaAt(barX, barY, &wl, &wt, &wr, &wb)
    px := Max(wl + 4, Min(barX + (barW - w) // 2, wr - w - 4))
    py := barY + barH - h
    if (py < wt)
        py := barY
    py := Max(wt + 4, Min(py, wb - h - 4))
    symGui.Show("NA x" px " y" py " w" w " h" h)
    ApplyGlass(symGui.Hwnd)
    corner := dia + 2 * pad
    rgn := DllCall("CreateRoundRectRgn", "int", 0, "int", 0, "int", w + 1, "int", h + 1, "int", corner, "int", corner, "ptr")
    DllCall("SetWindowRgn", "ptr", symGui.Hwnd, "ptr", rgn, "int", true)
    symVisible := true
    symShownTick := A_TickCount
    SetTimer(SymHoverTick, 50)
}

; =====================================================================
;  What each button does
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
;  Start with Windows
; =====================================================================
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
;  Dark theme helpers
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

; rounds a control; radius 0 = full pill
RoundCtrl(hwnd, radius := 0) {
    r := Buffer(16, 0)
    DllCall("GetClientRect", "ptr", hwnd, "ptr", r)
    w := NumGet(r, 8, "int"), h := NumGet(r, 12, "int")
    if (w <= 0 || h <= 0)
        return
    rad := radius ? radius : h
    rgn := DllCall("CreateRoundRectRgn", "int", 0, "int", 0, "int", w + 1, "int", h + 1, "int", rad, "int", rad, "ptr")
    DllCall("SetWindowRgn", "ptr", hwnd, "ptr", rgn, "int", true)
}

; =====================================================================
;  Tray menu
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

; =====================================================================
;  Settings window (dark + tabs)
; =====================================================================
ShowSettings(*) {
    global settingsGui, setPanels, setTabBtns, setHot, setBgNow, setActiveTab
    global setIconDarkEd, setIconLightEd, setDarkSw, setLightSw
    global setBoxes, setMyLangsEd, setSpellDD, setLangDD, setEmailEd, setStartCb, setHideDD, setExclEd
    if IsObject(settingsGui) {
        try settingsGui.Destroy()
        settingsGui := ""
    }
    HideBar()
    HideSymbols()

    setPanels := Map("buttons", [], "translate", [], "emails", [], "general", [])
    setTabBtns := Map()
    setHot := Map()
    setBgNow := Map()
    setBoxes := Map()
    setActiveTab := "buttons"

    g := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox", APP_NAME " settings")
    g.BackColor := C_BG
    g.MarginX := 0
    g.MarginY := 0
    g.SetFont("s9", "Segoe UI")
    DarkTitle(g.Hwnd)

    ; ----- header -----
    if FileExist(IconFile)
        g.AddPicture("x20 y16 w32 h32", IconFile)
    ttl := g.AddText("x62 y17 w300 h22", APP_NAME)
    ttl.SetFont("s13 bold c" C_TXT, "Segoe UI")
    sub := g.AddText("x63 y39 w300 h16", "Text toolbar for Windows")
    sub.SetFont("s8 c" C_DIM, "Segoe UI")

    ; ----- tabs -----
    tabs := [["buttons", "Buttons"], ["translate", "Language"], ["emails", "Emails"], ["general", "General"]]
    tx := 20
    for t in tabs {
        c := g.AddText("x" tx " y72 w116 h30 +0x200 Center Background" C_BG2, t[2])
        c.SetFont("s9 c" C_DIM, "Segoe UI")
        c.OnEvent("Click", SwitchTab.Bind(t[1]))
        RoundCtrl(c.Hwnd)
        setTabBtns[t[1]] := c
        setHot[c.Hwnd] := "tab:" t[1]
        setBgNow[c.Hwnd] := C_BG2
        tx += 122
    }
    g.AddText("x20 y114 w520 h1 Background" C_LINE)

    ; ----- tab 1: buttons -----
    AddPanelText(g, "buttons", "x20 y132 w500 h18", "Choose which buttons appear in the bar", C_DIM, "s9")
    col := 0, row := 0
    for def in Defs {
        bx := 20 + col * 255
        by := 160 + row * 28
        cb := g.AddCheckbox("x" bx " y" by " w245 h24", def["label"])
        cb.SetFont("s9 c" C_TXT, "Segoe UI")
        cb.Value := Enabled[def["key"]] ? 1 : 0
        DarkCtrl(cb.Hwnd)
        setBoxes[def["key"]] := cb
        setPanels["buttons"].Push(cb)
        row += 1
        if (row = 6) {
            row := 0
            col += 1
        }
    }

    ; icon colors
    AddPanelText(g, "buttons", "x20 y338 w500 h18", "Icon color (hex code)", C_DIM, "s9")
    AddPanelText(g, "buttons", "x20 y366 w80 h24 +0x200", "Dark mode", C_TXT, "s9")
    AddPanelText(g, "buttons", "x100 y366 w14 h24 +0x200", "#", C_DIM, "s9")
    setIconDarkEd := g.AddEdit("x114 y366 w84 h24 -E0x200 Limit7 Uppercase Background" C_BG2, DarkLook["icon"])
    setDarkSw := g.AddText("x206 y366 w24 h24 Background" DarkLook["icon"])
    AddPanelText(g, "buttons", "x275 y366 w80 h24 +0x200", "Light mode", C_TXT, "s9")
    AddPanelText(g, "buttons", "x355 y366 w14 h24 +0x200", "#", C_DIM, "s9")
    setIconLightEd := g.AddEdit("x369 y366 w84 h24 -E0x200 Limit7 Uppercase Background" C_BG2, LightLook["icon"])
    setLightSw := g.AddText("x461 y366 w24 h24 Background" LightLook["icon"])
    for pair in [[setIconDarkEd, setDarkSw], [setIconLightEd, setLightSw]] {
        pair[1].SetFont("s9 c" C_TXT, "Consolas")
        DarkCtrl(pair[1].Hwnd)
        pair[1].OnEvent("Change", UpdateSwatch.Bind(pair[1], pair[2]))
        RoundCtrl(pair[2].Hwnd, 8)
        setPanels["buttons"].Push(pair[1], pair[2])
    }
    resetB := g.AddText("x20 y404 w150 h28 +0x200 Center Background" C_BG2, "Default colors")
    resetB.SetFont("s9 c" C_TXT, "Segoe UI")
    resetB.OnEvent("Click", ResetIconColors)
    RoundCtrl(resetB.Hwnd)
    setHot[resetB.Hwnd] := "btn"
    setBgNow[resetB.Hwnd] := C_BG2
    setPanels["buttons"].Push(resetB)
    AddPanelText(g, "buttons", "x184 y404 w340 h28 +0x200",
        "Default: white in dark mode, 2B2B2B in light mode.", C_DIM, "s8")

    ; ----- tab 2: translate -----
    AddPanelText(g, "translate", "x20 y132 w500 h18", "Translate the selected text into", C_DIM, "s9")
    names := [], cur := 1
    for i, l in Langs {
        names.Push(l[1])
        if (l[2] = TargetLang)
            cur := i
    }
    setLangDD := g.AddDropDownList("x20 y158 w260 Background" C_BG2, names)
    setLangDD.SetFont("s9 c" C_TXT, "Segoe UI")
    setLangDD.Choose(cur)
    DarkCtrl(setLangDD.Hwnd, "DarkMode_CFD")
    setPanels["translate"].Push(setLangDD)
    AddPanelText(g, "translate", "x20 y206 w500 h18", "Spelling and grammar check language", C_DIM, "s9")
    names2 := [], cur2 := 1
    for i, l in SpellLangs {
        names2.Push(l[1])
        if (l[2] = SpellLang)
            cur2 := i
    }
    setSpellDD := g.AddDropDownList("x20 y232 w260 Background" C_BG2, names2)
    setSpellDD.SetFont("s9 c" C_TXT, "Segoe UI")
    setSpellDD.Choose(cur2)
    DarkCtrl(setSpellDD.Hwnd, "DarkMode_CFD")
    setPanels["translate"].Push(setSpellDD)
    AddPanelText(g, "translate", "x300 y206 w240 h18", "Languages I write in (auto-detect)", C_DIM, "s9")
    setMyLangsEd := g.AddEdit("x300 y232 w220 h24 -E0x200 Background" C_BG2, MyLangs)
    setMyLangsEd.SetFont("s9 c" C_TXT, "Consolas")
    DarkCtrl(setMyLangsEd.Hwnd)
    setPanels["translate"].Push(setMyLangsEd)
    AddPanelText(g, "translate", "x20 y274 w520 h70",
        "Short codes separated by commas, e.g.  fr,en  or  fr,en,es.  Auto-detect only picks`n"
        . "from these, so a short text like `"je suis decu`" is not taken for another language.`n`n"
        . "The checked text is sent to languagetool.org (free service, 20 checks per minute).", C_DIM, "s8")

    ; ----- tab 3: emails -----
    AddPanelText(g, "emails", "x20 y132 w500 h18", "Saved emails (one per line)", C_DIM, "s9")
    emailText := ""
    for e in Emails
        emailText .= (emailText = "" ? "" : "`n") e
    setEmailEd := g.AddEdit("x20 y158 w500 r8 -E0x200 Background" C_BG2, emailText)
    setEmailEd.SetFont("s9 c" C_TXT, "Consolas")
    DarkCtrl(setEmailEd.Hwnd)
    setPanels["emails"].Push(setEmailEd)
    AddPanelText(g, "emails", "x20 y296 w500 h18",
        "Click the @ button in the bar to paste one of them.", C_DIM, "s8")

    ; ----- tab 4: general -----
    setStartCb := g.AddCheckbox("x20 y134 w400 h24", "Start with Windows")
    setStartCb.SetFont("s9 c" C_TXT, "Segoe UI")
    setStartCb.Value := IsStartupOn() ? 1 : 0
    DarkCtrl(setStartCb.Hwnd)
    setPanels["general"].Push(setStartCb)

    openB := g.AddText("x400 y132 w120 h28 +0x200 Center Background" C_BG2, "Open folder")
    openB.SetFont("s9 c" C_TXT, "Segoe UI")
    openB.OnEvent("Click", (*) => Run(DataDir))
    RoundCtrl(openB.Hwnd)
    setHot[openB.Hwnd] := "btn"
    setBgNow[openB.Hwnd] := C_BG2
    setPanels["general"].Push(openB)

    AddPanelText(g, "general", "x20 y168 w500 h18", "Hide the bar by itself after", C_DIM, "s9")
    setHideDD := g.AddDropDownList("x20 y192 w160 Background" C_BG2, HideChoices)
    setHideDD.SetFont("s9 c" C_TXT, "Segoe UI")
    hsel := 3
    for i, v in HideValues {
        if (v = AutoHideMs)
            hsel := i
    }
    setHideDD.Choose(hsel)
    DarkCtrl(setHideDD.Hwnd, "DarkMode_CFD")
    setPanels["general"].Push(setHideDD)

    AddPanelText(g, "general", "x20 y230 w500 h18", "Never show the bar in these apps (one per line)", C_DIM, "s9")
    exclText := ""
    for p in ExcludedApps
        exclText .= (exclText = "" ? "" : "`n") p
    setExclEd := g.AddEdit("x20 y254 w500 r4 -E0x200 Background" C_BG2, exclText)
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

    ; ----- footer -----
    g.AddText("x20 y462 w520 h1 Background" C_LINE)
    ft := g.AddText("x20 y476 w260 h30 +0x200", "v" APP_VERSION "   -   by " APP_AUTHOR)
    ft.SetFont("s8 c" C_DIM, "Segoe UI")

    cancel := g.AddText("x330 y474 w100 h32 +0x200 Center Background" C_BG2, "Cancel")
    cancel.SetFont("s9 c" C_TXT, "Segoe UI")
    cancel.OnEvent("Click", (*) => SettingsClosed(g))
    RoundCtrl(cancel.Hwnd)
    setHot[cancel.Hwnd] := "cancel"
    setBgNow[cancel.Hwnd] := C_BG2

    save := g.AddText("x440 y474 w100 h32 +0x200 Center Background" C_ACC, "Save")
    save.SetFont("s9 bold c" C_BG, "Segoe UI")
    save.OnEvent("Click", SaveSettings.Bind(g))
    RoundCtrl(save.Hwnd)
    setHot[save.Hwnd] := "save"
    setBgNow[save.Hwnd] := C_ACC

    g.OnEvent("Close", SettingsClosed)
    g.OnEvent("Escape", SettingsClosed)
    settingsGui := g
    SwitchTab("buttons")
    g.Show("w560 h524")
    DarkTitle(g.Hwnd)
    SetTimer(SettingsHoverTick, 60)
}

AddPanelText(g, panel, opts, text, color, size) {
    c := g.AddText(opts, text)
    c.SetFont(size " c" color, "Segoe UI")
    setPanels[panel].Push(c)
    return c
}

SwitchTab(name, *) {
    global setActiveTab
    setActiveTab := name
    for key, list in setPanels {
        for c in list
            c.Visible := (key = name)
    }
    for key, btn in setTabBtns {
        if (key = name) {
            btn.Opt("+Background" C_ACC)
            btn.SetFont("s9 bold c" C_BG, "Segoe UI")
            setBgNow[btn.Hwnd] := C_ACC
        } else {
            btn.Opt("+Background" C_BG2)
            btn.SetFont("s9 norm c" C_DIM, "Segoe UI")
            setBgNow[btn.Hwnd] := C_BG2
        }
        btn.Redraw()
    }
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
    for hwnd, role in setHot {
        hovered := (inGui && hc = hwnd)
        if (SubStr(role, 1, 4) = "tab:") {
            if (SubStr(role, 5) = setActiveTab)
                want := C_ACC
            else
                want := hovered ? C_BG3 : C_BG2
        } else if (role = "save")
            want := hovered ? C_ACC2 : C_ACC
        else
            want := hovered ? C_BG3 : C_BG2
        if (setBgNow[hwnd] != want) {
            setBgNow[hwnd] := want
            SetBg(hwnd, want)
        }
    }
}

SettingsClosed(g, *) {
    global settingsGui
    SetTimer(SettingsHoverTick, 0)
    settingsGui := ""
    try g.Destroy()
}

SaveSettings(g, *) {
    global TargetLang, SpellLang, MyLangs, Emails, AutoHideMs, ExcludedApps, settingsGui

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

    ; buttons
    for def in Defs {
        key := def["key"]
        Enabled[key] := (setBoxes[key].Value = 1)
        IniWrite(Enabled[key] ? "1" : "0", IniFile, "Buttons", key)
    }

    ; language
    TargetLang := Langs[setLangDD.Value][2]
    IniWrite(TargetLang, IniFile, "General", "TargetLang")

    ; spell check language
    SpellLang := SpellLangs[setSpellDD.Value][2]
    IniWrite(SpellLang, IniFile, "General", "SpellLang")
    MyLangs := CleanLangList(setMyLangsEd.Value)
    IniWrite(MyLangs, IniFile, "General", "MyLangs")

    ; auto hide
    AutoHideMs := HideValues[setHideDD.Value]
    IniWrite(AutoHideMs, IniFile, "General", "AutoHideMs")

    ; excluded apps
    ExcludedApps := Map()
    list := ""
    for line in StrSplit(setExclEd.Value, "`n", " `t`r") {
        if (line = "")
            continue
        ExcludedApps[StrLower(line)] := 1
        list .= (list = "" ? "" : ",") StrLower(line)
    }
    IniWrite(list, IniFile, "General", "ExcludedApps")

    ; start with windows
    startOn := (setStartCb.Value = 1)
    SetStartup(startOn)
    IniWrite(startOn ? "1" : "0", IniFile, "General", "StartWithWindows")

    ; icon colors
    DarkLook["icon"]  := CleanHex(setIconDarkEd.Value, DarkLook["icon"])
    LightLook["icon"] := CleanHex(setIconLightEd.Value, LightLook["icon"])
    IniWrite(DarkLook["icon"], IniFile, "General", "IconDark")
    IniWrite(LightLook["icon"], IniFile, "General", "IconLight")
    ApplyTheme()

    SetTimer(SettingsHoverTick, 0)
    settingsGui := ""
    g.Destroy()
    BuildBar()
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

ResetIconColors(*) {
    setIconDarkEd.Value := DefaultIconDark
    setIconLightEd.Value := DefaultIconLight
    UpdateSwatch(setIconDarkEd, setDarkSw)
    UpdateSwatch(setIconLightEd, setLightSw)
}


; =====================================================================
;  Files created at launch (icons are stored inside this script)
; =====================================================================
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
;  Spelling + grammar correction (LanguageTool public API, free)
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

; Popup with the corrected text. Click it to replace your selection.
ShowSpellPopup(fixed, count, langName) {
    global symGui, symVisible, symCtrls, symHover, symShownTick
    HideSymbols()
    symCtrls := Map()
    symHover := 0
    dia := Round(BtnSize * Scale)
    gap := Round(BtnGap * Scale)
    pad := Round(BarPad * Scale)
    shown := Trim(RegExReplace(fixed, "\s+", " "))
    if (StrLen(shown) > 90)
        shown := SubStr(shown, 1, 90) "..."
    infoH := Round(20 * Scale)
    rowW := Min(Round(620 * Scale), Max(Round(200 * Scale), Round((StrLen(shown) * 7.4 + 40) * Scale)))
    w := rowW + 2 * pad
    h := pad + infoH + gap + dia + pad
    symGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000")
    symGui.MarginX := 0
    symGui.MarginY := 0
    symGui.BackColor := BarBg
    info := (langName != "" ? langName " - " : "") count (count = 1 ? " correction" : " corrections") " - click to apply"
    t := symGui.AddText("x" pad " y" pad " w" rowW " h" infoH " +0x200 Center Background" BarBg, info)
    t.SetFont("s8 c" DimColor, "Segoe UI")
    c := symGui.AddText("x" pad " y" (pad + infoH + gap) " w" rowW " h" dia " +0x100 +0x200 Center Background" BarBg, shown)
    c.SetFont("s10 c" IconColor, "Segoe UI Semibold")
    c.OnEvent("Click", PickSymbol.Bind(fixed))
    symCtrls[c.Hwnd] := fixed
    rgn := DllCall("CreateRoundRectRgn", "int", 0, "int", 0, "int", rowW + 1, "int", dia + 1, "int", dia, "int", dia, "ptr")
    DllCall("SetWindowRgn", "ptr", c.Hwnd, "ptr", rgn, "int", true)
    GetWorkAreaAt(barX, barY, &wl, &wt, &wr, &wb)
    px := Max(wl + 4, Min(barX + (barW - w) // 2, wr - w - 4))
    py := barY + barH - h
    if (py < wt)
        py := barY
    py := Max(wt + 4, Min(py, wb - h - 4))
    symGui.Show("NA x" px " y" py " w" w " h" h)
    ApplyGlass(symGui.Hwnd)
    corner := dia + 2 * pad
    rgn := DllCall("CreateRoundRectRgn", "int", 0, "int", 0, "int", w + 1, "int", h + 1, "int", corner, "int", corner, "ptr")
    DllCall("SetWindowRgn", "ptr", symGui.Hwnd, "ptr", rgn, "int", true)
    symVisible := true
    symShownTick := A_TickCount
    SetTimer(SymHoverTick, 50)
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

