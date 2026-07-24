--[[
	Rayfield Gen2 [Better]
	The official Rayfield Gen2 (by Sirius, https://docs.sirius.menu/rayfield-gen2),
	loaded unchanged, with two upgrades applied automatically to every window:

	  1. Window resizing - a smooth corner grip so the menu can be resized,
	     which the official Gen2 does not have.
	  2. Better dropdowns - the official Gen2 opens a dropdown to a tiny sliver
	     and clips its border corners. Here every dropdown opens to a proper
	     tall list and its rounded border renders cleanly.

	Everything else is byte-for-byte the official Gen2. All credit for
	Rayfield / Rayfield Gen2 goes to Sirius. MIT licensed.
]]

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

local DROPDOWN_OPEN_HEIGHT = 270

local function insetStrokeHost(parent, name, size, position, anchor, radius)
    local host = Instance.new("Frame")
    host.Name = name
    host.BackgroundTransparency = 1
    host.BorderSizePixel = 0
    host.Size = size
    host.Position = position
    host.AnchorPoint = anchor
    host.ZIndex = 2

    local corner = Instance.new("UICorner")
    corner.CornerRadius = radius
    corner.Parent = host

    host.Parent = parent
    return host
end


local function patchDropdown(dropdown)

    local dropdown = parent:CreateDropdown(props)

    if dropdown and dropdown._optionFrames then
        function dropdown._openHeight()
            return DROPDOWN_OPEN_HEIGHT
        end
    end

    if not dropdown then return dropdown end
    if not dropdown.main or not dropdown.top or not dropdown.panel then return dropdown end
    if dropdown.main:FindFirstChild("TopStrokeHost") then return dropdown end

    local topCorner = dropdown.top:FindFirstChildOfClass("UICorner")
    local radius = topCorner and topCorner.CornerRadius or UDim.new(0, 12)
    local inner = UDim.new(radius.Scale, math.max(0, radius.Offset - 1))

    local topStroke = dropdown.top:FindFirstChildOfClass("UIStroke")
    if topStroke then
        topStroke.Parent = insetStrokeHost(
            dropdown.main,
            "TopStrokeHost",
            UDim2.new(1, -2, 0, dropdown.top.Size.Y.Offset - 2),
            UDim2.fromOffset(1, 1),
            Vector2.new(0, 0),
            inner
        )
    end

    -- The option list gives its canvas 2px of bottom padding but none at the
    -- top, so the first option sits flush with the ScrollingFrame's clip edge
    -- and its rounded top corner and outward stroke get sliced off. Match the
    -- bottom padding so the first row clears the boundary.
    if dropdown.list then
        local listPadding = dropdown.list:FindFirstChildOfClass("UIPadding")
        if listPadding and listPadding.PaddingTop.Offset < 2 then
            listPadding.PaddingTop = UDim.new(0, 2)
        end
    end

    if dropdown.panelStroke then
        dropdown.panelStroke.Parent = insetStrokeHost(
            dropdown.main,
            "PanelStrokeHost",
            UDim2.new(1, -2, 1, dropdown.panel.Size.Y.Offset - 2),
            UDim2.new(1, -1, 1, -1),
            Vector2.new(1, 1),
            inner
        )
    end


	return dropdown
end


local function applyResize(Window)
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local GuiService = game:GetService("GuiService")

    local main = Window.main
    local screenGui = main:FindFirstAncestorWhichIsA("ScreenGui")
    local scale = 1

    local function tween(object, properties, info)
        TweenService:Create(object, info, properties):Play()
    end

    -- Gen2 sizes the page's bottom fade as Size = {1,0},{-0.093,100}, so the
    -- taller the window gets the SHORTER the fade becomes: 54px at a 500 tall
    -- window, 24px at 820. Both the fade and the window are rounded by 20, but
    -- Roblox clamps a corner radius to half the height, so once the fade drops
    -- under 40px its corners round tighter than the window's and its squarer
    -- bottom corners jut out past the curve, drawing a dark line across the
    -- bottom. Clamping the fade keeps the two curves identical at any height.
    local bottomFade, fadeScaleY, fadeOffsetY, fadeMinHeight
    local windowRadius = 20

    do
        local windowCorner = main:FindFirstChildOfClass("UICorner")
        if windowCorner then
            windowRadius = windowCorner.CornerRadius.Offset
        end

        for _, child in ipairs(main:GetChildren()) do
            if child:IsA("Frame") and child.ZIndex == 100 and child:FindFirstChildOfClass("UIGradient") then
                bottomFade = child
                break
            end
        end

        if bottomFade then
            local fadeCorner = bottomFade:FindFirstChildOfClass("UICorner")
            local radius = (fadeCorner and fadeCorner.CornerRadius.Offset) or windowRadius
            fadeScaleY = bottomFade.Size.Y.Scale
            fadeOffsetY = bottomFade.Size.Y.Offset
            fadeMinHeight = radius * 2
        end
    end

    local function clampBottomFade(height)
        if not bottomFade then return end
        local intended = fadeOffsetY + fadeScaleY * height
        bottomFade.Size = UDim2.new(1, 0, 0, math.max(fadeMinHeight, intended))
    end

    -- NEMESIS just assigns root.Size; here the library's own bookkeeping has to
    -- follow, or show / hide / minimise will each tween back to 475x500.
    local W, H = main.AbsoluteSize.X, main.AbsoluteSize.Y

    local function applySize(width, height)
        width, height = math.floor(width + 0.5), math.floor(height + 0.5)
        W, H = width, height

        if main.Size.X.Offset == width and main.Size.Y.Offset == height then
            return
        end

        main.Size = UDim2.fromOffset(width, height)
        Window.size = UDim2.fromOffset(width, height)
        clampBottomFade(height)

        if Window.drag and Window.drag.drag then
            local pos = main.Position
            Window.drag.drag.Position = UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset + height / 2 + 15)
        end
    end

    -- minimum size keeps the whole top bar visible; below this things overlap
    local minW = 380
    local minH = 320

    local resizeGrip = Instance.new("ImageButton")
    resizeGrip.Name = "ResizeGrip"
    resizeGrip.AnchorPoint = Vector2.new(1, 1)
    resizeGrip.Position = UDim2.new(1, -8, 1, -8)
    resizeGrip.Size = UDim2.fromOffset(54, 54)
    resizeGrip.BackgroundTransparency = 1
    resizeGrip.Image = ""
    resizeGrip.AutoButtonColor = false
    resizeGrip.ZIndex = 150
    resizeGrip.Parent = main

    -- 9-sliced so the curved icon stretches cleanly toward the cursor
    local resizeIcon = Instance.new("ImageLabel")
    resizeIcon.Name = "Icon"
    resizeIcon.AnchorPoint = Vector2.new(1, 1)
    resizeIcon.Position = UDim2.new(1, 0, 1, 0)
    resizeIcon.Size = UDim2.fromOffset(18, 18)
    resizeIcon.BackgroundTransparency = 1
    resizeIcon.Image = "rbxassetid://86527207319523"
    resizeIcon.ImageColor3 = Color3.fromRGB(90, 90, 98)
    resizeIcon.ImageTransparency = 0
    resizeIcon.ScaleType = Enum.ScaleType.Slice
    resizeIcon.SliceCenter = Rect.new(51, 52, 51, 52)
    resizeIcon.SliceScale = 0.5
    resizeIcon.ZIndex = 151
    resizeIcon.Parent = resizeGrip

    -- SIRIUS-style smooth resize: a RenderStepped loop where the visual size
    -- eases toward a cursor-driven target each frame (frame-rate independent
    -- exponential smoothing), so the window butter-glides to follow the cursor.
    local SMOOTH_K = 26          -- higher = tighter cursor-follow (SIRIUS ~28)
    local resizing = false
    local hovering = false
    local startPointer, startW, startH
    local targetW, targetH = W, H
    local visualW, visualH = W, H
    local loopConn
    local hoverX, hoverY

    Window.__resizing = false

    local function getPointer(input)
        if input and input.UserInputType == Enum.UserInputType.Touch then
            return Vector2.new(input.Position.X, input.Position.Y)
        end
        return UserInputService:GetMouseLocation()
    end

    local function maxSize()
        local camera = workspace.CurrentCamera
        local vp = camera and camera.ViewportSize or Vector2.new(1920, 1080)
        return math.max(minW, vp.X / scale - 40), math.max(minH, vp.Y / scale - 40)
    end

    -- SIRIUS stretch: normalize the cursor's position inside the grip, then
    -- stretch the icon NON-uniformly toward it (wider/taller as you move in)
    -- Whichever way the cursor's Y is reported, it has to be in the same space
    -- as AbsolutePosition or relY pins to an end and that axis stops responding
    -- (the top approach going dead is exactly that). Rather than assume a sign
    -- for the GUI inset, this resolves it from the geometry: while the cursor is
    -- over the grip its Y must fall inside the grip's rect, so if the raw
    -- reading does not, whichever of y+inset / y-inset does is the right space.
    local resolvedYOffset = 0

    local function resolveY(y, top, height)
        if y >= top and y <= top + height then
            return y
        end

        local inset = 0
        pcall(function() inset = GuiService:GetGuiInset().Y end)

        for _, candidate in ipairs({ y + inset, y - inset }) do
            if candidate >= top and candidate <= top + height then
                resolvedYOffset = candidate - y
                return candidate
            end
        end

        return y + resolvedYOffset
    end

    local function normResize()
        local pos, sz = resizeGrip.AbsolutePosition, resizeGrip.AbsoluteSize

        local mx, my
        if hoverX then
            mx, my = hoverX, hoverY
        else
            local raw = UserInputService:GetMouseLocation()
            mx, my = raw.X, raw.Y
        end

        my = resolveY(my, pos.Y, sz.Y)

        local relX = (mx - pos.X) / math.max(sz.X, 1)
        local relY = (my - pos.Y) / math.max(sz.Y, 1)
        return Vector2.new(1 - math.clamp(relX, 0, 1), 1 - math.clamp(relY, 0, 1))
    end

    local function stretchIcon(duration)
        local n = normResize()
        tween(resizeIcon, {
            Size = UDim2.new(0, 20 + n.X * 30, 0, 20 + n.Y * 30),
            ImageColor3 = Color3.fromRGB(125, 125, 135),
        }, TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
    end

    local function pressIcon()
        tween(resizeIcon, {
            Size = UDim2.new(0, 30, 0, 30),
            ImageColor3 = Color3.fromRGB(150, 150, 160),
        }, TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
    end

    local function resetIcon()
        tween(resizeIcon, {
            Size = UDim2.new(0, 18, 0, 18),
            ImageColor3 = Color3.fromRGB(90, 90, 98),
        }, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
    end

    local function stopLoop()
        if loopConn then loopConn:Disconnect(); loopConn = nil end
    end

    local function startLoop()
        stopLoop()
        visualW, visualH = W, H
        loopConn = RunService.RenderStepped:Connect(function(dt)
            local alpha = 1 - math.exp(-dt * SMOOTH_K)
            visualW = visualW + (targetW - visualW) * alpha
            visualH = visualH + (targetH - visualH) * alpha
            applySize(visualW, visualH)
            if not resizing
                and math.abs(visualW - targetW) <= 0.45
                and math.abs(visualH - targetH) <= 0.45 then
                applySize(targetW, targetH)
                stopLoop()
                Window.__resizing = false
            end
        end)
    end

    resizeGrip.MouseEnter:Connect(function()
        hovering = true
        if not resizing then stretchIcon(0.18) end
    end)

    resizeGrip.MouseLeave:Connect(function()
        hovering = false
        hoverX, hoverY = nil, nil
        if not resizing then resetIcon() end
    end)

    -- moving the cursor inside the grip restretches the icon toward it
    resizeGrip.MouseMoved:Connect(function(x, y)
        hoverX, hoverY = x, y
        if not resizing then stretchIcon(0.14) end
    end)

    resizeGrip.InputChanged:Connect(function(input)
        if resizing then return end
        if input.UserInputType == Enum.UserInputType.Touch then
            hoverX, hoverY = input.Position.X, input.Position.Y
            stretchIcon(0.14)
        end
    end)

    resizeGrip.InputBegan:Connect(function(input)
        if Window.hidden or Window.minimised then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            resizing = true
            Window.__resizing = true
            startPointer = getPointer(input)
            startW, startH = W, H
            targetW, targetH = W, H
            pressIcon()
            startLoop()
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not resizing then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local delta = getPointer(input) - startPointer
            local maxW, maxH = maxSize()
            -- *2: window is centre-anchored, so the corner tracks the cursor
            targetW = math.clamp(startW + (delta.X / scale) * 2, minW, maxW)
            targetH = math.clamp(startH + (delta.Y / scale) * 2, minH, maxH)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if resizing then
                resizing = false
                if hovering then stretchIcon(0.18) else resetIcon() end
            end
        end
    end)

    -- the grip has no place on a collapsed window
    main:GetPropertyChangedSignal("Size"):Connect(function()
        resizeGrip.Visible = not (Window.minimised or Window.hidden)
        clampBottomFade(main.AbsoluteSize.Y)
    end)

    clampBottomFade(main.AbsoluteSize.Y)
end



-- UPGRADE: global toggle keybind. Official Gen2 only hides from the topbar;
-- Better binds a key (default Right Control) to show/hide the whole window from
-- anywhere with a quick scale+fade. Rebind with Window:SetToggleKey(Enum.KeyCode.X).
local function applyKeybind(Window)
	local UserInputService = game:GetService("UserInputService")
	local TweenService = game:GetService("TweenService")
	local main = Window.main
	if not main then return end

	Window.__toggleKey = Enum.KeyCode.RightControl
	local shown = true
	local busy = false
	local baseSize = main.Size

	local function show()
		if shown then return end
		shown = true
		main.Visible = true
		main.Size = UDim2.fromOffset(math.floor(baseSize.X.Offset * 0.92), math.floor(baseSize.Y.Offset * 0.92))
		TweenService:Create(main, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = baseSize }):Play()
	end

	local function hide()
		if not shown then return end
		shown = false
		busy = true
		baseSize = main.Size -- capture current (resized) size
		local t = TweenService:Create(main, TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
			Size = UDim2.fromOffset(math.floor(baseSize.X.Offset * 0.9), math.floor(baseSize.Y.Offset * 0.9)),
		})
		t.Completed:Connect(function()
			if not shown then main.Visible = false; main.Size = baseSize end
			busy = false
		end)
		t:Play()
	end

	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe or busy then return end
		if input.KeyCode == Window.__toggleKey and not (Window.hidden or Window.minimised) then
			if shown then hide() else show() end
		end
	end)

	function Window.SetToggleKey(_, key)
		if typeof(key) == "EnumItem" then Window.__toggleKey = key end
	end
end


-- UPGRADE: smooth intro. Official Gen2 snaps the window in at full size.
-- Better scales + fades it up from 90% so it feels like it settles into place.
local function applyIntro(Window)
	local TweenService = game:GetService("TweenService")
	local main = Window.main
	if not main then return end
	local target = main.Size
	main.Size = UDim2.fromOffset(math.floor(target.X.Offset * 0.9), math.floor(target.Y.Offset * 0.9))
	TweenService:Create(main, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = target,
	}):Play()
end


local _CreateWindow = Rayfield.CreateWindow
function Rayfield.CreateWindow(self, settings)
	local Window = _CreateWindow(self, settings)
	pcall(applyIntro, Window)
	pcall(applyResize, Window)
	pcall(applyKeybind, Window)

	local _CreateTab = Window.CreateTab
	if _CreateTab then
		function Window.CreateTab(w, tabSettings)
			local tab = _CreateTab(w, tabSettings)
			local _CreateDropdown = tab and tab.CreateDropdown
			if _CreateDropdown then
				function tab.CreateDropdown(t, props)
					local dropdown = _CreateDropdown(t, props)
					pcall(patchDropdown, dropdown)
					return dropdown
				end
			end
			return tab
		end
	end

	return Window
end

return Rayfield
