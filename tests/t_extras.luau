-- 50 frames of DrawGrid + DrawCubes + DrawAxes + ViewManipulate (both overloads), then Roblox helper round trips.
local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImGuizmo = require(RS:WaitForChild("ImGuizmo"))(G)
local ImGui, ImVec2 = G.ImGui, G.ImVec2
local M = ImGuizmo._math
local R = ImGuizmo.Roblox

ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
local io = ImGui.GetIO()

local W, H = 800, 600
local view, proj = {}, {}
M.LookAt({ 3, 4, 8 }, { 0, 0, 0 }, { 0, 1, 0 }, view)
M.Perspective(27, W / H, 0.1, 100, proj)
local identity = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }
local cubes = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1,
    1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 2, 0, -1, 1 }
local matrix = table.clone(identity)

local function near(a, b, eps) return math.abs(a - b) < (eps or 1e-4) end

-- Roblox helpers (CFrame mock: CFrame.new returns its args as a list)
local function fakeCFrame(...)
    local c = { ... }
    return { GetComponents = function() return table.unpack(c) end }
end
local s2 = math.sqrt(0.5)
-- 45 deg about Y: right = (s2, 0, -s2), up = (0,1,0), back = (s2, 0, s2)
local cfc = { 1, 2, 3, s2, 0, s2, 0, 1, 0, -s2, 0, s2 }
local cf = fakeCFrame(table.unpack(cfc))
local m = R.MatrixFromCFrame(cf)
assert(near(m[13], 1) and near(m[14], 2) and near(m[15], 3), "translation not at 13..15")
assert(near(m[1], s2) and near(m[3], -s2), "right row wrong")
-- scale the basis, round trip must normalize and report the scale
for k = 1, 4 do m[k] *= 2 end
for k = 9, 12 do m[k] *= 3 end
local back, scale = R.CFrameFromMatrix(m)
for i = 1, 12 do assert(near(back[i], cfc[i]), "CFrame round trip component " .. i) end
assert(near(scale.X, 2) and near(scale.Y, 1) and near(scale.Z, 3), "scale wrong")

local camera = { CFrame = cf, FieldOfView = 70, ViewportSize = { X = W, Y = H } }
local v = M.matrix_t.new(R.ViewFromCamera(camera)) * M.matrix_t.new(R.MatrixFromCFrame(camera.CFrame))
for i = 1, 16 do assert(near(v[i], identity[i]), "view * camera ~= identity at " .. i) end
local p = R.ProjFromCamera(camera)
assert(near(p[6], 1 / math.tan(math.rad(35)), 1e-3), "proj fov wrong: " .. p[6])
assert(near(p[1] * W / H, p[6], 1e-3), "proj aspect wrong")

local frame = 0
local WF = G.ImGuiWindowFlags
game:GetService("RunService").Stepped:Connect(function()
    if frame >= 50 then return end
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    -- drag across the view cube for a few frames
    if frame == 5 then io:AddMousePosEvent(W - 64, 64) end
    if frame == 8 then io:AddMouseButtonEvent(0, true) end
    if frame > 8 and frame < 20 then io:AddMousePosEvent(W - 64 + (frame - 8) * 3, 64) end
    if frame == 22 then io:AddMouseButtonEvent(0, false) end
    ImGui.NewFrame()
    ImGuizmo.BeginFrame()
    ImGui.SetNextWindowPos(ImVec2(0, 0))
    ImGui.SetNextWindowSize(ImVec2(W, H))
    ImGui.Begin("Viewport", nil, bit32.bor(WF.NoTitleBar, WF.NoMove, WF.NoResize))
    ImGuizmo.SetDrawlist()
    ImGuizmo.SetRect(0, 0, W, H)
    ImGuizmo.DrawGrid(view, proj, identity, 10)
    ImGuizmo.DrawGridCustom(view, proj, identity, 5, 2, 4)
    ImGuizmo.DrawCubes(view, proj, cubes, 2)
    ImGuizmo.DrawAxes(view, proj, cubes, 2)
    ImGuizmo.Manipulate(view, proj, ImGuizmo.OPERATION.TRANSLATE, ImGuizmo.MODE.LOCAL, matrix)
    if frame % 2 == 0 then
        ImGuizmo.ViewManipulate(view, 8, ImVec2(W - 128, 0), ImVec2(128, 128), 0x10101010)
    else
        ImGuizmo.ViewManipulate(view, proj, ImGuizmo.OPERATION.TRANSLATE, ImGuizmo.MODE.LOCAL, matrix, 8, ImVec2(W - 128, 0), ImVec2(128, 128), 0x10101010)
    end
    ImGui.End()
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    for i = 1, 16 do assert(view[i] == view[i], "view has NaN at frame " .. frame) end
    if frame == 50 then
        print("OK")
    end
end)
