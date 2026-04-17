#SingleInstance Force		; forces single instance
#Requires AutoHotkey v2 ; forces v2

SendMode "Input"  ; Recommended for scripts due to its superior speed and reliability, but will not be using for modifier key toggles!
A_HotkeyInterval := 2000  ; This is the default value (milliseconds).
A_MaxHotkeysPerInterval := 1024	; prevent error message from high loads, 1024 hotkeys per 2 secs
#MaxThreadsPerHotkey 1 ; allow only one thread per Hotkey; a hotkey cannot interrupt itself
#MaxThreads 16 ; allow up to 16 threads to simultaneously run
KeyHistory 0 ; disable key logging
SetKeyDelay -1, -1	; no delay between keypresses, no delay between helds, default when sendmode input fallsback to event
ProcessSetPriority("High") ; allows for spamming without remorse, disabling this increases liklihood of keyhook interruption, resulting in race conditions

; CONFIGURATION PRIMATIVES, time in miliseconds
; 	Vertical Jump controls the amount of lines to jump on ;
VERT_JUMP := 2
;	Word Distance controls the amount of letters to skip on space
WORD_DIST := 12 ; 9-10 is twice the length of average english word
;	Vertical Distance controls the amount of letters/jumps skip on space
VERT_DIST := 4  ; currently set to 4
;   Traversal Timer is the amount of time to await traversal concluson during hyperjump
TRAVERSAL_TIMER := 500
;	Tab Swap delay is the amount of delay between rapid tab switching
TAB_SWAP_DELAY := 80
;   This is how long the tab switch is held, recommended to set it to 0.2
TAB_PRESS_HELD := 0.2

; 	FILE locations
UserProfile := EnvGet("USERPROFILE")
VSCODE_LAUNCH := UserProfile "\AppData\Local\Programs\Microsoft VS Code\bin\code"
SCREENSHOTS := UserProfile "\Pictures\Screenshots"
DOWNLOADS := UserProfile "\Downloads"
OBS := UserProfile "\Videos\OBS Output"
BROWSER := "floorp.exe"

; Terminology for SYNCHRONIZATION PRIMITIVES
; Binary Semaphores indicating conditions are called INDICATORS, of the form "has[verb]"
;;;;	Consider - indicators persist after triggering, released through another action
;;;;	Imagine - a button which, once pushed, is locked into place and requires another mechanism to reset it
; Binary Semaphores that are indicators with shared release and reactivation methods are called TOGGLES
;;;;	Consider - toggles are triggered and released through the same action, like a switch
;;;;	Imagine - a lever-like switch; or a non-locking button that turns things on and off
;;;;	Consider - toggles are a subset of indicators
; Counting Semaphores are called GEARS, like the gear shift on a wheeled vehicle

; DUAL CLICK
;;;;	set to active via pressing of both L and R clicks in F24 (Paddle)

; SYNCHRONIZATION PRIMITIVES
global gear := 0 ; mutually exclusive semaphore to control resource sharing of F24 (Paddle)
global backToggle := 0 ; toggled when back button is pressed in conjunction with any other input (excepting RButton), indicates back is overridden
global capsToggle := 0 ; toggled when capslock is activated, disabled by default; not mutually exclusive
global dualClickToggle := 0 ; toggled with an activation of dual click
global focusWindow := 0 ; helps keep track of switching stacked window, a special toggle to be reworked

global hasScrolled := 0 ; indicator, triggered via scroll with F24 (Paddle), Back, or BackPaddle; reset upon release of those
global hasSelected := 1 ; indicator, trigged via scrolling with shift activated (RButton held); reset upon new scroll without shift
global hasCopied := 0 ; indicator, triggered via copying any text, and reset whenever paddle is released, or scroll, etc
global isTraversing := 0 ; indicator, triggered via traversal with hyperjump
global hasDropSelected := 0 ; indicator, triggered via dropping F24 (Paddle) during a selection

SetScrollLockState "AlwaysOff" ; disable capslock by default, later to be toggled

; change focus of stacked windows via PowerToys Fancyzones
LAlt & CapsLock:: {
    global
    Send((focusWindow := !focusWindow) ? "#{PgUp}" : "#{PgDn}")
}

; toggle capslock disabled state
CapsLock:: {
    global
    if (capsToggle) {
        SetCapsLockState "AlwaysOff"
        capsToggle := 0
    } else {
        SetCapsLockState "AlwaysOn"
        capsToggle := 1
    }
}

; File Explorer Function, gets the current path of the folder being inspected
; within windows file explorer
; see https://www.autohotkey.com/boards/viewtopic.php?t=109907
GetActiveExplorerPath() {
    ; CabinetWClass is the classname for windows explorer
    explorerActivehwnd := WinActive("ahk_class CabinetWClass")
    if explorerActivehwnd {

        ; Identify the specific active tab handle
        ; If tabs aren't present, activeTab will be 0 and the code falls back to window HWND
        activeTab := 0
        try activeTab := ControlGetHwnd("ShellTabWindowClass1", explorerActivehwnd) ; Win 11
        catch
            try activeTab := ControlGetHwnd("TabWindowClass1", explorerActivehwnd) ; IE

        ; opens the list of all window objects and iterates until
        ; the current file explorer window is found, then iterates for active tab
        shell := ComObject("Shell.Application")

        for window in shell.Windows {
            ; Skip windows that don't belong to our current process/HWND
            if (window.hwnd != explorerActivehwnd)
                continue

            if activeTab {
                ; IID_IShellBrowser := "{000214E2-0000-0000-C000-000000000046}"
                ; Query the window for the ShellBrowser interface
                shellBrowser := ComObjQuery(window, "{000214E2-0000-0000-C000-000000000046}",
                    "{000214E2-0000-0000-C000-000000000046}")

                ; IShellBrowser::GetWindow is the 3rd method in the vtable
                ; It retrieves the HWND of the specific tab/view
                ComCall(3, shellBrowser, "uint*", &thisTab := 0)

                if (thisTab != activeTab)
                    continue
            }

            ; return the found path
            return window.Document.Folder.Self.Path
        }
    } else {
        ; for further reference, check out https://www.autohotkey.com/boards/viewtopic.php?t=85607
        throw Error("Couldn't find handle of File Explorer. Something has gone terribly wrong.")
    }
}

; gets the latest file in a directory
GetLatestFile(Directory, precursorTM := False) {
    LatestFN := ""
    LatestTime := precursorTM ? precursorTM : 0
    foundNewMax := False

    ; Use "F" mode to explicitly tell AHK to ignore directories immediately
    ; NOTE Patterns longer than 259 characters may fail to find any files due to system limitations (MAX_PATH). This limit can be bypassed by using the \\?\ long path prefix, with some stipulations.
    loop files, Directory "\*.*", "F" {
        ; loop through all files, and compare the modification timestamps
        if (A_LoopFileTimeModified > LatestTime) {
            LatestTime := A_LoopFileTimeModified
            ; Store only the name, not the full path for faster memory
            LatestFN := A_LoopFileName
            foundNewMax := True
        }
    }

    ; package two values in a tuple
    ans := {}
    ; Only perform expensive string concatenation once at the end
    newfoundLFN := LatestFN ? Directory "\" LatestFN : ""
    ans.FN := foundNewMax ? newfoundLFN : False
    ans.Time := LatestTime
    return ans
}

; repeats a key at the specified frequency
SendRepeatKeys(sentStuff, freq, iter) {
    loop iter {
        Send(sentStuff)
        BlockingSleep freq
    }
}

; safe sleep, prevents key input for duration
BlockingSleep(duration) {
    Critical
    BlockInput 1
    Sleep duration
    BlockInput 0
}

; UI function, gets the current coordinates of the active window
; displays a short message via new GUI window that doesn't interfere with current window
; recalling this will replace the current window's text, if it has not been destroyed
DisplayNotification(notifyText, backgroundColor := "434343", timeAlive := 720, posX := 20, posY := 20) {
    ; No active window? Then just return. This shouldn't happen, so give warning
    if !(WinExist("A")) {
        notifyText := "NO ACTIVE WINDOW FOUND"
    }

    WinGetPos &X, &Y, &W, &H, "A"  ; using "A" to get the active window's pos.

    ; give a small buffer to the positioning to account for inaccuracies in WinGetPos
    ; buffer is typically specified as pixels, decimal values are treated as percentile translations
    if (posX + posY > 2) {
        X += posX
        Y += posY
    } else {
        X += W * posX
        Y += H * posY
    }
    ; +Owner avoids a taskbar button
    ; +AlwaysOnTop does as expected
    ; -Border removes curved borders
    MyGui := Gui("+AlwaysOnTop -Border +Owner", "AHKnotification1")
    MyGui.BackColor := backgroundColor ; set background color
    ; Set font (10pt, semi-bold Verdana)
    MyGui.SetFont("s10 w600", "Verdana")
    MyGui.Add("Text", "cWhite", notifyText) ; add text
    ; NoActivate avoids deactivating the currently active window.
    MyGui.Show("NoActivate x" X " y" Y)
    ; Destroy after specified time
    SetTimer(() => MyGui.Destroy(), -timeAlive)
}

; UI function, a secondary notification that appears centered by default
; If not centered, notifications are right-justified, by percentage of width or height
DisplayNotification2(notifyText, backgroundColor := "434343", timeAlive := 900, posX := "Center", posY := "Center") {
    ; No active window? Then just return. This shouldn't happen, so give warning
    if !(WinExist("A")) {
        notifyText := "NO ACTIVE WINDOW FOUND"
    }

    WinGetPos &X, &Y, &W, &H, "A"  ; using "A" to get the active window's pos.

    ; give a small buffer to the positioning to account for inaccuracies in WinGetPos
    ; buffer is typically specified as pixels, decimal values are treated as percentile translations
    if posX != "Center" {
        posX := X + W - (W * posX)
    }
    if posY != "Center" {
        posY := Y + H - (H * posY)
    }

    ; +Owner avoids a taskbar button
    ; +AlwaysOnTop does as expected
    ; -Border removes curved borders
    MyGui := Gui("+AlwaysOnTop -Border +Owner", "AHKnotification2")
    MyGui.BackColor := backgroundColor ; set background color
    ; Set font (10pt, semi-bold Verdana)
    MyGui.SetFont("s10 w600", "Verdana")
    MyGui.Add("Text", "cWhite", notifyText) ; add text
    ; NoActivate avoids deactivating the currently active window.
    MyGui.Show("NoActivate x" posX " y" posY)
    ; Destroy after specified time
    SetTimer(() => MyGui.Destroy(), -timeAlive)
}

LogSemaphoreInfo() {
    if !(WinExist("A")) {
        notifyText := "NO ACTIVE WINDOW FOUND"
    }

    WinGetPos &X, &Y, &W, &H, "A"  ; using "A" to get the active window's pos.
    local posX := X + W - 220
    local posY := Y + 20

    local notifyText :=
        (
            "gear :" gear "`n"
            "backToggle  :" backToggle "`n"
            "capsToggle  :" capsToggle "`n"
            "dualClickTog :" dualClickToggle "`n"
            "hasScrolled :" hasScrolled "`n"
            "hasSelected :" hasSelected "`n"
            "hasCopied :" hasCopied "`n"
            "isTraversing :" isTraversing "`n"
            "hasDropSel :" hasDropSelected "`n"
            "F24 :" GetKeyState("F24", "P") "`n"
            "F24 Logic:" GetKeyState("F24") "`n"
            "Right :" GetKeyState("RButton", "P") "`n"
            "Right Logic:" GetKeyState("RButton") "`n"
            "Shift:" GetKeyState("LShift", "P") "`n"
            "Shift Logic:" GetKeyState("LShift") "`n"
            "Back :" GetKeyState("XButton1", "P")
        )

    ; +Owner avoids a taskbar button
    ; +AlwaysOnTop does as expected
    ; -Border removes curved borders
    MyGui := Gui("+AlwaysOnTop -Border +Owner", "AHKnotification3")
    MyGui.BackColor := "222222" ; set background color
    ; Set font (10pt, semi-bold Verdana)
    MyGui.SetFont("s10 w600", "Verdana")
    MyGui.Add("Text", "cWhite", notifyText) ; add text
    ; NoActivate avoids deactivating the currently active window.
    MyGui.Show("NoActivate x" posX " y" posY)
    SetTimer(() => MyGui.Destroy(), -800)
}

; function to pre-empt a race condition check
safeGetKeyStateLogical(modifierKey) {
    return GetKeyState(modifierKey)
}

; sometimes, race conditions persist despite marking critical sections
; this is speculated to occur due to system interrupts, keyboard issues with registering multiple keypresses, or the AHK runner interpretting this script rather than compiling to an exe
; another possible reason is keyhook delay, this is not something that can be  fixed without amending hardware interface code
;;;; The following is a bandage solution ;;;;
fixRaceCondition(modifierKey) {
    local Counter := 0
    loop {
        Sleep (2 ** (Counter * 2)) + 200
        if (Counter > 5) {
            ; Force a non-race, also logically terminate the catch
            ; DisplayNotification2("TIMEOUT", "red", 600, 0.07, 0.95)
            Send("{Blind}{" modifierKey " Up}")
            break
        }
        Counter++
        if !GetKeyState(modifierKey, "P") {
            ; DisplayNotification2("RESOLVED", "green", 600, 0.07, 0.95)
            Send("{Blind}{" modifierKey " Up}")
            break
        }
    }
}
; declare ; as a modifier
`;::;

; consume on input with RShift
RShift & `;:: {
    Critical
    ; DO NOTHING, activate only when (wasd) or alternative
    if (GetKeyState("j", "P") && !GetKeyState("l", "P")) {
        arrowNavigate(1, 1)
    } else if (GetKeyState("l", "P") && !GetKeyState("j", "P")) {
        arrowNavigate(0, 1)
    }
}

~RShift:: {
    fixRaceCondition("RShift")
}

; --- Context-dependent Keybinds ---

; --- Dasonian Navigation ---
; Arrowkey Navigation Replacement
; Replacement for right-handed arrow key navigation, can be remapped to any set of (wasd) keys
arrowNavigate(direction, p) {
    ; Special Technique - Send blind modifier up to logically indicate that RShift is being released during operation
    Send("{blind}{RShift up}")
    if (direction) {
        Send(p ? "{Blind}{Home}" : "{Blind}{Left}")
    } else {
        Send(p ? "{Blind}{End}" : "{Blind}{Right}")
    }
}
; Replacement for vertical navigation
arrowNavigateVert(direction, p) {
    ; Special Technique - Send blind modifier up to logically indicate that RShift is being released during operation
    Send("{blind}{RShift up}")
    if (direction) {
        p ? SendRepeatKeys("{Blind}{Up}", 30, VERT_JUMP) : Send("{Blind}{Up}")
    } else {
        p ? SendRepeatKeys("{Blind}{Down}", 30, VERT_JUMP) : Send("{Blind}{Down}")
    }
}
; horizontal navigation without blind sending, ideal for repeated sends
; not supported for ctrl modifier
; NOTABLE for using SendEvent, with buffered pauses
arrowNavigateUnblind(direction) {
    local lShiftPress := (GetKeyState("LShift", "P"))
    SetKeyDelay(0.92, 0.26)
    if (direction) {
        SendEvent(lShiftPress ? "+{Left " WORD_DIST "}" : "{Left " WORD_DIST "}")
    } else {
        SendEvent(lShiftPress ? "+{Right " WORD_DIST "}" : "{Right " WORD_DIST "}")
    }
}
; as above, so below, for vertical navigation
arrowNavigateUnblindVert(direction) {
    local lShiftPress := (GetKeyState("LShift", "P"))
    SetKeyDelay(1, 0.25)
    if (direction) {
        SendEvent(lShiftPress ? "+{Up " VERT_DIST "}" : "{Up " VERT_DIST "}")
    } else {
        SendEvent(lShiftPress ? "+{Down " VERT_DIST "}" : "{Down " VERT_DIST "}")
    }
}

; Up is 0 (zoom in), down is 1 (zoom out)
zoomBind(direction) {
    if WinActive("ahk_exe Resolve.exe") {
        Send(direction ? "!{WheelDown}" : "!{WheelUp}")
    } else {
        Send(direction ? "^{WheelDown}" : "^{WheelUp}")
    }
}

; Up is 0 (scroll left), down is 1 (scroll right)
horizontalScrollBind(direction) {
    if WinActive("ahk_exe Resolve.exe") {
        Send(direction ? "^{WheelDown}" : "^{WheelUp}")
    } else {
        Send(direction ? "+{WheelDown}" : "+{WheelUp}")
    }
}

; For Dasonian Navigation, ensure that we buffer input
; Also increase the number of threads handling these inputs
#MaxThreadsBuffer True
#MaxThreadsPerHotkey 3

; Activates arrowkey navigation, assignment to ijkl keys (wasd)
RShift & j:: arrowNavigate(1, GetKeyState(";", "P"))
RShift & l:: arrowNavigate(0, GetKeyState(";", "P"))
RShift & i:: arrowNavigateVert(1, GetKeyState(";", "P"))
RShift & k:: arrowNavigateVert(0, GetKeyState(";", "P"))

; Not Assigned
; RShift & u::{}
; RShift & o::{}

; set traversal to true, keep alive for traversal timer
refreshTraversal() {
    global
    isTraversing := 1
    SetTimer(() => isTraversing := 0, TRAVERSAL_TIMER)
}

; Dasonian hyperjump fast navigation
RShift & Space:: {
    global
    ; contains a small buffer to help with correcting erroneous space input when hyper-traversing, using traversal timer
    local isKeyj := GetKeyState("j", "P")
    local isKeyi := GetKeyState("i", "P")
    if (isKeyj Or GetKeyState("l", "P")) {
        ; Special Technique - Send blind modifier up to logically indicate that RShift is being released during operation (logically up)
        refreshTraversal()
        arrowNavigateUnblind(isKeyj)
    } else if (isKeyi Or GetKeyState("k", "P")) {
        ; Special Technique - Send blind modifier up to logically indicate that RShift is being released during operation (logically up)
        refreshTraversal()
        arrowNavigateUnblindVert(isKeyi)
    } else if !(isTraversing) {
        send("{Space}")
    } else {
        refreshTraversal()
    }
}

; Conclude buffering
#MaxThreadsBuffer False
#MaxThreadsPerHotkey 1

; Allows CTRL to fire during arrowkey navigation
; tilda (~) prevents the original input from being consumed
; here, LCtrl is being treated like a normal key only in terms of tilda's effect
RShift & ~LCtrl:: {
    ; Use the physical state of key
    if (GetKeyState("j", "P") && !GetKeyState("l", "P")) {
        arrowNavigate(1, 0)
    } else if (GetKeyState("l", "P") && !GetKeyState("j", "P")) {
        arrowNavigate(0, 0)
    }
}

;;; START OF MOUSE KEYBINDS ;;;
; FOR DEBUGGING
#F12:: {
    BlockingSleep 400
    loop {
        LogSemaphoreInfo()
        if GetKeyState("F12", "P") {
            break
        }
        BlockingSleep 400
    }
}

; Buffer this button to prevent unintended race conditions not being fixed
; Increase responsiveness with 2 threads
#MaxThreadsBuffer True
#MaxThreadsPerHotkey 2
; PADDLE FUNCTIONS
F24:: {
    global
    fixRaceCondition("F24")
}

F24 Up:: {
    global
    Critical
    if (gear) {
        ; MsgBox ,,,"F24 is released - gear 0", 1
        gear := 0
    }
    if (hasScrolled == hasSelected) {
        CaretGetPos(&x, &y)
        Click x, y
        hasDropSelected := 1
    } else {
        hasDropSelected := 0
    }
    hasScrolled := 0
    hasSelected := 1
    dualClickToggle := 0
    hasCopied := 0
}
#MaxThreadsPerHotkey 1
#MaxThreadsBuffer False

F16:: {
    WinMinimize("A")
}

; Send event is optimal for repeated inputs
tabSwap(direction) {
    SetKeyDelay(TAB_SWAP_DELAY, TAB_PRESS_HELD)
    SendEvent(direction ? "^+{Tab " 2 " }" : "^{Tab " 2 " }")
}

; left tab
F17:: {
    Send("^+{Tab}")
    KeyWait("F17", "T0.3125")
    while GetKeyState("F17", "P") {
        tabSwap(1)
    }
}
; right tab
F18:: {
    SendInput("^{Tab}")
    KeyWait("F18", "T0.3125")
    while GetKeyState("F18", "P") {
        tabSwap(0)
    }
}
; LWheel
F23:: {
    Send("^t")
}
; RWheel
F22:: {
    Send("^w")
}
; Hypershifted LWheel
F21:: {
    Send("^r")
}
; Hypershifted RWheel
F20:: {
    Send("^+t")
}
; Hypershifted MClick
F15:: {
    ; VScode shortcut
    if (gear == 2) {
        if WinActive("ahk_exe explorer.exe") {
            local path := GetActiveExplorerPath()
            Run('`"' VSCODE_LAUNCH '`" ' path, , "Hide")
            DisplayNotification2("Starting VSCode in " path, "1a2294", 1000)
        } else {
            Send("Dason")
        }
    } else {
        Send("!{F4}")
    }
}

;;; HYPERPADDLE
; Zooming in and out
F19 & PgUp:: {
    zoomBind(0)
}
F19 & PgDn:: {
    zoomBind(1)
}

; Snipping tool, with popup, useful for editing or AI text extraction
F19 & F18:: {
    try {
        Run("SnippingTool", , "Hide")
        WinWait("Snipping Tool", "", 1)
    } catch Error {
        DisplayNotification2("Error opening snipping tool", "Red")
    }
    Send("^{n}")
}

; Snipping tool, without popup, "quick snip"
F19 & F17:: {
    Send("#+s")
}

; Arrange window on Monitor Left/Right
F19 & F20:: {
    Send("+#{Left}")
}

; Arrange window on Monitor Left/Right
F19 & F21:: {
    Send("+#{Right}")
}

;; Text selection with mouse wheel ;;
F24 & WheelUp:: {
    global
    Critical
    Send((dualClickToggle) ? "{Blind}{Left}" : "{Blind}^{Left}")
    hasSelected := GetKeyState("LShift")
    hasCopied := 0
    hasScrolled := 1
}

;; Text selection with mouse wheel ;;
F24 & WheelDown:: {
    global
    Critical
    Send((dualClickToggle) ? "{Blind}{Right}" : "{Blind}^{Right}")
    hasSelected := GetKeyState("LShift")
    hasCopied := 0
    hasScrolled := 1
}

; Enter and Rename File and Blender Pan
F24 & MButton:: {
    ; only for file explorer - rename a file
    if WinActive("ahk_exe explorer.exe") {
        Send((GetKeyState("LShift")) ? "^+n" : "{F2}")
    }
    ; panning in blender
    else if WinActive("ahk_exe blender.exe") {
        Send("+{MButton Down}")
    } else {
        Send("{Enter}")
    }
}

; Need to release blender pan especially
F24 & MButton Up:: {
    if WinActive("ahk_exe blender.exe") {
        Send("+{MButton Up}")
    }
}

; Adds shifting to mouse
F24 & RButton:: {
    Send("{Shift Down}")
}

; copies iff hasScrolled not detected and not dualClicked
F24 & RButton Up:: {
    global
    Critical
    Send("{Shift Up}")
    if (hasScrolled) {
        hasScrolled := 0
    } else {
        if (hasSelected && !hasDropSelected) {
            if (hasCopied) {
                Critical "Off"
                ; send cut
                Send("^x")
                DisplayNotification(" Cut ", "55AE55")
            } else {
                hasCopied := 1
                Critical "Off"
                ; send copy
                Send("^c")
                DisplayNotification("Copied", "2f842f")
            }
        }
        hasDropSelected := 0
    }
}

; either pastes or activates special toggle
F24 & LButton:: {
    global
    Critical
    if GetKeyState("LShift") {
        ; MsgBox ,,,"Special State Activated", 1
        dualClickToggle := (dualClickToggle) ? 0 : 1
        local phrase := (dualClickToggle) ? " LETTER " : "  WORD  "
        local color := (dualClickToggle) ? "aa1fa8" : "50108b"
        DisplayNotification(phrase, color)
    } else {
        Critical "Off"
        ; paste
        Send("^v")
    }
}

; search and find
F24 & F16:: {
    Send("^h")
}

; Shift+home and Backspace/tab
F24 & F22:: {
    ; CabinetWClass is the classname for windows explorer
    if (WinActive("ahk_class CabinetWClass") && GetKeyState("LShift")) {
        Critical
        ; ; CHOOSES LATEST DOWNLOAD OR SCREENSHOT
        ; ; extra feature: directly move the latest screenshot from "screenshots" folder to the current active file explorer window using powershell
        ; ; extra feature: directly move the last downloaded file from "downlaods" folder to the current active file explorer window using powershell
        ; ; EXPLANATION OF POWERSHELL.EXE FLAGS:
        ; ;		-ExecutionPolicy Bypass removes user access warning
        ; ;		-NonInteractive  Create sessions that shouldn't require user input, maybe faster?
        ; ;		-WindowStyle Hidden Make the terminal window not pop up, but still will make it flash
        ; ;		cmd /c start /min "" 	will start the powershell window minimized, making the flash quicker
        ; Run(
        ;     'powershell.exe -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -file "powershell_scripts\MoveNewestItem.ps1"'
        ; )
        ; DisplayNotification2("PowerShell - File Moved", "0047AB", 2000)
        ; Run('powershell.exe -ExecutionPolicy Restricted -NonInteractive -WindowStyle Hidden')
        targetDest := GetActiveExplorerPath()
        possibleLoc := [DOWNLOADS, OBS]

        ; first round, comparisons begin at 0
        ans := GetLatestFile(SCREENSHOTS)
        latestFile := ans.FN
        latestTime := ans.Time

        ; next rounds compared against previous winner
        for loc in possibleLoc {
            ans := GetLatestFile(loc, latestTime)
            if (ans.FN) {
                latestFile := ans.FN
            }
            latestTime := ans.Time
        }

        ; Finally, move the files
        if latestFile {
            FileMove latestFile, targetDest
            ; Inform user
            DisplayNotification2("AHK - File Moved", "1fcfa9", 2200)
        } else {
            DisplayNotification2("AHK - No Files", "563509", 2400)
        }
        Critical "Off"
    } else {
        if GetKeyState("LShift") {
            Send("{Blind}{Home}")
            hasScrolled := 1
        } else {
            Send("{Blind}{Backspace}")
        }
    }
}

; Shfit+end and Del
F24 & F23:: {
    global
    if GetKeyState("LShift") {
        Send("{Blind}{End}")
        hasScrolled := 1
    } else {
        Send("{Del}")
    }
}

~XButton1 & F24:: {
    global
    Critical
    if (gear == 0) {
        gear := 1
        backToggle := 1
    }
}

~F24 & XButton1:: {
    global
    Critical
    if (gear == 0) {
        gear := 1
        backToggle := 1
    }
}

; XButton1 & F24 Up:: {
;     global
;     Critical
;     gear := 0
; }
; F24 & XButton1 Up:: {
;     global
;     Critical
;     gear := 0
;     backToggle := 0
; }
; delete line, move carat up

XButton1 & WheelUp:: {
    global
    backToggle := 1
    hasScrolled := 1
    if (gear) {
        Send("{Blind}{Up}")
    } else {
        if GetKeyState("LShift") {
            DisplayNotification2("PLACEHOLDER")
        } else {
            if WinActive("ahk_exe Code.exe") {
                Send("!{Up}")
            } else {
                ; swap this line and the line above
                Send("{Home}")
                Send("+{End}")
                BlockingSleep 32
                Send("^x")
                BlockingSleep 32
                Send("{Up}")
                BlockingSleep 32
                Send("^v")
                BlockingSleep 32
                Send("{Up}")
                Send("{End}")
            }
        }

    }
}

; duplicate line, move carat down
XButton1 & WheelDown:: {
    global
    backToggle := 1
    hasScrolled := 1
    if (gear) {
        Send("{Blind}{Down}")
    } else {
        if GetKeyState("LShift") {
            if WinActive("ahk_exe Code.exe") {
                Send("!{Down}")
            } else {
                Send("{Shift Up}")
                BlockingSleep 64
                Send("{Home}")
                BlockingSleep 64
                Send("+{End}")
                BlockingSleep 64
                Send("^c")
                BlockingSleep 128
                Send("{End}")
                BlockingSleep 64
                Send("+{Enter}")
                BlockingSleep 64
                Send("^v")
            }
        } else {
            if WinActive("ahk_exe Code.exe") {
                Send("!{Down}")
            } else {
                ; swap this line and the line below
                Send("{Home}")
                Send("+{End}")
                BlockingSleep 32
                Send("^x")
                BlockingSleep 32
                Send("{End}")
                Send("+{Enter}")
                BlockingSleep 32
                Send("^v")
                BlockingSleep 32
                Send("{Backspace}")
            }
        }
    }
}

XButton1 & LButton:: {
    global
    backToggle := 1
    if (gear == 0) {
        ; duplicate multi-carat mode
        ; uses ALT-click for VScode, CTRL-click otherwise
        if WinActive("ahk_exe Code.exe") {
            Send("!{LButton}")
        } else {
            Send("^{LButton}")
        }
    } else {
        ; clipboard history
        Send("{F24 Up}")
        Send("#v")
        Send("{F24 Down}")
    }
}

XButton1 & RButton:: {
    Critical
    Send("{Shift Down}")
}

; Placeholder if hasScrolled not detected, otherwise exists hasScrolled
XButton1 & RButton Up:: {
    global
    Critical
    backToggle := 1
    Send("{Shift Up}")
    if (hasScrolled) {
        hasScrolled := 0
    } else {
        Send("+{LButton}")
    }
}

; Save with ctrl+s
XButton1 & MButton:: {
    global
    backToggle := 1
    if (gear == 0) {
        Send("^s")
    } else {
        MsgBox("Placeholder")
    }
}

XButton1 & F16:: {
    backToggle := 1
    Send("^e")
}

XButton1 & F22:: {
    global
    backToggle := 1
    if (gear == 0) {
        Send("^z")
        KeyWait("F22", "T0.3125")
        while GetKeyState("F22", "P") {
            Send("^z")
            BlockingSleep 128
        }
    } else {
        if WinActive("ahk_exe " BROWSER) {
            Send("^1")
        }
    }
}

XButton1 & F23:: {
    global
    backToggle := 1
    if (gear == 0) {
        Send("^y")
        KeyWait("F23", "T0.3125")
        while GetKeyState("F23", "P") {
            Send("^y")
            BlockingSleep 128
        }
    } else {
        if WinActive("ahk_exe " BROWSER) {
            Send("^9")
        }
    }
}

; different functionality then doing XButton1 Up, although this is a prefix key,
; it has been tildafied, and thus is custom coded.
XButton1:: {
}

XButton1 Up:: {
    global
    Critical
    hasScrolled := 0
    gear := 0
    if (backToggle) {
        backToggle := 0
    } else {
        Send("{XButton1}")
    }
}

; HyperBack mode
XButton2 & PgUp:: {
    global
    if (gear == 2) {
        Send("!{WheelUp}")
    } else {
        horizontalScrollBind(0)
    }
}

XButton2 & PgDn:: {
    global
    if (gear == 2) {
        Send("!{WheelDown}")
    } else {
        horizontalScrollBind(1)
    }
}

; Everything mode
XButton2 & F17:: {
    Send("^+{PgUp}")
    KeyWait("LButton", "T0.3125")
    while GetKeyState("LButton", "P") {
        Send("^+{PgUp}")
        BlockingSleep 48
    }
}
XButton2 & F18:: {
    Send("^+{PgDn}")
    KeyWait("RButton", "T0.3125")
    while GetKeyState("RButton", "P") {
        Send("^+{PgDn}")
        BlockingSleep 48
    }
}
; same functionality as doing XButton2 Up, because this is a prefix key
XButton2:: {
    global
    Critical
    if (gear == 0) {
        Send("{XButton2}")
    } else {
        gear := 0
    }
}
XButton2 & F19:: {
    global
    Critical
    gear := 2
}
F19 & XButton2:: {
    global
    ; gear := 3
}
XButton2 & F19 Up:: {
    global
    Critical
    gear := 0
}
