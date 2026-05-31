---
name: release
description: Prepares an App Store release for a given version number — stamps the CHANGELOG, updates the App Store "What's New" write-up, bumps the build number, and sets the marketing version in the Xcode project. Invoke as `/release <version>` (e.g. `/release 2.5`).
---

# release

Prepare a CardPulse App Store release from a single version number. The skill stamps the
unreleased CHANGELOG section, rewrites the App Store "What's New" copy, increments the build
number, and sets the marketing version across the Xcode project — leaving everything staged
for your review (it does **not** build, commit, tag, or upload).

## Invocation

```
/release <version>
```

`<version>` is the marketing version, e.g. `2.5` or `2.5.1`. If the user invokes the skill
with no argument, ask which version they're releasing before proceeding.

## Inputs & validation

Before touching any file:

1. **Validate the version string.** It must look like `X.Y` or `X.Y.Z` (digits and dots only).
   If it doesn't, stop and ask the user to re-enter.
2. **Determine today's date** in `YYYY-MM-DD` format (use the real current date — it appears in
   your session context). This is the release date.
3. **Sanity-check the version is new.** Grep `MARKETING_VERSION` in
   `CardPulse.xcodeproj/project.pbxproj`. If the current value already equals the requested
   version, stop and ask the user whether to continue (the release may already be prepared).

Run these reads in parallel to gather the current state:
- `CHANGELOG.md` (repo root)
- `appstore/write-up.md`
- `grep -n "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" CardPulse.xcodeproj/project.pbxproj`

## Workflow

Execute the steps in order. Surface a one-sentence progress update between phases.

### 1. Stamp the CHANGELOG

`CHANGELOG.md` keeps unreleased entries under a placeholder heading at the top:

```
# CHANGELOG

## XX.XX.XX - 20XX-XX-XX
- [ADDED] - ...
- [CHANGED] - ...

## 2.4 - 2026-05-16
...
```

Collect the bullet lines that sit **between** the placeholder heading (`## XX.XX.XX - 20XX-XX-XX`)
and the next `##` heading — these are the items being released.

- **If there are no bullets** under the placeholder, there's nothing to release. Stop and tell
  the user; ask whether to proceed anyway.

Rewrite the top of the file so the placeholder is preserved (now empty) for the next cycle, and
a new dated heading carries the released items:

```
# CHANGELOG

## XX.XX.XX - 20XX-XX-XX

## <version> - <today's date>
- [ADDED] - ...
- [CHANGED] - ...

## 2.4 - 2026-05-16
...
```

Use the date format `YYYY-MM-DD` (matches the most recent entry). Do not edit, reword, or
reorder the released bullets — only move them under the new heading. Keep the blank empty
placeholder block so future `/gh-minion`-style edits have a home.

### 2. Update the App Store "What's New" write-up

Edit `appstore/write-up.md`. Under the `# What's New in This Version` header, entries are listed
newest-first as `vX.Y` blocks of plain, user-facing bullets (no `[ADDED]`/`[CHANGED]` tags).

Insert a new block at the **top** of that section (immediately under the header, above the
previous `v...` block):

```
v<version>
- <user-facing line>
- <user-facing line>
- Some performance improvements and bug fixes
```

Derive the bullets from the CHANGELOG items you just released:
- **Drop the category tag** (`[ADDED] - `, `[CHANGED] - `, `[DELETED] - `).
- Keep the wording user-facing and marketing-friendly, matching the tone and length of the
  existing `v2.4` / `v2.2` entries. Light polishing for readability is fine; do not invent
  features that aren't in the CHANGELOG.
- It is customary to end the block with a catch-all line like
  `Some performance improvements and bug fixes` — include it, matching how prior entries read.
- Internal-only or purely technical changes (e.g. migrations, refactors) can be folded into the
  catch-all line rather than listed verbatim.

### 3. Increment the build number

In `CardPulse.xcodeproj/project.pbxproj`, `CURRENT_PROJECT_VERSION` is the build number and
appears once per build configuration (Debug/Release) per target (app + widget) — normally four
identical occurrences kept in sync.

- Read the current value, add **1**, and apply the new value to **every** occurrence so they
  stay in sync (use a replace-all on `CURRENT_PROJECT_VERSION = <old>;` → `... = <new>;`).
- If the occurrences are **not** all identical, stop and surface the mismatch to the user rather
  than guessing — they need to be reconciled by hand.

### 4. Set the marketing version

In the same `project.pbxproj`, `MARKETING_VERSION` is the user-visible version, also appearing
once per configuration per target.

- Replace **every** occurrence of `MARKETING_VERSION = <old>;` with the requested `<version>`
  (replace-all). As with the build number, if the existing values differ, stop and report it.

### 5. Summary

Report back, concisely:
- The CHANGELOG version + date that was stamped, and how many items moved.
- The new `v<version>` "What's New" block (show the bullets).
- Build number `<old> → <new>` and marketing version `<old> → <version>`.

Then remind the user that the changes are **left unstaged for review** — the skill does not
build, commit, tag, or upload. Suggest they review the diff, then archive/upload from Xcode.

## Guardrails

- Edit only these files: `CHANGELOG.md`, `appstore/write-up.md`, and
  `CardPulse.xcodeproj/project.pbxproj`. Nothing else.
- Do **not** run `xcodebuild`, commit, push, tag, or otherwise touch git — the user drives the
  actual release from Xcode (see auto-memory `feedback_skip_build`).
- Never invent release notes. Every "What's New" bullet must trace back to a released CHANGELOG
  item (the generic performance/bug-fix catch-all line is the only exception).
- If the CHANGELOG placeholder heading is missing or malformed, stop and ask the user rather
  than reformatting the file.
- Keep build number and marketing version in sync across all targets/configurations.
