Optional hands-on exercises, one file per milestone: `MN.md`.

**These never gate anything.** `plan.md`'s "done when" is the only gate, and it lives in
`docs/walkthroughs/MN.md`. Skip every exercise here and the milestone still closes. Do them
where you want the understanding to go deeper, and not otherwise.

They are written **after** the implementation lands, because they need real files and a
running cluster to point at. `/m-start` never writes them. A second batch may be appended at
`/m-close` under `## From the grill`, but only where the grill found a boundary — a clean
grill appends nothing.

## What an exercise is

A **goal** and at most two collapsed hints. Not a script. You are meant to work out the
commands, because deciding what to look at is most of the skill — a checklist you can follow
without thinking teaches nothing.

Each one states how to undo it. `make reset` is always the backstop.

There is no answer key, deliberately. The goal is phrased as something you should be able to
*explain* afterwards, so you can tell whether you got there. If you can't, ask — that
conversation is the point.

## What an exercise is not

- Not a prediction. `docs/predictions/` existed once and was deleted: it asked for exact
  strings from experiments needing a cluster that didn't exist yet. These run against
  something already built and running.
- Not a chore that restates the concept note. If doing it couldn't surprise you, it shouldn't
  be here — say so and it gets cut.
- Not homework. One or two per topic, each far smaller than the milestone itself.

## From M4 onward

`plan.md` makes git the only path to the cluster from M4. Exercises follow that rule, so from
M4 each one is either **read-only** (`describe`, `logs`, `get -o yaml`, PromQL, k9s as a
viewer) or **commit and revert** — change it in git, let Argo sync, watch, then `git revert`.
Watching the reconciliation happen is usually the better exercise anyway.

Before M4, an imperative `kubectl` exercise is fine, and says so.
