local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(RS:WaitForChild("ImGui"))
local ImGuizmo = require(RS:WaitForChild("ImGuizmo"))(G)
local ImGui, ImVec2 = G.ImGui, G.ImVec2
local OP, MODE, Roblox = ImGuizmo.OPERATION, ImGuizmo.MODE, ImGuizmo.Roblox

local Part = workspace:FindFirstChild("GizmoPart")
if not Part then
	Part = Instance.new("Part")
	Part.Name = "GizmoPart"
	Part.Anchored = true
	Part.Size = Vector3.new(4, 4, 4)
	Part.CFrame = CFrame.new(0, 5, 0)
	Part.Parent = workspace
end

local Operation, Mode = OP.TRANSLATE, MODE.WORLD
local Camera = workspace.CurrentCamera

ImGui.CreateContext()
G.ImGui_ImplRoblox.Init(game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"))
RunService.RenderStepped:Connect(function()
	G.ImGui_ImplRoblox.NewFrame()
	ImGui.NewFrame()
	ImGuizmo.BeginFrame()

	ImGui.Begin("Gizmo")
	_, Operation = ImGui.RadioButton("Translate", Operation, OP.TRANSLATE)
	ImGui.SameLine()
	_, Operation = ImGui.RadioButton("Rotate", Operation, OP.ROTATE)
	ImGui.SameLine()
	_, Operation = ImGui.RadioButton("Scale", Operation, OP.SCALE)
	_, Mode = ImGui.RadioButton("Local", Mode, MODE.LOCAL)
	ImGui.SameLine()
	_, Mode = ImGui.RadioButton("World", Mode, MODE.WORLD)
	ImGui.End()

	local Viewport = Camera.ViewportSize
	ImGuizmo.SetDrawlist(ImGui.GetForegroundDrawList())
	ImGuizmo.SetRect(0, 0, Viewport.X, Viewport.Y)

	local View = Roblox.ViewFromCamera(Camera)
	local Proj = Roblox.ProjFromCamera(Camera)

	-- Part.Size is baked into the basis so SCALE edits it
	local Matrix = Roblox.MatrixFromCFrame(Part.CFrame)
	local Size = Part.Size
	for I = 1, 3 do
		Matrix[I] *= Size.X
		Matrix[4 + I] *= Size.Y
		Matrix[8 + I] *= Size.Z
	end
	if ImGuizmo.Manipulate(View, Proj, Operation, Mode, Matrix) then
		local NewCFrame, NewSize = Roblox.CFrameFromMatrix(Matrix)
		Part.CFrame = NewCFrame
		Part.Size = NewSize
	end

	-- ViewManipulate edits View in place; the camera is its inverse
	ImGuizmo.ViewManipulate(View, 10, ImVec2(Viewport.X - 128, 0), ImVec2(128, 128), 0x10101010)
	if ImGuizmo.IsUsingViewManipulate() then
		Camera.CameraType = Enum.CameraType.Scriptable
		Camera.CFrame = Roblox.CFrameFromMatrix(View):Inverse()
	end

	ImGui.Render()
	G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
end)
