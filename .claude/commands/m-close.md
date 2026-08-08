---
description: Close milestone N — grill, log prediction deltas, commit
argument-hint: <milestone number, e.g. 3>
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Skill
---

Close out milestone **M$1**.

## 1. Confirm the gate was actually run

Ask whether they ran M$1's "done when" themselves and what they observed. Do not run it for
them, and do not accept "it should work" — if they haven't run it, stop here and send them
to do it. This is the whole point of the gate.

## 2. Grill them

Invoke the `grill-me` skill, scoped to M$1. Use the **actual files produced** as the
material — walk the real manifests, migrations, and queries in this repo, not the abstract
topic. Priorities, in order:

1. **Fields they can't justify.** For M2 especially, plan.md's gate is literally "you can
   open every YAML file and explain what every single field does." Pick fields at random and
   ask what breaks if it's removed or doubled.
2. **The `TODO(learn):` markers.** Each one is a decision with a defensible alternative. Make
   them argue for the alternative, then say why it lost.
3. **The traps.** If M$1 has traps in plan.md's list, check they understand the mechanism,
   not just the rule. "Don't label with job_id" is a rule; "each distinct label value creates
   a separate time series, and Prometheus holds every active series in memory" is the model.
4. **One level deeper than the milestone required.** Find the edge of what they know and stop
   there — the goal is to locate the boundary, not to humiliate.

Do not accept vague answers. "It handles the ordering" is not an answer; ask what *does* the
ordering and what happens when it doesn't.

## 3. Log it

Append a dated entry to `docs/LOG.md` (newest at the bottom) from `docs/predictions/M$1.md`
and the session's actual outcome:

```markdown
## YYYY-MM-DD — M$1: <milestone title>

**Predicted:** <their predictions, condensed>

**Actually happened:** <what they observed running the gate>

**What I had wrong:** <every delta between the two, plus anything the grill exposed>

**Worth remembering:** <commands, PromQL, flags they had to look up>
```

The **What I had wrong** section is the most valuable part of this file. If it's empty,
say so plainly — either the predictions were too vague to be falsified, or they were
written after seeing the implementation. Both are worth naming.

## 4. Commit

Stage the milestone's work and commit. Subject names the milestone and the gate it passed:

```
M$1: <what now works, phrased as the gate>
```

No AI attribution, no `Co-Authored-By` trailer, no generated-with footer.

Then report which milestone is next and stop. Do not start it.
