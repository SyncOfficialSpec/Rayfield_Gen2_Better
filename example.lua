-- Rayfield Gen2 [Better] example: official Gen2 elements + the extra ones.
-- Base library by Sirius: https://docs.sirius.menu/rayfield-gen2
local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SyncOfficialSpec/Rayfield_Gen2_Better/main/source.lua"))()

local Window = Rayfield:CreateWindow({
	name = "Gen2 Better",
	subtitle = "official + extras",
})

--== Home: official elements ==--
local Home = Window:CreateTab({ name = "Home" })

Home:CreateSection({ name = "Built-in" })
Home:CreateButton({ name = "Say hello", callback = function() print("hello") end })
Home:CreateToggle({ name = "Auto Sprint", currentValue = false, callback = function(v) print(v) end })
Home:CreateSlider({
	name = "Walk Speed", range = { 16, 200 }, increment = 1, suffix = "spd", currentValue = 16,
	callback = function(value)
		local char = game.Players.LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = value end
	end,
})
Home:CreateDropdown({ name = "Weapon", options = { "Sword", "Bow", "Rifle" }, currentOption = "Sword", callback = function(v) end })

--== Extras: the added elements ==--
local Extra = Window:CreateTab({ name = "Extras" })

Extra:CreateParagraph({
	title = "What is this?",
	content = "Rayfield Gen2 [Better] is the official Gen2 with a few extra elements added, drawn to match the Gen2 card style.",
})
Extra:CreateLabel({ text = "A plain label line." })
Extra:CreateDivider()

Extra:CreateChart({ Name = "Score trend", Data = { 3, 7, 4, 9, 6, 11, 8 } })
Extra:CreateBarChart({ Name = "Kills / day", Data = { 5, 9, 3, 7, 6 } })
Extra:CreateStackedChart({
	Name = "Resources",
	Series = { "Wood", "Stone" },
	Rows = {
		{ Name = "Mon", Values = { 3, 2 } },
		{ Name = "Tue", Values = { 5, 3 } },
		{ Name = "Wed", Values = { 2, 4 } },
	},
})

Extra:CreateFAQ({
	items = {
		{ question = "How do I use it?", answer = "Exactly like Rayfield Gen2, plus the extra methods above." },
		{ question = "Where's the base library from?", answer = "The official Gen2 by Sirius, loaded unchanged." },
	},
})
