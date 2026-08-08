---
description: Open milestone N — write concept notes only, then prompt for predictions
argument-hint: <milestone number, e.g. 3>
allowed-tools: Read, Write, Glob, Grep, WebFetch, WebSearch
---

Open milestone **M$1** of this project.

Read the M$1 section of `plan.md`, plus the "Traps worth walking into deliberately" section
at the bottom.

## What to produce

Write concept notes to `docs/concepts/M$1-<topic>.md` — one file per distinct topic if the
milestone spans several (e.g. M3 has "why entrypoint migrations race" and "Job semantics" as
separate concerns). Each note covers:

1. **The mental model.** What is this component actually doing, in terms of the loop it runs
   or the invariant it maintains. Not a feature list.
2. **Why the design is this way.** The failure mode that motivated it. This is the part that
   makes it stick.
3. **The tradeoffs this milestone names.** `plan.md`'s "Learn:" bullets for M$1 are the
   syllabus — cover each one, and be honest where the answer is "it depends."
4. **The traps that apply here**, from plan.md's trap list. Say what the human will observe
   when they hit it, not just that it exists.
5. **Links to the primary docs.** Don't restate them — plan.md line 246 notes these projects
   have unusually good docs. Point at the specific page.

Aim for something readable in 10–15 minutes. Depth over breadth; skip what they'll absorb
from the implementation diff anyway.

## Hard constraints

- **Write no code and no config.** No Makefile, no YAML, no Python, no Dockerfile, not even
  as an illustrative snippet longer than a few lines. If you catch yourself writing the
  implementation, stop — that's step 3 of the loop, a separate session in plan mode.
- **Do not write `docs/predictions/M$1.md`.** Create it only if absent, containing the
  prompts below and nothing else — no answers, no hints, no examples of a good answer.

## Then stop

Create `docs/predictions/M$1.md` with a dated heading and 4–6 prediction prompts specific to
M$1. Good prompts are falsifiable and force a commitment:

- name the exact status string, error, or exit code that will appear
- name what will *still be working* after the failure
- name a number (seconds, replica count, retry attempts) and a range
- ask which of two plausible mechanisms is the one that actually fires

Avoid anything answerable with "it will work" or "it depends."

Print the prompts in your response too, then end your turn. Do not offer to implement.
The human fills in predictions before the implementation session starts.
