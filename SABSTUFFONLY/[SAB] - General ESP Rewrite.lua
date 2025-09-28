--// Objects & Variables
local Workspace = game.Workspace
local Plots = Workspace:FindFirstChild("Plots")
local LocalPlayer = entity.GetLocalPlayer()
local LocalPlayersPlot

local LastCache, UpdateTime = 0, 3
local RunwayFellas, Cache = {}, {}
local FontCache = { "ConsolasBold", "SmallestPixel", "Verdana", "Tahoma" }
local Rarities = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Brainrot God", "Secret" }
local PodiumData = { "DisplayName", "Rarity", "Generation" }

local RarityColours = {
	Default = Color3.fromRGB(255, 255, 255),
	Common = Color3.fromRGB(85, 255, 85),
	Rare = Color3.fromRGB(85, 170, 255),
	Epic = Color3.fromRGB(170, 85, 255),
	Legendary = Color3.fromRGB(255, 215, 0),
	Mythic = Color3.fromRGB(255, 85, 85),
	["Brainrot God"] = Color3.fromRGB(255, 0, 255),
	Secret = Color3.fromRGB(200, 200, 200),
}

--// UI Init
local Library = file.read("UIWrapper.lua") and loadstring(file.read("UIWrapper.lua"))()
if not Library then
	print("Failed to load UIWrapper.lua, Are you sure you have it in C:\\Serotonin\\files?")
	return
end

local Main = Library.NewTab("SABGENERALESP", "SAB ESP")
local VisualsContainer = Main:Container("MAIN", "Visuals", { autosize = true, next = true })
local SettingsContainer = Main:Container("SETTINGS", "Settings", { autosize = true })
local ColorContainer = Main:Container("COLORS", "Server Info Theming", { autosize = true })

local Enabled = VisualsContainer:Checkbox("Enabled")
local HighlightGlobalBest = VisualsContainer:Checkbox("Highlight Best Brainrot")
local ShowSelfPlot = VisualsContainer:Checkbox("Show Own Plot")
local ShowServerInfo = VisualsContainer:Checkbox("Show Server Info")
local DrawRunway = VisualsContainer:Checkbox("Draw Runway Brainrots")
local PlotESPInfo = VisualsContainer:Multiselect("Plot ESP Details", { "Owner", "Time Remaining" })
local PodiumESPInfo = VisualsContainer:Multiselect("Brainrot ESP Details", PodiumData)
local TracerGlobalBest = VisualsContainer:Checkbox("Tracer to Best Brainrot")
local TracerColor = VisualsContainer:Colorpicker("Tracer Color", { r = 255, g = 255, b = 255 }, true)
local TracerPosition = VisualsContainer:Dropdown("Tracer Position", { "Bottom Center", "Top Center", "Mouse" }, 1)
local TracerThickness = VisualsContainer:SliderInt("Tracer Thickness", 1, 5, 1)

local UIColors = {
	Defaults = {
		Accent = Color3.fromRGB(24, 222, 201),
		Header = Color3.fromRGB(16, 21, 26),
		Text = Color3.fromRGB(223, 225, 229),
		Background = Color3.fromRGB(20, 26, 31),
	},
	Checkboxes = {},
	Colourpickers = {},
}
for name, color in pairs(UIColors.Defaults) do
	UIColors.Checkboxes[name] = ColorContainer:Checkbox(name .. " Custom Colour")
	UIColors.Colourpickers[name] =
		ColorContainer:Colorpicker(name, { r = color.R * 255, g = color.G * 255, b = color.B * 255 }, true)
end

local PriceFilter = SettingsContainer:SliderInt("Minimum Brainrot Generation ($M/s)", 0, 100, 0)
local RaritySelection = SettingsContainer:Multiselect("Rarities to Show", Rarities)
local FontSelection = SettingsContainer:Dropdown("Font Selection", FontCache, 1)
local CacheMode = SettingsContainer:Dropdown("Cache Mode", { "Performance", "Performance Eater" }, 1)

--// Server Info Vars
local ServerInfoRelPos, ServerInfoPos, ServerInfoOffset = { x = 0.5, y = 0.1 }, { x = 0, y = 0 }, { x = 0, y = 0 }
local ServerInfoDragging = false

--// Utility Functions
math.clamp = function(num, min, max)
	return math.min(math.max(num, min), max)
end

local function GetUIColor(name)
	return (UIColors.Checkboxes[name] and UIColors.Checkboxes[name]:Get() and UIColors.Colourpickers[name]:Get())
		or UIColors.Defaults[name]
end

local function GetTracerPosition()
	local sw, sh = cheat.getWindowSize()
	if TracerPosition:Get() == "Bottom Center" then
		return sw / 2, sh
	elseif TracerPosition:Get() == "Top Center" then
		return sw / 2, 0
	else
		local MousePosition = utility.GetMousePos()
		return MousePosition[1], MousePosition[2]
	end
end

local function TableToRgb(c)
	if type(c) == "table" then
		return Color3.fromRGB(c.r or 255, c.g or 255, c.b or 255)
	end
	if c and c.R then
		return c
	end
	return Color3.new(1, 1, 1)
end

local function CalculateOutline(part)
	local screenPts = {}
	for _, corner in ipairs(draw.GetPartCorners(part) or {}) do
		local sx, sy, onScreen = utility.WorldToScreen(corner)
		if onScreen then
			table.insert(screenPts, { sx, sy })
		end
	end
	return (#screenPts >= 2) and draw.ComputeConvexHull(screenPts) or nil
end

local function ParseGeneration(str)
	if not str or str == "" then
		return 0
	end
	str = str:gsub(",", ""):match("^%s*(.-)%s*$")
	if not str:find("%$") and str:find("[smh]") then
		return 0
	end
	local num, suffix = str:match("%$([%d%.]+)%s*([KMBkmb]?)%s*/s")
	num = tonumber(num) or 0
	local multipliers = { K = 1e3, M = 1e6, B = 1e9 }
	return num * (multipliers[(suffix or ""):upper()] or 1)
end

local function FindChildByAddress(parent, address)
	for _, child in ipairs(parent:GetChildren()) do
		if child.Address == address then
			return child
		end
	end
	return nil
end

local function IsGUIDObject(obj)
	return obj.Name:match("^[0-9a-fA-F]+%-%x+%-%x+%-%x+%-%x+$") ~= nil
end

--// Plot Functions
local function IsPlotActive(plot)
	return plot.Owner and plot.Owner.Value and plot.Owner.Value ~= "Empty Base"
end

local function GetPlotOwner(plot)
	if not plot.Owner or not plot.Owner.Value then
		return "Unknown"
	end
	return (IsPlotActive(plot) and plot.Owner.Value:match("^(.-)'s [Bb]ase%s*$") or plot.Owner.Value or "Unknown")
end

local function CachePlotBrainrots(plotCache)
	plotCache.CachedBrainrots = {}

	if CacheMode:Get() == "Performance Eater" then
		for _, desc in pairs(plotCache.Plot:GetDescendants()) do
			coroutine.resume(coroutine.create(function()
				if desc.Name == "AnimalOverhead" then
					local data = {
						BestRenderPart = desc:FindFirstAncestor("Decoration") or desc:FindFirstAncestorOfClass("Part"),
						DrawPart = desc:FindFirstChild("Spawn") or desc:FindFirstAncestorOfClass("Part"),
						Info = {},
					}

					for _, label in ipairs(PodiumData) do
						local obj = desc:FindFirstChild(label)
						if obj then
							data.Info[label] = obj.Value
						end
					end

					plotCache.CachedBrainrots[desc.Address] = data
				end
			end))
		end
	else
		for _, podium in pairs(plotCache.Podiums:GetChildren()) do
			coroutine.resume(coroutine.create(function()
				local base = podium:FindFirstChild("Base")
				if not base then
					return
				end

				local spawn = base:FindFirstChild("Spawn")
				local decoration = base:FindFirstChild("Decorations") and base.Decorations:FindFirstChild("Decoration")

				if not spawn then
					return
				end
				local attachment = spawn:FindFirstChild("Attachment")
				if not attachment then
					return
				end

				local overhead = attachment:FindFirstChild("AnimalOverhead")
				if not overhead then
					return
				end

				local data = {
					BestRenderPart = decoration,
					DrawPart = spawn,
					Info = {},
				}
				for _, label in ipairs(PodiumData) do
					local obj = overhead:FindFirstChild(label)
					if obj then
						data.Info[label] = obj.Value
					end
				end

				plotCache.CachedBrainrots[podium.Address] = data
			end))
		end
	end
end

local function RegisterPlot(plot)
	if Cache[plot.Address] then
		return Cache[plot.Address]
	end
	local PlotSign, Purchases, AnimalPodiums =
		plot:FindFirstChild("PlotSign"), plot:FindFirstChild("Purchases"), plot:FindFirstChild("AnimalPodiums")
	if not (PlotSign and Purchases and AnimalPodiums) then
		return
	end
	local _, Frame =
		PlotSign:FindFirstChild("SurfaceGui"), PlotSign.SurfaceGui and PlotSign.SurfaceGui:FindFirstChild("Frame")
	local _, BillboardUI =
		Purchases:FindFirstChild("PlotBlock"),
		Purchases.PlotBlock and Purchases.PlotBlock:FindFirstChild("Main") and Purchases.PlotBlock.Main:FindFirstChild(
			"BillboardGui"
		)
	local data = {
		DrawPart = PlotSign,
		Owner = Frame and Frame:FindFirstChild("TextLabel"),
		Time = BillboardUI and BillboardUI:FindFirstChild("RemainingTime"),
		Podiums = AnimalPodiums,
		Plot = plot,
		CachedBrainrots = {},
	}
	Cache[plot.Address] = data
	return data
end

local function CapturePlots()
	Cache = {}
	if not Plots then
		Plots = Workspace:FindFirstChild("Plots")
		return
	end
	for _, plot in pairs(Plots:GetChildren()) do
		RegisterPlot(plot)
	end
end

--// Drawing
local function DrawPlotInfo(cached)
	if not cached or not cached.DrawPart then
		return
	end
	local font, drawPart, timeLabel, owner = FontSelection:Get(), cached.DrawPart, cached.Time, GetPlotOwner(cached)
	if not IsPlotActive(cached) then
		return
	end
	if not ShowSelfPlot:Get() and owner == LocalPlayer.DisplayName then
		return
	end
	local x, y, onScreen = utility.WorldToScreen(drawPart.Position)
	if not onScreen then
		return
	end
	local selectedInfo, yOffset = PlotESPInfo:Get(), 0

	if selectedInfo["Owner"] and owner ~= "" then
		local textW, textH = draw.GetTextSize(owner, font)
		draw.TextOutlined(owner, x - textW / 2, y - textH - 5, Color3.fromRGB(255, 255, 255), font, 255)
		yOffset = yOffset + textH + 5
	end
	if selectedInfo["Time Remaining"] and timeLabel and timeLabel.Value ~= "" then
		local timeText = timeLabel.Value == "0s" and "Unlocked" or timeLabel.Value
		local textW = draw.GetTextSize(timeText, font)
		draw.TextOutlined(timeText, x - textW / 2, y + yOffset, Color3.fromRGB(255, 255, 255), font, 255)
	end
end

local function DrawBrainrots(brainrotData, isRunway)
	if not brainrotData or not brainrotData.DrawPart then
		return
	end
	local font, info, part = FontSelection:Get(), brainrotData.Info, brainrotData.DrawPart
	if not info or not part then
		return
	end
	local rarity = isRunway and info.Rarity and info.Rarity.Value or info.Rarity
	if not (rarity and RaritySelection:Get()[rarity]) then
		return
	end
	local sx, sy, visible = utility.WorldToScreen(part.Position + Vector3.new(0, 3, 0))
	if not visible then
		return
	end

	local drawings, totalHeight = {}, 0
	local _, textH = draw.GetTextSize("A", font)
	for _, label in ipairs(PodiumData) do
		local obj = info[label]
		if PodiumESPInfo:Get()[label] and obj then
			local text = tostring(isRunway and obj.Value or obj)
			local color = label == "Rarity" and (RarityColours[rarity] or RarityColours.Default)
				or RarityColours.Default
			table.insert(drawings, { Text = text ~= "" and text or "N/A", Color = color })
			totalHeight = totalHeight + textH
		end
	end

	if #drawings > 0 then
		local cy = sy - totalHeight - 5
		for _, d in ipairs(drawings) do
			local textW = draw.GetTextSize(d.Text, font)
			draw.TextOutlined(d.Text, sx - textW / 2, cy, d.Color, font, 255)
			cy = cy + textH
		end
	end
end

local function DrawServerInfo(x, y, items)
	local HeaderHeight, Padding, Rounding = 30, 20, 6
	local title = "Server Info"
	local titleW, titleH = draw.GetTextSize(title, "Verdana")
	local maxWidth = titleW
	for _, item in ipairs(items) do
		local w = draw.GetTextSize(item.name, "Verdana")
		if w > maxWidth then
			maxWidth = w
		end
	end
	local boxWidth = maxWidth + Padding

	local totalHeight = 0
	for _, item in ipairs(items) do
		local _, h = draw.GetTextSize(item.name, "Verdana")
		totalHeight = totalHeight + h + 2
	end
	local contentHeight = HeaderHeight + 5 + totalHeight + 5

	local bg, header, accent, textCol =
		GetUIColor("Background"), GetUIColor("Header"), GetUIColor("Accent"), GetUIColor("Text")
	draw.RectFilled(x, y, boxWidth, contentHeight, TableToRgb(bg), Rounding, bg.a or 255)
	draw.RectFilled(x, y, boxWidth, HeaderHeight, TableToRgb(header), Rounding, header.a or 255)
	draw.RectFilled(x, y + HeaderHeight - 2, boxWidth, 2, TableToRgb(accent), nil, accent.a or 255)
	draw.Text(title, x + 10, y + (HeaderHeight - titleH) / 2, TableToRgb(textCol), "Verdana", textCol.a or 255)

	local cy = y + HeaderHeight + 5
	for _, item in ipairs(items) do
		local _, h = draw.GetTextSize(item.name, "Verdana")
		draw.Text(item.name, x + 10, cy, TableToRgb(textCol), "Verdana", textCol.a or 255)
		cy = cy + h + 2
	end
	return { x = x, y = y, w = boxWidth, h = contentHeight, headerH = HeaderHeight }
end

local function ClampToScreen(x, y, w, h)
	local sw, sh = cheat.getWindowSize()
	x = math.clamp(x, 0, sw - w)
	y = math.clamp(y, 0, sh - h)
	return x, y
end

local function MoveServerInfo(bounds)
	local MousePosition = utility.GetMousePos()
	local mx, my = MousePosition[1], MousePosition[2]
	if not mx then
		return
	end

	if keyboard.IsPressed("leftmouse") and utility.GetMenuState() then
		if not ServerInfoDragging then
			if mx >= bounds.x and mx <= bounds.x + bounds.w and my >= bounds.y and my <= bounds.y + bounds.headerH then
				ServerInfoDragging = true
				ServerInfoOffset.x = mx - bounds.x
				ServerInfoOffset.y = my - bounds.y
			end
		else
			local newX, newY = ClampToScreen(mx - ServerInfoOffset.x, my - ServerInfoOffset.y, bounds.w, bounds.h)
			ServerInfoPos.x, ServerInfoPos.y = newX, newY
			local sw, sh = cheat.getWindowSize()
			ServerInfoRelPos.x = newX / sw
			ServerInfoRelPos.y = newY / sh
		end
	else
		ServerInfoDragging = false
	end
end

local function DrawServerInfoRelative(items)
	local sw, sh = cheat.getWindowSize()
	ServerInfoPos.x = ServerInfoRelPos.x * sw
	ServerInfoPos.y = ServerInfoRelPos.y * sh

	local bounds = DrawServerInfo(ServerInfoPos.x, ServerInfoPos.y, items)
	ServerInfoPos.x, ServerInfoPos.y = ClampToScreen(ServerInfoPos.x, ServerInfoPos.y, bounds.w, bounds.h)
	ServerInfoRelPos.x = ServerInfoPos.x / sw
	ServerInfoRelPos.y = ServerInfoPos.y / sh

	MoveServerInfo(bounds)
end

--// Runtime
cheat.Register("onPaint", function()
	if game.PlaceId == 0 then
		return
	end

	if not Enabled:Get() then
		return
	end

	local GlobalBestBrainrot, GlobalBestGen = nil, -1
	local ClosestPlot, ClosestDist = nil, math.huge
	local RootPosition = LocalPlayer:GetBonePosition("Head")

	for _, cached in pairs(Cache) do
		local owner = GetPlotOwner(cached)
		if owner:lower():gsub("[^%w]", "") == LocalPlayer.DisplayName:lower():gsub("[^%w]", "") then
			LocalPlayersPlot = cached
		end

		if RootPosition and cached.DrawPart and IsPlotActive(cached) and cached ~= LocalPlayersPlot then
			local pos = cached.DrawPart.Position
			local distSq = (pos.X - RootPosition.X) ^ 2 + (pos.Z - RootPosition.Z) ^ 2
			if distSq < ClosestDist and distSq <= 2500 then
				ClosestDist = distSq
				ClosestPlot = cached
			end
		end

		DrawPlotInfo(cached)

		local MinGen = PriceFilter:Get() * 1e6
		for _, brainrot in pairs(cached.CachedBrainrots) do
			local gen = ParseGeneration(brainrot.Info.Generation)

			if gen >= MinGen then
				if cached ~= LocalPlayersPlot then
					if gen > GlobalBestGen then
						GlobalBestGen, GlobalBestBrainrot = gen, brainrot
					end
				end

				if owner ~= LocalPlayer.DisplayName or ShowSelfPlot:Get() then
					DrawBrainrots(brainrot, false)
				end
			end
		end
	end

	if ShowServerInfo:Get() then
		local sw, _ = cheat.getWindowSize()
		if ServerInfoPos.x == 0 then
			ServerInfoPos.x = sw / 2 - 150
		end

		local infoItems = {
			{
				name = "Time Until Local Plot Unlock: "
					.. (
						LocalPlayersPlot
							and LocalPlayersPlot.Time
							and (LocalPlayersPlot.Time.Value == "0s" and "Unlocked" or LocalPlayersPlot.Time.Value)
						or "Failed to find Local Plot"
					),
			},
			{
				name = "Time Until Closest Plot Unlock: "
					.. (
						ClosestPlot
							and ClosestPlot.Time
							and (ClosestPlot.Time.Value == "0s" and "Unlocked" or ClosestPlot.Time.Value)
						or "No plots nearby."
					),
			},
			{
				name = "Best Brainrot: "
					.. (
						GlobalBestBrainrot
							and ((GlobalBestBrainrot.Info.DisplayName or "Unknown") .. " (Gen: " .. (GlobalBestBrainrot.Info.Generation or "N/A") .. ")")
						or "No brainrot found."
					),
			},
		}

		DrawServerInfoRelative(infoItems)
	end

	if TracerGlobalBest:Get() and GlobalBestBrainrot then
		local BrSPx, BrSPy, OnScreen = utility.WorldToScreen(GlobalBestBrainrot.BestRenderPart.Position)
		if OnScreen then
			local TracerX, TracerY = GetTracerPosition()
			local TracerColourRGB, TracerColourTable = TracerColor:Get("rgb"), TracerColor:Get()
			draw.Line(TracerX, TracerY, BrSPx, BrSPy, TracerColourRGB, TracerThickness:Get(), TracerColourTable.a)
		end
	end

	if HighlightGlobalBest:Get() and GlobalBestBrainrot then
		local outline = CalculateOutline(GlobalBestBrainrot.BestRenderPart)
		if outline and #outline >= 3 then
			draw.polyline(outline, Color3.fromRGB(255, 255, 255), true, 2, 255)
			draw.ConvexPolyFilled(outline, Color3.fromRGB(24, 222, 201), 100)
		end
	end

	if DrawRunway:Get() then
		for _, data in pairs(RunwayFellas) do
			DrawBrainrots(data, true)
		end
	end
end)

cheat.Register("onUpdate", function()
	local now = utility.GetTickCount()
	if now - LastCache > UpdateTime * 1000 then
		CapturePlots()
		for _, plot in pairs(Cache) do
			CachePlotBrainrots(plot)
		end
		LastCache = now
	end

	ui.setValue("Movement", "Main", "Shadow-Clone Jutsu", LocalPlayer.IsAlive)
end)

cheat.Register("onSlowUpdate", function()
	if game.PlaceId == 0 then
		return
	end

	if Workspace.Address ~= game.Workspace.Address then
		Workspace = game.Workspace
		Plots = Workspace:FindFirstChild("Plots")
		Cache, LastCache, LocalPlayersPlot = {}, 0, nil
		CapturePlots()
	end

	if not DrawRunway:Get() then
		RunwayFellas = {}
		return
	end

	for _, obj in pairs(Workspace:GetChildren()) do
		if IsGUIDObject(obj) and not RunwayFellas[obj.Address] then
			local data = { Info = {} }
			local renderPart = obj:FindFirstChild("Part")
			if renderPart then
				data.DrawPart = renderPart
				local Info = renderPart:FindFirstChild("Info")
				if Info then
					local overhead = Info:FindFirstChild("AnimalOverhead")
					if overhead then
						for _, label in ipairs(PodiumData) do
							local o = overhead:FindFirstChild(label)
							if o then
								data.Info[label] = o
							end
						end
					end
					RunwayFellas[obj.Address] = data
				end
			end
		end
	end

	for address in pairs(RunwayFellas) do
		if not FindChildByAddress(Workspace, address) then
			RunwayFellas[address] = nil
		end
	end
end)
