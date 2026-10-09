---
name: build-request-triage
description: "Asked to build a tool: check existing options before coding."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [workflow, scoping, triage]
---

# Build Request Triage

## When to Use

Any request to write a custom app, tool, daemon, or utility — "write me an X", "can you build something that does Y", a gap the user wants filled in C/C++/script. Applies before a line of code is written.

The user corrected this flow twice: they want the plan and the existing-options landscape BEFORE anything gets built.

## Procedure

1. **Survey existing solutions first.** The user's standing preference: check whether an app or service already exists before writing one. Web-search the class of tool (include the current year) and check GitHub before proposing custom code. Present findings honestly, including which tools are maintained vs dying.
2. **State hard platform constraints plainly.** If the requested capability is blocked by a platform (e.g. iOS forbids silent background clipboard access; AirDrop is Apple-only), say so as a wall, not a workaround to be clever around. Distinguish what is genuinely impossible from what merely needs a manual step.
3. **Present the options comparison as a FILE, then a short chat summary.** This user's terminal shows only ~15 lines of a long message at a time — long inline tables/lists are unreadable for them. Write the full comparison (per-option: platforms, sync/network model, cost, verdict) to a scratch .txt file, state the absolute path, and give a compact numbered summary in chat. This satisfied them after inline versions failed.
4. **Ask decision questions via `clarify` before building.** Typical forks: where does it run (VPS / LAN / host-agnostic), which platforms are actually in play (verify — e.g. their "Mac" hardware may run Linux), acceptable UX trade-offs, scope (text vs images, etc.). Batch questions into one clarify call.
5. **Prefer deploying an existing maintained tool over custom code.** Only write the custom implementation if the user explicitly wants the project itself as the goal, or nothing existing covers the requirement.

## Pitfalls

- Do not start compiling/writing code in the same turn as scoping — the user interrupted with "tell me what you want to write before you do it" and "show me your plan in detail and ask me some questions before you do". Plan + questions first, always.
- Do not dump long comparison tables inline in the CLI; the ~15-lines-at-a-time truncation makes them useless. File + short summary is the proven shape.
- Verify the device matrix before designing: users may describe hardware by brand ("Mac") while it runs a different OS — ask which OSes are actually in play.
