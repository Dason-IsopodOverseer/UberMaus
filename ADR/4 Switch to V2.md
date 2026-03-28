# Switching to V2, but keeping legacy V1 code for compatibility

- Status: Accepted

* Date: 2026-02-28 <!-- optional -->

## Context and Problem Statement

Upgrading to V2 for better performance and much more consistent language conventions!
Spent an entire night converting everything over.
Keeping V1 still for compatibility, though now several features are outdated!
V2 scripts going henceforth should declare themselves as such

## Decision Drivers

- V1 was starting to wear down on me with how badly outdated it was
- Hoping for better performance and less chance of keybind randomly not registering, or hotkey being unclearly specified

## How to Check

- Check for the V2 declaration at the start of script for modern scripts
- Scripts marked as "legacy" or "old" and such are in V2

## Considered Options

- N/A

## Decision Outcome

- N/A

### Positive Consequences <!-- optional -->

- Modernism

### Negative Consequences <!-- optional -->

- Compatibility reduced, legacy version no longer supported means lack of support for newest features on machines that run V1 only
