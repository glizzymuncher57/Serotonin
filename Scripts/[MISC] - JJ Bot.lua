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

	local Data = {
		Enabled = false,
		Index = 1,
		LastTick = 0,
	}

	local Menu = Library.NewTab("JJBOT", "JJ Bot")
	local Main = Menu:Container("MAIN", "Main", { autosize = true })
	local ForceIndexEnabled = Main:Checkbox("Force Starting Index")
	local ForceIndex = Main:SliderInt("Force Start Index", 1, 1000, 1)
	local Amount = Main:SliderInt("Amount", 1, 1000, 10)
	local Delay = Main:SliderFloat("Delay (seconds)", 0.1, 2, 1.5)
	local Mode = Main:Dropdown("Mode", { "Normal", "Grammar" }, 1)
	local _ = Main:Button("Reset Bot", function()
		Data.Index = 1
		Data.Enabled = false
	end)

	local function Chat(msg)
		keyboard.click(0xBF)

		for i = 1, #msg do
			local ch = msg:sub(i, i)

			if ch == " " then
				keyboard.click("Space")
			elseif ch == "\n" then
				keyboard.click("Enter")
			else
				if ch:match("%u") then
					keyboard.press("lshift")
					keyboard.click(ch)
					keyboard.release("lshift")
				else
					keyboard.click(ch)
				end
			end
		end

		if Mode:Get() == "Grammar" then
			keyboard.click(0xBE) -- '.'
		end

		keyboard.click("Enter")
		keyboard.click("Space")
	end

	local function NumberToWords(n)
		local ones = {
			"zero",
			"one",
			"two",
			"three",
			"four",
			"five",
			"six",
			"seven",
			"eight",
			"nine",
			"ten",
			"eleven",
			"twelve",
			"thirteen",
			"fourteen",
			"fifteen",
			"sixteen",
			"seventeen",
			"eighteen",
			"nineteen",
		}
		local tens = {
			[2] = "twenty",
			[3] = "thirty",
			[4] = "forty",
			[5] = "fifty",
			[6] = "sixty",
			[7] = "seventy",
			[8] = "eighty",
			[9] = "ninety",
		}

		if n < 20 then
			return ones[n + 1]
		elseif n < 100 then
			local ten = math.floor(n / 10)
			local one = n % 10
			if one == 0 then
				return tens[ten]
			else
				return tens[ten] .. " " .. ones[one + 1]
			end
		elseif n < 1000 then
			local hundred = math.floor(n / 100)
			local remainder = n % 100
			if remainder == 0 then
				return ones[hundred + 1] .. " hundred"
			else
				return ones[hundred + 1] .. " hundred " .. "and " .. NumberToWords(remainder)
			end
		elseif n == 1000 then
			return "one thousand"
		else
			return tostring(n)
		end
	end

	local function CapFirstLetter(str)
		return str:sub(1, 1):upper() .. str:sub(2)
	end

	local function UpdateData()
		if keyboard.IsPressed("middlemouse") then
			Data.Enabled = not Data.Enabled
			if Data.Enabled then
				ForceIndexEnabled:Set(false)
			end
		end

		if ForceIndexEnabled:Get() then
			Data.Index = ForceIndex:Get()
		end
	end

	local function MainLoop()
		if utility.GetMenuState() then
			print("menu open")
			return
		end

		if not Data.Enabled then
			print("not enabled")
			return
		end

		print(utility.GetTickCount() - Data.LastTick, Delay:Get() * 1000)
		if utility.GetTickCount() - Data.LastTick <= Delay:Get() * 1000 then
			print("too early")
			return
		end

		if Data.Index > tonumber(Amount:Get()) then
			Data.Enabled = false
			print("reached max amount")
			return
		end

		local Word = CapFirstLetter(NumberToWords(Data.Index))
		Chat(Word)
		Data.Index = Data.Index + 1
		Data.LastTick = utility.GetTickCount()
	end

	cheat.Register("onPaint", MainLoop)
	cheat.Register("onUpdate", UpdateData)
end)
