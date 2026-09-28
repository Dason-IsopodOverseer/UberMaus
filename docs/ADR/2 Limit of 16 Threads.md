# Enforcing AHK to use up to 16 simultaneous threads

- Status: Accepted

## Context and Problem Statement

- Limiting to one thread for the entire script is unwise as it means keywait or wait events other keybinds. We should have a few sacrificial threads for when a keybind needs to wait or otherwise compute something heavy.
- Note that sleep is cross-thread
- The more threads the better, but there should be an upper ceiling to prevent massive memory usage from retriggers of keywait or wait keybinds

## Decision Drivers

- I want sacrificial threads without clogging up threadcount to large numbers
- 12 or 16 just work, chose the larger one arbitrarily

## How to Check

- Ensure script has a configuration variable limiting threads

## Considered Options

- 8 threads, in earlyer versions
- 12 threads, for a while
- 16 threads, now

## Decision Outcome

- 16 threads

### Positive Consequences <!-- optional -->

- Sacrificial threads so no stalling
- Prevents generating numberous threads with hotkey retriggers

### Negative Consequences <!-- optional -->

- None, but the ideal number of threads needs to be configured per system
