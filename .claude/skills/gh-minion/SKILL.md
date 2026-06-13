---
name: gh-minion
description: Reads a GitHub issue, implements the feature on a new branch, updates CHANGELOG.md, opens a PR, and self-reviews it as a senior engineer. Invoke as `/gh-minion <issue-number>` (e.g. `/gh-minion 42`).
---

# gh-minion

End-to-end implementation of a GitHub issue: fetch ticket → branch → implement → changelog → bump build → PR → senior-engineer review.

## Invocation

```
/gh-minion <issue-number>
```

If the user invokes the skill with no argument, ask them which issue number to work on before proceeding.

## Workflow

Execute these steps in order. Do not skip steps. Surface progress to the user with one-sentence updates between phases.

### 1. Read the ticket

Run the following in parallel:
- `gh issue view <num> --json number,title,body,labels,state,author,url`
- `git status` (to confirm a clean working tree)
- `git branch --show-current`

If the working tree is dirty, **stop** and ask the user how to proceed (stash, commit, or abandon). Do not overwrite their work.

If the current branch is not `main`, ask the user whether to branch off `main` or off the current branch before continuing.

Read the issue body carefully. Identify:
- **What** is being requested (feature, fix, removal)
- **Acceptance criteria** if listed
- **Affected areas** of the codebase (mentioned files, screens, modules)

If the ticket is ambiguous or missing key details, ask the user a focused clarifying question before writing code. Do not guess at scope.

### 2. Classify the change

Pick exactly one CHANGELOG category based on the ticket:
- **ADDED** — a new feature, screen, capability, or surface
- **CHANGED** — a bug fix or a behavior/UX change to existing functionality
- **DELETED** — removing a feature, screen, or capability

When in doubt between ADDED and CHANGED, ask the user.

### 3. Create the branch

Pick the branch prefix from the classification:
- ADDED → `feature/<slug>`
- CHANGED → `fix/<slug>`
- DELETED → `chore/remove-<slug>`

The `<slug>` is a short kebab-case summary of the ticket title (3–6 words, lowercase, no punctuation). Example: issue "Add dark mode toggle to Settings" → `feature/add-dark-mode-toggle`.

Make sure local `main` is up to date, then create and check out the branch:

```bash
git fetch origin main
git checkout main
git pull --ff-only origin main
git checkout -b <branch-name>
```

If `git pull` is not fast-forward, stop and ask the user how to reconcile.

### 4. Implement the feature

Follow the project's CLAUDE.md conventions strictly. For this iOS project that means:
- Use `AppColors.*` and `AppTypography.*` design tokens — never inline colors or fonts.
- Use `MerchantUtils.normalizedCategory(for:)` when handling categories.
- Use `CurrencyUtils.parseCurrencyAndAmount(from:)` for amount parsing.
- Use `AnalyticsTracker` (never `Analytics.logEvent` directly) for any new events.
- Add `#Preview` blocks with `.modelContainer(ModelContainer.createMockContainer())` for new SwiftUI views.
- Keep dark-mode-only assumption intact.

Do **not** run `xcodebuild` to verify — the user builds in Xcode themselves (see auto-memory `feedback_skip_build`).

Use TaskCreate to plan sub-steps for non-trivial implementations and mark each task complete as it lands.

### 5. Update CHANGELOG.md

Edit `CHANGELOG.md` at the repo root. The file uses a placeholder line at the top:

```
## XX.XX.XX - 20XX-XX-XX
```

Insert a new bullet directly **under that placeholder** (do not change the placeholder itself — the user fills in the version/date at release time). Format:

```
- [ADDED] - <concise one-line description>
- [CHANGED] - <concise one-line description>
- [DELETED] - <concise one-line description>
```

Match the tone and length of existing entries: short, user-facing, present-tense, no trailing period unless existing entries use one. Reference the issue only if it adds value (usually not).

If a bullet from the current change already exists under the placeholder, do not duplicate it.

### 6. Bump the build number

Always increment the build number so every PR produces an installable build. Bump `CURRENT_PROJECT_VERSION` by 1 across **all** build configurations in `CardPulse.xcodeproj/project.pbxproj` (it appears once per config for the app and widget targets — currently 4 occurrences). Do **not** touch `MARKETING_VERSION` — that is bumped only at release time via the `/release` skill.

```bash
# Read the current value, then replace every occurrence with current+1.
grep -n "CURRENT_PROJECT_VERSION" CardPulse.xcodeproj/project.pbxproj
sed -i '' 's/CURRENT_PROJECT_VERSION = <current>;/CURRENT_PROJECT_VERSION = <current+1>;/g' CardPulse.xcodeproj/project.pbxproj
```

After editing, confirm the new value appears the expected number of times and the file still parses:

```bash
grep -c "CURRENT_PROJECT_VERSION = <current+1>;" CardPulse.xcodeproj/project.pbxproj
plutil -lint CardPulse.xcodeproj/project.pbxproj
```

All occurrences must share the same value — if they were already inconsistent, stop and tell the user rather than guessing.

### 7. Commit

Stage only the files touched by this change (avoid `git add -A`) — this includes `CardPulse.xcodeproj/project.pbxproj` from the build-number bump. Create a single commit with a message that:
- Has a short subject line (under 70 chars)
- References the issue in the body: `Closes #<num>`
- Ends with the standard Co-Authored-By trailer

Example:

```
git commit -m "$(cat <<'EOF'
Add dark mode toggle to Settings

Closes #42

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### 8. Push and open the PR

```bash
git push -u origin <branch-name>
```

Create the PR with `gh pr create`. The PR body should:
- Summarize the change in 1–3 bullets
- Include `Closes #<num>` so the issue auto-closes on merge
- Include a short Test plan checklist

```bash
gh pr create --title "<short title>" --body "$(cat <<'EOF'
## Summary
- <bullet>
- <bullet>

Closes #<num>

## Test plan
- [ ] <step>
- [ ] <step>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Note the PR URL — you'll return it after the review in step 9.

### 9. Self-review the PR as a senior engineer

Once the PR is open, change hats: review your own diff as critically as a senior engineer who *didn't* write it would in a code review. Review the **pushed** diff so you catch what actually landed, not your memory of the change:

```bash
gh pr diff <num>
```

Optionally run `/code-review high` for a second machine pass, but still do the manual review below — the checklist is project-aware in ways a generic pass is not. Read the entire diff and evaluate against each lens:

**Correctness & edge cases**
- Empty / nil / zero inputs, first launch, missing or not-yet-loaded data (e.g. FX rates absent), very large values.
- Off-by-one and boundary conditions — date/billing-cycle edges, rounding, currency conversion.
- Anything that silently drops or double-counts data (e.g. converting an amount twice across layers).

**Build & integration risk** — you cannot run `xcodebuild`, so reason about it explicitly:
- **Target membership.** If a file gains a new dependency (a new `import`, or a reference to a type like `CurrencyUtils`), confirm *every* target that compiles that file also compiles the dependency. The widget extension only includes a subset of `CardPulse/` — check the synchronized-group `membershipExceptions` in `CardPulse.xcodeproj/project.pbxproj`. App-only utilities must not leak into a file the widget target compiles.
- **Schema changes.** A new or changed SwiftData `@Model` field needs a migration stage in `CardPulseMigrationPlan` and, if seeded, a `CategorySeeding`-style safety seed.

**SwiftUI reactivity**
- A view only re-renders for a `UserDefaults`/`@AppStorage`-derived value (exchange rates, default currency, etc.) if it actually observes that key. If a parent computes state (status, counts, filters) from the same source as a child, the parent needs the same observation or it goes stale while the child updates.

**Conventions (CLAUDE.md)**
- `AppColors`/`AppTypography` tokens only — no inline colors/fonts. `MerchantUtils.normalizedCategory(for:)` for categories. `CurrencyUtils` for currency parsing/symbols. `AnalyticsTracker` for events (never `Analytics.logEvent`). New SwiftUI views have a `#Preview` using `ModelContainer.createMockContainer()`. Dark-mode-only intact.

**Scope & hygiene**
- The diff touches only files relevant to the ticket — no stray/unrelated files, leftover debug prints, commented-out code, or committed secrets.
- The CHANGELOG bullet is present, correctly categorized, and accurate.

**Security**
- No hardcoded secrets or keys; no logging of sensitive data; external/parsed input is validated.

Then act on what you find:
- **Clear bug or convention violation** → fix it and push a *separate* follow-up commit on the same branch (subject like `Address self-review: <what>`). The PR updates automatically. Do **not** amend or force-push the already-pushed commits.
- **Judgment call, ambiguity, or a larger redesign** → don't silently change scope; describe it to the user and ask how to proceed.
- **Nothing actionable** → say so explicitly rather than inventing nitpicks.

As the final output, give the user a review summary grouped into **Blockers**, **Minor / non-blocking**, and **Verified OK**, followed by the PR URL. If you pushed review-fix commits, note them.

## Guardrails

- Never force-push, never `--no-verify`, never amend pushed commits.
- Never push to `main` directly.
- If `gh` is not authenticated (`gh auth status` fails), stop and tell the user to run `gh auth login` themselves via `! gh auth login`.
- If the issue is already closed, ask the user whether to proceed anyway.
- If a PR for this issue already exists, link it and ask the user whether to continue on the existing branch or open a new one.
