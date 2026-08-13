---
description: Close milestone N — confirm the gate, grill, add exercises, log what broke, commit
argument-hint: <milestone number, e.g. 3>
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

Close out milestone **M$1**.

## 1. Confirm the gate was actually run

Ask whether they ran M$1's "done when" themselves and what they observed. It's restated in
plain English at the end of `docs/walkthroughs/M$1.md`.

Do not run it for them. Do not accept "it should work" — if they haven't run it, stop here and
send them to do it. That check is the milestone.

## 2. Check the walkthrough still matches reality

Read `docs/walkthroughs/M$1.md` against what was actually built. Implementation always drifts
from the plan a little; the walkthrough is what the human will re-read in six months, so it
has to describe what exists.

Where they diverge, ask what changed and why, then update the walkthrough in this commit.
If a reference in it has gone stale, fix the link and its `checked:` date.

## 3. Grill them

Use the **actual files in this repo** as the material — the real manifests, migrations, and
queries, not the abstract topic. In priority order:

1. **Fields they can't justify.** Pick fields at random and ask what breaks if it's removed
   or doubled. For M2 the gate is literally "you can open every YAML file and explain what
   every single field does" — hold that bar.
2. **The `TODO(learn):` markers.** Each is a decision with a defensible alternative, named in
   advance in the walkthrough. Make them argue *for* the alternative, then say why it lost.
3. **The traps.** Check they understand the mechanism, not the rule. "Don't label with
   `job_id`" is a rule; "each distinct label value is a separate time series and Prometheus
   holds every active series in memory" is the model.
4. **One level deeper than the milestone required.** Find the edge of what they know and stop
   there. The goal is to locate the boundary, not to humiliate.

Do not accept vague answers. "It handles the ordering" is not an answer — ask what *does* the
ordering, and what happens when it doesn't.

Any term that comes up in the grill and isn't in `docs/lexicon.md` gets added.

## 4. Turn what the grill exposed into exercises

Where the grill found a boundary — an answer that was wrong, thin, or "I don't know" — and
there is a hands-on experiment that would settle it, append it to `docs/exercises/M$1.md`
under a `## From the grill` heading.

This is remediation, not coverage. **If they answered everything cleanly, append nothing** and
say so. Padding this section is how the file becomes wallpaper.

Same rules as the rest of that file, from `CLAUDE.md`: a goal and at most two collapsed hints,
no command list, no expected output, an undo, and small. Explaining the answer during the
grill does not remove the value of them doing it — the exercise is where it sticks.

If M$1 has no exercises file because nothing in it was worth an experiment, create one now
only if the grill produced something. Never for the sake of the heading.

## 5. Log it

Append a dated entry to `docs/LOG.md` (newest at the bottom):

```markdown
## YYYY-MM-DD — M$1: <milestone title>

**Built:** <what exists now, two or three lines>

**What broke, and what actually caused it:** <the real cause, not the symptom — including
anything that failed on the way and got fixed>

**What surprised me:** <where the behaviour didn't match the mental model, including
anything the grill exposed>

**Worth remembering:** <commands, PromQL, flags, error strings they had to look up>
```

**What broke** and **What surprised me** are the point of this file. If both are empty, say so
plainly — either the milestone was too easy or it was followed without being understood. Don't
pad them.

If they did any exercises and one came out differently than they expected, that belongs in
**What surprised me** — it is the same kind of evidence as a failed gate, and it is the only
place the exercises leave a trace.

## 6. Commit

Stage the milestone's work and commit. Subject names the milestone and the gate it passed:

```
M$1: <what now works, phrased as the gate>
```

No AI attribution, no `Co-Authored-By` trailer, no generated-with footer.

Then tick M$1 in `todo.md`, report which milestone is next, and stop. Do not start it.
