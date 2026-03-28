# Use 'Critical' flags for specific contexts

- Status: Accepted

## Context and Problem Statement

- Due to race conditions, use Critical to lock down critical sections in hotkeys, no need to put it at the start of the hotkey, and end it as soon as possible to free up thread flexbility.
- Usually, do typical use of requiring it only for sections where important public variables are being modified (semaphores, indicators, etc) and evaluated to determine action
- Also use in sections that seem important and require the "full attention" of one thread without context switching, for example, browser left tab and right tab, and Dasonian arrowkey navigation
- The above is a nonstandard usecase, and currently not sure if this is strictly desirable

## Decision Drivers

- I want atomic safety
- Hotkeys were race-conditioning with one another (still unsure exactly how)
- Some sections felt like they needed higher protection and dedication (no context switching)

## How to Check

- Ensure sections which modify global variables or read global variables are Critical for each keybind, though when the critical starts and ends is irrelevant so long as the variables are contained within the safe section
- Ensure sections which encode for discrete, instantaneous tasks that alter the viewport drastically or imply a critical control action (arrowkeys and similar) are also marked as critical, with the same stipulation as above

## Considered Options

- Removing nonstandard usecase

## Decision Outcome

- Keeping nonstandard for now because it doesn't seem to hurt the performance

### Positive Consequences <!-- optional -->

- Atomic safety

### Negative Consequences <!-- optional -->

- None, but also how AHK does multi-threading is pseudo and confusing
