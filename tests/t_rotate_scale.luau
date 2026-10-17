-- Drags the Z rotation ring and the X scale handle; runs one frame with localBounds.
local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImGuizmo = require(RS:WaitForChild("ImGuizmo"))(G)
local ImGui, ImVec2 = G.ImGui, G.ImVec2
local M = ImGuizmo._math
local OP = ImGuizmo.OPERATION

ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
local io = ImGui.GetIO()

local W, H = 800, 600
local view, proj = {}, {}
M.LookAt({ 0, 0, 8 }, { 0, 0, 0 }, { 0, 1, 0 }, view)
M.Perspective(27, W / H, 0.1, 100, proj)
local function identity() return { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 } end

-- phases: each picks a start point (world, in screen-factor units) and a per-frame mouse delta
local phases = {
    { op = OP.ROTATE_Z, start = function(sf) local r = 1.2 * sf * math.sqrt(0.5); return M.makeVect(r, r, 0) end, dx = -4, dy = -4 },
    { op = OP.SCALE, start = function(sf) return M.makeVect(0.7 * sf, 0, 0) end, dx = 5, dy = 0,
        -- oblique camera: the X scale pick plane (normal X through the origin) must not contain the eye
        eye = { 4, 3, 8 } },
    { op = OP.TRANSLATE, bounds = { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 } },
    { op = OP.UNIVERSAL },
}
local results = {}
local phase, frame, done = 1, 0, false
local matrix, delta = identity(), identity()
local mx, my = 0, 0
local WF = G.ImGuiWindowFlags
game:GetService("RunService").Stepped:Connect(function()
    if done then return end
    frame += 1
    local ph = phases[phase]
    if frame == 1 then M.LookAt(ph.eye or { 0, 0, 8 }, { 0, 0, 0 }, { 0, 1, 0 }, view) end
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    if ph.start then
        if frame == 4 then
            local c = ImGuizmo._context
            local p = ImGuizmo._worldToPos(ph.start(c.mScreenFactor), c.mViewProjection)
            mx, my = p.x, p.y
            io:AddMousePosEvent(mx, my)
        elseif frame == 6 then
            io:AddMouseButtonEvent(0, true)
        elseif frame > 6 and frame <= 16 then
            io:AddMousePosEvent(mx + (frame - 6) * ph.dx, my + (frame - 6) * ph.dy)
        elseif frame == 18 then
            io:AddMouseButtonEvent(0, false)
        end
    end
    ImGui.NewFrame()
    ImGuizmo.BeginFrame()
    ImGui.SetNextWindowPos(ImVec2(0, 0))
    ImGui.SetNextWindowSize(ImVec2(W, H))
    ImGui.Begin("Viewport", nil, bit32.bor(WF.NoTitleBar, WF.NoMove, WF.NoResize))
    ImGuizmo.SetDrawlist()
    ImGuizmo.SetRect(0, 0, W, H)
    ImGuizmo.Manipulate(view, proj, ph.op, ImGuizmo.MODE.LOCAL, matrix, delta, nil, ph.bounds)
    if ph.start and frame == 10 then assert(ImGuizmo.IsUsing(), "phase " .. phase .. ": not in use while dragging") end
    ImGui.End()
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == 20 or (not ph.start and frame == 2) then
        assert(not ImGuizmo.IsUsing(), "phase " .. phase .. ": still using after release")
        local t, r, s = {}, {}, {}
        ImGuizmo.DecomposeMatrixToComponents(matrix, t, r, s)
        results[phase] = { t = t, r = r, s = s }
        phase += 1
        frame = 0
        matrix, delta = identity(), identity()
        if phase > #phases then
            done = true
            local r1, r2 = results[1], results[2]
            assert(math.abs(r1.r[3]) > 1, "rotation Z did not change: " .. r1.r[3])
            assert(math.abs(r1.r[1]) < 1e-3 and math.abs(r1.r[2]) < 1e-3, "rotated off-axis")
            assert(r2.s[1] > 1.01, "scale X did not increase: " .. r2.s[1])
            assert(math.abs(r2.s[2] - 1) < 1e-4 and math.abs(r2.s[3] - 1) < 1e-4, "scaled off-axis")
            print("OK")
        end
    end
end)
