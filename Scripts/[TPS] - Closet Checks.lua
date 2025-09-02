local Link = "https://raw.githubusercontent.com/glizzymuncher57/Serotonin/refs/heads/main/Utility/UIAPIWrapper.lua"
local function GetWrapper(callback)
	if getfenv().CachedWrapper then
		callback(getfenv().CachedWrapper)
		return
	end

	http.Get(Link, {}, function(Response)
		if Response then
			local Wrapper = loadstring(Response)()
			callback(Wrapper)
			getfenv().CachedWrapper = Wrapper
			return
		end

		callback(nil)
	end)
end

GetWrapper(function(Library)
	if not Library then
		print("Failed to load UI Wrapper")
		return
	end

	local Player = entity.GetLocalPlayer()
	local WorldToScreen = utility.WorldToScreen
	local GetMousePosition = utility.GetMousePos
	local GetTarget = entity.GetTarget

	local MainTab = Library.NewTab("TPSBONUSCHECKS", "Clanner Checks")
	local MainContainer = MainTab:Container("MAIN", "Checks", { autosize = true })
	local LocalDeadCheck = MainContainer:Checkbox("Local Dead Check", false)
	local RightMouseCheck = MainContainer:Checkbox("Right Mouse Check", false)
	local FOVDistanceCheck = MainContainer:Checkbox("FOV Distance Check", false)
	local FOVMaxRange = MainContainer:SliderInt("FOV Max Range", 1, 1000, 150)
	local FOVMaxRangePart = MainContainer:Dropdown("FOV Max Range Part", { "Head", "Torso" }, 1)

	local function AimbotChecks()
		local ShouldDisableAimbot = (LocalDeadCheck:Get() and not Player.IsAlive)
			or (RightMouseCheck:Get() and keyboard.IsPressed("RightMouse"))
		ui.setValue("Aimbot", "Aimbot", "Enabled", not ShouldDisableAimbot)
	end

	local function StickyChecks()
		if FOVDistanceCheck:Get() then
			ui.setValue("Aimbot", "Aimbot", "Sticky Aim", true)

			local Target = GetTarget()
			if not Target then
				return
			end

			local MousePosition = GetMousePosition()
			local FovRadius = ui.getValue("Aimbot", "Aimbot", "Field of View")
			local TargetPosition = Target:GetBonePosition(FOVMaxRangePart:Get())

			local XPos, YPos, OnScreen = WorldToScreen(TargetPosition)
			if not OnScreen then
				ui.setValue("Aimbot", "Aimbot", "Sticky Aim", false)
				return
			end

			local Distance = (Vector3.new(MousePosition[1], MousePosition[2], 0) - Vector3.new(XPos, YPos, 0)).Magnitude
			local UnlockDistance = FovRadius + FOVMaxRange:Get()

			if Distance > UnlockDistance then
				ui.setValue("Aimbot", "Aimbot", "Sticky Aim", false)
			end
		end
	end

	local function MainLoop()
		if not Player then
			Player = entity.GetLocalPlayer()
		end

		AimbotChecks()
		StickyChecks()
	end

	cheat.register("onPaint", MainLoop)
end)
