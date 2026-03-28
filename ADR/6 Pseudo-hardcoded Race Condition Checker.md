# Pseudo-hardcoded Race Condition Checker

- Status: Accepted, addendum to ADR 3

## Context and Problem Statement

- Race conditions STILL occur with modifier keys held down, most egregiously with right shift during Dasonian arrowkey navigation
- This is apparently to do with keyboard hardware and keyhook limitations. Sometimes the keyhook just fails unexpectedly when the key itself has been released
- Noticed that this occurs more often with heavy CPU load, implying many system calls leads to keyhooks being dropped
- Therefore, there must be a mechanism to catch these as a failsafe for modifier keys for now, even inside critical sections

## Decision Drivers

- STOP failing to release modifier keys under heavy use

## How to Check

- Check that there exists a race condition checker function
- This must be called whenever a modifier key is physically (not logically) pressed, and it can continuously reinput the release of that key on an exponential decay timer, with a maximum limit of ideally no more than 2 minutes

## Considered Options

- N/A

## Decision Outcome

- N/A

### Positive Consequences <!-- optional -->

- Uncertain, but it seems to have reduced the chance of modifier keys sticking on release

### Negative Consequences <!-- optional -->

- Timer of repeat checks uses CPU resources unnecessarily
