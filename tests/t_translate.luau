-- Drags the X translation arrow to the right and checks the matrix translation X increased.
local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImGuizmo = require(RS:WaitForChild("ImGuizmo"))(G)
local ImGui, ImVec2 = G.ImGui, G.ImVec2
local M = ImGuizmo._math

ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
local io = ImGui.GetIO()

local W, H = 800, 600
local view, proj = {}, {}
M.LookAt({ 0, 0, 8 }, { 0, 0, 0 }, { 0, 1, 0 }, view)
M.Perspective(27, W / H, 0.1, 100, proj)
local matrix = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }

local frame, done = 0, false
local mx, my = 0, 0
local WF = G.ImGuiWindowFlags
game:GetService("RunService").Stepped:Connect(function()
    if done then return end
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    if frame == 4 then
        -- mouse at 70% along the projected X axis
        local c = ImGuizmo._context
        local p = ImGuizmo._worldToPos(M.makeVect(0.7 * c.mScreenFactor, 0, 0), c.mViewProjection)
        mx, my = p.x, p.y
        io:AddMousePosEvent(mx, my)
    elseif frame == 6 then
        io:AddMouseButtonEvent(0, true)
    elseif frame > 6 and frame <= 16 then
        io:AddMousePosEvent(mx + (frame - 6) * 5, my)
    elseif frame == 18 then
        io:AddMouseButtonEvent(0, false)
    end
    ImGui.NewFrame()
    ImGuizmo.BeginFrame()
    ImGui.SetNextWindowPos(ImVec2(0, 0))
    ImGui.SetNextWindowSize(ImVec2(W, H))
    ImGui.Begin("Viewport", nil, bit32.bor(WF.NoTitleBar, WF.NoMove, WF.NoResize))
    ImGuizmo.SetDrawlist()
    ImGuizmo.SetRect(0, 0, W, H)
    ImGuizmo.Manipulate(view, proj, ImGuizmo.OPERATION.TRANSLATE, ImGuizmo.MODE.WORLD, matrix)
    if frame == 10 then assert(ImGuizmo.IsUsing(), "gizmo not in use while dragging") end
    ImGui.End()
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == 20 then
        done = true
        assert(not ImGuizmo.IsUsing(), "still using after release")
        assert(matrix[13] > 0.01, "translation X did not increase: " .. tostring(matrix[13]))
        assert(math.abs(matrix[14]) < 1e-4 and math.abs(matrix[15]) < 1e-4, "moved off-axis")
        print("OK")
    end
end)
