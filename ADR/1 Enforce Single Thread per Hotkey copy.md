# Enforcing AHK to assign maximum one thread per keybind

- Status: Accepted

## Context and Problem Statement

Concurrent thread logic is confusing. Behavior is not consistent when multiple threads can execute the same hotkey or function in parallel, potentially causing race conditions

## Decision Drivers

- I want consistency, easily debuggable behaviors

## How to Check

- Ensure script has a configuration variable limiting threads per hotkey

## Considered Options

- N/A

## Decision Outcome

- N/A

### Positive Consequences <!-- optional -->

- Consistency

### Negative Consequences <!-- optional -->

- Less responsive, parallel actions disabled
