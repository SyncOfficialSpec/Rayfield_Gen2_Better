-- Showcase with the ocean background behind the menu.
-- The image is loaded from GitHub raw (no Discord re-compression) via
-- getcustomasset, so it renders at whatever quality the source file has.

local BG_URL = "https://raw.githubusercontent.com/SyncOfficialSpec/Rayfield_Gen2_Better/main/assets/bg-ocean.jpeg"

-- fetch + cache to disk, then resolve to an rbxasset id the ImageLabel can use
local bgAsset
do
	local ok, data = pcall(function() return game:HttpGet(BG_URL) end)
	if ok and data then
		pcall(function() writefile("gen2_showcase_bg.jpeg", data) end)
		local ok2, id = pcall(function() return getcustomasset("gen2_showcase_bg.jpeg") end)
		if ok2 then bgAsset = id end
	end
end

-- paint the background first, so the menu sits on top of it
local bgGui = Instance.new("ScreenGui")
bgGui.Name = "Gen2ShowcaseBG"
bgGui.IgnoreGuiInset = true
bgGui.DisplayOrder = -10 -- behind the Rayfield menu
bgGui.ResetOnSpawn = false
bgGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
bgGui.Parent = game:GetService("CoreGui")

local img = Instance.new("ImageLabel")
img.Size = UDim2.fromScale(1, 1)
img.BackgroundColor3 = Color3.fromRGB(10, 20, 35)
img.BorderSizePixel = 0
img.ScaleType = Enum.ScaleType.Crop -- fill the screen, no stretching
img.Image = bgAsset or ""
img.Parent = bgGui

-- now the menu
local Rayfield = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/SyncOfficialSpec/Rayfield_Gen2_Better/main/source.lua"
))()

local Window = Rayfield:CreateWindow({
	name = "Gen2 [Better]",
	subtitle = "hosted background · full quality",
})

local Combat = Window:CreateTab({ name = "Combat" })
Combat:CreateSection({ name = "Aimbot" })
Combat:CreateToggle({ name = "Enabled", currentValue = false, callback = function() end })
Combat:CreateSlider({ name = "FOV", range = { 30, 400 }, increment = 5, suffix = "px", currentValue = 120, callback = function() end })
Combat:CreateDropdown({ name = "Target Part", options = { "Head", "Torso", "Random" }, currentOption = "Head", callback = function() end })

local Visual = Window:CreateTab({ name = "Visual" })
Visual:CreateSection({ name = "ESP" })
Visual:CreateToggle({ name = "Boxes", currentValue = true, callback = function() end })
Visual:CreateToggle({ name = "Names", currentValue = true, callback = function() end })
Visual:CreateDropdown({ name = "Mode", options = { "Off", "Box", "Chams" }, currentOption = "Box", callback = function() end })
