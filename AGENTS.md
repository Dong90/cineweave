# Repository instructions

Before changing code, configuration, content schemas, or release artifacts, inspect the current Git branch and working tree. Read [CONTRIBUTING.md](./CONTRIBUTING.md) whenever creating branches, committing, merging, tagging, releasing, or hotfixing.

Work on a `feature/*` or `bugfix/*` branch created from `develop`. A `research/*` branch is the Wayfinder-only exception for disposable evidence: it never opens a PR or merges into a product branch. The initial documentation baseline on the unborn repository is the bootstrap exception; after that baseline, `main` and `develop` only receive changes through the GitFlow paths defined in `CONTRIBUTING.md`.

When adding, inserting, renumbering, freezing, or releasing a milestone, read [docs/ROADMAP.md](./docs/ROADMAP.md) and update its change record. When introducing or changing a domain concept, read and update [GLOSSARY.md](./GLOSSARY.md).

Before handing off an implementation, run the relevant tests and checks, account for migrations and offline fallback, and report the current branch plus uncommitted changes. Create commits, tags, pushes, releases, and remote branch changes only when the user explicitly requests them. Invoking `/wayfinder` is narrow authorization to commit and push only the `research/*` context branches required by its newly charted Research tickets; it never authorizes a PR, merge, tag, or release.

## Agent skills

### Issue tracker

Track specs and implementation work in `Dong90/cineweave` GitHub Issues. Read `docs/agents/issue-tracker.md` before creating, reading, linking, or closing issues.

### Triage labels

Use the five canonical workflow labels for incoming issues and agent-ready work. Read `docs/agents/triage-labels.md` before triaging or changing workflow state.

### Domain docs

This is a single-context repository: use the root `GLOSSARY.md` and relevant ADRs under `docs/adr/`. Read `docs/agents/domain.md` before exploring or naming domain concepts.

### Development workflow

For feature, bug, architecture, review, PR, or release work, follow `docs/agents/development-workflow.md`; it defines the fixed skill sequence and points to `CONTRIBUTING.md` for GitFlow mechanics.
