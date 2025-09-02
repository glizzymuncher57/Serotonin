local WorldToScreen = utility.WorldToScreen
local GetMousePosition = utility.GetMousePos
local GetTarget = entity.GetTarget

cheat.register("onUpdate", function()
	ui.setValue("Aimbot", "Aimbot", "Sticky Aim", true)

	local Target = GetTarget()
	local MousePosition = GetMousePosition()
	local FovRadius = ui.getValue("Aimbot", "Aimbot", "Field of View")

	if not Target then
		return
	end

	local HeadPosition = Target:GetBonePosition("Head")
	if HeadPosition then
		local XPos, YPos, OnScreen = WorldToScreen(HeadPosition)
		if not OnScreen then
			ui.setValue("Aimbot", "Aimbot", "Sticky Aim", false)
			return
		end

		local Distance = (Vector3.new(MousePosition[1], MousePosition[2], 0) - Vector3.new(XPos, YPos, 0)).Magnitude
		local IsInFov = Distance <= FovRadius

		if not IsInFov then
			ui.setValue("Aimbot", "Aimbot", "Sticky Aim", false)
			return
		end
	end
end)
