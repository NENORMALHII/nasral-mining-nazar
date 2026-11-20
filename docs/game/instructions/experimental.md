# Experimental features

Opt-in features on the `Experimental` UI page. Most are saved
(`experimentalMultiMine`); they are not part of the normal mining loop and the
server may refuse them.

## Mine 5 blocks (3x3)

`Experimental.mineMany` is used from Farm only for the ore target (the block
`Ores.nearest` selected). The down-dig and planner steps always use the
single-block path.

It claims the target plus its four horizontal neighbours — a plus inside the
3x3 cell layer, 5 blocks:

```
    .
  . X .
    .
```

Per batch:

1. `BlockEvent(block.Name, { dug = true })` for every valid block. A block is
   included when `Mining.why` returns nil and it is inside `Mining.reach()`.
2. Wait `max(mineTime of the batch) * (1 + penalty)` + the normal safety margin
   (one ping sample, one jitter).
3. `BlockMinedEvent({ blockName })` for every block still present.
4. Poll the removal once per frame, up to `mineRejectGrace = 0.6` s.
5. Any block still present gets `BlockEvent(name, { dug = false })`.

Counting: each removed block calls `Mining.confirm()`, which clears the reject
streak and the proportional penalty. A partial batch (some blocks refused, at
least one mined) is logged but is **not** counted as a rejection — the server
refused concurrent claims, not the timing. A batch where nothing was mined
counts as one rejection (`Mining.punish()` + `Mining.rejects`),
and at `maxRejects` the normal surface reset runs. The batch returns true when at
least one block was mined; otherwise Farm calls `Ores.ignore` on the target (5 s).

The server tracks `Dug` per block, so concurrent claims can be accepted or
rejected independently; a partial result is expected and is not an error in the
experimental path.
