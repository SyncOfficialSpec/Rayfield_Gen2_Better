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
