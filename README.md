# Rayfield Gen2 [Better]

The **official Rayfield Gen2** (by Sirius) loaded unchanged, plus the extra
elements from the Gen2 fanmade rebuild — drawn to match the official Gen2 card
style (read live from the window theme), so they sit alongside the built-in
elements seamlessly and in the right order.

- Base library and docs: <https://docs.sirius.menu/rayfield-gen2> (all credit to Sirius)
- Extra elements ported from the Gen2 fanmade build.

## Load it

```lua
local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SyncOfficialSpec/Rayfield_Gen2_Better/main/source.lua"))()
```

Everything from official Gen2 works exactly as documented. On top of that you get:

## Extra elements

| Method | What it is |
|---|---|
| `Tab:CreateParagraph{ title, content }` | A titled block of body text |
| `Tab:CreateLabel{ text, color }` | A single line of text |
| `Tab:CreateDivider()` | A thin separator line |
| `Tab:CreateFAQ{ items = { {question, answer}, ... } }` | Expandable Q&A (accordion) |
| `Tab:CreateChart{ Name, Data = {..numbers..} }` | Animated line chart |
| `Tab:CreateBarChart{ Name, Data = {..numbers..} }` | Bar chart |
| `Tab:CreateStackedChart{ Name, Series = {"A","B"}, Rows = { {Name, Values={..}}, ... } }` | Stacked bar chart |

## Mobile

The official base has no small screen handling, so Better adds it: the window scales itself down automatically on phones and tablets, and the extra elements (charts, tooltips) respond to touch. Scripts can adjust the scale too:

```lua
Rayfield:SetUIScale(0.9)   -- multiplies the automatic fit
Rayfield:GetUIScale()      -- effective scale right now
```

Both methods also exist on the window handle.

## Example

```lua
local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SyncOfficialSpec/Rayfield_Gen2_Better/main/source.lua"))()

local Window = Rayfield:CreateWindow({ name = "My Menu", subtitle = "Gen2 Better" })

local Home = Window:CreateTab({ name = "Home" })

-- official Gen2 elements
Home:CreateToggle({ name = "Auto Sprint", callback = function(v) end })
Home:CreateSlider({ name = "Walk Speed", range = { 16, 200 }, increment = 1, currentValue = 16, callback = function(v) end })

-- extra elements
Home:CreateParagraph({ title = "Welcome", content = "Official Gen2 with a few extra elements bolted on." })
Home:CreateDivider()
Home:CreateBarChart({ Name = "Kills / day", Data = { 5, 9, 3, 7, 6 } })
Home:CreateFAQ({ items = {
	{ question = "How do I use it?", answer = "Exactly like Gen2, plus the extra methods above." },
} })
```

See [`example.lua`](example.lua) for a fuller demo.

## Credit

Rayfield and Rayfield Gen2 are made by **Sirius** (<https://sirius.menu>). This
project loads the official Gen2 unchanged and only adds extra elements on top;
all credit for the library goes to Sirius. MIT licensed — see [`LICENSE`](LICENSE).
