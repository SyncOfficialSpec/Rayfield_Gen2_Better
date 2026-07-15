--[[
	Rayfield Gen2 [Better]
	The official Rayfield Gen2 (by Sirius, https://sirius.menu) plus the extra
	elements from the Gen2 fanmade rebuild: Paragraph, Label, Divider, FAQ, and
	charts. The base library is loaded unchanged; the extra elements are drawn to
	match the official Gen2 card style (read live from the window theme), so they
	sit alongside the built-in elements seamlessly.

	All credit for Rayfield / Rayfield Gen2 goes to Sirius. MIT licensed.
]]

local OFFICIAL = "https://gist.githubusercontent.com/jensonhirst/3408be6bafa9feffb20fb4cbfd54e5f8/raw/Gen2-Preview-diablo.luau"
local Rayfield = loadstring(game:HttpGet(OFFICIAL))()

local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local function new(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props) do i[k] = v end
	if parent then i.Parent = parent end
	return i
end

local function tween(o, ti, props)
	local t = TweenService:Create(o, ti, props)
	t:Play()
	return t
end

local TI_MORPH = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TI_FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- measure how tall wrapped text will be at a given width
local function measureWrapped(text, size, font, width)
	local ok, v = pcall(function()
		local params = Instance.new("GetTextBoundsParams")
		params.Text = text
		params.Font = font
		params.Size = size
		params.Width = width
		return TextService:GetTextBoundsAsync(params).Y
	end)
	if ok and v then return v end
	-- fallback estimate
	local perLine = math.max(1, math.floor(width / (size * 0.55)))
	local lines = math.ceil(#text / perLine)
	return lines * (size + 3)
end

local function commafy(s)
	local sign = ""
	if s:sub(1, 1) == "-" then sign = "-"; s = s:sub(2) end
	s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if s:sub(1, 1) == "," then s = s:sub(2) end
	return sign .. s
end
local function catmull(p0, p1, p2, p3, t)
	local t2, t3 = t * t, t * t * t
	return 0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
end


-- ============================ Gen3 element support ============================
-- lucide icon loader (fetches the Rayfield icon index once, cached to disk)
local G3Icons
do
	local src
	pcall(function() if isfile and isfile("RayfieldGen2Better/icons.lua") then src = readfile("RayfieldGen2Better/icons.lua") end end)
	if not src then
		local ok, fetched = pcall(function() return game:HttpGet("https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/refs/heads/main/icons.lua") end)
		if ok and type(fetched) == "string" then
			src = fetched
			pcall(function()
				if makefolder and not (isfolder and isfolder("RayfieldGen2Better")) then makefolder("RayfieldGen2Better") end
				if writefile then writefile("RayfieldGen2Better/icons.lua", src) end
			end)
		end
	end
	if src then
		local ok, res = pcall(function() return loadstring(src)() end)
		if ok and type(res) == "table" and res["48px"] then G3Icons = res end
	end
end
local function getLucide(name)
	if not G3Icons then return nil end
	local e = G3Icons["48px"][string.lower(tostring(name))]
	if not e or type(e[1]) ~= "number" then return nil end
	return { id = e[1], size = Vector2.new(e[2][1], e[2][2]), offset = Vector2.new(e[3][1], e[3][2]) }
end
local function applyLucide(img, names, onApplied)
	if type(names) == "string" then names = { names } end
	for _, n in ipairs(names) do
		local a = getLucide(n)
		if a then img.Image = "rbxassetid://" .. a.id; img.ImageRectSize = a.size; img.ImageRectOffset = a.offset; if onApplied then onApplied() end; return true end
	end
	return false
end
local G3Connections = {}
local function connect(signal, fn) local c = signal:Connect(fn); table.insert(G3Connections, c); return c end
local function measureText(text, size, font)
	local ok, v = pcall(function() return TextService:GetTextSize(text, size, font, Vector2.new(math.huge, math.huge)) end)
	return (ok and v) or Vector2.new(#tostring(text) * size * 0.5, size)
end
local FONT_SETS = {}

local function extendTab(tab)
	if not tab or type(tab) ~= "table" or tab.__betterExtended then return tab end
	tab.__betterExtended = true

	local win = tab.window
	local theme = win and win.theme or {}
	local page = tab.tabPage
	if not page then return tab end

	-- theme-derived style, matching the official Gen2 elements
	local FONT = theme.Font or Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)
	local FONT_BOLD = theme.TitleFont or Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold)
	local ELEMENT_GRADIENT = theme.ElementGradient
	local ELEMENT_STROKE = theme.ElementStroke or Color3.fromRGB(35, 35, 35)
	local CORNER = theme.ElementCornerRadius or UDim.new(0, 12)
	local TEXT_MAIN = theme.ContentColor or Color3.fromRGB(255, 255, 255)
	local TEXT_TITLE = theme.TitlingColor or Color3.fromRGB(255, 255, 255)
	local TEXT_SUB = theme.PlaceholderColor or Color3.fromRGB(178, 178, 178)
	local ACCENT = theme.AccentColor or Color3.fromRGB(23, 153, 110)
	local DIVIDER = theme.DividerColor or Color3.fromRGB(255, 255, 255)

	-- keep custom elements in creation order alongside the built-in ones (the
	-- official library orders by LayoutOrder in steps of ~10)
	local function nextOrder()
		local lo = 0
		for _, c in ipairs(page:GetChildren()) do
			if c:IsA("GuiObject") and c.LayoutOrder > lo then lo = c.LayoutOrder end
		end
		return lo + 1
	end

	-- an empty card matching the official element look
	local function card(height, autoY)
		local c = new("Frame", {
			Name = "BetterElement",
			Size = UDim2.new(1, -20, 0, height or 0),
			AutomaticSize = autoY and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 0),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			LayoutOrder = nextOrder(),
		})
		new("UICorner", { CornerRadius = CORNER }, c)
		if ELEMENT_GRADIENT then
			new("UIGradient", { Color = ELEMENT_GRADIENT, Rotation = 90 }, c)
		else
			c.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
		end
		new("UIStroke", { Color = ELEMENT_STROKE, Thickness = 1, Transparency = 0.3 }, c)
		c.Parent = page
		return c
	end

	local function label(props, parent)
		local l = new("TextLabel", props, parent)
		l.BackgroundTransparency = 1
		l.RichText = props.RichText or false
		l.FontFace = props.FontFace or FONT
		return l
	end

	local function prop(t, ...)
		for _, k in ipairs({ ... }) do
			if t[k] ~= nil then return t[k] end
		end
		return nil
	end

	----------------------------------------------------------- chart shim
	-- compatibility helpers so the fanmade chart code runs against the Gen2 theme
	local FONT_MEDIUM, FONT_REGULAR = FONT, FONT
	local compact = false
	local chartPalette = { Color3.fromRGB(150, 222, 186), Color3.fromRGB(70, 168, 120), Color3.fromRGB(44, 108, 80), Color3.fromRGB(26, 62, 47), Color3.fromRGB(214, 240, 226) }
	local Theme = {
		Card = Color3.fromRGB(255, 255, 255), -- white so the gradient shows the Gen2 colour
		CardHover = Color3.fromRGB(255, 255, 255),
		TextTitle = TEXT_TITLE,
		TextBody = TEXT_MAIN,
		TextSub = TEXT_SUB,
		TextMuted = Color3.fromRGB(120, 120, 120),
		Accent = ACCENT,
		AccentSoft = theme.AccentStroke or ACCENT,
		AccentDark = ACCENT,
		Knob = Color3.fromRGB(255, 255, 255),
		Stroke = ELEMENT_STROKE,
		Divider = DIVIDER,
	}
	local function create(class, props, children)
		local inst = Instance.new(class)
		if class == "TextButton" or class == "ImageButton" then inst.AutoButtonColor = false end
		local parent
		if props then
			for k, v in pairs(props) do
				if k == "Parent" then parent = v
				elseif k == "Font" and typeof(v) == "Font" then inst.FontFace = v
				else inst[k] = v end
			end
		end
		if children then for _, c in ipairs(children) do c.Parent = inst end end
		if parent then inst.Parent = parent end
		return inst
	end
	local function paint(inst, p, key) inst[p] = Theme[key] end
	local function round(inst, r) return create("UICorner", { CornerRadius = UDim.new(0, r), Parent = inst }) end
	local function roundFull(inst) return create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = inst }) end
	local function padAll(inst, t, r, b, l)
		return create("UIPadding", { PaddingTop = UDim.new(0, t or 0), PaddingRight = UDim.new(0, r or 0), PaddingBottom = UDim.new(0, b or 0), PaddingLeft = UDim.new(0, l or 0), Parent = inst })
	end
	local function cardBase(c)
		round(c, (CORNER and CORNER.Offset) or 12)
		if ELEMENT_GRADIENT then create("UIGradient", { Rotation = 90, Color = ELEMENT_GRADIENT, Parent = c }) end
		create("UIStroke", { Color = ELEMENT_STROKE, Thickness = 1, Transparency = 0.3, Parent = c })
	end
	local function makeIcon(parent, icon, size, color3, transparency)
		if icon == nil or icon == 0 or icon == "" then return nil end
		local img = create("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), ImageColor3 = color3 or TEXT_TITLE, ImageTransparency = transparency or 0, Parent = parent })
		if type(icon) == "number" then img.Image = "rbxassetid://" .. tostring(icon)
		elseif type(icon) == "string" and (icon:find("rbxasset") or icon:find("://")) then img.Image = icon end
		return img
	end

	local function odometerValue(label, initial)
		label.Text = tostring(initial or "")
		return function(v) label.Text = tostring(v) end
	end
	local function chartShell(settings, h)
		local card = create("Frame", {
			Size = UDim2.new(1, 0, 0, h),
			LayoutOrder = nextOrder(),
			ClipsDescendants = true,
			Parent = page,
		})
		card:SetAttribute("SearchName", settings.Name or "")
		paint(card, "BackgroundColor3", "Card")
		cardBase(card)
		local textX = 17
		if settings.Icon then
			local ic = makeIcon(card, settings.Icon, 18, Theme.TextTitle, 0.04)
			if ic then
				ic.Position = UDim2.fromOffset(16, 13)
				textX = 44
			end
		end
		local nameLabel = create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(textX, 13),
			Size = UDim2.new(0.5, -textX, 0, 18),
			Font = FONT_BOLD,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = settings.Name or "",
			Parent = card,
		})
		paint(nameLabel, "TextColor3", "TextTitle")
		local valueLabel = create("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -17, 0, 11),
			Size = UDim2.new(0.4, 0, 0, 22),
			Font = FONT_BOLD,
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = "",
			Parent = card,
		})
		paint(valueLabel, "TextColor3", "TextTitle")
		return card, nameLabel, valueLabel
	end
	local function replayOnVisible(card, entrance)
		local function chainVisible()
			local a = card
			while a and not a:IsA("ScreenGui") do
				if a:IsA("GuiObject") and not a.Visible then return false end
				a = a.Parent
			end
			return true
		end
		task.defer(function()
			local node = card.Parent
			while node and not node:IsA("ScreenGui") do
				if node:IsA("GuiObject") then
					local nn = node
					nn:GetPropertyChangedSignal("Visible"):Connect(function()
						if nn.Visible and chainVisible() then task.defer(entrance) end
					end)
				end
				node = node.Parent
			end
			if chainVisible() then entrance() end
		end)
	end


	------------------------------------------------ Gen3 element shim
	local FONT_REGULAR2 = FONT
	local TI_MED = TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local TI_SMOOTH = TweenInfo.new(0.32, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
	local TI_SLOW = TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
	local TI_DOCK = TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	local GenStyle = { windowCorner = 12, cardRadius = 12, cardGradient = true, cardStroke = false, glow = false, windowW = 530, windowH = 550, toggleTrackW = 58, toggleTrackH = 26, toggleKnobW = 28, toggleKnobH = 20, fontKey = "builder" }
	-- extra theme keys the Gen3 elements read
	Theme.Background = Color3.fromRGB(20, 20, 20)
	Theme.CardInset = Color3.fromRGB(24, 24, 24)
	Theme.CardSelected = Color3.fromRGB(48, 48, 48)
	Theme.CardHover = Color3.fromRGB(40, 40, 40)
	Theme.KnobOff = Color3.fromRGB(66, 68, 70)
	Theme.ToggleTrack = Color3.fromRGB(18, 18, 18)
	Theme.SearchBox = Color3.fromRGB(44, 44, 44)
	Theme.BadgeText = Color3.fromRGB(66, 45, 15)
	Theme.NotifyBackground = Color3.fromRGB(16, 16, 16)
	Theme.Stroke = Color3.fromRGB(255, 255, 255)
	-- upgrade makeIcon to resolve lucide names
	local function makeIcon(parent, icon, size, color3, transparency)
		if icon == nil or icon == 0 or icon == "" then return nil end
		local img = create("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), ImageColor3 = color3 or TEXT_TITLE, ImageTransparency = transparency or 0, Parent = parent })
		if type(icon) == "number" then img.Image = "rbxassetid://" .. tostring(icon)
		elseif type(icon) == "string" then
			if icon:find("rbxasset") or icon:find("://") then img.Image = icon else applyLucide(img, icon) end
		end
		return img
	end
	local function registerGlass() end
	local function softGlow(parent, color, trans, spread, z)
		local g = create("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, (spread or 12) * 2, 1, (spread or 12) * 2), Image = "rbxassetid://6014261993", ImageColor3 = color or ACCENT, ImageTransparency = trans or 0.5, ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49, 49, 450, 450), ZIndex = z or 0, Parent = parent })
		return g
	end
	local function glowColor(holder, color) if holder then holder.ImageColor3 = color end end
	local function glowSet(holder, amount, ti) if holder then if ti then tween(holder, ti, { ImageTransparency = 1 - (amount or 0) * 0.5 }) else holder.ImageTransparency = 1 - (amount or 0) * 0.5 end end end
	local function runCallback(cb, ...) if type(cb) == "function" then local ok, e = pcall(cb, ...); if not ok then warn("Gen2Better callback: " .. tostring(e)) end end end
	local function hoverable(cardf, base, hover)
		local st = cardf:FindFirstChildOfClass("UIStroke")
		cardf.MouseEnter:Connect(function() if st then tween(st, TI_FAST, { Transparency = 0 }) end end)
		cardf.MouseLeave:Connect(function() if st then tween(st, TI_FAST, { Transparency = 0.3 }) end end)
	end
	local function makeDescription(page2, cardf, text)
		if not text or text == "" then return nil end
		local d = create("TextLabel", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -30, 0, 0), FontFace = FONT, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = TEXT_SUB, Text = text, LayoutOrder = nextOrder(), Parent = page })
		padAll(d, 0, 0, 5, 16)
		return d
	end
	local function descFor(cardf, text) return makeDescription(page, cardf, text) end
	local function tipFor() end
	local function lockOverlay(cardf, startLocked)
		local locked = startLocked and true or false
		return function(state) locked = state and true or false end
	end
	local function makeCard(page2, name, icon, height)
		local c = card(height or 50, false)
		c:SetAttribute("SearchName", name or "")
		local textX = 17
		if icon then
			local ic = makeIcon(c, icon, 18, TEXT_TITLE, 0.04)
			if ic then ic.AnchorPoint = Vector2.new(0, 0.5); ic.Position = UDim2.new(0, 16, 0.5, 0); textX = 44 end
		end
		local lbl = create("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, textX, 0.5, 0), Size = UDim2.new(1, -textX - 16, 0, 18), FontFace = FONT, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = TEXT_MAIN, Text = name or "", Parent = c })
		return c, lbl, textX
	end
	-- nested-element API for CollapsibleSection / Spoiler: builds real elements
	-- into the tab, then reparents the new instances into the container
	local function buildTabAPI(container, compact2)
		return setmetatable({ Page = container }, { __index = function(_, key)
			if type(key) == "string" and key:sub(1, 6) == "Create" and type(tab[key]) == "function" then
				return function(_, ...)
					local before = {}
					for _, ch in ipairs(page:GetChildren()) do before[ch] = true end
					local ret = table.pack(tab[key](tab, ...))
					for _, ch in ipairs(page:GetChildren()) do
						if not before[ch] and ch:IsA("GuiObject") then ch.Parent = container end
					end
					return table.unpack(ret, 1, ret.n)
				end
			end
			return nil
		end })
	end


	------------------------------------------------------------------ Divider
	function tab:CreateDivider()
		local holder = new("Frame", {
			Name = "BetterDivider",
			Size = UDim2.new(1, -20, 0, 10),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 0),
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
			Parent = page,
		})
		local line = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -8, 0, 1),
			BackgroundColor3 = DIVIDER,
			BackgroundTransparency = 0.88,
			BorderSizePixel = 0,
			Parent = holder,
		})
		local api = {}
		function api:Set(v) holder.Visible = v and true or false end
		return api
	end

	------------------------------------------------------------------ Label
	function tab:CreateLabel(settings)
		local text, color
		if type(settings) == "table" then
			text = prop(settings, "text", "Text", "name", "Name") or ""
			color = prop(settings, "color", "Color")
		else
			text = tostring(settings or "")
		end
		local c = card(nil, true)
		c.Size = UDim2.new(1, -20, 0, 0)
		new("UIPadding", {
			PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16),
			PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12),
		}, c)
		local l = label({
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			FontFace = FONT,
			TextSize = 15,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = (typeof(color) == "Color3") and color or TEXT_SUB,
			Text = text,
		}, c)
		local api = {}
		function api:Set(newText, newColor)
			if newText then l.Text = tostring(newText) end
			if typeof(newColor) == "Color3" then l.TextColor3 = newColor end
		end
		return api
	end

	------------------------------------------------------------------ Paragraph
	function tab:CreateParagraph(settings)
		settings = settings or {}
		local titleText = prop(settings, "title", "Title", "name", "Name") or ""
		local bodyText = prop(settings, "content", "Content", "body", "Body", "text", "Text") or ""

		local c = card(nil, true)
		c.Size = UDim2.new(1, -20, 0, 0)
		new("UIPadding", {
			PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16),
			PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14),
		}, c)
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}, c)
		local titleLbl = label({
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			FontFace = FONT_BOLD,
			TextSize = 16,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = TEXT_TITLE,
			Text = titleText,
			LayoutOrder = 1,
			Visible = titleText ~= "",
		}, c)
		local bodyLbl = label({
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			FontFace = FONT,
			TextSize = 14,
			LineHeight = 1.1,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = TEXT_SUB,
			Text = bodyText,
			LayoutOrder = 2,
		}, c)
		local api = {}
		function api:Set(s)
			s = s or {}
			local t = prop(s, "title", "Title")
			local b = prop(s, "content", "Content")
			if t then titleLbl.Text = t; titleLbl.Visible = t ~= "" end
			if b then bodyLbl.Text = b end
		end
		return api
	end

	------------------------------------------------------------------ FAQ
	function tab:CreateFAQ(settings)
		settings = settings or {}
		local items = prop(settings, "items", "Items") or {}
		local closers = {}
		local api = { Items = {} }
		for _, item in ipairs(items) do
			local question = prop(item, "question", "Question") or ""
			local answer = prop(item, "answer", "Answer") or ""
			local c = card(52)
			c.ClipsDescendants = true
			local q = label({
				Position = UDim2.fromOffset(16, 0),
				Size = UDim2.new(1, -58, 0, 52),
				FontFace = FONT,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = TEXT_TITLE,
				Text = question,
			}, c)
			local plus = new("ImageLabel", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -16, 0, 26),
				Size = UDim2.fromOffset(16, 16),
				BackgroundTransparency = 1,
				Image = "rbxassetid://3926305904",
				ImageRectOffset = Vector2.new(4, 84),
				ImageRectSize = Vector2.new(36, 36),
				ImageColor3 = TEXT_SUB,
				ImageTransparency = 0.1,
			}, c)
			local a = label({
				Position = UDim2.fromOffset(16, 52),
				Size = UDim2.new(1, -32, 0, 0),
				FontFace = FONT,
				TextSize = 14,
				TextWrapped = true,
				TextTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextColor3 = TEXT_SUB,
				Text = answer,
			}, c)
			local open = false
			local function setOpen(state)
				if open == state then return end
				open = state
				if open then
					local ah = measureWrapped(answer, 14, FONT, math.max(c.AbsoluteSize.X - 34, 50))
					a.Size = UDim2.new(1, -32, 0, ah + 4)
					tween(c, TI_MORPH, { Size = UDim2.new(1, -20, 0, 52 + ah + 16) })
					tween(plus, TI_MORPH, { Rotation = 135, ImageColor3 = ACCENT, ImageTransparency = 0 })
					tween(a, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.08), { TextTransparency = 0.1, Position = UDim2.fromOffset(16, 48) })
				else
					tween(c, TI_MORPH, { Size = UDim2.new(1, -20, 0, 52) })
					tween(plus, TI_MORPH, { Rotation = 0, ImageColor3 = TEXT_SUB, ImageTransparency = 0.1 })
					tween(a, TI_FAST, { TextTransparency = 1 })
				end
			end
			closers[#closers + 1] = function() setOpen(false) end
			local function openExclusive()
				for _, fn in ipairs(closers) do fn() end
				setOpen(true)
			end
			local clicker = new("TextButton", {
				BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1),
			}, c)
			clicker.MouseButton1Click:Connect(function()
				if open then setOpen(false) else openExclusive() end
			end)
			api.Items[#api.Items + 1] = { Open = openExclusive, Close = function() setOpen(false) end }
		end
		return api
	end

	function tab:CreateChart(ChartSettings)
		ChartSettings = ChartSettings or {}
		local points = {}
		for _, v in ipairs(ChartSettings.Points or {}) do
			local n = tonumber(v)
			if n then points[#points + 1] = n end
		end
		if #points == 0 then points = {0, 0} end
		if #points == 1 then points = {points[1], points[1]} end
		local prefix = ChartSettings.Prefix or ""
		local suffix = ChartSettings.Suffix or ""
		local decimals = ChartSettings.Decimals or 0
		local filled = ChartSettings.Filled ~= false
		local smooth = ChartSettings.Smooth == true
		local showDots = ChartSettings.Dots == true or (ChartSettings.Dots == nil and not smooth)
		local maxPoints = ChartSettings.MaxPoints or math.max(#points, 12)

		local cardH = compact and 118 or 152
		local plotTop = compact and 38 or 44
		local card = create("Frame", {
			Size = UDim2.new(1, 0, 0, cardH),
			LayoutOrder = nextOrder(),
			ClipsDescendants = true,
			Parent = page,
		})
		card:SetAttribute("SearchName", ChartSettings.Name or "")
		paint(card, "BackgroundColor3", "Card")
		cardBase(card)

		local textX = 17
		if ChartSettings.Icon then
			local ic = makeIcon(card, ChartSettings.Icon, 18, Theme.TextTitle, 0.04)
			if ic then
				ic.Position = UDim2.fromOffset(16, compact and 11 or 13)
				textX = 44
			end
		end
		local nameLabel = create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(textX, compact and 11 or 13),
			Size = UDim2.new(0.5, -textX, 0, 18),
			Font = FONT_BOLD,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = ChartSettings.Name or "",
			Parent = card,
		})
		paint(nameLabel, "TextColor3", "TextTitle")
		local valueLabel = create("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -17, 0, compact and 9 or 11),
			Size = UDim2.new(0.4, 0, 0, 22),
			Font = FONT_BOLD,
			TextSize = compact and 17 or 20,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = "",
			Parent = card,
		})
		paint(valueLabel, "TextColor3", "TextTitle")

		local plot = create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(17, plotTop),
			Size = UDim2.new(1, -34, 1, -plotTop - 14),
			Parent = card,
		})
		create("Frame", {
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.93,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(1, 0, 0, 1),
			Parent = plot,
		})
		create("Frame", {
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.93,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 1, -1),
			Size = UDim2.new(1, 0, 0, 1),
			Parent = plot,
		})
		local hairline = create("Frame", {
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.new(0, 1, 1, 0),
			Visible = false,
			ZIndex = 2,
			Parent = plot,
		})

		local fillHolder = create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Parent = plot,
		})
		local segHolder = create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
			Parent = plot,
		})
		local segCanvas = create("Frame", {
			BackgroundTransparency = 1,
			Parent = segHolder,
		})
		local dotHolder = create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
			Parent = plot,
		})

		local dots, segs, cols, colTargets = {}, {}, {}, {}
		local xsCache, ysCache = {}, {}
		local hoverIdx = nil

		local function fmt(n)
			local str = decimals > 0 and string.format("%." .. decimals .. "f", n) or tostring(math.floor(n + 0.5))
			return prefix .. commafy(str) .. suffix
		end
		local setValue = odometerValue(valueLabel, fmt(points[#points]))

		local function redraw(animate)
			local w, h = plot.AbsoluteSize.X, plot.AbsoluteSize.Y
			if w < 24 or h < 24 then return end
			segCanvas.Size = UDim2.fromOffset(w, h)
			local n = #points
			local lo, hi = points[1], points[1]
			for _, v in ipairs(points) do
				if v < lo then lo = v end
				if v > hi then hi = v end
			end
			local range = hi - lo
			if range == 0 then range = math.max(math.abs(hi), 1) end
			local edgePad = (smooth and 3 or 4) / 2 + 1.5
			for i = 1, n do
				xsCache[i] = edgePad + (i - 1) / (n - 1) * (w - edgePad * 2)
				ysCache[i] = math.floor(10 + (1 - (points[i] - lo) / range) * (h - 22) + 0.5)
			end
			for i = #xsCache, n + 1, -1 do
				xsCache[i] = nil
				ysCache[i] = nil
			end

			local rxs, rys = xsCache, ysCache
			if smooth and n >= 3 then
				rxs, rys = {}, {}
				for i = 1, n - 1 do
					local x0 = xsCache[i > 1 and i - 1 or 1]
					local y0 = ysCache[i > 1 and i - 1 or 1]
					local x1, y1 = xsCache[i], ysCache[i]
					local x2, y2 = xsCache[i + 1], ysCache[i + 1]
					local x3 = xsCache[i + 2] or x2
					local y3 = ysCache[i + 2] or y2
					local sub = math.clamp(math.ceil((x2 - x1) / 3), 8, 36)
					for tstep = 0, sub - 1 do
						local a = tstep / sub
						rxs[#rxs + 1] = catmull(x0, x1, x2, x3, a)
						rys[#rys + 1] = math.clamp(catmull(y0, y1, y2, y3, a), 2, h - 2)
					end
				end
				rxs[#rxs + 1] = xsCache[n]
				rys[#rys + 1] = ysCache[n]
			end
			local rn = #rxs

			for i = #dots, n + 1, -1 do
				dots[i]:Destroy()
				dots[i] = nil
			end
			for i = #segs, rn, -1 do
				segs[i]:Destroy()
				segs[i] = nil
			end

			for i = 1, n do
				local d = dots[i]
				local fresh = not d
				if fresh then
					d = create("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Size = UDim2.fromOffset(10, 10),
						ZIndex = 4,
						Parent = dotHolder,
					})
					paint(d, "BackgroundColor3", "Knob")
					roundFull(d)
					d.Visible = showDots
					dots[i] = d
				end
				local target = UDim2.fromOffset(xsCache[i], ysCache[i])
				if fresh then
					d.Position = target
					if animate then
						d.Size = UDim2.fromOffset(0, 0)
						task.delay(0.12, function()
							tween(d, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(10, 10)})
						end)
					end
				elseif animate then
					tween(d, TI_MORPH, {Position = target})
				else
					d.Position = target
				end
			end

			for i = 1, rn - 1 do
				local s = segs[i]
				local fresh = not s
				if fresh then
					s = create("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BorderSizePixel = 0,
						ZIndex = 3,
						Parent = segCanvas,
					})
					paint(s, "BackgroundColor3", "AccentSoft")
					roundFull(s)
					segs[i] = s
				end
				local dx = rxs[i + 1] - rxs[i]
				local dy = rys[i + 1] - rys[i]
				local len = math.max(math.sqrt(dx * dx + dy * dy), 0.001)
				local ov = smooth and 3 or 4
				local cxx, cyy = rxs[i] + dx / 2, rys[i] + dy / 2
				if rn == 2 then
					ov = 0
				elseif i == 1 or i == rn - 1 then
					local push = (i == 1 and ov or -ov) / 4
					cxx = cxx + dx / len * push
					cyy = cyy + dy / len * push
					ov = ov / 2
				end
				local props = {
					Position = UDim2.fromScale(cxx / w, cyy / h),
					Size = UDim2.fromOffset(math.ceil(len + ov), 3),
					Rotation = math.deg(math.atan2(dy, dx)),
				}
				if animate and not fresh then
					tween(s, TI_MORPH, props)
				else
					s.Position = props.Position
					s.Size = props.Size
					s.Rotation = props.Rotation
				end
			end

			if filled then
				local colW = 3
				local fillX = rxs[1]
				local count = math.max(math.ceil((rxs[rn] - fillX) / colW), 1)
				for i = #cols, count + 1, -1 do
					cols[i]:Destroy()
					cols[i] = nil
				end
				local seg = 1
				for c = 1, count do
					local f = cols[c]
					local fresh = not f
					if fresh then
						f = create("Frame", {
							AnchorPoint = Vector2.new(0, 1),
							BorderSizePixel = 0,
							BackgroundTransparency = 0.12,
							Parent = fillHolder,
						})
						paint(f, "BackgroundColor3", "AccentDark")
						create("UIGradient", {
							Rotation = 90,
							Transparency = NumberSequence.new(0, 0.78),
							Parent = f,
						})
						cols[c] = f
					end
					local left = fillX + (c - 1) * colW
					local cw = math.min(colW, rxs[rn] - left)
					local cx = left + cw / 2
					while seg < rn - 1 and rxs[seg + 1] < cx do seg = seg + 1 end
					local x1, x2 = rxs[seg], rxs[seg + 1]
					local a = math.clamp((cx - x1) / math.max(x2 - x1, 1), 0, 1)
					local y = rys[seg] + (rys[seg + 1] - rys[seg]) * a
					local props = {
						Position = UDim2.fromOffset(left, h - 1),
						Size = UDim2.fromOffset(math.max(cw, 1), math.max(h - 1 - y, 0)),
					}
					colTargets[c] = props.Size
					if animate and not fresh then
						tween(f, TI_MORPH, props)
					else
						f.Position = props.Position
						f.Size = props.Size
					end
				end
			end
		end

		local function applyHover(i)
			if hoverIdx == i then return end
			if hoverIdx and dots[hoverIdx] then
				dots[hoverIdx].Size = UDim2.fromOffset(10, 10)
				dots[hoverIdx].BackgroundColor3 = Theme.Knob
				dots[hoverIdx].Visible = showDots
			end
			hoverIdx = i
			local d = i and dots[i]
			if d then
				d.Size = UDim2.fromOffset(14, 14)
				d.BackgroundColor3 = Theme.AccentSoft
				d.Visible = true
				hairline.Position = UDim2.fromOffset(xsCache[i], 0)
				hairline.Visible = true
				setValue(fmt(points[i]))
			else
				hairline.Visible = false
				setValue(fmt(points[#points]))
			end
		end

		card.InputChanged:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			if #xsCache < 2 then return end
			local rx = input.Position.X - plot.AbsolutePosition.X
			local best, bestDist = nil, math.huge
			for i = 1, #points do
				local dist = math.abs((xsCache[i] or 0) - rx)
				if dist < bestDist then
					best, bestDist = i, dist
				end
			end
			applyHover(best)
		end)
		card.MouseLeave:Connect(function()
			applyHover(nil)
		end)

		local animToken = 0
		local function entrance()
			if #dots == 0 then return end
			animToken = animToken + 1
			local my = animToken
			local w = plot.AbsoluteSize.X
			if w < 24 then return end
			local D = 0.75
			segHolder.ClipsDescendants = true
			segHolder.Size = UDim2.new(0, 0, 1, 0)
			tween(segHolder, TweenInfo.new(D, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 1, 0)})
			task.delay(D + 0.1, function()
				if my == animToken then
					segHolder.ClipsDescendants = false
					segHolder.Size = UDim2.fromScale(1, 1)
				end
			end)
			for i, d in ipairs(dots) do
				if not showDots then break end
				d.Size = UDim2.fromOffset(0, 0)
				local at = math.clamp((xsCache[i] or 0) / w, 0, 1)
				task.delay(at * D * 0.62, function()
					if my ~= animToken then return end
					tween(d, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(10, 10)})
				end)
			end
			for c, f in ipairs(cols) do
				local target = colTargets[c] or f.Size
				f.Size = UDim2.fromOffset(target.X.Offset, 0)
				local at = math.clamp(((c - 0.5) * 3) / w, 0, 1)
				task.delay(at * D * 0.62 + 0.05, function()
					if my ~= animToken then return end
					tween(f, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = target})
				end)
			end
		end

		local function chainVisible()
			local a = card
			while a and not a:IsA("ScreenGui") do
				if a:IsA("GuiObject") and not a.Visible then return false end
				a = a.Parent
			end
			return true
		end

		plot:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			redraw(false)
		end)
		task.defer(function()
			redraw(false)
			local node = card.Parent
			while node and not node:IsA("ScreenGui") do
				if node:IsA("GuiObject") then
					local n = node
					n:GetPropertyChangedSignal("Visible"):Connect(function()
						if n.Visible and chainVisible() then
							task.defer(entrance)
						end
					end)
				end
				node = node.Parent
			end
			if chainVisible() then entrance() end
		end)

		local Chart = {}
		function Chart:Set(newSettings)
			newSettings = newSettings or {}
			if newSettings.Name then
				nameLabel.Text = newSettings.Name
				card:SetAttribute("SearchName", newSettings.Name)
			end
			if newSettings.Points then
				local fresh = {}
				for _, v in ipairs(newSettings.Points) do
					local nv = tonumber(v)
					if nv then fresh[#fresh + 1] = nv end
				end
				if #fresh == 0 then fresh = {0, 0} end
				if #fresh == 1 then fresh = {fresh[1], fresh[1]} end
				while #fresh > maxPoints do table.remove(fresh, 1) end
				if hoverIdx then applyHover(nil) end
				points = fresh
				setValue(fmt(points[#points]))
				redraw(true)
			end
		end
		local function ripple(i)
			local x, y = xsCache[i], ysCache[i]
			if not x or not y then return end
			local r = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(x, y),
				Size = UDim2.fromOffset(12, 12),
				BackgroundColor3 = Theme.AccentSoft,
				BackgroundTransparency = 0.55,
				ZIndex = 3,
				Parent = dotHolder,
			})
			roundFull(r)
			tween(r, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(56, 56), BackgroundTransparency = 1})
			task.delay(0.65, function() r:Destroy() end)
		end

		function Chart:Push(v)
			local nv = tonumber(v)
			if not nv then return end
			if hoverIdx then applyHover(nil) end
			points[#points + 1] = nv
			while #points > maxPoints do table.remove(points, 1) end
			setValue(fmt(points[#points]))
			redraw(true)
			task.delay(0.16, function() ripple(#points) end)
		end
		function Chart:Replay()
			if hoverIdx then applyHover(nil) end
			entrance()
		end
		return Chart
	end

	function tab:CreateBarChart(ChartSettings)
		ChartSettings = ChartSettings or {}
		local function parsePoints(list)
			local v, l = {}, {}
			for _, item in ipairs(list or {}) do
				if type(item) == "table" then
					local nv = tonumber(item.Value)
					if nv then
						v[#v + 1] = nv
						l[#v] = item.Label
					end
				else
					local nv = tonumber(item)
					if nv then v[#v + 1] = nv end
				end
			end
			if #v == 0 then v = {0} end
			return v, l
		end
		local vals, labs = parsePoints(ChartSettings.Points)
		local prefix = ChartSettings.Prefix or ""
		local suffix = ChartSettings.Suffix or ""
		local decimals = ChartSettings.Decimals or 0
		local maxPoints = ChartSettings.MaxPoints or math.max(#vals, 12)
		local hasLabels = next(labs) ~= nil

		local card, nameLabel, valueLabel = chartShell(ChartSettings, hasLabels and 168 or 152)
		local plot = create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(17, 44),
			Size = UDim2.new(1, -34, 1, hasLabels and -74 or -58),
			Parent = card,
		})
		create("Frame", {
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.93,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(1, 0, 0, 1),
			Parent = plot,
		})
		create("Frame", {
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.93,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 1, -1),
			Size = UDim2.new(1, 0, 0, 1),
			Parent = plot,
		})
		local barHolder = create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			Parent = plot,
		})

		local bars, barTargets, labelInsts = {}, {}, {}
		local hoverIdx = nil
		local function fmt(n)
			local str = decimals > 0 and string.format("%." .. decimals .. "f", n) or tostring(math.floor(n + 0.5))
			return prefix .. commafy(str) .. suffix
		end
		local setValue = odometerValue(valueLabel, fmt(vals[#vals]))

		local function redraw(animate)
			local w, h = plot.AbsoluteSize.X, plot.AbsoluteSize.Y
			if w < 24 or h < 24 then return end
			local n = #vals
			local hi = 0
			for _, v in ipairs(vals) do hi = math.max(hi, v) end
			if hi <= 0 then hi = 1 end
			for i = #bars, n + 1, -1 do
				bars[i]:Destroy()
				bars[i] = nil
				barTargets[i] = nil
			end
			for i = #labelInsts, n + 1, -1 do
				labelInsts[i]:Destroy()
				labelInsts[i] = nil
			end
			local slot = w / n
			local barW = math.max(6, math.min(46, math.floor(slot * 0.72)))
			for i = 1, n do
				local b = bars[i]
				local fresh = not b
				if fresh then
					b = create("Frame", {
						AnchorPoint = Vector2.new(0.5, 1),
						BorderSizePixel = 0,
						ZIndex = 2,
						Parent = barHolder,
					})
					paint(b, "BackgroundColor3", "Accent")
					round(b, 6)
					create("UIGradient", {
						Rotation = 90,
						Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(178, 178, 178)),
						Parent = b,
					})
					bars[i] = b
				end
				local bh = math.max(3, math.floor(math.max(vals[i], 0) / hi * (h - 12)))
				local props = {
					Position = UDim2.fromOffset(math.floor(slot * (i - 0.5) + 0.5), h - 1),
					Size = UDim2.fromOffset(barW, bh),
				}
				barTargets[i] = props.Size
				if fresh then
					b.Position = props.Position
					if animate then
						b.Size = UDim2.fromOffset(barW, 0)
						tween(b, TI_MORPH, {Size = props.Size})
					else
						b.Size = props.Size
					end
				elseif animate then
					tween(b, TI_MORPH, props)
				else
					b.Position = props.Position
					b.Size = props.Size
				end
				if hasLabels then
					local lab = labelInsts[i]
					if not lab then
						lab = create("TextLabel", {
							BackgroundTransparency = 1,
							AnchorPoint = Vector2.new(0.5, 0),
							Size = UDim2.fromOffset(math.floor(slot), 12),
							Font = FONT_MEDIUM,
							TextSize = 11,
							TextTruncate = Enum.TextTruncate.AtEnd,
							Parent = plot,
						})
						paint(lab, "TextColor3", "TextMuted")
						labelInsts[i] = lab
					end
					lab.Position = UDim2.new(0, math.floor(slot * (i - 0.5) + 0.5), 1, 3)
					lab.Text = labs[i] or ""
				end
			end
		end

		local function applyHover(i)
			if hoverIdx == i then return end
			if hoverIdx and bars[hoverIdx] then
				bars[hoverIdx].BackgroundColor3 = Theme.Accent
			end
			hoverIdx = i
			if i and bars[i] then
				bars[i].BackgroundColor3 = Theme.AccentSoft
				setValue(fmt(vals[i]))
			else
				setValue(fmt(vals[#vals]))
			end
		end

		card.InputChanged:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			local w = plot.AbsoluteSize.X
			if w < 24 or #vals == 0 then return end
			local rx = input.Position.X - plot.AbsolutePosition.X
			local i = math.clamp(math.floor(rx / (w / #vals)) + 1, 1, #vals)
			applyHover(i)
		end)
		card.MouseLeave:Connect(function()
			applyHover(nil)
		end)

		local animToken = 0
		local function entrance()
			if #bars == 0 then return end
			animToken = animToken + 1
			local my = animToken
			for i, b in ipairs(bars) do
				local target = barTargets[i] or b.Size
				b.Size = UDim2.fromOffset(target.X.Offset, 0)
				task.delay(0.04 + (i - 1) * 0.05, function()
					if my ~= animToken then return end
					tween(b, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = target})
				end)
			end
		end

		plot:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			redraw(false)
		end)
		task.defer(function() redraw(false) end)
		replayOnVisible(card, entrance)

		local Chart = {}
		function Chart:Set(newSettings)
			newSettings = newSettings or {}
			if newSettings.Name then
				nameLabel.Text = newSettings.Name
				card:SetAttribute("SearchName", newSettings.Name)
			end
			if newSettings.Points then
				if hoverIdx then applyHover(nil) end
				vals, labs = parsePoints(newSettings.Points)
				while #vals > maxPoints do
					table.remove(vals, 1)
					table.remove(labs, 1)
				end
				setValue(fmt(vals[#vals]))
				redraw(true)
			end
		end
		function Chart:Push(v, label)
			local nv = tonumber(v)
			if not nv then return end
			if hoverIdx then applyHover(nil) end
			vals[#vals + 1] = nv
			labs[#vals] = label
			while #vals > maxPoints do
				table.remove(vals, 1)
				table.remove(labs, 1)
			end
			setValue(fmt(vals[#vals]))
			redraw(true)
		end
		function Chart:Replay()
			if hoverIdx then applyHover(nil) end
			entrance()
		end
		return Chart
	end

	function tab:CreateStackedChart(ChartSettings)
		ChartSettings = ChartSettings or {}
		local series = {}
		for _, s in ipairs(ChartSettings.Series or {}) do
			series[#series + 1] = tostring(s)
		end
		local colors = {}
		for i = 1, math.max(#series, 1) do
			colors[i] = (ChartSettings.Colors and ChartSettings.Colors[i]) or chartPalette[(i - 1) % #chartPalette + 1]
		end
		local function parseRows(list)
			local out = {}
			for _, r in ipairs(list or {}) do
				local vals = {}
				for _, v in ipairs(r.Values or {}) do
					vals[#vals + 1] = math.max(tonumber(v) or 0, 0)
				end
				out[#out + 1] = {name = r.Name or "", values = vals}
			end
			if #out == 0 then out = {{name = "", values = {1}}} end
			return out
		end
		local rowsData = parseRows(ChartSettings.Rows)
		local prefix = ChartSettings.Prefix or ""
		local suffix = ChartSettings.Suffix or ""

		local cardH = 78 + #rowsData * 34
		local card, nameLabel, valueLabel = chartShell(ChartSettings, cardH)
		local legend = create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(17, 40),
			Size = UDim2.new(1, -34, 0, 18),
			Parent = card,
		})
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 14),
			Parent = legend,
		})
		for i, s in ipairs(series) do
			local item = create("Frame", {
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				LayoutOrder = i,
				Parent = legend,
			})
			local chip = create("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.fromOffset(10, 10),
				BackgroundColor3 = colors[i],
				BorderSizePixel = 0,
				Parent = item,
			})
			roundFull(chip)
			local nm = create("TextLabel", {
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 16, 0.5, 0),
				Size = UDim2.new(0, 0, 0, 14),
				Font = FONT_MEDIUM,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = s,
				Parent = item,
			})
			paint(nm, "TextColor3", "TextSub")
		end
		local rowsHolder = create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(17, 66),
			Size = UDim2.new(1, -34, 1, -80),
			Parent = card,
		})

		local rowInsts = {}
		local segMap = {}
		local hoverKey = nil
		local function fmt(n)
			return prefix .. commafy(tostring(math.floor(n + 0.5))) .. suffix
		end

		local function rebuildRows()
			for _, inst in ipairs(rowInsts) do inst:Destroy() end
			rowInsts = {}
			segMap = {}
			for i, r in ipairs(rowsData) do
				local rf = create("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, (i - 1) * 34),
					Size = UDim2.new(1, 0, 0, 28),
					Parent = rowsHolder,
				})
				local nm = create("TextLabel", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 0, 0.5, 0),
					Size = UDim2.fromOffset(76, 14),
					Font = FONT_MEDIUM,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Text = r.name,
					Parent = rf,
				})
				paint(nm, "TextColor3", "TextBody")
				local track = create("Frame", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 84, 0.5, 0),
					Size = UDim2.new(1, -84, 0, 22),
					Parent = rf,
				})
				local barc = create("Frame", {
					BackgroundTransparency = 1,
					ClipsDescendants = true,
					Size = UDim2.new(0, 0, 1, 0),
					Parent = track,
				})
				round(barc, 6)
				rowInsts[i] = rf
				segMap[i] = {track = track, container = barc, segs = {}}
			end
		end

		local function redraw(animate)
			local hi = 0
			for _, r in ipairs(rowsData) do
				local t = 0
				for _, v in ipairs(r.values) do t = t + v end
				r.total = t
				hi = math.max(hi, t)
			end
			if hi <= 0 then hi = 1 end
			for i, r in ipairs(rowsData) do
				local m = segMap[i]
				if m then
					local trackW = m.track.AbsoluteSize.X
					if trackW < 10 then trackW = 300 end
					local contW = math.floor(trackW * r.total / hi + 0.5)
					local props = {Size = UDim2.new(0, contW, 1, 0)}
					if animate then
						tween(m.container, TI_MORPH, props)
					else
						m.container.Size = props.Size
					end
					for _, sg in ipairs(m.segs) do sg:Destroy() end
					m.segs = {}
					local x = 0
					for k, v in ipairs(r.values) do
						local segW = math.floor(v / math.max(r.total, 0.0001) * contW + 0.5)
						if k == #r.values then segW = contW - x end
						local sg = create("Frame", {
							Position = UDim2.fromOffset(x, 0),
							Size = UDim2.new(0, segW, 1, 0),
							BackgroundColor3 = colors[k] or chartPalette[1],
							BorderSizePixel = 0,
							Parent = m.container,
						})
						m.segs[k] = sg
						x = x + segW
					end
				end
			end
		end

		local function applyHover(key)
			if hoverKey and (not key or key[1] ~= hoverKey[1] or key[2] ~= hoverKey[2]) then
				local m = segMap[hoverKey[1]]
				local sg = m and m.segs[hoverKey[2]]
				if sg then sg.BackgroundColor3 = colors[hoverKey[2]] or chartPalette[1] end
				hoverKey = nil
				valueLabel.Text = ""
			end
			if key then
				local m = segMap[key[1]]
				local sg = m and m.segs[key[2]]
				local v = rowsData[key[1]] and rowsData[key[1]].values[key[2]]
				if sg and v then
					hoverKey = key
					sg.BackgroundColor3 = (colors[key[2]] or chartPalette[1]):Lerp(Color3.fromRGB(255, 255, 255), 0.22)
					valueLabel.Text = fmt(v)
				end
			end
		end

		card.InputChanged:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			local ry = input.Position.Y - rowsHolder.AbsolutePosition.Y
			local i = math.floor(ry / 34) + 1
			local m = segMap[i]
			if not m then
				applyHover(nil)
				return
			end
			local rx = input.Position.X - m.container.AbsolutePosition.X
			if rx < 0 or rx > m.container.AbsoluteSize.X then
				applyHover(nil)
				return
			end
			local x = 0
			for k, sg in ipairs(m.segs) do
				x = x + sg.AbsoluteSize.X
				if rx <= x then
					applyHover({i, k})
					return
				end
			end
			applyHover(nil)
		end)
		card.MouseLeave:Connect(function()
			applyHover(nil)
		end)

		local animToken = 0
		local function entrance()
			animToken = animToken + 1
			local my = animToken
			for i, m in ipairs(segMap) do
				local target = m.container.Size
				m.container.Size = UDim2.new(0, 0, 1, 0)
				task.delay(0.05 + (i - 1) * 0.09, function()
					if my ~= animToken then return end
					tween(m.container, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = target})
				end)
			end
		end

		rowsHolder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			redraw(false)
		end)
		rebuildRows()
		task.defer(function() redraw(false) end)
		replayOnVisible(card, entrance)

		local Chart = {}
		function Chart:Set(newSettings)
			newSettings = newSettings or {}
			if newSettings.Name then
				nameLabel.Text = newSettings.Name
				card:SetAttribute("SearchName", newSettings.Name)
			end
			if newSettings.Rows then
				applyHover(nil)
				rowsData = parseRows(newSettings.Rows)
				rebuildRows()
				redraw(true)
			end
		end
		function Chart:Replay()
			applyHover(nil)
			entrance()
		end
		return Chart
	end


		function tab:CreateSpacer(height)
			local holder = create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, math.clamp(tonumber(height) or 12, 2, 300)),
				LayoutOrder = nextOrder(),
				Parent = page,
			})
			holder:SetAttribute("Structural", true)
			local SpacerValue = {}
			function SpacerValue:Set(newHeight)
				holder.Size = UDim2.new(1, 0, 0, math.clamp(tonumber(newHeight) or 12, 2, 300))
			end
			return SpacerValue
		end
	
		function tab:CreateProgressBar(ProgressSettings)
			ProgressSettings = ProgressSettings or {}
			local maxValue = ProgressSettings.MaxValue or 100
			local card, label, textX = makeCard(page, ProgressSettings.Name, ProgressSettings.Icon, 50)
			descFor(card, ProgressSettings.Description)
			tipFor(card, ProgressSettings.Tooltip)
			hoverable(card)
			label.Size = UDim2.new(0.42, -textX, 0, 18)
	
			local valueLabel = create("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -16, 0.5, 0),
				Size = UDim2.fromOffset(42, 16),
				Font = FONT_REGULAR,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Right,
				Text = "",
				Parent = card,
			})
			paint(valueLabel, "TextColor3", "TextSub")
	
			local track = create("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -66, 0.5, 0),
				Size = UDim2.new(0.4, 0, 0, 10),
				BackgroundColor3 = Color3.fromRGB(47, 47, 47),
			})
			roundFull(track)
			track.Parent = card
	
			local fill = create("Frame", {
				Size = UDim2.new(0, 0, 1, 0),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				Parent = track,
			})
			roundFull(fill)
			create("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Theme.AccentDark),
					ColorSequenceKeypoint.new(1, Theme.Accent),
				}),
				Parent = fill,
			})
	
			local Progress = {CurrentValue = 0}
			local function apply(value, animate)
				value = math.clamp(tonumber(value) or 0, 0, maxValue)
				Progress.CurrentValue = value
				local frac = maxValue > 0 and value / maxValue or 0
				valueLabel.Text = ProgressSettings.Suffix
					and (tostring(math.floor(value + 0.5)) .. ProgressSettings.Suffix)
					or (tostring(math.floor(frac * 100 + 0.5)) .. "%")
				local goal = UDim2.new(frac, 0, 1, 0)
				if animate then
					tween(fill, TI_SMOOTH, {Size = goal})
				else
					fill.Size = goal
				end
			end
			apply(ProgressSettings.CurrentValue or 0, false)
	
			function Progress:Set(value)
				apply(value, true)
			end
			return Progress
		end
	
		function tab:CreateCheckbox(CheckboxSettings)
			CheckboxSettings = CheckboxSettings or {}
			local card = create("Frame", {
				Size = UDim2.new(1, 0, 0, 50),
				LayoutOrder = nextOrder(),
				Parent = page,
			})
			card:SetAttribute("SearchName", CheckboxSettings.Name or "")
			paint(card, "BackgroundColor3", "Card")
			cardBase(card)
			descFor(card, CheckboxSettings.Description)
			tipFor(card, CheckboxSettings.Tooltip)
			hoverable(card)
	
			local box = create("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 15, 0.5, 0),
				Size = UDim2.fromOffset(26, 26),
				BackgroundColor3 = Theme.ToggleTrack,
			})
			round(box, 8)
			local boxStroke = create("UIStroke", {
				Color = Color3.fromRGB(255, 255, 255),
				Transparency = 0.84,
				Parent = box,
			})
			create("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(Color3.fromRGB(255, 255,255), Color3.fromRGB(196, 196, 196)),
				Parent = box,
			})
			box.Parent = card
	
			local check = makeIcon(box, "check", 18, Color3.fromRGB(26, 26, 26), 1)
			check.AnchorPoint = Vector2.new(0.5, 0.5)
			check.Position = UDim2.fromScale(0.5, 0.5)
			check.Size = UDim2.fromOffset(10, 10)
	
			local label = create("TextLabel",{
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 53, 0.5, 0),
				Size = UDim2.new(1, -69, 0, 18),
				Font = FONT_MEDIUM,
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = CheckboxSettings.Name or "",
				Parent = card,
			})
			paint(label, "TextColor3", "TextBody")
	
			local Checkbox = {
				Type = "Checkbox",
				CurrentValue = CheckboxSettings.CurrentValue == true,
			}
	
			local function render(animate)
				local on = Checkbox.CurrentValue
				local info = animate and TI_SMOOTH or TweenInfo.new(0)
				tween(box, info, {BackgroundColor3 = on and Theme.Knob or Theme.ToggleTrack})
				tween(boxStroke, info, {Transparency = on and 1 or 0.84})
				if on then
					if animate then check.Size = UDim2.fromOffset(10, 10) end
					tween(check, info, {ImageTransparency = 0, Size = UDim2.fromOffset(18, 18)})
				else
					tween(check, animate and TI_FAST or TweenInfo.new(0), {ImageTransparency = 1, Size = UDim2.fromOffset(10, 10)})
				end
			end
			render(false)
	
			local clicker = create("TextButton",{
				BackgroundTransparency = 1,
				Text = "",
				Size = UDim2.fromScale(1,1),
				Parent = card,
			})
			clicker.MouseButton1Click:Connect(function()
				Checkbox.CurrentValue = not Checkbox.CurrentValue
				render(true)
				runCallback(CheckboxSettings.Callback, Checkbox.CurrentValue)
				saveConfiguration()
			end)
	
			function Checkbox:Set(value)
				Checkbox.CurrentValue = value == true
				render(true)
				runCallback(CheckboxSettings.Callback, Checkbox.CurrentValue)
				saveConfiguration()
			end
	
			if CheckboxSettings.Flag then
				Checkbox.Flag = CheckboxSettings.Flag
				RayfieldLibrary.Flags[CheckboxSettings.Flag] = Checkbox
			end
			return Checkbox
		end
	
		function tab:CreateRippleButton(ButtonSettings)
			ButtonSettings = ButtonSettings or {}
			local card, label = makeCard(page, ButtonSettings.Name, ButtonSettings.Icon, 50)
			descFor(card, ButtonSettings.Description)
			tipFor(card, ButtonSettings.Tooltip)
			hoverable(card)
	
			local rippleClip = create("CanvasGroup", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 4,
				Parent = card,
			})
			round(rippleClip, 14)
	
			local clicker = create("TextButton", {
				BackgroundTransparency = 1,
				Text = "",
				Size = UDim2.fromScale(1, 1),
				ZIndex = 5,
				Parent = card,
			})
			clicker.InputBegan:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.MouseButton1
					and input.UserInputType ~= Enum.UserInputType.Touch then
					return
				end
				local rx = math.clamp(input.Position.X - card.AbsolutePosition.X, 0, card.AbsoluteSize.X)
				local ry = math.clamp(input.Position.Y - card.AbsolutePosition.Y, 0, card.AbsoluteSize.Y)
				local circle = create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(rx, ry),
					Size = UDim2.fromOffset(0, 0),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 0.88,
					Parent = rippleClip,
				})
				roundFull(circle)
				local span = math.max(card.AbsoluteSize.X, card.AbsoluteSize.Y) * 2.2
				tween(circle, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = UDim2.fromOffset(span, span),
					BackgroundTransparency = 1,
				})
				task.delay(0.6, function()
					circle:Destroy()
				end)
			end)
			clicker.MouseButton1Click:Connect(function()
				runCallback(ButtonSettings.Callback)
			end)
	
			local ButtonValue = {}
			function ButtonValue:Set(newName)
				label.Text = newName
				card:SetAttribute("SearchName", newName or "")
			end
			return ButtonValue
		end
	
		function tab:CreateShimmerLabel(ShimmerSettings)
			ShimmerSettings = ShimmerSettings or {}
			local holder = create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, ShimmerSettings.Height or 34),
				LayoutOrder = nextOrder(),
				Parent = page,
			})
			holder:SetAttribute("SearchName", ShimmerSettings.Text or "")
			local lbl = create("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Font = ShimmerSettings.Bold and FONT_BOLD or FONT_MEDIUM,
				TextSize = ShimmerSettings.TextSize or 20,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Text = ShimmerSettings.Text or "Shimmer",
				Parent = holder,
			})
			local grad = create("UIGradient", {
				Offset = Vector2.new(-1, 0),
				Rotation = ShimmerSettings.Rotation or 8,
				Parent = lbl,
			})
	
			local spread = math.clamp(ShimmerSettings.Spread or 0.2, 0.05, 0.45)
			local speed = math.clamp(ShimmerSettings.Speed or 1.4, 0.3, 6)
			local rest = ShimmerSettings.Rest or 0.35
	
			local function rebuild()
				local base = Color3.fromRGB(110, 110, 110)
				local glow = Color3.fromRGB(190, 190, 190)
				local core = Color3.fromRGB(255, 255, 255)
				local lo = 0.5 - spread
				local hi = 0.5 + spread
				grad.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, base),
					ColorSequenceKeypoint.new(math.max(0.001, lo), base),
					ColorSequenceKeypoint.new(0.5 - spread * 0.4, glow),
					ColorSequenceKeypoint.new(0.5, core),
					ColorSequenceKeypoint.new(0.5 + spread * 0.4, glow),
					ColorSequenceKeypoint.new(math.min(0.999, hi), base),
					ColorSequenceKeypoint.new(1, base),
				})
			end
			rebuild()
	
			task.spawn(function()
				while grad.Parent do
					grad.Offset = Vector2.new(-1, 0)
					local t = tween(grad, TweenInfo.new(speed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Offset = Vector2.new(1, 0)})
					t.Completed:Wait()
					task.wait(rest)
				end
			end)
	
			local Shimmer = {}
			function Shimmer:Set(newText)
				lbl.Text = newText or lbl.Text
				holder:SetAttribute("SearchName", lbl.Text)
			end
			function Shimmer:SetSpeed(newSpeed)
				speed = math.clamp(tonumber(newSpeed) or speed, 0.3, 6)
			end
			function Shimmer:SetSpread(newSpread)
				spread = math.clamp(tonumber(newSpread) or spread, 0.05, 0.45)
				rebuild()
			end
			return Shimmer
		end
	
		function tab:CreateScrollHint(HintSettings)
			HintSettings = HintSettings or {}
			local holder = create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 40),
				LayoutOrder = nextOrder(),
				Parent = page,
			})
			holder:SetAttribute("SearchName", HintSettings.Text or "")
	
			local center = create("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				Parent = holder,
			})
			create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 10),
				Parent = center,
			})
			local lbl = create("TextLabel", {
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				Font = FONT_MEDIUM,
				TextSize = 15,
				Text = HintSettings.Text or "Scroll to see more",
				LayoutOrder = 1,
				Parent = center,
			})
			paint(lbl, "TextColor3", "TextBody")
	
			local arrowWell = create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(16, 24),
				LayoutOrder = 2,
				Parent = center,
			})
			local arrow = makeIcon(arrowWell, HintSettings.Icon or "arrow-down", 16, Theme.TextBody, 0.1)
			if arrow then
				arrow.AnchorPoint = Vector2.new(0.5, 0)
				arrow.Position = UDim2.new(0.5, 0, 0, 0)
				tween(arrow, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
					Position = UDim2.new(0.5, 0, 0, 7),
				})
			end
	
			local Hint = {}
			function Hint:Set(newText)
				lbl.Text = newText or lbl.Text
				holder:SetAttribute("SearchName", lbl.Text)
			end
			return Hint
		end
	
		function tab:CreateCopyButton(CopySettings)
			CopySettings = CopySettings or {}
			local card, label = makeCard(page, CopySettings.Name, CopySettings.Icon, 50)
			descFor(card, CopySettings.Description)
			tipFor(card, CopySettings.Tooltip)
			hoverable(card)
	
			local well = create("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(30, 30),
				BackgroundColor3 = Theme.Knob,
			})
			round(well, 9)
			create("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(Color3.fromRGB(255, 255,255), Color3.fromRGB(196, 196, 196)),
				Parent = well,
			})
			well.Parent = card
	
			local wellScale = create("UIScale", {Parent = well})
	
			local copyIcon = makeIcon(well, "copy", 16, Color3.fromRGB(26, 26, 26), 0)
			copyIcon.AnchorPoint = Vector2.new(0.5, 0.5)
			copyIcon.Position = UDim2.fromScale(0.5, 0.5)
			local checkIcon = makeIcon(well, "check", 16, Color3.fromRGB(26, 26, 26), 1)
			checkIcon.AnchorPoint = Vector2.new(0.5, 0.5)
			checkIcon.Position = UDim2.fromScale(0.5, 0.5)
			checkIcon.Size = UDim2.fromOffset(10, 10)
	
			local CopyValue = {
				CurrentValue = tostring(CopySettings.Text or CopySettings.Value or ""),
			}
	
			local copied = false
			local function copyToClipboard(text)
				return pcall(function()
					if type(setclipboard) == "function" then
						setclipboard(text)
					elseif type(toclipboard) == "function" then
						toclipboard(text)
					elseif type(writeclipboard) == "function" then
						writeclipboard(text)
					elseif type(Clipboard) == "table" and type(Clipboard.set) == "function" then
						Clipboard.set(text)
					else
						error("clipboard is not available")
					end
				end)
			end
	
			local clicker = create("TextButton", {
				BackgroundTransparency = 1,
				Text = "",
				Size = UDim2.fromScale(1, 1),
				Parent = card,
			})
			clicker.MouseButton1Click:Connect(function()
				if copied then return end
				local ok = copyToClipboard(CopyValue.CurrentValue)
				if not ok then
					warn("Rayfield Gen3 | Copy failed, no clipboard function available")
					return
				end
				copied = true
				tween(wellScale, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.85})
				task.delay(0.09, function()
					tween(wellScale, TI_SMOOTH, {Scale = 1})
				end)
				tween(copyIcon, TI_FAST, {ImageTransparency = 1, Size = UDim2.fromOffset(10, 10)})
				tween(checkIcon, TI_SMOOTH, {ImageTransparency = 0, Size = UDim2.fromOffset(16, 16)})
				runCallback(CopySettings.Callback, CopyValue.CurrentValue)
				task.delay(2, function()
					if not well.Parent then return end
					copied = false
					tween(checkIcon, TI_FAST, {ImageTransparency = 1, Size = UDim2.fromOffset(10, 10)})
					tween(copyIcon, TI_SMOOTH, {ImageTransparency = 0, Size = UDim2.fromOffset(16, 16)})
				end)
			end)
	
			function CopyValue:Set(newText)
				CopyValue.CurrentValue = tostring(newText or "")
			end
			function CopyValue:SetName(newName)
				label.Text = newName or ""
				card:SetAttribute("SearchName", newName or "")
			end
			return CopyValue
		end
	
		function tab:CreateFlipButton(FlipSettings)
			FlipSettings = FlipSettings or {}
			local frontText = FlipSettings.Front or FlipSettings.Name or "Front"
			local backText = FlipSettings.Back or frontText
	
			local card = create("Frame", {
				Size = UDim2.new(1, 0, 0, 50),
				LayoutOrder = nextOrder(),
				ClipsDescendants = true,
				Parent = page,
			})
			card:SetAttribute("SearchName", frontText .. " " .. backText)
			paint(card, "BackgroundColor3", "Card")
			cardBase(card)
			descFor(card, FlipSettings.Description)
			tipFor(card, FlipSettings.Tooltip)
	
			local function makeFace(text, dark)
				local layer = create("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Parent = card,
				})
				local lbl = create("TextLabel", {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Font = FONT_MEDIUM,
					TextSize = 16,
					Text = text,
					Parent = layer,
				})
				if dark then
					lbl.TextColor3 = Color3.fromRGB(28, 28, 28)
				else
					paint(lbl, "TextColor3", "TextBody")
				end
				return layer, lbl
			end
			local frontLayer, frontLabel = makeFace(frontText, false)
			local backLayer, backLabel = makeFace(backText, true)
			backLayer.Position = UDim2.fromScale(0, -1)
	
			local flipped = false
			local function render(state)
				if flipped == state then return end
				flipped = state
				tween(frontLayer, TI_MORPH, {Position = state and UDim2.fromScale(0, 1) or UDim2.fromScale(0, 0)})
				tween(backLayer, TI_MORPH, {Position = state and UDim2.fromScale(0, 0) or UDim2.fromScale(0, -1)})
				tween(card, TI_MORPH, {BackgroundColor3 = state and Theme.Knob or Theme.Card})
			end
			card.MouseEnter:Connect(function() render(true) end)
			card.MouseLeave:Connect(function() render(false) end)
	
			local clicker = create("TextButton", {
				BackgroundTransparency = 1,
				Text = "",
				Size = UDim2.fromScale(1, 1),
				Parent = card,
			})
			clicker.MouseButton1Click:Connect(function()
				runCallback(FlipSettings.Callback)
			end)
	
			local FlipValue = {}
			function FlipValue:Set(newSettings)
				newSettings = newSettings or {}
				if newSettings.Front then
					frontLabel.Text = newSettings.Front
				end
				if newSettings.Back then
					backLabel.Text = newSettings.Back
				end
				card:SetAttribute("SearchName", frontLabel.Text .. " " .. backLabel.Text)
			end
			return FlipValue
		end
	
		function tab:CreateHoldButton(HoldSettings)
			HoldSettings = HoldSettings or {}
			local duration = math.clamp(tonumber(HoldSettings.Duration) or 1.5, 0.2, 10)
			local card, label = makeCard(page, HoldSettings.Name, HoldSettings.Icon, 50)
			descFor(card, HoldSettings.Description or "Press and hold to confirm.")
			tipFor(card, HoldSettings.Tooltip)
			hoverable(card)
	
			-- CanvasGroup so the sweeping fill is clipped to the card's rounded
			-- corners (ClipsDescendants ignores UICorner, a CanvasGroup does not).
			local fillClip = create("CanvasGroup", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 0,
				Parent = card,
			})
			round(fillClip, GenStyle.cardRadius)
			local fill = create("Frame", {
				BackgroundColor3 = Theme.Accent,
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 0, 1, 0),
				ZIndex = 0,
				Parent = fillClip,
			})
			if label then label.ZIndex = 2 end
	
			local clicker = create("TextButton", {
				BackgroundTransparency = 1,
				Text = "",
				Size = UDim2.fromScale(1, 1),
				ZIndex = 3,
				Parent = card,
			})
	
			-- a confirm checkmark that pops in on completion (sits on the right so
			-- it never covers the label)
			local checkIcon = makeIcon(card, "check", 20, Theme.Accent, 1)
			local checkScale
			if checkIcon then
				checkIcon.AnchorPoint = Vector2.new(1, 0.5)
				checkIcon.Position = UDim2.new(1, -16, 0.5, 0)
				checkIcon.ZIndex = 4
				checkScale = create("UIScale", { Scale = 0.5, Parent = checkIcon })
			end
	
			local holding, token = false, 0
			local function reset(animate)
				tween(fill, animate and TI_MED or TweenInfo.new(0), {Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 0.55})
			end
	
			-- plays exactly once when the hold is completed, then fully clears
			-- itself; it never replays on its own, only a fresh hold restarts it
			local function complete(myToken)
				-- flash the full fill bright, then dissolve it away (not shrink)
				tween(fill, TweenInfo.new(0.08, Enum.EasingStyle.Quad), {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.03})
				task.delay(0.1, function()
					if myToken ~= token then return end
					tween(fill, TI_MED, {BackgroundTransparency = 1})
					task.delay(0.3, function()
						if myToken == token then reset(false) end
					end)
				end)
				-- checkmark pop
				if checkIcon and checkScale then
					checkScale.Scale = 0.5
					checkIcon.ImageTransparency = 1
					tween(checkScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
					tween(checkIcon, TI_FAST, {ImageTransparency = 0})
					task.delay(0.55, function()
						if checkIcon and myToken == token then tween(checkIcon, TI_MED, {ImageTransparency = 1}) end
					end)
				end
				-- professional completion notification (opt out with Notify = false)
				if HoldSettings.Notify ~= false then
					RayfieldLibrary:Notify({
						Title = HoldSettings.CompletionTitle or HoldSettings.Name or "Confirmed",
						Content = HoldSettings.CompletionText or "Hold complete.",
						Duration = HoldSettings.NotifyDuration or 3,
						Icon = HoldSettings.CompletionIcon or "circle-check",
					})
				end
				runCallback(HoldSettings.Callback)
			end
	
			clicker.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					holding = true
					token += 1
					local myToken = token
					-- sweep the fill and firm it up slightly as it goes
					tween(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.35})
					task.delay(duration, function()
						if holding and myToken == token then
							holding = false
							complete(myToken)
						end
					end)
				end
			end)
			local function releaseInput(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					if holding then
						holding = false
						token += 1
						reset(true)
					end
				end
			end
			clicker.InputEnded:Connect(releaseInput)
			clicker.MouseLeave:Connect(function()
				if holding then holding = false; token += 1; reset(true) end
			end)
	
			local HoldValue = {}
			function HoldValue:Set(newName) label.Text = newName; card:SetAttribute("SearchName", newName or "") end
			return HoldValue
		end
	
		function tab:CreateChangelog(LogSettings)
			LogSettings = LogSettings or {}
			local muted = Color3.fromRGB(150, 152, 160)
			local TAGS = {
				["+"] = { color = Color3.fromRGB(110, 192, 142), word = "ADDED" },
				["-"] = { color = Color3.fromRGB(214, 120, 120), word = "REMOVED" },
				["~"] = { color = Color3.fromRGB(220, 180, 112), word = "CHANGED" },
				["!"] = { color = Color3.fromRGB(122, 166, 226), word = "FIXED" },
				["*"] = { color = muted, word = "NOTE" },
			}
	
			-- refined release-notes panel: a header, a hairline, then a timeline
			-- of entries with a small node dot, small-caps category, and body text
			local card = create("Frame", {
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				LayoutOrder = nextOrder(),
				Parent = page,
			})
			card:SetAttribute("SearchName", (LogSettings.Title or "changelog"))
			paint(card, "BackgroundColor3", "Card")
			cardBase(card)
			padAll(card, 17, 20, 16, 20)
			create("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 14),
				Parent = card,
			})
	
			-- header: title on the left, a quiet version / date on the right
			local head = create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 24),
				LayoutOrder = 1,
				Parent = card,
			})
			local htitle = create("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.new(0.6, 0, 1, 0),
				Font = FONT_BOLD,
				TextSize = 18,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = LogSettings.Title or "Update Log",
				Parent = head,
			})
			paint(htitle, "TextColor3", "TextTitle")
			local metaParts = {}
			if LogSettings.Version then table.insert(metaParts, tostring(LogSettings.Version)) end
			if LogSettings.Date then table.insert(metaParts, tostring(LogSettings.Date)) end
			if #metaParts > 0 then
				local meta = create("TextLabel", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.new(0.4, 0, 1, 0),
					Font = FONT_MEDIUM,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Right,
					Text = table.concat(metaParts, "  \u{00B7}  "),
					Parent = head,
				})
				paint(meta, "TextColor3", "TextSub")
			end
			create("Frame", {
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 0.92,
				BorderSizePixel = 0,
				LayoutOrder = 2,
				Parent = card,
			})
	
			for i, e in ipairs(LogSettings.Entries or {}) do
				local etype = (type(e) == "table" and (e.Type or e.Tag)) or "*"
				local text = (type(e) == "table" and e.Text) or tostring(e)
				local m = TAGS[etype] or TAGS["*"]
				local word = (type(e) == "table" and e.Label) or m.word
	
				local row = create("Frame", {
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.Y,
					Size = UDim2.new(1, 0, 0, 18),
					LayoutOrder = i + 2,
					Parent = card,
				})
				row:SetAttribute("SearchName", text)
				-- The body is top-aligned; its first line is centered at ~LINE/2.
				-- The dot and category are centered on that same line so all three
				-- align, and multi-line entries keep wrapping cleanly below.
				local LINE = 18
				-- timeline node dot, on the first line
				local dot = create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0, 4, 0, LINE / 2),
					Size = UDim2.fromOffset(7, 7),
					BackgroundColor3 = m.color,
					BorderSizePixel = 0,
					Parent = row,
				})
				roundFull(dot)
				-- small-caps category, quietly colored
				create("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(18, 0),
					Size = UDim2.new(0, 74, 0, LINE),
					Font = FONT_BOLD,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					Text = string.upper(tostring(word)),
					TextColor3 = m.color:Lerp(muted, 0.35),
					Parent = row,
				})
				-- body text, top-aligned so the first line sits in the LINE box
				local lbl = create("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(100, 0),
					Size = UDim2.new(1, -100, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Font = FONT_MEDIUM,
					TextSize = 14,
					LineHeight = 1.28,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextWrapped = true,
					Text = text,
					Parent = row,
				})
				paint(lbl, "TextColor3", "TextBody")
			end
	
			local LogValue = {}
			return LogValue
		end
	
		function tab:CreateCollapsibleSection(SectionSettings)
			SectionSettings = SectionSettings or {}
			local name = SectionSettings.Name or SectionSettings.Title or "Section"
			local open = SectionSettings.Open ~= false
	
			local header, hlabel = makeCard(page, name, SectionSettings.Icon, 42)
			header.BackgroundTransparency = 0.4
			if hlabel then hlabel.FontFace = FONT_BOLD end
			hoverable(header)
			local chevron = create("ImageLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -14, 0.5, 0),
				Size = UDim2.fromOffset(16, 16),
				ImageColor3 = Theme.TextSub,
				Parent = header,
			})
			applyLucide(chevron, {"chevron-down"})
			local hclick = create("TextButton", {
				BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), Parent = header,
			})
	
			local content = create("Frame", {
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				LayoutOrder = nextOrder(),
				Parent = page,
			})
			content:SetAttribute("Composite", true)
			create("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
				Parent = content,
			})
	
			local function apply(animate)
				if open then
					content.Visible = true
					content.AutomaticSize = Enum.AutomaticSize.Y
				else
					content.AutomaticSize = Enum.AutomaticSize.None
					content.Size = UDim2.new(1, 0, 0, 0)
					content.Visible = false
				end
				tween(chevron, animate and TI_MED or TweenInfo.new(0), {Rotation = open and 0 or -90})
			end
			apply(false)
			hclick.MouseButton1Click:Connect(function()
				open = not open
				apply(true)
			end)
	
			local api = buildTabAPI(content, false)
			function api:SetOpen(state) open = state and true or false; apply(true) end
			function api:Toggle() open = not open; apply(true) end
			function api:IsOpen() return open end
			return api
		end
	
		function tab:CreateSpoiler(SpoilerSettings)
			SpoilerSettings = SpoilerSettings or {}
			local name = SpoilerSettings.Name or SpoilerSettings.Title or "Spoiler"
			local revealed = SpoilerSettings.Revealed == true
			local SPOIL_TW = TweenInfo.new(0.36, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	
			local card = create("Frame", {
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				LayoutOrder = nextOrder(),
				Parent = page,
			})
			card:SetAttribute("SearchName", name .. " " .. tostring(SpoilerSettings.Text or ""))
			paint(card, "BackgroundColor3", "Card")
			cardBase(card)
			padAll(card, 12, 12, 12, 14)
			create("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 10),
				Parent = card,
			})
	
			-- header: label on the left, an eye toggle on the right
			local header = create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 18),
				LayoutOrder = 1,
				Parent = card,
			})
			local hlabel = create("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.new(1, -30, 0, 18),
				Font = FONT_MEDIUM,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = name,
				Parent = header,
			})
			paint(hlabel, "TextColor3", "TextBody")
			local eyeBtn = create("TextButton", {
				BackgroundTransparency = 1,
				Text = "",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(24, 24),
				Parent = header,
			})
			local eyeIcon = makeIcon(eyeBtn, "eye-off", 17, Theme.TextSub)
			if eyeIcon then
				eyeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
				eyeIcon.Position = UDim2.fromScale(0.5, 0.5)
			end
			eyeBtn.MouseEnter:Connect(function() if eyeIcon then tween(eyeIcon, TI_FAST, { ImageColor3 = Theme.TextTitle }) end end)
			eyeBtn.MouseLeave:Connect(function() if eyeIcon then tween(eyeIcon, TI_FAST, { ImageColor3 = revealed and Theme.Accent or Theme.TextSub }) end end)
	
			-- the stage clips to a height we animate between the cover bar (44px) and
			-- the full content, so reveal/hide is a smooth unfold instead of a snap.
			local stage = create("Frame", {
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				AutomaticSize = Enum.AutomaticSize.None,
				Size = UDim2.new(1, 0, 0, 44),
				LayoutOrder = 2,
				Parent = card,
			})
	
			-- the real content (text and/or nested elements); always laid out inside
			-- the stage, revealed as the stage grows
			local content = create("Frame", {
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.new(1, 0, 0, 0),
				ZIndex = 1,
				Parent = stage,
			})
			create("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
				Parent = content,
			})
			if SpoilerSettings.Text and SpoilerSettings.Text ~= "" then
				local txt = create("TextLabel", {
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.Y,
					Size = UDim2.new(1, 0, 0, 0),
					Font = FONT_REGULAR,
					TextSize = 14,
					LineHeight = 1.14,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = SpoilerSettings.Text,
					LayoutOrder = 1,
					Parent = content,
				})
				paint(txt, "TextColor3", "TextBody")
			end
			local inner = create("Frame", {
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				LayoutOrder = 2,
				Parent = content,
			})
			create("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
				Parent = inner,
			})
	
			-- the redacted cover bar overlays the top of the stage and peels up on reveal
			local coverBar = create("Frame", {
				Size = UDim2.new(1, 0, 0, 44),
				Position = UDim2.fromOffset(0, 0),
				BackgroundColor3 = Theme.CardInset,
				ZIndex = 3,
				Parent = stage,
			})
			paint(coverBar, "BackgroundColor3", "CardInset")
			round(coverBar, math.max(6, GenStyle.cardRadius - 2))
			create("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(232, 232, 232)),
				Parent = coverBar,
			})
			local coverStroke = create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.9, Thickness = 1, Parent = coverBar })
			paint(coverStroke, "Color", "Stroke")
			local pill = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 0, 28),
				BackgroundColor3 = Theme.CardHover,
				ZIndex = 3,
				Parent = coverBar,
			})
			paint(pill, "BackgroundColor3", "CardHover")
			roundFull(pill)
			create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.86, Thickness = 1, Parent = pill })
			local pillScale = create("UIScale", { Scale = 1, Parent = pill })
			create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 7),
				Parent = pill,
			})
			create("UIPadding", { PaddingLeft = UDim.new(0, 13), PaddingRight = UDim.new(0, 15), Parent = pill })
			local pillIcon = makeIcon(pill, "eye-off", 15, Theme.Accent)
			if pillIcon then pillIcon.LayoutOrder = 1; pillIcon.ZIndex = 3 end
			paint(pillIcon, "ImageColor3", "Accent")
			local pillLabel = create("TextLabel", {
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 0, 18),
				Font = FONT_MEDIUM,
				TextSize = 13,
				Text = SpoilerSettings.RevealText or "Spoiler, tap to reveal",
				LayoutOrder = 2,
				ZIndex = 3,
				Parent = pill,
			})
			paint(pillLabel, "TextColor3", "TextBody")
			local coverBtn = create("TextButton", {
				BackgroundTransparency = 1,
				Text = "",
				Size = UDim2.fromScale(1, 1),
				ZIndex = 4,
				Parent = coverBar,
			})
			coverBtn.MouseEnter:Connect(function()
				tween(coverBar, TI_FAST, { BackgroundColor3 = Theme.CardHover })
				tween(pillScale, TI_FAST, { Scale = 1.04 })
			end)
			coverBtn.MouseLeave:Connect(function()
				tween(coverBar, TI_FAST, { BackgroundColor3 = Theme.CardInset })
				tween(pillScale, TI_FAST, { Scale = 1 })
			end)
	
			local sEpoch = 0
			local function apply(state, animate)
				revealed = state and true or false
				sEpoch = sEpoch + 1
				local e = sEpoch
				if eyeIcon then
					applyLucide(eyeIcon, revealed and "eye" or "eye-off")
					eyeIcon.ImageColor3 = revealed and Theme.Accent or Theme.TextSub
				end
				if revealed then
					coverBtn.Active = false
					if animate then
						-- clamp to the cover height so a pre-layout (0px) measure never
						-- makes the stage tween backwards to 1px
						local H = math.max(content.AbsoluteSize.Y, 44)
						stage.AutomaticSize = Enum.AutomaticSize.None
						stage.Size = UDim2.new(1, 0, 0, math.max(stage.AbsoluteSize.Y, 44))
						coverBar.Visible = true
						coverBar.Position = UDim2.fromOffset(0, 0)
						tween(stage, SPOIL_TW, { Size = UDim2.new(1, 0, 0, H) })
						tween(coverBar, SPOIL_TW, { Position = UDim2.fromOffset(0, -50) })
						task.delay(0.38, function()
							if e == sEpoch and revealed then
								coverBar.Visible = false
								-- reset the offset to 0 so the size floor doesn't pin the
								-- stage taller than the content if it later shrinks
								stage.Size = UDim2.new(1, 0, 0, 0)
								stage.AutomaticSize = Enum.AutomaticSize.Y
							end
						end)
					else
						coverBar.Visible = false
						stage.AutomaticSize = Enum.AutomaticSize.Y
						stage.Size = UDim2.new(1, 0, 0, 0)
					end
				else
					coverBtn.Active = true
					if animate then
						-- start the collapse from the stage's current (possibly mid-tween)
						-- height, not the full content height, to avoid an upward pop
						local curH = math.max(stage.AbsoluteSize.Y, 44)
						stage.AutomaticSize = Enum.AutomaticSize.None
						stage.Size = UDim2.new(1, 0, 0, curH)
						coverBar.Visible = true
						coverBar.Position = UDim2.fromOffset(0, -50)
						coverBar.BackgroundColor3 = Theme.CardInset -- clear any lingering hover tint
						pillScale.Scale = 1
						tween(coverBar, SPOIL_TW, { Position = UDim2.fromOffset(0, 0) })
						tween(stage, SPOIL_TW, { Size = UDim2.new(1, 0, 0, 44) })
					else
						stage.AutomaticSize = Enum.AutomaticSize.None
						stage.Size = UDim2.new(1, 0, 0, 44)
						coverBar.Visible = true
						coverBar.Position = UDim2.fromOffset(0, 0)
					end
				end
			end
			apply(revealed, false)
	
			coverBtn.MouseButton1Click:Connect(function() apply(true, true) end)
			eyeBtn.MouseButton1Click:Connect(function() apply(not revealed, true) end)
	
			local api = buildTabAPI(inner, false)
			api.Card = card
			function api:Reveal() if not revealed then apply(true, true) end end
			function api:Hide() if revealed then apply(false, true) end end
			function api:Toggle() apply(not revealed, true) end
			function api:IsRevealed() return revealed end
			function api:SetText(t)
				for _, child in ipairs(content:GetChildren()) do
					if child:IsA("TextLabel") then child.Text = tostring(t or ""); break end
				end
			end
			return api
		end
	
		function tab:CreateSegmentedPicker(PickerSettings)
			PickerSettings = PickerSettings or {}
			local options = {}
			for i, opt in ipairs(PickerSettings.Options or {}) do
				if type(opt) == "string" then
					options[i] = {Name = opt}
				else
					options[i] = {Name = opt.Name or ("Option " .. i), Subs = opt.Options}
				end
			end
			if #options == 0 then
				options = {{Name = "A"}, {Name = "B"}}
			end
	
			local card = create("Frame", {
				Size = UDim2.new(1, 0, 0, 58),
				LayoutOrder = nextOrder(),
				Parent = page,
			})
			card:SetAttribute("SearchName", PickerSettings.Name or "")
			paint(card, "BackgroundColor3", "Card")
			cardBase(card)
			descFor(card, PickerSettings.Description)
			tipFor(card, PickerSettings.Tooltip)
	
			local track = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -20, 0, 42),
				BackgroundColor3 = Theme.CardInset,
				Parent = card,
			})
			roundFull(track)
	
			local indicator = create("Frame", {
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				ZIndex = 2,
				Parent = track,
			})
			roundFull(indicator)
			create("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(224, 224, 224)),
				Parent = indicator,
			})
	
			local Picker = {CurrentOption = nil, CurrentSub = nil}
			local selMain = 1
			local segs = {}
	
			local function geometry()
				local n = #options
				local rects = {}
				local sel = options[selMain]
				if sel.Subs then
					local wSel = n == 1 and 1 or 0.62
					local wOther = n == 1 and 0 or (1 - wSel) / (n - 1)
					local x = 0
					for i = 1, n do
						local w = (i == selMain) and wSel or wOther
						rects[i] = {x = x, w = w}
						x = x + w
					end
				else
					for i = 1, n do
						rects[i] = {x = (i - 1) / n, w = 1 / n}
					end
				end
				return rects
			end
	
			local function relayout(animate)
				local rects = geometry()
				local r = rects[selMain]
				local goalPos = UDim2.new(r.x, 4, 0, 4)
				local goalSize = UDim2.new(r.w, -8, 1, -8)
				if animate then
					tween(indicator, TI_MORPH, {Position = goalPos, Size = goalSize})
				else
					indicator.Position = goalPos
					indicator.Size = goalSize
				end
				for i, seg in ipairs(segs) do
					local rect = rects[i]
					local pos = UDim2.new(rect.x, 0, 0, 0)
					local size = UDim2.new(rect.w, 0, 1, 0)
					if animate then
						tween(seg.Zone, TI_MORPH, {Position = pos, Size = size})
					else
						seg.Zone.Position = pos
						seg.Zone.Size = size
					end
					local isSel = i == selMain
					local hasSubsOpen = isSel and options[i].Subs ~= nil
					tween(seg.Label, TI_MED, {
						TextTransparency = hasSubsOpen and 1 or 0,
						TextColor3 = isSel and Color3.fromRGB(28, 28, 28) or Theme.TextSub,
					})
					if seg.SubHolder then
						seg.SubHolder.Visible = true
						for _, s in ipairs(seg.SubLabels) do
							tween(s, TI_MED, {TextTransparency = hasSubsOpen and 0 or 1})
						end
						tween(seg.SubIndicator, TI_MED, {BackgroundTransparency = hasSubsOpen and 0 or 1})
						if not hasSubsOpen then
							task.delay(0.28, function()
								if selMain ~= i then seg.SubHolder.Visible = false end
							end)
						end
					end
				end
			end
	
			local function report(silent)
				local opt = options[selMain]
				Picker.CurrentOption = opt.Name
				Picker.CurrentSub = opt.Subs and opt.Subs[segs[selMain].SubSel] or nil
				if not silent then
					runCallback(PickerSettings.Callback, Picker.CurrentOption, Picker.CurrentSub)
				end
			end
	
			for i, opt in ipairs(options) do
				local zone = create("Frame", {
					BackgroundTransparency = 1,
					ZIndex = 3,
					Parent = track,
				})
				local label = create("TextButton", {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Font = FONT_MEDIUM,
					TextSize = 14,
					TextColor3 = Theme.TextSub,
					Text = opt.Name,
					ZIndex = 4,
					Parent = zone,
				})
				local seg = {Zone = zone, Label = label, SubSel = 1}
				label.MouseButton1Click:Connect(function()
					if selMain ~= i then
						selMain = i
						relayout(true)
						report()
					end
				end)
				if opt.Subs then
					local subHolder = create("Frame", {
						BackgroundTransparency = 1,
						Position = UDim2.new(0, 6, 0, 6),
						Size = UDim2.new(1, -12, 1, -12),
						Visible = false,
						ZIndex = 5,
						Parent = zone,
					})
					local subIndicator = create("Frame", {
						BackgroundColor3 = Color3.fromRGB(28, 28, 28),
						BackgroundTransparency = 1,
						ZIndex = 5,
						Parent = subHolder,
					})
					roundFull(subIndicator)
					seg.SubHolder = subHolder
					seg.SubIndicator = subIndicator
					seg.SubLabels = {}
					local m = #opt.Subs
					local function subGoal()
						return UDim2.new((seg.SubSel - 1) / m, 0, 0, 0), UDim2.new(1 / m, 0, 1, 0)
					end
					for j, subName in ipairs(opt.Subs) do
						local sbtn = create("TextButton", {
							BackgroundTransparency = 1,
							Position = UDim2.new((j - 1) / m, 0, 0, 0),
							Size = UDim2.new(1 / m, 0, 1, 0),
							Font = FONT_MEDIUM,
							TextSize = 13,
							TextColor3 = Color3.fromRGB(28, 28, 28),
							TextTransparency = 1,
							Text = subName,
							ZIndex = 6,
							Parent = subHolder,
						})
						seg.SubLabels[j] = sbtn
						sbtn.MouseButton1Click:Connect(function()
							if selMain ~= i then return end
							seg.SubSel = j
							local p, s = subGoal()
							tween(subIndicator, TI_MORPH, {Position = p, Size = s})
							for k, other in ipairs(seg.SubLabels) do
								tween(other, TI_MED, {TextColor3 = k == j and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(28, 28, 28)})
							end
							report()
						end)
					end
					local p, s = subGoal()
					subIndicator.Position = p
					subIndicator.Size = s
					seg.SubLabels[seg.SubSel].TextColor3 = Color3.fromRGB(255, 255, 255)
				end
				segs[i] = seg
			end
	
			local function findMain(name)
				for i, opt in ipairs(options) do
					if opt.Name == name then return i end
				end
			end
			if PickerSettings.CurrentOption then
				local want = PickerSettings.CurrentOption
				local mainName = type(want) == "table" and want[1] or want
				local subName = type(want) == "table" and want[2] or nil
				local mi = findMain(mainName)
				if mi then
					selMain = mi
					if subName and options[mi].Subs then
						for j, s in ipairs(options[mi].Subs) do
							if s == subName then segs[mi].SubSel = j end
						end
						local m = #options[mi].Subs
						segs[mi].SubIndicator.Position = UDim2.new((segs[mi].SubSel - 1) / m, 0, 0, 0)
						segs[mi].SubIndicator.Size = UDim2.new(1 / m, 0, 1, 0)
						for k, other in ipairs(segs[mi].SubLabels) do
							other.TextColor3 = k == segs[mi].SubSel and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(28, 28, 28)
						end
					end
				end
			end
			relayout(false)
			report(true)
	
			function Picker:Set(mainName, subName)
				local mi = findMain(mainName)
				if not mi then return end
				selMain = mi
				if subName and options[mi].Subs then
					for j, s in ipairs(options[mi].Subs) do
						if s == subName then segs[mi].SubSel = j end
					end
					local m = #options[mi].Subs
					tween(segs[mi].SubIndicator, TI_MORPH, {
						Position = UDim2.new((segs[mi].SubSel - 1) / m, 0, 0, 0),
						Size = UDim2.new(1 / m, 0, 1, 0),
					})
					for k, other in ipairs(segs[mi].SubLabels) do
						tween(other, TI_MED, {TextColor3 = k == segs[mi].SubSel and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(28, 28, 28)})
					end
				end
				relayout(true)
				report()
			end
			return Picker
		end
	
		function tab:CreateCursorTag(TagSettings)
			TagSettings = TagSettings or {}
			local scope = TagSettings.Scope or "Area"
			local offX = (TagSettings.Offset and TagSettings.Offset.X) or 14
			local offY = (TagSettings.Offset and TagSettings.Offset.Y) or 18
	
			local card = create("Frame", {
				Size = UDim2.new(1, 0, 0, TagSettings.Height or 110),
				LayoutOrder = nextOrder(),
				Parent = page,
			})
			card:SetAttribute("SearchName", TagSettings.Text or "")
			paint(card, "BackgroundColor3", "Card")
			cardBase(card)
	
			local hint = create("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Font = FONT_REGULAR,
				TextSize = 14,
				TextTransparency = 0.35,
				Text = TagSettings.Hint or "Move your mouse over this area",
				Parent = card,
			})
			paint(hint, "TextColor3", "TextSub")
	
			local region, chipParent
			if scope == "Screen" then
				region = nil
				chipParent = ensureRoot()
			elseif scope == "Window" then
				local node = page
				while node.Parent and not node.Parent:IsA("ScreenGui") do
					node = node.Parent
				end
				region = node
				chipParent = node
			else
				region = card
				chipParent = card
			end
	
			local chip = create("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				TextColor3 = Color3.fromRGB(24, 24, 24),
				Font = FONT_MEDIUM,
				TextSize = 12,
				Text = TagSettings.Text or "Tag",
				Visible = false,
				TextTransparency = 1,
				BackgroundTransparency = 1,
				ZIndex = 5000,
				Parent = chipParent,
			})
			round(chip, 6)
			padAll(chip, 4, 8, 4, 8)
	
			local shown = false
			local enabled = TagSettings.Enabled ~= false
			local hideToken = 0
			local function showChip()
				if not enabled then return end
				hideToken = hideToken + 1
				shown = true
				chip.Visible = true
				tween(chip, TI_FAST, {TextTransparency = 0, BackgroundTransparency = 0})
			end
			local function hideChip()
				hideToken = hideToken + 1
				local myToken = hideToken
				shown = false
				tween(chip, TI_FAST, {TextTransparency = 1, BackgroundTransparency = 1})
				task.delay(0.16, function()
					if hideToken == myToken and not shown then
						chip.Visible = false
					end
				end)
			end
			local function moveTo(px, py)
				local base = chipParent.AbsolutePosition
				local bounds = chipParent.AbsoluteSize
				local cw = math.max(chip.AbsoluteSize.X, 24)
				local ch = math.max(chip.AbsoluteSize.Y, 16)
				local x = math.clamp(px - base.X + offX, 2, math.max(2, bounds.X - cw - 2))
				local y = math.clamp(py - base.Y + offY, 2, math.max(2, bounds.Y - ch - 2))
				tween(chip, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = UDim2.fromOffset(x, y),
				})
			end
	
			if region then
				region.InputChanged:Connect(function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
					moveTo(input.Position.X, input.Position.Y)
				end)
				region.MouseEnter:Connect(showChip)
				region.MouseLeave:Connect(hideChip)
			else
				connect(UserInputService.InputChanged, function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
					if not shown then showChip() end
					moveTo(input.Position.X, input.Position.Y)
				end)
			end
	
			local Tag = {}
			function Tag:Set(newText)
				chip.Text = newText or chip.Text
			end
			function Tag:SetEnabled(state)
				state = state ~= false
				if enabled == state then return end
				enabled = state
				if not enabled then
					hideChip()
				end
			end
			return Tag
		end

		function tab:CreateGradientPicker(GradientSettings)
			GradientSettings = GradientSettings or {}
			local COLLAPSED_H = 50
			local EXPANDED_H = 256
			local SV_W, SV_H, SV_CY = 180, 76, 176
			local HUE_CY = 228
			local EXPO = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
			local EXPO_FAST = TweenInfo.new(0.45, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
			local MAX_STOPS = 12
	
			local stops = {}
			local function addStopRaw(pos, color)
				local hh, ss, vv = color:ToHSV()
				table.insert(stops, {Pos = math.clamp(pos, 0, 1), H = hh, S = ss, V = vv})
			end
			local function loadFromSequence(seq)
				stops = {}
				for _, kp in ipairs(seq.Keypoints) do
					addStopRaw(kp.Time, kp.Value)
				end
			end
			if typeof(GradientSettings.Color) == "ColorSequence" then
				loadFromSequence(GradientSettings.Color)
			elseif type(GradientSettings.Colors) == "table" and #GradientSettings.Colors >= 2 then
				local n = #GradientSettings.Colors
				for i, c in ipairs(GradientSettings.Colors) do
					if typeof(c) == "Color3" then addStopRaw((i - 1) / (n - 1), c) end
				end
			end
			if #stops < 2 then
				stops = {}
				addStopRaw(0, Color3.fromRGB(74, 178, 124))
				addStopRaw(1, Color3.fromRGB(70, 130, 220))
			end
	
			local card = create("Frame", {
				Size = UDim2.new(1, 0, 0, COLLAPSED_H),
				ClipsDescendants = true,
				LayoutOrder = nextOrder(),
				Parent = page,
			})
			card:SetAttribute("SearchName", GradientSettings.Name or "")
			paint(card, "BackgroundColor3", "Card")
			cardBase(card)
			hoverable(card)
	
			local textX = 17
			if GradientSettings.Icon then
				local ic = makeIcon(card, GradientSettings.Icon, 18, Theme.TextTitle, 0.04)
				if ic then
					ic.AnchorPoint = Vector2.new(0, 0.5)
					ic.Position = UDim2.new(0, 16, 0, 25)
					textX = 44
				end
			end
			local label = create("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, textX, 0, 25),
				Size = UDim2.new(0.5, -textX, 0, 18),
				Font = FONT_MEDIUM,
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = GradientSettings.Name or "",
				Parent = card,
			})
			paint(label, "TextColor3", "TextBody")
	
			local GradientPicker = {Type = "GradientPicker"}
			local selIdx = 1
			local open = false
			local push, refresh, refreshSelection
			local handleFrames = {}
			local railDragIdx = nil
	
			local function buildSequence()
				local sorted = {}
				for _, st in ipairs(stops) do table.insert(sorted, st) end
				table.sort(sorted, function(a, b) return a.Pos < b.Pos end)
				local kps = {}
				local lastT = -1
				for _, st in ipairs(sorted) do
					local t = math.clamp(st.Pos, 0, 1)
					if t <= lastT then t = math.min(1, lastT + 0.0012) end
					lastT = t
					table.insert(kps, ColorSequenceKeypoint.new(t, Color3.fromHSV(st.H, st.S, st.V)))
				end
				if kps[1].Time > 0 then
					table.insert(kps, 1, ColorSequenceKeypoint.new(0, kps[1].Value))
				end
				if kps[#kps].Time < 1 then
					table.insert(kps, ColorSequenceKeypoint.new(1, kps[#kps].Value))
				end
				local ok, seq = pcall(ColorSequence.new, kps)
				if ok then return seq end
				return ColorSequence.new(kps[1].Value, kps[#kps].Value)
			end
	
			-- collapsed swatch that morphs into the full preview bar
			local previewBar = create("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -16, 0, 25),
				Size = UDim2.fromOffset(46, 26),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				Parent = card,
			})
			round(previewBar, 9)
			local previewGrad = create("UIGradient", {Parent = previewBar})
			create("UIStroke", {Color = Theme.Stroke, Transparency = 0.85, Parent = previewBar})
			local pvGlow = softGlow(previewBar, Color3.fromHSV(stops[1].H, stops[1].S, stops[1].V), 0.4, 30, 0)
			local glowOn = GradientSettings.Glow ~= false
			if not glowOn then glowSet(pvGlow, 0) end
	
			-- stops rail
			local rail = create("TextButton", {
				Text = "",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -16, 0, 116),
				Size = UDim2.new(1, -32, 0, 24),
				AutoButtonColor = false,
				Parent = card,
			})
			paint(rail, "BackgroundColor3", "CardInset")
			round(rail, 8)
			create("UIStroke", {Color = Theme.Stroke, Transparency = 0.9, Parent = rail})
	
			-- SV square (edits the selected stop)
			local sv = create("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -16, 0, SV_CY),
				Size = UDim2.fromOffset(SV_W, SV_H),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				Parent = card,
			})
			round(sv, 10)
			create("UIStroke", {Color = Theme.Stroke, Transparency = 0.85, Parent = sv})
			local satOverlay = create("Frame", {BackgroundColor3 = Color3.fromRGB(255, 255, 255), Size = UDim2.fromScale(1, 1), Parent = sv})
			round(satOverlay, 10)
			create("UIGradient", {
				Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
				Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}),
				Parent = satOverlay,
			})
			local valOverlay = create("Frame", {BackgroundColor3 = Color3.fromRGB(0, 0, 0), Size = UDim2.fromScale(1, 1), Parent = sv})
			round(valOverlay, 10)
			create("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(Color3.fromRGB(0, 0, 0)),
				Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)}),
				Parent = valOverlay,
			})
			local svPoint = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(14, 14),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				Parent = sv,
			})
			roundFull(svPoint)
			create("UIStroke", {Color = Color3.fromRGB(255, 255, 255), Thickness = 2, Parent = svPoint})
			local svHit = create("TextButton", {BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), Parent = sv})
	
			-- hue bar
			local hueBar = create("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -16, 0, HUE_CY),
				Size = UDim2.fromOffset(SV_W, 14),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				Parent = card,
			})
			roundFull(hueBar)
			create("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
					ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
					ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
					ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
					ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
					ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
					ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
				}),
				Parent = hueBar,
			})
			local huePoint = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.fromOffset(16, 16),
				BackgroundColor3 = Color3.fromRGB(255, 0, 0),
				Parent = hueBar,
			})
			roundFull(huePoint)
			create("UIStroke", {Color = Color3.fromRGB(255, 255, 255), Thickness = 2, Parent = huePoint})
			local hueHit = create("TextButton", {BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), Parent = hueBar})
	
			-- left column buttons
			local function makeBtn(text, iconPath, y)
				local btn = create("TextButton", {
					Text = "",
					AnchorPoint = Vector2.new(0, 0),
					Position = UDim2.new(0, 16, 0, y),
					Size = UDim2.fromOffset(150, 34),
					AutoButtonColor = false,
					Parent = card,
				})
				paint(btn, "BackgroundColor3", "CardInset")
				round(btn, 9)
				local row = create("Frame", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.new(0, 0, 1, 0),
					Parent = btn,
				})
				create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 7), Parent = row})
				local ic = makeIcon(row, iconPath, 15, Theme.TextBody, 0)
				if ic then ic.LayoutOrder = 1 end
				local lbl = create("TextLabel", {BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), Font = FONT_MEDIUM, TextSize = 13, Text = text, LayoutOrder = 2, Parent = row})
				paint(lbl, "TextColor3", "TextBody")
				btn.MouseEnter:Connect(function() if open then tween(btn, TI_FAST, {BackgroundColor3 = Theme.CardSelected}) end end)
				btn.MouseLeave:Connect(function() tween(btn, TI_FAST, {BackgroundColor3 = Theme.CardInset}) end)
				return btn
			end
			local addBtn = makeBtn("Add stop", "plus", 138)
			local removeBtn = makeBtn("Remove stop", "trash-2", 178)
	
			local clicker = create("TextButton", {BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), Parent = card})
	
			local function colorAt(pos)
				local sorted = {}
				for _, st in ipairs(stops) do table.insert(sorted, st) end
				table.sort(sorted, function(a, b) return a.Pos < b.Pos end)
				local lo, hi = sorted[1], sorted[#sorted]
				for i = 1, #sorted - 1 do
					if pos >= sorted[i].Pos and pos <= sorted[i + 1].Pos then
						lo, hi = sorted[i], sorted[i + 1]
						break
					end
				end
				local t = (hi.Pos == lo.Pos) and 0 or (pos - lo.Pos) / (hi.Pos - lo.Pos)
				local c1 = Color3.fromHSV(lo.H, lo.S, lo.V)
				local c2 = Color3.fromHSV(hi.H, hi.S, hi.V)
				return c1:Lerp(c2, math.clamp(t, 0, 1))
			end
	
			refreshSelection = function()
				for i, hd in ipairs(handleFrames) do
					local isSel = i == selIdx
					tween(hd, TI_FAST, {Size = UDim2.fromOffset(isSel and 21 or 16, isSel and 21 or 16)})
					local st = hd:FindFirstChildOfClass("UIStroke")
					if st then
						tween(st, TI_FAST, {Color = isSel and Theme.Accent or Color3.fromRGB(255, 255, 255), Thickness = isSel and 3 or 2.5})
					end
				end
			end
	
			refresh = function()
				previewGrad.Color = buildSequence()
				glowColor(pvGlow, colorAt(0.5))
				local st = stops[selIdx]
				local hueColor = Color3.fromHSV(st.H, 1, 1)
				sv.BackgroundColor3 = hueColor
				svPoint.BackgroundColor3 = Color3.fromHSV(st.H, st.S, st.V)
				svPoint.Position = UDim2.new(st.S, 0, 1 - st.V, 0)
				huePoint.BackgroundColor3 = hueColor
				huePoint.Position = UDim2.new(st.H, 0, 0.5, 0)
				for i, hd in ipairs(handleFrames) do
					if stops[i] then
						hd.BackgroundColor3 = Color3.fromHSV(stops[i].H, stops[i].S, stops[i].V)
						hd.Position = UDim2.new(stops[i].Pos, 0, 0.5, 0)
					end
				end
				GradientPicker.Value = buildSequence()
			end
	
			push = function(fire)
				GradientPicker.Value = buildSequence()
				if fire then
					runCallback(GradientSettings.Callback, GradientPicker.Value)
					saveConfiguration()
				end
			end
	
			local function makeHandle(i)
				local hd = create("TextButton", {
					Text = "",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(stops[i].Pos, 0, 0.5, 0),
					Size = UDim2.fromOffset(16, 16),
					BackgroundColor3 = Color3.fromHSV(stops[i].H, stops[i].S, stops[i].V),
					AutoButtonColor = false,
					ZIndex = 3,
					Parent = rail,
				})
				round(hd, 5)
				create("UIStroke", {Color = Color3.fromRGB(255, 255, 255), Thickness = 2.5, Parent = hd})
				hd.InputBegan:Connect(function(input)
					if not open then return end
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						selIdx = i
						railDragIdx = i
						refreshSelection()
						refresh()
					end
				end)
				return hd
			end
			local function rebuildHandles()
				for _, hd in ipairs(handleFrames) do hd:Destroy() end
				handleFrames = {}
				for i = 1, #stops do
					handleFrames[i] = makeHandle(i)
				end
				refreshSelection()
			end
			rebuildHandles()
	
			rail.MouseButton1Click:Connect(function()
				if not open then return end
				if #stops >= MAX_STOPS then return end
				local rel = math.clamp((UserInputService:GetMouseLocation().X - rail.AbsolutePosition.X) / math.max(rail.AbsoluteSize.X, 1), 0, 1)
				addStopRaw(rel, colorAt(rel))
				selIdx = #stops
				rebuildHandles()
				refresh()
				push(true)
			end)
	
			addBtn.MouseButton1Click:Connect(function()
				if not open or #stops >= MAX_STOPS then return end
				addStopRaw(0.5, colorAt(0.5))
				selIdx = #stops
				rebuildHandles()
				refresh()
				push(true)
			end)
			removeBtn.MouseButton1Click:Connect(function()
				if not open or #stops <= 2 then return end
				table.remove(stops, selIdx)
				selIdx = math.max(1, selIdx - 1)
				rebuildHandles()
				refresh()
				push(true)
			end)
	
			local function setOpen(state)
				if state == open then return end
				open = state
				if open then
					tween(card, EXPO, {Size = UDim2.new(1, 0, 0, EXPANDED_H)})
					tween(clicker, EXPO, {Size = UDim2.new(1, 0, 0, COLLAPSED_H)})
					tween(previewBar, EXPO, {Position = UDim2.new(1, -16, 0, 77), Size = UDim2.new(1, -32, 0, 30)})
				else
					tween(card, EXPO, {Size = UDim2.new(1, 0, 0, COLLAPSED_H)})
					tween(clicker, EXPO, {Size = UDim2.fromScale(1, 1)})
					tween(previewBar, EXPO, {Position = UDim2.new(1, -16, 0, 25), Size = UDim2.fromOffset(46, 26)})
				end
			end
			clicker.MouseButton1Click:Connect(function()
				setOpen(not open)
			end)
	
			local svDragging = false
			local function svFromInput(px, py)
				local ax = math.clamp((px - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
				local ay = math.clamp((py - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
				stops[selIdx].S = ax
				stops[selIdx].V = 1 - ay
				refresh()
				push(true)
			end
			svHit.InputBegan:Connect(function(input)
				if not open then return end
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					svDragging = true
					svFromInput(input.Position.X, input.Position.Y)
				end
			end)
			local hueDragging = false
			local function hueFromInput(px)
				stops[selIdx].H = math.clamp((px - hueBar.AbsolutePosition.X) / math.max(hueBar.AbsoluteSize.X, 1), 0, 1)
				refresh()
				push(true)
			end
			hueHit.InputBegan:Connect(function(input)
				if not open then return end
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					hueDragging = true
					hueFromInput(input.Position.X)
				end
			end)
	
			connect(UserInputService.InputChanged, function(input)
				if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
					if svDragging then svFromInput(input.Position.X, input.Position.Y) end
					if hueDragging then hueFromInput(input.Position.X) end
					if railDragIdx and stops[railDragIdx] then
						stops[railDragIdx].Pos = math.clamp((input.Position.X - rail.AbsolutePosition.X) / math.max(rail.AbsoluteSize.X, 1), 0, 1)
						refresh()
						push(true)
					end
				end
			end)
			connect(UserInputService.InputEnded, function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					svDragging = false
					hueDragging = false
					railDragIdx = nil
				end
			end)
	
			function GradientPicker:Set(data)
				if typeof(data) == "ColorSequence" then
					loadFromSequence(data)
				elseif type(data) == "table" then
					stops = {}
					for _, e in ipairs(data) do
						if e.Color and typeof(e.Color) == "Color3" then
							addStopRaw(e.Pos or e.T or 0, e.Color)
						elseif e.R then
							addStopRaw(e.T or e.Pos or 0, Color3.fromRGB(e.R, e.G or 0, e.B or 0))
						end
					end
				end
				if #stops < 2 then
					stops = {}
					addStopRaw(0, Color3.fromRGB(74, 178, 124))
					addStopRaw(1, Color3.fromRGB(70, 130, 220))
				end
				selIdx = math.clamp(selIdx, 1, #stops)
				rebuildHandles()
				refresh()
			end
			function GradientPicker:Serialize()
				local out = {}
				for _, st in ipairs(stops) do
					local c = Color3.fromHSV(st.H, st.S, st.V)
					table.insert(out, {T = st.Pos, R = math.floor(c.R * 255 + 0.5), G = math.floor(c.G * 255 + 0.5), B = math.floor(c.B * 255 + 0.5)})
				end
				return out
			end
			function GradientPicker:SetGlow(state)
				glowOn = state ~= false
				glowSet(pvGlow, glowOn and 1 or 0, TI_FAST)
			end
	
			if GradientSettings.Flag then
				GradientPicker.Flag = GradientSettings.Flag
				RayfieldLibrary.Flags[GradientSettings.Flag] = GradientPicker
			end
	
			refresh()
			return GradientPicker
		end
	
		function tab:CreatePinnedList(ListSettings)
			ListSettings = ListSettings or {}
			local ITEM_H, GAP, HEADER_H = 54, 8, 20
			local holder = create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				LayoutOrder = nextOrder(),
				Parent = page,
			})
			local header = create("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, HEADER_H),
				Font = FONT_MEDIUM,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = ListSettings.Title or "All Items",
				Parent = holder,
			})
			paint(header, "TextColor3", "TextSub")
			create("UIPadding", {PaddingLeft = UDim.new(0, 4), Parent = header})
	
			local List = {}
			local items = {}
			local itemsByName = {}
			local pinSerial = 0
	
			local function relayout(animate)
				local pinned, unpinned = {}, {}
				for _, item in ipairs(items) do
					table.insert(item.Pinned and pinned or unpinned, item)
				end
				table.sort(pinned, function(x, y) return x.PinStamp < y.PinStamp end)
				local y = 0
				local function place(inst, h)
					local goal = UDim2.fromOffset(0, y)
					if animate then
						tween(inst, TI_MORPH, {Position = goal})
					else
						inst.Position = goal
					end
					y = y + h + GAP
				end
				for _, item in ipairs(pinned) do
					place(item.Card, ITEM_H)
				end
				place(header, HEADER_H)
				for _, item in ipairs(unpinned) do
					place(item.Card, ITEM_H)
				end
				holder.Size = UDim2.new(1, 0, 0, math.max(0, y - GAP))
			end
	
			local function makeItem(cfg, index)
				local card = create("Frame", {
					Size = UDim2.new(1, 0, 0, ITEM_H),
					Parent = holder,
				})
				card:SetAttribute("SearchName", cfg.Name or "")
				paint(card, "BackgroundColor3", "Card")
				cardBase(card)
				hoverable(card)
	
				local textX = 16
				if cfg.Icon then
					local well = create("Frame", {
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 12, 0.5, 0),
						Size = UDim2.fromOffset(32, 32),
						BackgroundColor3 = Theme.CardInset,
						Parent = card,
					})
					round(well, 9)
					local ic = makeIcon(well, cfg.Icon, 16, Theme.TextTitle, 0.04)
					if ic then
						ic.AnchorPoint = Vector2.new(0.5, 0.5)
						ic.Position = UDim2.fromScale(0.5, 0.5)
					end
					textX = 54
				end
	
				local title = create("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(textX, 10),
					Size = UDim2.new(1, -textX - 56, 0, 17),
					Font = FONT_MEDIUM,
					TextSize = 15,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Text = cfg.Name or "",
					Parent = card,
				})
				paint(title, "TextColor3", "TextBody")
				local sub = create("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(textX, 28),
					Size = UDim2.new(1, -textX - 56, 0, 15),
					Font = FONT_REGULAR,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Text = cfg.Description or "",
					Parent = card,
				})
				paint(sub, "TextColor3", "TextSub")
	
				local pinBtn = create("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -12, 0.5, 0),
					Size = UDim2.fromOffset(30, 30),
					BackgroundColor3 = Theme.CardSelected,
					BackgroundTransparency = 1,
					Text = "",
					Parent = card,
				})
				roundFull(pinBtn)
				local pinIcon = makeIcon(pinBtn, "pin", 14, Theme.TextTitle, 1)
				if pinIcon then
					pinIcon.AnchorPoint = Vector2.new(0.5, 0.5)
					pinIcon.Position = UDim2.fromScale(0.5, 0.5)
				end
	
				local item = {
					Name = cfg.Name or ("Item " .. index),
					Pinned = false,
					PinStamp = 0,
					Order = index,
					Card = card,
				}
				local function refreshPin()
					local show = item.Pinned
					tween(pinBtn, TI_FAST, {BackgroundTransparency = show and 0.25 or 1})
					if pinIcon then
						tween(pinIcon, TI_FAST, {ImageTransparency = show and 0.1 or 1})
					end
				end
				local function setPinned(state, silent)
					if item.Pinned == state then return end
					item.Pinned = state
					if state then
						pinSerial = pinSerial + 1
						item.PinStamp = pinSerial
					end
					relayout(true)
					refreshPin()
					tween(card, TweenInfo.new(0.07, Enum.EasingStyle.Quad), {BackgroundColor3 = Theme.CardSelected})
					task.delay(0.14, function()
						tween(card, TI_MED, {BackgroundColor3 = Theme.Card})
					end)
					if not silent then
						runCallback(ListSettings.Callback, item.Name, state)
					end
				end
				item.SetPinned = setPinned
	
				pinBtn.MouseButton1Click:Connect(function()
					setPinned(not item.Pinned)
				end)
				card.MouseEnter:Connect(function()
					tween(pinBtn, TI_FAST, {BackgroundTransparency = 0.25})
					if pinIcon then
						tween(pinIcon, TI_FAST, {ImageTransparency = 0.1})
					end
				end)
				card.MouseLeave:Connect(refreshPin)
	
				table.insert(items, item)
				itemsByName[item.Name] = item
			end
	
			for i, cfg in ipairs(ListSettings.Items or {}) do
				makeItem(cfg, i)
			end
			for i, cfg in ipairs(ListSettings.Items or {}) do
				if cfg.Pinned and items[i] then
					items[i].Pinned = true
					pinSerial = pinSerial + 1
					items[i].PinStamp = pinSerial
				end
			end
			relayout(false)
	
			function List:Pin(name, state)
				local item = itemsByName[name]
				if item then
					item.SetPinned(state ~= false)
				end
			end
			function List:GetPinned()
				local out = {}
				for _, item in ipairs(items) do
					if item.Pinned then
						table.insert(out, item.Name)
					end
				end
				return out
			end
			return List
		end

	return tab
end

-- wrap CreateWindow -> wrap window.CreateTab -> extend each tab
local realCreateWindow = Rayfield.CreateWindow
Rayfield.CreateWindow = function(self, ...)
	local win = realCreateWindow(self, ...)
	if type(win) == "table" then
		local realCreateTab = win.CreateTab
		if realCreateTab then
			win.CreateTab = function(w, ...)
				return extendTab(realCreateTab(w, ...))
			end
		end
	end
	return win
end

return Rayfield
