local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(RS:WaitForChild("ImGui"))
local ImGuizmo = require(RS:WaitForChild("ImGuizmo"))(G)
local ImGui, ImVec2, ImGuiKey = G.ImGui, G.ImVec2, G.ImGuiKey
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
local UseSnap, ShowGrid = false, true
local Snap = { 1, 1, 1 } -- translation xyz; [1] doubles as angle / scale snap
local AngleSnap, ScaleSnap = 15, 0.1
local BoundSizing, BoundSizingSnap = false, false
-- Part.Size is baked into the matrix, so the unit box hugs the part
local Bounds = { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 }
local BoundsSnap = { 0.1, 0.1, 0.1 }
local Identity = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }
local Camera = workspace.CurrentCamera

local function EditTransform(Matrix)
	if ImGui.IsKeyPressed(ImGuiKey.T) then Operation = OP.TRANSLATE end
	if ImGui.IsKeyPressed(ImGuiKey.E) then Operation = OP.ROTATE end
	if ImGui.IsKeyPressed(ImGuiKey.R) then Operation = OP.SCALE end
	_, Operation = ImGui.RadioButton("Translate", Operation, OP.TRANSLATE)
	ImGui.SameLine()
	_, Operation = ImGui.RadioButton("Rotate", Operation, OP.ROTATE)
	ImGui.SameLine()
	_, Operation = ImGui.RadioButton("Scale", Operation, OP.SCALE)
	ImGui.SameLine()
	_, Operation = ImGui.RadioButton("Universal", Operation, OP.UNIVERSAL)

	local Tr, Rt, Sc = {}, {}, {}
	ImGuizmo.DecomposeMatrixToComponents(Matrix, Tr, Rt, Sc)
	local Edited = ImGui.DragFloat3("Tr", Tr, 0.1)
	Edited = ImGui.DragFloat3("Rt", Rt, 1) or Edited
	Edited = ImGui.DragFloat3("Sc", Sc, 0.01) or Edited
	if Edited then ImGuizmo.RecomposeMatrixFromComponents(Tr, Rt, Sc, Matrix) end

	if Operation ~= OP.SCALE then
		_, Mode = ImGui.RadioButton("Local", Mode, MODE.LOCAL)
		ImGui.SameLine()
		_, Mode = ImGui.RadioButton("World", Mode, MODE.WORLD)
	end

	_, UseSnap = ImGui.Checkbox("Snap", UseSnap)
	ImGui.SameLine()
	if Operation == OP.ROTATE then
		AngleSnap = ImGui.DragFloat("Angle Snap", AngleSnap, 1)
	elseif Operation == OP.SCALE then
		ScaleSnap = ImGui.DragFloat("Scale Snap", ScaleSnap, 0.01)
	else
		ImGui.DragFloat3("Snap Value", Snap, 0.1)
	end

	_, BoundSizing = ImGui.Checkbox("Bound Sizing", BoundSizing)
	if BoundSizing then
		ImGui.PushID(3)
		_, BoundSizingSnap = ImGui.Checkbox("Bound Snap", BoundSizingSnap)
		ImGui.SameLine()
		ImGui.DragFloat3("Snap", BoundsSnap, 0.01)
		ImGui.PopID()
	end
	_, ShowGrid = ImGui.Checkbox("Show Grid", ShowGrid)

	local SnapArg = nil
	if UseSnap then
		if Operation == OP.ROTATE then
			SnapArg = { AngleSnap, AngleSnap, AngleSnap }
		elseif Operation == OP.SCALE then
			SnapArg = { ScaleSnap, ScaleSnap, ScaleSnap }
		else
			SnapArg = Snap
		end
	end
	return Edited, SnapArg
end

ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
RunService.RenderStepped:Connect(function()
	G.ImGui_ImplRoblox.NewFrame()
	ImGui.NewFrame()
	ImGuizmo.BeginFrame()

	local Viewport = Camera.ViewportSize
	ImGuizmo.SetDrawlist(ImGui.GetForegroundDrawList())
	ImGuizmo.SetRect(0, 0, Viewport.X, Viewport.Y)

	local View = Roblox.ViewFromCamera(Camera)
	local Proj = Roblox.ProjFromCamera(Camera)

	-- Part.Size is baked into the basis so SCALE / bounds edit it
	local Matrix = Roblox.MatrixFromCFrame(Part.CFrame)
	local Size = Part.Size
	for I = 1, 3 do
		Matrix[I] *= Size.X
		Matrix[4 + I] *= Size.Y
		Matrix[8 + I] *= Size.Z
	end

	ImGui.Begin("Editor")
	local Edited, SnapArg = EditTransform(Matrix)
	ImGui.End()

	if ShowGrid then ImGuizmo.DrawGrid(View, Proj, Identity, 100) end
	local Moved = ImGuizmo.Manipulate(View, Proj, Operation, Mode, Matrix, nil, SnapArg,
		BoundSizing and Bounds or nil, BoundSizing and BoundSizingSnap and BoundsSnap or nil)
	if Edited or Moved then
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
