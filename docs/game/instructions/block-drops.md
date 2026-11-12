# Block drops

Drops of blocks are located in `workspace.TargetFilter`. The folder contains `{BlockName}_Drop`
models. Inside a model is a `Part` named `{BlockName}` (or use `:IsA("BasePart")`), a
`DropScript`, and a `StringValue` named `Player` under that script. `Player.Value` is the player
who broke the block.

Bot rule: collect only drops where `Player.Value` matches `LocalPlayer`, keep them in a cache,
and do not mine until the cache is empty.
