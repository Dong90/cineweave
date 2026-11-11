## Summary

Adds the Player CI contract.

Refs #14

## GitFlow

- Source: `feature/CW-14-player-ci-guardrails`
- Target: `develop`
- Type: Feature

## Evidence

- **Before:** <!-- failing behavior, test, or screenshot -->
  **After:** <!-- passing behavior, test, or screenshot -->

## Impact Check

- [x] Automated tests, builds, and static checks pass.
- [x] Schema, save, and release compatibility were checked; migration and rollback are documented when needed.
- [x] UI loading, error, cancellation, offline, and input states were checked when applicable.
- [x] AI/network changes cover budget, safety, privacy, persistence, and offline fallback when applicable.
- [x] External or generated asset sources and rights are recorded when applicable.
- [x] README, ROADMAP, GLOSSARY, ADRs, and CHANGELOG were updated when needed.

## Merge Danger

**Door:** Two-way

The workflow can be reverted without migrating product data.

**Blast Radius:** Development workflow
