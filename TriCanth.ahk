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

; UI function, gets the current coordinates of the active window, BLACK ON WHITE
; maintains the notification forever until suc
; unlike prior two examples, returns a pointer to this object, for dismissal
PersistentNotification(notifyText, backgroundColor := "White", textColor := "Black", posX := 20, posY := 20) {
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
    MyGui := Gui("+AlwaysOnTop -Border +Owner", "AHKpersistentnotificatoin")
    MyGui.BackColor := backgroundColor ; set background color

    ; Set font (12pt, bold Segoe UI)
    MyGui.SetFont("s12 bold", "Segoe UI")
    MyGui.Add("Text", "c" . textColor, notifyText) ; add text
    ; NoActivate avoids deactivating the currently active window.
    MyGui.Show("NoActivate x" X " y" Y)

    ; Define the dismissal method (acts like a Promise Resolution)
    MyGui.Dismiss := NotifyDismiss

    NotifyDismiss(self) {
        if (self.HasProp("OnDismiss") && self.OnDismiss) {
            self.OnDismiss.Call() ; Trigger resolution callback hook
        }
        self.Destroy()
    }

    return MyGui
}

; helper function to toggle persistent notifications, up to thee pointers
; pass in gears to associate persistent global modifier state toggles
; can pass in up to one lambda function to curry a state-specific result, by default a
TogglePersistentNotification(pointerSelect, nt, bc := "White", tc := "Black", x := 20, y := 20, gearOff := 0, gearOn :=
    0, lambda := (*) => "") {
    ; start an array of static pointers
    static nP := ["", "", ""]
    global gear

    ; arrays are 1-indexed!
    i := pointerSelect + 1

    if (nP[i]) {
        nP[i].Dismiss()
        nP[i] := ""
        gear := gearOff
        return
    }

    nP[i] := PersistentNotification(nt, bc, tc, x, y)

    ; register the dismissal hook with lambda function
    nP[i].OnDismiss := (*) => (nP[i] := "")

    gear := gearOn

    ; wrapper function runner
    if (lambda is Func) {
        lambda()
    }
}

TogglePersistentNotification(1, "ACTIVATED: | TriCanth Typing |", "f1cbb6", "593404", 24, 84, 0, 5)

;; Rocking states correspond to the following:
;;;; 0 = L
;;;; 1 = LR
;;;; 2 = R
;;;; 3 = RL
;;;; 4 = LRL
;;;; 5 = RLR
;;;; -1 = EMPTY STATE

global rockingGear := -1

LButton:: {
    global rockingGear
    if rockingGear == -1 {
        rockingGear := 0
    } else if rockingGear == 2 {
        rockingGear := 3
    } else {
        rockingGear := 4
    }
}

LButton Up:: {
    global rockingGear
    if not GetKeyState("RButton", "P") and rockingGear >= 0 {
        Send(rockingGear == 0 ? "u" : (rockingGear == 3 ? "j" : ","))
        rockingGear := -1
    }
}

RButton:: {
    global rockingGear
    if rockingGear == -1 {
        rockingGear := 2
    } else if rockingGear == 0 {
        rockingGear := 1
    } else {
        rockingGear := 5
    }
}

RButton Up:: {
    global rockingGear
    if not GetKeyState("LButton", "P") and rockingGear >= 0 {
        Send(rockingGear == 2 ? "i" : (rockingGear == 1 ? "k" : "."))
        rockingGear := -1
    }
}

;;;; 0 = L
;;;; 1 = LR
;;;; 2 = R
;;;; 3 = RL
;;;; 4 = LRL
;;;; 5 = RLR
;;;; -1 = EMPTY STATE

WheelDown:: {
    global rockingGear
    if rockingGear == 0 {
        Send("{Backspace}")
    } else if rockingGear == 1 {
        Send("m")
    } else if rockingGear == 2 {
        Send("o")
    } else if rockingGear == 3 {
        Send("n")
    } else {
        Send("{WheelDown}")
    }
    rockingGear := -1
}

WheelUp:: {
    global rockingGear
    if rockingGear == 0 {
        Send("y")
    } else if rockingGear == 1 {
        Send("l")
    } else if rockingGear == 2 {
        Send("p")
    } else if rockingGear == 3 {
        Send("h")
    } else {
        Send("{WheelUp}")
    }
    rockingGear := -1
}

;; terminate Tricanth
F19 & XButton2 Up:: {
    Critical
    ExitApp()
}
