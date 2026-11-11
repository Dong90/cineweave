## Summary

Adds the Player CI contract.

Refs #14

## GitFlow

- Source: `feature/CW-14-player-ci-guardrails`
- Target: `develop`
- Type: Feature

## Evidence

- **Before:** no required checks were reported.
  **After:** official-player and fork-player both pass.

## Impact Check

- Offline behavior remains unchanged.

## Merge Danger

**Door:** Two-way

The workflow can be reverted without migrating product data.

**Blast Radius:** Development workflow

