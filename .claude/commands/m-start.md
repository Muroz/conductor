---
description: Open milestone N — write the walkthrough, concept notes, and lexicon entries. No code.
argument-hint: <milestone number, e.g. 3>
allowed-tools: Read, Write, Edit, Glob, Grep, WebFetch, WebSearch, Bash(curl:*)
---

Open milestone **M$1**.

Read the M$1 section of `plan.md`, the "Traps worth walking into deliberately" section at the
bottom, `docs/lexicon.md`, and the walkthroughs for earlier milestones so you know what
vocabulary the human already has.

You are writing the material the human reads **before** you implement M$1. They will read
your diff against it. Three files, no code.

---

## 1. `docs/walkthroughs/M$1.md` — write this first

The map of the work you are about to do. Not a tutorial they execute — you implement, they
review. Its job is to make the diff legible before it exists.

Sections, in this order:

### What you'll have when this is done

The deliverable, in plain English, as a table of files and what each one is for. Someone who
has never seen this milestone should be able to read this section alone and know what M$1
produces. No jargon here — this is the section that answers "what am I actually building?"

### What's not in this milestone

The things a reasonable person would expect here and won't get, each with the milestone
number where it *does* arrive. Be specific: "no Dockerfile — that's M1", not "we'll add more
later."

### The order of work

Numbered tasks, in implementation order. Each task gets exactly four things:

1. **What it is** — one plain sentence.
2. **Why it comes here** — what it depends on, or what breaks if you do it later.
3. **Where the reasoning is** — link to the section of the concept note that explains it,
   as `docs/concepts/M$1-<topic>.md#anchor`.
4. **The reference** — the exact page or file, with version and date (see the currency rule).

### The decisions worth arguing with

The 2–3 places you will leave `TODO(learn):` markers — real tradeoffs with a defensible
alternative. Name them here so the human knows where to push back during review. State the
alternative honestly, not as a strawman.

### How you'll know it worked

`plan.md`'s "done when" for M$1, restated in plain English, with the exact commands that
produce the evidence and what a passing result looks like.

**The human runs these. You never do.** Say so in the section.

---

## 2. `docs/concepts/M$1-<topic>.md` — one file per distinct topic

Cover `plan.md`'s "Learn:" bullets for M$1 — those are the syllabus. One file per genuinely
separate concern (M3 has "why entrypoint migrations race" and "Job semantics"; don't merge
them, and don't split one idea into three files).

Each note covers:

1. **The mental model.** What is this thing actually doing — the loop it runs, or the
   invariant it holds. Not a feature list.
2. **Why the design is this way.** The failure mode that motivated it. This is the part that
   makes it stick.
3. **The tradeoffs.** Be honest where the answer is "it depends", and say what it depends on.
4. **The traps from `plan.md` that apply.** Say what the human will *observe* when they hit
   it — the actual symptom — not just that it exists.
5. **References.** Per the currency rule below.

Give sections `##` headings the walkthrough can link to. Aim for 10–15 minutes of reading
across all the notes for one milestone. Depth over breadth.

---

## 3. `docs/lexicon.md` — append, never rewrite

Every term you use for the first time gets a line: the term, one plain sentence, and the
milestone it first appears in. Add the entries for M$1 to the end of the file, under a
`## M$1` heading. Do not restate or edit earlier milestones' entries.

If you write a term in a concept note and it isn't in the lexicon, that's a bug.

---

## The currency rule

**Never cite from memory.** Before any reference appears in what you write, fetch it in this
session and confirm it says what you think it says — the doc page, the release tag, the
manifest, the flag. Tools move faster than training data, and a stale instruction costs the
human an hour of trust.

Every reference carries three things:

```
<URL> — <what's there and why you're pointing at it>
pinned: <version or tag>  ·  checked: YYYY-MM-DD
```

Point at the specific page or section, not a doc-site landing page. If the answer lives in a
file in a repo rather than a docs site, link the file at a tag and say so.

**When upstream recommends something different from what this project does, say so out loud.**
A short block: what they now recommend, what we do instead, and the concrete reason we differ.
Silent divergence is how the human ends up reading a page that contradicts their own repo.

Worked example, for calibration: kind's ingress page now documents `cloud-provider-kind` and
no longer describes installing a third-party controller; this project still uses ingress-nginx
because `cloud-provider-kind` needs a `sudo` process running on the host outside the cluster,
which `make up`/`make down` can't own. That divergence belongs in the note, with both links.

---

## The plain-language rule

The reader knows how to program and does not know Kubernetes. Assume nothing beyond the
previous milestones' notes.

- **Define every term the first time you use it**, in one sentence, inline. Then add it to the
  lexicon.
- **Lead with the plain answer**, then elaborate. Not the other way round.
- **Short sentences.** One idea each. Don't stack three clauses with dashes and semicolons.
- **No flourishes.** Cut "worth being able to draw from memory", "the whole subject of",
  "the interesting trap here". Say the thing.
- **Concrete over clever.** "A Service gives a stable address to a set of pods that keep being
  replaced" beats "a Service is an abstraction over pod lifecycle".

If a sentence needs a term the reader doesn't have yet, define the term or cut the sentence.

---

## Hard constraints

- **No code, no config.** No Makefile, no YAML, no Python, no Dockerfile. Snippets longer than
  a few lines are implementation — that's the next session, in plan mode.
- **One milestone.** Nothing about M$1+1, except in "What's not in this milestone".
- **Don't run the "done when".** Not to check your own reasoning, not partially.
- **Don't write `docs/exercises/M$1.md`.** That comes at step 4 of the loop, once the code
  exists — before then there are no real files or running cluster to point at, which is
  exactly how `docs/predictions/` failed.

## Then stop

Report what you wrote and end your turn. Do not offer to implement — the human reads first,
asks whatever is unclear, and starts the implementation session when they're ready.
