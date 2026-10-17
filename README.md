# imguizmo-luau

3D gizmo (translate/rotate/scale) for imgui-luau, with Roblox Camera/CFrame helpers.

Luau port of [ImGuizmo](https://github.com/CedricGuillemet/ImGuizmo) for [imgui-luau](https://git.bug.tools/bug/imgui-luau) ([GitHub](https://github.com/4DBug/imgui-luau)).
Mirrors: [git.bug.tools](https://git.bug.tools/bug/imguizmo-luau) / [GitHub](https://github.com/4DBug/imguizmo-luau).

## Usage

```lua
local G = require(ReplicatedStorage.ImGui)
local ImGuizmo = require(ReplicatedStorage.ImGuizmo)(G)
local Roblox = ImGuizmo.Roblox

-- each frame, after ImGui.NewFrame():
ImGuizmo.BeginFrame()
ImGuizmo.SetDrawlist(G.ImGui.GetForegroundDrawList())
local Camera = workspace.CurrentCamera
ImGuizmo.SetRect(0, 0, Camera.ViewportSize.X, Camera.ViewportSize.Y)

local View = Roblox.ViewFromCamera(Camera)
local Proj = Roblox.ProjFromCamera(Camera)        -- near 0.1, far 1000
local Matrix = Roblox.MatrixFromCFrame(Part.CFrame) -- 16-array, translation at [13..15]
if ImGuizmo.Manipulate(View, Proj, ImGuizmo.OPERATION.TRANSLATE, ImGuizmo.MODE.WORLD, Matrix) then
    Part.CFrame = Roblox.CFrameFromMatrix(Matrix)   -- also returns the basis scale as a Vector3
end
ImGuizmo.ViewManipulate(View, 10, G.ImVec2(Camera.ViewportSize.X - 128, 0), G.ImVec2(128, 128), 0x10101010)
```

Matrices are plain 1-based 16-number arrays in upstream order; `matrix`, `deltaMatrix` and `view` are mutated in place.
Full example: `examples/roblox/main.client.luau`.

## Status

Ported (upstream @105e4fd): math (LookAt/Perspective/Frustum, Decompose/Recompose), context/style/IDs,
`Manipulate` (translate, rotate, scale, universal, snapping, local bounds, deltaMatrix), `DrawGrid`,
`DrawGridCustom`, `DrawGridCustomColor`, `DrawCubes`, `DrawAxes`, `ViewManipulate` (both overloads),
`IsOver` (all overloads), `ComputeMouseRay`, `SetAlternativeWindow`, axis mask/limits, `Roblox` helpers.

Not ported: `Ortho` (not in this upstream revision); `PushID(int)`/`PushID(ptr)` are merged into one `PushID`
(numbers hash as ints, other values via `tostring`).

## Development

```sh
git clone --recursive https://git.bug.tools/bug/imguizmo-luau.git
bash tools/test.sh   # tests/t_*.luau in the core's Roblox mock
```

Upstream source (pinned) is in `tools/upstream/`; port-specific comments are tagged `[Port]`.

## License

MIT, see LICENSE (upstream copyright kept).
