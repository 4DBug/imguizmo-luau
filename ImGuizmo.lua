-- ImGuizmo for imgui-luau. Port of https://github.com/CedricGuillemet/ImGuizmo (105e4fde45e4e74aae8973d98750820ef7aca7e2).
-- Usage: local ImGuizmo = require(path.to.ImGuizmo)(require(path.to.ImGui))
return function(G)
    local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4
    local ImGuizmo = {}
    -- [Port] TODO: port from tools/upstream
    return ImGuizmo
end
