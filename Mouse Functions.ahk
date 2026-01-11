#SingleInstance Force	; forces single instance

SendMode Input  ; Recommended for scripts due to its superior speed and reliability.
#MaxHotkeysPerInterval 999	; prevent error message from high loads
#MaxThreadsPerHotkey 1 ; allow only one thread per Hotkey; a hotkey cannot interrupt itself
#MaxThreads 12 ; allow up to 12 threads to simultaneously run 
SetBatchLines, -1	; prevent program from sleeping, running at maximum utilization
#KeyHistory 0 ; disable key logging
SetKeyDelay, 0	; no delay between keypresses

; Terminology for SYNCRHONIZATION PRIMATIVES
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

; SYNCRHONIZATION PRIMATIVES
gear = 0 ; mutually exclusive semaphore to control resource sharing of F24 (Paddle)

backToggle = 0 ; toggled when back button is pressed in conjunction with anything else
capsToggle = 0 ; toggled when capslock is activated, disabled by default; not mutually exclusive
dualClickToggle = 0 ; toggled with an activation of dual click
focusWindow = 0 ; helps keep track of switching stacked window, a special toggle to be reworked

hasScrolled = 0 ; indicator, triggered via scroll with F24 (Paddle), Back, or BackPaddle; reset upon release of those
hasSelected = 1 ; indicator, trigged via scrolling with shift activated (RButton held); reset upon new scroll without shift
hasCopied = 0 ; indicator, triggered via copying any text, and reset whenever paddle is released, or scroll, etc


SetCapsLockState, alwaysoff ; disable capslock
; change focus of stacked windows via PowerToys Fancyzones
LAlt & CapsLock::
	Send, % (focusWindow := !focusWindow) ? "#{PgUp}" : "#{PgDn}"
	return

; toggle capslock disabled state
CapsLock::
	if (capsToggle) {
		SetCapsLockState, alwaysoff
		capsToggle = 0
	} else {
		SetCapsLockState, alwayson
		capsToggle = 1
	}
	return

; File Explorer Function, gets the current path of the folder being inspected
; within windows file explorer
GetActiveExplorerPath() {
	; CabinetWClass is the classname for windows explorer
    explorerActivehwnd := WinActive("ahk_class CabinetWClass")
    if (explorerActivehwnd) {
		; opens the list of all window objects and iterates until
		; the current file explorer window is found
        for window in ComObjCreate("Shell.Application").Windows {
            if (window.hwnd==explorerActivehwnd) {
                return window.Document.Folder.Self.Path
            }
        }
    }
	; for further reference, check out https://www.autohotkey.com/boards/viewtopic.php?t=85607
	throw "Couldn't find handle of File Explorer. Something has gone terribly wrong."
}

; UI function, gets the current coordinates of the active window
; displays a short message via new GUI window that doesn't interfere with current window
; recalling this will replace the current window's text, if it has not been destroyed
DisplayNotification(notifyText, backgroundColor, timeAlive:=720) {
	WinGetPos, X, Y, W, H, A  ; using "A" to get the active window's pos.
	; give a small buffer to the positioning to account for inaccuracies in WinGetPos
	X := X + 10
	Y := Y + 10
	; +Owner avoids a taskbar button
	; +AlwaysOnTop does as expected
	; -Border removes curved borders
	Gui, n:New, +AlwaysOnTop -Border +Owner, "AHKnotificaiton"  
	Gui, Color, %backgroundColor% ; set bacgkround color
	Gui, Font, s10 w600, Verdana  ; Set 11-point Verdana, just slightly bolder.
	Gui, Add, Text, cWhite, %notifyText% ; add text 
	; NoActivate avoids deactivating the currently active window.
	Gui, Show, NoActivate x%X% y%Y%
	; remove this window after 0.72 seconds
	SetTimer, DestroyGUI, %timeAlive%
	return
}

DestroyGUI() {
	Gui, n:Destroy
	return
}

; declare ; as a modifier
`;::;
; consume on input with RShift
RShift & `;::
	Critical
	; DO NOTHING, activate only when (wasd) or alternative
	If (GetKeyState("j", "P") && !GetKeyState("l", "P")) {
		arrowNavigate(1, 1)
	} Else If (GetKeyState("l", "P") && !GetKeyState("j", "P")) {
		arrowNavigate(0, 1)
	}
	return

; --- Dasonian Navigation ---
; Arrowkey Navigation Replacement
; Replacement for right-handed arrow key navigation, can be remapped to any set of (wasd) keys
arrowNavigate(direction, p) {
	if (direction) {
		If GetKeyState("LShift"){
			Send % (p) ?  "{Blind}{Home}" : "{Blind}+{Left}"
		} else {
			Send % (p) ?  "{Blind}{Home}" : "{Blind}{Left}"
		}
	} else {		
		If GetKeyState("LShift"){
			Send % (p) ?  "{Blind}+{End}" : "{Blind}+{Right}"
		} else {
			Send % (p) ?  "{Blind}{End}" : "{Blind}{Right}"
		}
	}

	; THIS OLDER VERSION WAS MADE BEFORE THE ADVENT OF FIGURING OUT BLIND MODIFIER BEHAVIOR
	; Explanation:
	;Modifier keys are restored differently to allow a Send to turn off a hotkey's modifiers even 
	; if the user is still physically holding them down. For example, ^space::Send {Ctrl up} 
	; automatically pushes Ctrl back down if the user is still physically holding Ctrl, whereas 
	; ^space::Send {Blind}{Ctrl up} allows Ctrl to be logically up even though it is physically down. */

	; arrowNavigate(direction, p){
	; if (direction) {
	; 	If GetKeyState("LCtrl") {
	; 		If GetKeyState("LShift"){
	; 			Send % (p) ?  "^+{Home}" : "+^{Left}"
	; 		} else {
	; 			Send % (p) ?  "^{Home}" : "^{Left}"
	; 		}
	; 	} else {
	; 		If GetKeyState("LShift"){
	; 			Send % (p) ? "+{Home}" : "+{Left}"
	; 		} else {
	; 			Send % (p) ? "{Home}" : "{Left}"
	; 		}
	; 	}
	; } else {		
	; 	If GetKeyState("LCtrl") {
	; 		If GetKeyState("LShift"){
	; 			Send % (p) ?  "^+{End}" : "+^{Right}"
	; 		} else {
	; 			Send % (p) ?  "^{End}" : "^{Right}"
	; 		}
	; 	} else {
	; 		If GetKeyState("LShift"){
	; 			Send % (p) ? "+{End}" : "+{Right}"
	; 		} else {
	; 			Send % (p) ? "{End}" : "{Right}"
	; 		}
	; 	}
	; }

	; THIS EVEN OLDER VERSION IS SLOWER
	; direction := (direction == 0) ? "Left" : "Right"
	; If GetKeyState("LCtrl") {
	; 	If GetKeyState("LShift"){
	; 		Send % (powerToggle) ?  "+^{" . direction . "}+^{" . direction . "}" : "+^{" . direction . "}"
	; 	} else {
	; 		Send % (powerToggle) ?  "^{" . direction . "}^{" . direction . "}" : "^{" . direction . "}"
	; 	}
	; } else {
	; 	If GetKeyState("LShift"){
	; 		Send % (powerToggle) ? "+{" . direction . "}+{" . direction . "}" : "+{" . direction . "}"
	; 	} else {
	; 		Send % (powerToggle) ? "{" . direction . "}{" . direction . "}" : "{" . direction . "}"
	; 	}
	; }
}

; Activates arrowkey navigation, assignment to ijkl keys (wasd)
RShift & j::
	Critical
	; Special Technique - Send blind modifier up to logically indicate that RShift is being released during operation
	send {blind}{RShift up}
	If GetKeyState(";", "P"){
		arrowNavigate(1, 1)
	} else {
		arrowNavigate(1, 0)
	}
	send {blind}{RShift down}
	return

RShift & l::
	Critical
	; Special Technique - Send blind modifier up to logically indicate that RShift is being released during operation
	send {blind}{RShift up}
	If GetKeyState(";", "P"){
		arrowNavigate(0, 1)
	} else {
		arrowNavigate(0, 0)
	}
	send {blind}{RShift down}
	return

; Dasonian hyperjump fast navigation
RShift & Space::
	Critical
	If (GetKeyState("l", "P") Or GetKeyState("j", "P")){
		; Special Technique - Send blind modifier up to logically indicate that RShift is being released during operation
		send {blind}{RShift up}
		; 9.4 is twice the length of average english word, round down to 9
		hyperjump_dist := GetKeyState("LCtrl") ? 4 : 9    
		Loop, %hyperjump_dist% {
			arrowNavigate(GetKeyState("j", "P"), 0)
		}
		send {blind}{RShift down}
	} else {
		send {Space}
	}
	return

RShift & k::
	Critical
	If GetKeyState("LShift"){
		Send, +{Down}
	} else {
		Send, {Down}
	}
 	return

RShift & i::
	Critical
	If GetKeyState("LShift"){
		Send, +{Up}
	} else {
		Send, {Up}
	}
 	return

RShift & u::
	; MsgBox ,,,"NOT ASSIGNED", 1
 	return

RShift & o::
	; MsgBox ,,,"NOT ASSIGNED", 1
 	return

; Allows CTRL to fire during arrowkey navigation
; tilda (~) prevents the original input from being consumed
RShift & ~LCtrl::
; Use the physical state of key
If (GetKeyState("j", "P") && !GetKeyState("l", "P")) {
		arrowNavigate(1, 0)
	} Else If (GetKeyState("l", "P") && !GetKeyState("j", "P")) {
		arrowNavigate(0, 0)
	}
	return
	
; PADDLE FUNCTIONS
F24::
	return

F24 Up::
	Critical
	if (gear) {
		; MsgBox ,,,"F24 is released - gear 0", 1
		gear = 0
	}
	hasScrolled = 0
	hasSelected = 1
	dualClickToggle = 0
	hasCopied = 0
	return

F16::	
	WinMinimize, A
	return


; left tab
F17::
	Send, ^+{Tab}
	KeyWait F17,T0.3125
	If ErrorLevel
		While GetKeyState("F17","P"){
			SendInput ^+{Tab}
			Sleep 48
		}
	return

; right tab
F18::
	SendInput, ^{Tab}
	KeyWait F18,T0.3125
	If ErrorLevel
		While GetKeyState("F18","P"){
			Send ^{Tab}
			Sleep 48
		}
	return

; LWheel
F23::
	Send, ^t
	return

; RWheel
F22::
	Send, ^w
	return

; Hypershifted LWheel
F21::
	Send, ^r
	return

; Hypershifted RWheel
F20::
	Send, ^+t
	return

; Hypershifted MClick
F15::
	; VScode shortcut
	if (gear = 2) {
		if WinActive("ahk_exe explorer.exe") {
			path := GetActiveExplorerPath()
			run, "C:\Users\dason\AppData\Local\Programs\Microsoft VS Code\bin\code" "%path%"
		} else {
			Send, Dason
		}
	} else {
		Send, !{F4}
	}
	return

;;; HYPERPADDLE
F19 & PgUp::
	Send, ^{WheelUp}	
	return

F19 & PgDn::
	Send, ^{WheelDown}
	return	

; Snipping tool, with popup, useful for editing or AI text extraction
F19 & F18::
	Run, SnippingTool
	WinWait, Snipping Tool, ,1
	if ErrorLevel {
		MsgBox ,,,"Error Opening Snipping Tool", 0.5
	}
	Send, ^{n}
	return

; Snipping tool, without popup, "quick snip"
F19 & F17::
	Send, #+s
	return

; Arrange window on Monitor Left/Right 
F19 & F20::
	Send, +#{Left}
	return
; Arrange window on Monitor Left/Right
F19 & F21::
	Send, +#{Right}
	return	

F24 & WheelUp::
	Critical
	Send, % (dualClickToggle) ? "{Blind}{Left}" : "{Blind}^{Left}"
	if GetKeyState("LShift") {
		hasSelected = 1
	} else {
		hasSelected = 0
	}
	hasCopied = 0
	hasScrolled = 1
	return

F24 & WheelDown::
	Critical
	Send, % (dualClickToggle) ? "{Blind}{Right}" : "{Blind}^{Right}"
	if GetKeyState("LShift") {
		hasSelected = 1
	} else {
		hasSelected = 0
	}
	hasCopied = 0
	hasScrolled = 1
	return

; Enter and Rename File
F24 & MButton::
	; only for file explorer - rename a file
	if WinActive("ahk_exe explorer.exe") {
		Send, % (GetKeyState("LShift")) ? "^+n" : "{F2}"
	}
	else {
		Send, {Enter}
	}
	return

F24 & RButton::
	Send, {Shift Down}
	return

; copies iff hasScrolled not detected and not dualClicked
F24 & RButton Up::
	Critical
	Send, {Shift Up}
	if (hasScrolled) {
		hasScrolled = 0
	} else {
		if (hasSelected) {
			if (hasCopied) {
				Critical Off
				; send cut
				Send, ^x

				DisplayNotification(" Cut ", "55AE55")
			} else {
				hasCopied = 1
				Critical Off
				; send copy
				Send, ^c

				DisplayNotification("Copied", "5FA85F")
			}
		}
	}
	return

; either pastes or activates special toggle
F24 & LButton::
	Critical
	if GetKeyState("LShift") {
		; MsgBox ,,,"Special State Activated", 1
		dualClickToggle := (dualClickToggle) ? 0 : 1
		phrase := (dualClickToggle) ? " Letter " : " Word "
		color := (dualClickToggle) ? "FF8C00" : "BA8E23"
		DisplayNotification(phrase, color)
	} else {
		Critical Off
		; paste
		Send, ^v
	}
	return
				
F24 & F16::
	Send, ^h
	return

; Shift+home and Backspace/tab
F24 & F22::
	; CabinetWClass is the classname for windows explorer
	if (WinActive("ahk_class CabinetWClass") && GetKeyState("LShift")) {
		Critical On
		; CHOOSES LATEST DOWNLOAD OR SCREENSHOT
		; extra feature: directly move the latest screenshot from "screenshots" folder to the current active file explorer window using powershell
		; extra feature: directly move the last downloaded file from "downlaods" folder to the current active file explorer window using powershell
		; EXPLANATION OF POWERSHELL.EXE FLAGS:
		;		-ExecutionPolicy Bypass removes user access warning
		;		-NonInteractive  Create sessions that shouldn't require user input, maybe faster?
		;		-WindowStyle Hidden Make the terminal window not pop up, but still will make it flash
		;		cmd /c start /min "" 	will start the powershell window minimized, makign the flash quicker
		Run, powershell.exe -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -file "Powershell Scripts\MoveNewestItem.ps1"
		DisplayNotification("PowerShell - File Moved", "0047AB", timeAlive:=2000)
		Critical Off
	} else {
		if GetKeyState("LShift"){
			Send, {Home}
			hasScrolled = 1
		} else {
			Send, {Blind}{Backspace}
		}
	}
	return

; Shfit+end and Del/shift+tab
F24 & F23::
	if GetKeyState("LShift"){
		Send, {End}
		hasScrolled = 1
	} else {
		Send, {Del}
	}
	return

~XButton1 & F24::
	Critical
	if (gear = 0) {
		gear = 1
		backToggle = 1
	}
	return

~F24 & XButton1::
	Critical
	if (gear = 0) {
		gear = 1
		backToggle = 1
	}
	return

; delete line, move carat up
XButton1 & WheelUp::
	backToggle = 1
	if (gear) {
		Send, {Blind}{Up}
	} else {
		if GetKeyState("LShift") {
			MsgBox, % "placeholder"
		} else {
			if WinActive("ahk_exe Code.exe") {
				Send, !{Up}
			} else {
				; swap this line and the line above
				Send, {Home}
				Send, +{End}
				Sleep, 32
				Send, ^x
				Sleep, 32
				Send, {Up}
				Sleep, 32
				Send, ^v
				Sleep, 32
				Send, {Up}
				Send, {End}
			}
		}

	}
	hasScrolled = 1
	return

; duplicate line, move carat down
XButton1 & WheelDown::
	backToggle = 1
	if (gear) {
		Send, {Blind}{Down}
	} else {
		if GetKeyState("LShift") {
			if WinActive("ahk_exe Code.exe") {
				Send, !{Down}
			} else {
				Send, {Shift Up}
				Sleep, 64
				Send, {Home}
				Sleep, 64
				Send, +{End}
				Sleep, 64
				Send, ^c
				Sleep, 128
				Send, {End}
				Sleep, 64
				Send, +{Enter}
				Sleep, 64
				Send, ^v
			}
		} else {
			if WinActive("ahk_exe Code.exe") {
				Send, !{Down}
			} else {
				; swap this line and the line below
				Send, {Home}
				Send, +{End}
				Sleep, 32
				Send, ^x
				Sleep, 32
				Send, {End}
				Send, +{Enter}
				Sleep, 32
				Send, ^v
				Sleep, 32
				Send, {Backspace}
			}
		}
	}
	hasScrolled = 1
	return

XButton1 & LButton::
	backToggle = 1
	if (gear = 0) {
		; duplicate multi-carat mode
		; uses ALT-click for VScode, CTRL-click otherwise
		if WinActive("ahk_exe Code.exe") {
			Send, !{LButton}
		} else {
			Send, ^{LButton}
		}
	} else {
		; clipboard history
		Send, {F24 Up}
		Send, #v
		Send, {F24 Down}
	}
	return

XButton1 & RButton::
	Critical
	backToggle = 1
	Send, {Shift Down}
	return

; Placeholder if hasScrolled not detected, otherwise exists hasScrolled
XButton1 & RButton Up::
	Critical
	Send, {Shift Up}
	if (hasScrolled) {
		hasScrolled = 0
	} else {
		Send, +{LButton}
	}
	return

XButton1 & MButton::
	backToggle = 1
	if (gear = 0) {
		Send, ^s
	} else {
		MsgBox "Placeholder"
	}
	return

XButton1 & F16::
	backToggle = 1
	Send, ^e
	return

XButton1 & F22::
	backToggle = 1
	if (gear = 0) {
		Send, ^z
		KeyWait F22,T0.3125
		If ErrorLevel
			While GetKeyState("F22","P"){
				Send ^z
				Sleep 128
			}
	} else {
		if WinActive("ahk_exe floorp.exe") {
			Send ^1
		}
	}
	return

XButton1 & F23::
	backToggle = 1
	if (gear = 0) {
		Send, ^y
		KeyWait F23,T0.3125
		If ErrorLevel
			While GetKeyState("F23","P"){
				Send ^y
				Sleep 128
			}
	} else {
		if WinActive("ahk_exe floorp.exe") {
			Send ^9
		}
	}
	return

; different functionality then doing XButton1 Up, although this is a prefix key,
; it has been tildafied, and thus is custom coded.
XButton1::
	return

XButton1 Up::
	Critical
	hasScrolled = 0
	if (backToggle) {
		if (gear) {
			; MsgBox ,,, "Back is released - gear 0", 1
			; CURIOUS
		}
		backToggle = 0
	} else {
		Send, {XButton1}
	}
	return

; Everything mode
XButton2 & PgUp::
	if (gear = 2) {
		Send, !{WheelUp}
	} else {
		Send, +{WheelUp}
	}
	return

; Everything mode
XButton2 & PgDn::
	if (gear = 2) {
		Send, !{WheelDown}
	} else {
		Send, +{WheelDown}
	}
	return
	
XButton2 & F17::
	Send, ^+{PgUp}
	KeyWait LButton,T0.3125
	If ErrorLevel
	While GetKeyState("LButton","P"){
		Send ^+{PgUp}
		Sleep 48
	}
	return

XButton2 & F18::
	Send, ^+{PgDn}
	KeyWait RButton,T0.3125
	If ErrorLevel
	While GetKeyState("RButton","P"){
		Send ^+{PgDn}
		Sleep 48
	}
	return

; same functionality as doing XButton2 Up, because this is a prefix key
XButton2::
	Critical
	if (gear = 0) {
		Send, {XButton2}
	} else {
		gear = 0
	}
	return

XButton2 & F19::
	Critical
	gear = 2
	return

F19 & XButton2::
	; gear = 3
	return

XButton2 & F19 Up::
	Critical
	gear = 0
	return