# imguizmo-luau

3D gizmo (translate/rotate/scale) for imgui-luau, with Roblox Camera/CFrame helpers.

Luau port of [ImGuizmo](https://github.com/CedricGuillemet/ImGuizmo) for [imgui-luau](https://git.bug.tools/bug/imgui-luau) ([GitHub](https://github.com/4DBug/imgui-luau)).
Mirrors: [git.bug.tools](https://git.bug.tools/bug/imguizmo-luau) / [GitHub](https://github.com/4DBug/imguizmo-luau).

**Status: work in progress.**

```lua
local G = require(ReplicatedStorage.ImGui)
local ImGuizmo = require(ReplicatedStorage.ImGuizmo)(G)
```

## Development

```sh
git clone --recursive https://git.bug.tools/bug/imguizmo-luau.git
bash tools/test.sh   # tests/t_*.luau in the core's Roblox mock
```

Upstream source (pinned) is in `tools/upstream/`; port-specific comments are tagged `[Port]`.

## License

MIT, see LICENSE (upstream copyright kept).
