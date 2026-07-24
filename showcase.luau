-- ============================================================================
--  SIDE-BY-SIDE SHOWCASE
--  The SAME menu, built with the SAME code, on two libraries. Only the one
--  loadstring line below changes. Run each and compare — anything different is
--  the library, not the script.
--
--  Original Rayfield Gen2:
--    loadstring(game:HttpGet("https://raw.githubusercontent.com/SyncOfficialSpec/Rayfield_Gen2_Copy/main/source.lua"))()
--
--  Rayfield Gen2 [Better]:
--    loadstring(game:HttpGet("https://raw.githubusercontent.com/SyncOfficialSpec/Rayfield_Gen2_Better/main/source.lua"))()
-- ============================================================================

local Rayfield = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/SyncOfficialSpec/Rayfield_Gen2_Better/main/source.lua"
))()

local Window = Rayfield:CreateWindow({
	name = "Gen2 Showcase",
	subtitle = "same script, two libraries",
})

-- Combat tab
local Combat = Window:CreateTab({ name = "Combat" })

Combat:CreateSection({ name = "Aimbot" })
Combat:CreateToggle({ name = "Enabled", currentValue = false, callback = function(v) print("aimbot", v) end })
Combat:CreateToggle({ name = "Team Check", currentValue = true, callback = function(v) end })
Combat:CreateSlider({
	name = "FOV", range = { 30, 400 }, increment = 5, suffix = "px", currentValue = 120,
	callback = function(v) print("fov", v) end,
})
Combat:CreateDropdown({
	name = "Target Part", options = { "Head", "Torso", "Random" }, currentOption = "Head",
	callback = function(v) print("part", v) end,
})

-- Movement tab
local Movement = Window:CreateTab({ name = "Movement" })

Movement:CreateSection({ name = "Character" })
Movement:CreateSlider({
	name = "Walk Speed", range = { 16, 200 }, increment = 1, suffix = "spd", currentValue = 16,
	callback = function(value)
		local char = game.Players.LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = value end
	end,
})
Movement:CreateSlider({
	name = "Jump Power", range = { 50, 350 }, increment = 5, suffix = "jp", currentValue = 50,
	callback = function(value)
		local char = game.Players.LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then hum.JumpPower = value end
	end,
})
Movement:CreateToggle({ name = "Infinite Jump", currentValue = false, callback = function(v) end })

-- Misc tab
local Misc = Window:CreateTab({ name = "Misc" })

Misc:CreateSection({ name = "Actions" })
Misc:CreateButton({ name = "Rejoin Server", callback = function() print("rejoin") end })
Misc:CreateButton({ name = "Copy Job ID", callback = function() print("job id") end })
Misc:CreateSection({ name = "Visual" })
Misc:CreateToggle({ name = "Fullbright", currentValue = false, callback = function(v) end })
Misc:CreateDropdown({
	name = "ESP Mode", options = { "Off", "Box", "Chams", "Both" }, currentOption = "Off",
	callback = function(v) end,
})
