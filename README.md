# trust-hub-mine

Roblox Luau modules for a game-owned UI and visual target marker.

## Roblox Studio setup

1. In **ReplicatedStorage**, create a folder named `ModMenu`.
2. Add the repository's `ui` and `loader` files there as **ModuleScripts**.
3. Create a folder named `features` inside `ModMenu`; add `features/esp` there as a **ModuleScript** named `esp`.
4. In **StarterPlayer > StarterPlayerScripts**, add a **LocalScript** with:

```lua
local modMenu = game:GetService("ReplicatedStorage"):WaitForChild("ModMenu")
require(modMenu:WaitForChild("loader")).Start()
```

Press **F4** to open or close the animated menu. The Visuals tab has a toggle for the target marker. It only draws a label for a target your own game explicitly passes to the feature; it does not find targets, attack, or change gameplay.

From your game's own client logic, set or clear the displayed target like this:

```lua
local features = game:GetService("ReplicatedStorage"):WaitForChild("ModMenu"):WaitForChild("features")
local TargetESP = require(features:WaitForChild("esp"))

TargetESP.SetTarget(workspace:WaitForChild("Dummy")) -- show marker
TargetESP.ClearTarget() -- clear marker
```

Combat and Movement are placeholder tabs for future game-owned, server-validated features. The target marker is client-side visual UI only.
