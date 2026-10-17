-- Prepended to examples/roblox/main.client.luau by tools/test.sh: the core mock has no Part/CFrame math.
local CFrame = {}
CFrame.__index = CFrame
function CFrame.new(x, y, z, ...)
	local R = { ... }
	if #R == 0 then R = { 1, 0, 0, 0, 1, 0, 0, 0, 1 } end
	return setmetatable({ x, y, z, table.unpack(R) }, CFrame)
end
function CFrame:GetComponents() return table.unpack(self, 1, 12) end
function CFrame:Inverse()
	local x, y, z, a, b, c, d, e, f, g, h, i = self:GetComponents() -- orthonormal: inverse = transpose
	return CFrame.new(-(a * x + d * y + g * z), -(b * x + e * y + h * z), -(c * x + f * y + i * z), a, d, g, b, e, h, c, f, i)
end
local Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }
local Enum = { CameraType = { Scriptable = "Scriptable" } }
local workspace = {
	CurrentCamera = { CFrame = CFrame.new(0, 5, 20), FieldOfView = 70, ViewportSize = { X = 1280, Y = 720 } },
	FindFirstChild = function() return nil end,
}
local Instance = { new = function() return {} end }
do
	local Run = game:GetService("RunService")
	Run.RenderStepped = Run.Stepped -- the mock only fires Stepped
	local Frames = 0
	Run.RenderStepped:Connect(function()
		Frames += 1
		if Frames == 30 then -- last frame (--frames 30): 29 example frames ran clean print("OK") end
	end)
end
