# Repository instructions

Before changing code, configuration, content schemas, or release artifacts, inspect the current Git branch and working tree. Read [CONTRIBUTING.md](./CONTRIBUTING.md) whenever creating branches, committing, merging, tagging, releasing, or hotfixing.

Work on a `feature/*` or `bugfix/*` branch created from `develop`. The initial documentation baseline on the unborn repository is the bootstrap exception; after that baseline, `main` and `develop` only receive changes through the GitFlow paths defined in `CONTRIBUTING.md`.

When adding, inserting, renumbering, freezing, or releasing a milestone, read [docs/ROADMAP.md](./docs/ROADMAP.md) and update its change record. When introducing or changing a domain concept, read and update [GLOSSARY.md](./GLOSSARY.md).

Before handing off an implementation, run the relevant tests and checks, account for migrations and offline fallback, and report the current branch plus uncommitted changes. Create commits, tags, pushes, releases, and remote branch changes only when the user explicitly requests them.
