local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

-- ============================================================
-- bobby.noob hub
-- ============================================================

local function fn()
	local genv = getgenv and getgenv() or _G
	local instance = genv.__BOBBY_NOOB_INSTANCE
	if instance and instance.ScreenGui and instance.ScreenGui.Parent then
		return instance
	end
	local CoreGui = game:GetService("CoreGui")
	local playerGui = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
	playerGui = CoreGui and CoreGui:FindFirstChild("BobbyNoob_UI") or playerGui and playerGui:FindFirstChild("BobbyNoob_UI")

	if playerGui then
		if instance and instance.ScreenGui == playerGui then
			return instance
		end
		local instance2 = { ScreenGui = playerGui, MainFrame = playerGui:FindFirstChild("MainFrame", true) }
		genv.__BOBBY_NOOB_INSTANCE = instance2
		return instance2
	end

	return nil
end

local existing = fn()

if existing then
	pcall(function()
		if existing.ScreenGui then existing.ScreenGui.Enabled = true end
		if existing.MainFrame then existing.MainFrame.Visible = true end
	end)
	return
end

local currentCamera = workspace.CurrentCamera

if not game:IsLoaded() then game.Loaded:Wait() end

while not localPlayer.Character or not localPlayer.Character:FindFirstChild("FULLY_LOADED_CHAR") do
	task.wait()
end

-- ============================================================
-- Config system
-- ============================================================

getgenv().BOBBY_ConfigControls = {}
getgenv().BOBBY_ConfigName = ""
getgenv().BOBBY_ConfigApplying = false
getgenv().BOBBY_KeybindCapturing = false
getgenv().BOBBY_ConfigCache = {}
local CONFIG_DIR = "BobbyNoob_Configs"

local function notify(text, good)
	local inst = getgenv().__BOBBY_NOOB_INSTANCE
	local parent = inst and inst.ScreenGui
	if not parent then return end
	local notif = Instance.new("TextLabel")
	notif.Size = UDim2.new(0, 320, 0, 34)
	notif.Position = UDim2.new(0.5, -160, 0, 20)
	notif.BackgroundColor3 = good and Color3.fromRGB(46, 160, 90) or Color3.fromRGB(200, 55, 70)
	notif.Text = tostring(text)
	notif.TextColor3 = Color3.fromRGB(255, 255, 255)
	notif.Font = Enum.Font.GothamBold
	notif.TextSize = 12
	notif.ZIndex = 100
	notif.Parent = parent
	Instance.new("UICorner", notif).CornerRadius = UDim.new(0, 6)
	task.delay(2.5, function() if notif and notif.Parent then notif:Destroy() end end)
end

local function configPath(arg)
	local safe = tostring(arg or "default"):gsub("[^%w%._%-]", "_")
	if safe == "" then safe = "default" end
	return CONFIG_DIR .. "/" .. safe .. ".json"
end

local function ensureConfigFolder()
	if type(makefolder) ~= "function" then return end
	pcall(function()
		if type(isfolder) ~= "function" or not isfolder(CONFIG_DIR) then
			makefolder(CONFIG_DIR)
		end
	end)
end

local function sanitize(arg)
	return tostring(arg or ""):gsub("[^%w%._%-]", "_")
end

local function collectConfig()
	local tbl = {}
	for k, ctrl in pairs(getgenv().BOBBY_ConfigControls) do
		if ctrl then
			if type(ctrl.get) == "function" then
				local ok, result = pcall(ctrl.get)
				if ok and result ~= nil then tbl[k] = result end
			end
			if type(ctrl.getKey) == "function" then
				local ok2, result2 = pcall(ctrl.getKey)
				if ok2 then
					tbl[k .. ":keybind"] = result2 or false
				end
			end
		end
	end
	return tbl
end

local function saveConfig(arg)
	local name = sanitize(arg)
	if name == "" then return false end
	getgenv().BOBBY_ConfigName = name
	local data = collectConfig()
	getgenv().BOBBY_ConfigCache[name] = data

	if type(writefile) ~= "function" then
		notify("Save failed: writefile not supported", false)
		return false
	end

	ensureConfigFolder()
	local ok = pcall(function()
		writefile(configPath(name), HttpService:JSONEncode(data))
	end)
	if not ok then
		notify("Save failed: could not write file", false)
	end
	return ok
end

local function applyConfig(arg)
	local name = sanitize(arg)
	if name == "" then return false end
	local data = nil

	if type(isfile) == "function" and type(readfile) == "function" then
		local ok, result = pcall(function()
			if isfile(configPath(name)) then return readfile(configPath(name)) end
			return nil
		end)
		if ok and result and result ~= "" then
			pcall(function() data = HttpService:JSONDecode(result) end)
		end
	end

	if type(data) ~= "table" then
		data = getgenv().BOBBY_ConfigCache[name]
	end
	if type(data) ~= "table" then return false end

	getgenv().BOBBY_ConfigApplying = true
	local failed = false

	for k, v in pairs(data) do
		local isKeybind = k:sub(-8) == ":keybind"
		local baseKey = isKeybind and k:sub(1, -9) or k
		local ctrl = getgenv().BOBBY_ConfigControls[baseKey]

		if isKeybind then
			if ctrl and type(ctrl.setKey) == "function" then
				local keyVal = (v == false) and nil or v
				if not pcall(ctrl.setKey, keyVal) then failed = true end
			end
		elseif ctrl and type(ctrl.set) == "function" then
			if not pcall(ctrl.set, v) then failed = true end
		end
	end

	getgenv().BOBBY_ConfigApplying = false
	getgenv().BOBBY_ConfigCache[name] = data
	return not failed
end

local function autoSave()
	if getgenv().BOBBY_ConfigApplying then return end
	local name = getgenv().BOBBY_ConfigName or ""
	if name == "" then return end
	saveConfig(name)
end

local function listConfigs()
	local out = {}
	local seen = {}

	if type(listfiles) == "function" then
		local ok, result = pcall(function() return listfiles(CONFIG_DIR) end)
		if ok and type(result) == "table" then
			for _, path in ipairs(result) do
				local match = tostring(path):match("([^/\\]+)%.json$")
				if match then
					local n = sanitize(match)
					if not seen[n] then seen[n] = true; out[#out + 1] = n end
				end
			end
		end
	end

	for k in pairs(getgenv().BOBBY_ConfigCache) do
		local n = sanitize(k)
		if not seen[n] then seen[n] = true; out[#out + 1] = n end
	end

	table.sort(out, function(a, b) return a:lower() < b:lower() end)
	return out
end

local function deleteConfig(arg)
	local name = sanitize(arg)
	getgenv().BOBBY_ConfigCache[name] = nil
	local path = configPath(name)
	local removed = false

	if type(delfile) == "function" and type(isfile) == "function" then
		if not pcall(function()
			if isfile(path) then delfile(path); removed = true end
		end) then removed = false end
	end

	return removed or true
end

-- ============================================================
-- UI library
-- ============================================================

local UI = {}
UI.__index = UI

local function create(className, props)
	local instance = Instance.new(className)
	for k, v in pairs(props or {}) do instance[k] = v end
	return instance
end

UI.CreateWindow = function(_, title)
	local ScreenGui = create("ScreenGui", {
		Name = "BobbyNoob_UI",
		Parent = RunService:IsStudio() and localPlayer:WaitForChild("PlayerGui") or game:GetService("CoreGui"),
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
	})

	local Frame = create("Frame", {
		Name = "MainFrame",
		Parent = ScreenGui,
		BackgroundColor3 = Color3.fromRGB(16, 17, 23),
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, -340, 0.5, -240),
		Size = UDim2.new(0, 680, 0, 480),
		ClipsDescendants = true,
		Active = true,
		Draggable = true,
	})

	create("UICorner", { Parent = Frame, CornerRadius = UDim.new(0, 10) })
	create("UIStroke", { Parent = Frame, Color = Color3.fromRGB(60, 130, 246), Thickness = 1.2 })

	local Topbar = create("Frame", {
		Name = "Topbar",
		Parent = Frame,
		BackgroundColor3 = Color3.fromRGB(22, 24, 32),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 60),
	})

	create("UICorner", { Parent = Topbar, CornerRadius = UDim.new(0, 10) })

	create("TextLabel", {
		Name = "Title",
		Parent = Topbar,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 20, 0, 0),
		Size = UDim2.new(1, -40, 1, 0),
		Font = Enum.Font.GothamBold,
		Text = title or "bobby.noob",
		TextColor3 = Color3.fromRGB(240, 245, 255),
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local discordLink = create("TextButton", {
		Name = "DiscordLink",
		Parent = Topbar,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 20, 0, 30),
		Size = UDim2.new(1, -40, 0, 20),
		Font = Enum.Font.Gotham,
		Text = "discord.gg/FAwnxqjMW2",
		TextColor3 = Color3.fromRGB(120, 160, 220),
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
	})

	discordLink.MouseButton1Click:Connect(function()
		if type(setclipboard) == "function" then
			pcall(setclipboard, "https://discord.gg/FAwnxqjMW2")
			discordLink.Text = "copied!"
			task.delay(1.2, function()
				if discordLink and discordLink.Parent then
					discordLink.Text = "discord.gg/FAwnxqjMW2"
				end
			end)
		end
	end)

	local Sidebar = create("ScrollingFrame", {
		Name = "Sidebar",
		Parent = Frame,
		BackgroundColor3 = Color3.fromRGB(12, 13, 18),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 0, 72),
		Size = UDim2.new(0, 135, 1, -84),
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Color3.fromRGB(60, 130, 246),
		CanvasSize = UDim2.new(0, 0, 0, 0),
	})

	create("UICorner", { Parent = Sidebar, CornerRadius = UDim.new(0, 8) })

	local SidebarLayout = create("UIListLayout", {
		Parent = Sidebar,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	SidebarLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		Sidebar.CanvasSize = UDim2.new(0, 0, 0, SidebarLayout.AbsoluteContentSize.Y + 12)
	end)

	local Content = create("Frame", {
		Name = "ContentArea",
		Parent = Frame,
		BackgroundColor3 = Color3.fromRGB(12, 13, 18),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 160, 0, 72),
		Size = UDim2.new(1, -172, 1, -84),
	})

	create("UICorner", { Parent = Content, CornerRadius = UDim.new(0, 8) })

	local lib
	lib = {
		Pages = {},
		ActivePage = nil,
		ScreenGui = ScreenGui,
		MainFrame = Frame,
	}

	lib.addPage = function(_, name)
		local TabBtn = create("TextButton", {
			Name = name .. "_Btn",
			Parent = Sidebar,
			BackgroundColor3 = Color3.fromRGB(24, 26, 34),
			BorderSizePixel = 0,
			Size = UDim2.new(1, -12, 0, 32),
			Position = UDim2.new(0, 6, 0, 0),
			Font = Enum.Font.GothamMedium,
			Text = name,
			TextColor3 = Color3.fromRGB(160, 170, 190),
			TextSize = 12,
			AutoButtonColor = false,
			LayoutOrder = #lib.Pages,
		})
		create("UICorner", { Parent = TabBtn, CornerRadius = UDim.new(0, 6) })

		local Container = create("ScrollingFrame", {
			Name = name .. "_Container",
			Parent = Content,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Position = UDim2.new(0, 8, 0, 8),
			Size = UDim2.new(1, -16, 1, -16),
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Color3.fromRGB(60, 130, 246),
			Visible = false,
			CanvasSize = UDim2.new(0, 0, 0, 0),
		})

		local Layout = create("UIListLayout", {
			Parent = Container,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})

		Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			Container.CanvasSize = UDim2.new(0, 0, 0, Layout.AbsoluteContentSize.Y + 12)
		end)

		local page = { Button = TabBtn, Container = Container }

		local function select()
			for _, other in pairs(lib.Pages) do
				other.Container.Visible = false
				other.Button.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
				other.Button.TextColor3 = Color3.fromRGB(160, 170, 190)
			end
			Container.Visible = true
			TabBtn.BackgroundColor3 = Color3.fromRGB(30, 46, 78)
			TabBtn.TextColor3 = Color3.fromRGB(120, 190, 255)
			lib.ActivePage = page
		end

		TabBtn.MouseButton1Click:Connect(select)

		if not lib.ActivePage then select() end

		page.addToggle = function(_, label, default, callback, keybindEnabled, keybindDefault, noKeybind)
			local Frame4 = create("Frame", {
				Name = "Toggle_" .. label,
				Parent = Container,
				BackgroundColor3 = Color3.fromRGB(22, 24, 32),
				BorderSizePixel = 0,
				Size = UDim2.new(1, -6, 0, 36),
			})
			create("UICorner", { Parent = Frame4, CornerRadius = UDim.new(0, 6) })

			local ClickBtn = create("TextButton", {
				Parent = Frame4,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -80, 1, 0),
				Text = "",
				ZIndex = 3,
			})

			create("TextLabel", {
				Parent = Frame4,
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0, 0),
				Size = UDim2.new(0.65, 0, 1, 0),
				Font = Enum.Font.Gotham,
				Text = label,
				TextColor3 = Color3.fromRGB(220, 226, 238),
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
			})

			local Switch = create("TextButton", {
				Parent = Frame4,
				BackgroundColor3 = Color3.fromRGB(38, 42, 54),
				BorderSizePixel = 0,
				Position = UDim2.new(1, -46, 0.5, -10),
				Size = UDim2.new(0, 34, 0, 20),
				Text = "",
				ZIndex = 3,
			})
			create("UICorner", { Parent = Switch, CornerRadius = UDim.new(1, 0) })

			local Dot = create("Frame", {
				Parent = Switch,
				BackgroundColor3 = Color3.fromRGB(140, 148, 165),
				BorderSizePixel = 0,
				Position = UDim2.new(0, 3, 0.5, -7),
				Size = UDim2.new(0, 14, 0, 14),
				ZIndex = 4,
			})
			create("UICorner", { Parent = Dot, CornerRadius = UDim.new(1, 0) })

			local keyBtn = nil
			local key = typeof(keybindDefault) == "EnumItem" and keybindDefault or nil
			local listening = false

			if keybindEnabled and not noKeybind then
				keyBtn = create("TextButton", {
					Parent = Frame4,
					BackgroundColor3 = Color3.fromRGB(32, 36, 48),
					BorderSizePixel = 0,
					Position = UDim2.new(1, -132, 0.5, -10),
					Size = UDim2.new(0, 76, 0, 20),
					Font = Enum.Font.Gotham,
					Text = key and ("[" .. key.Name .. "]") or "[ unbound ]",
					TextColor3 = Color3.fromRGB(120, 190, 255),
					TextSize = 10,
					AutoButtonColor = false,
					ZIndex = 4,
				})
				create("UICorner", { Parent = keyBtn, CornerRadius = UDim.new(0, 4) })

				keyBtn.MouseButton1Click:Connect(function()
					listening = true
					getgenv().BOBBY_KeybindCapturing = true
					keyBtn.Text = "[ press key ]"
					keyBtn.TextColor3 = Color3.fromRGB(255, 205, 100)
				end)
			end

			local state = default == true

			local function render()
				Switch.BackgroundColor3 = state and Color3.fromRGB(60, 130, 246) or Color3.fromRGB(38, 42, 54)
				Dot.Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
				Dot.BackgroundColor3 = state and Color3.fromRGB(240, 245, 255) or Color3.fromRGB(140, 148, 165)
			end

			local function toggle()
				state = not state
				render()
				if callback then task.spawn(callback, state) end
				autoSave()
			end

			ClickBtn.MouseButton1Click:Connect(toggle)
			Switch.MouseButton1Click:Connect(toggle)

			UserInputService.InputBegan:Connect(function(input, processed)
				if listening and input.UserInputType == Enum.UserInputType.Keyboard then
					if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
						key = nil
						if keyBtn then
							keyBtn.Text = "[ unbound ]"
							keyBtn.TextColor3 = Color3.fromRGB(120, 190, 255)
						end
					else
						key = input.KeyCode
						if keyBtn then
							keyBtn.Text = "[" .. key.Name .. "]"
							keyBtn.TextColor3 = Color3.fromRGB(120, 190, 255)
						end
					end
					listening = false
					getgenv().BOBBY_KeybindCapturing = false
					autoSave()
					return
				end

				if getgenv().BOBBY_KeybindCapturing then return end
				if not processed and key and input.KeyCode == key then
					toggle()
				end
			end)

			render()

			getgenv().BOBBY_ConfigControls["toggle:" .. tostring(label)] = {
				get = function() return state end,
				set = function(v)
					local new = v == true
					if state ~= new then
						state = new
						render()
						if callback then task.spawn(callback, state) end
					else
						render()
					end
				end,
				getKey = function() return key and key.Name or nil end,
				setKey = function(v)
					if not keyBtn then return end
					local enum = type(v) == "string" and Enum.KeyCode[v] or nil
					key = enum
					keyBtn.Text = enum and ("[" .. enum.Name .. "]") or "[ unbound ]"
				end,
			}

			return Frame4
		end

		page.addKeybind = function(_, label, defaultKey, onPressed)
			local Frame4 = create("Frame", {
				Name = "Keybind_" .. label,
				Parent = Container,
				BackgroundColor3 = Color3.fromRGB(22, 24, 32),
				BorderSizePixel = 0,
				Size = UDim2.new(1, -6, 0, 36),
			})
			create("UICorner", { Parent = Frame4, CornerRadius = UDim.new(0, 6) })

			create("TextLabel", {
				Parent = Frame4,
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0, 0),
				Size = UDim2.new(0.65, 0, 1, 0),
				Font = Enum.Font.Gotham,
				Text = label,
				TextColor3 = Color3.fromRGB(220, 226, 238),
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
			})

			local key = typeof(defaultKey) == "EnumItem" and defaultKey or nil
			local listening = false

			local keyBtn = create("TextButton", {
				Parent = Frame4,
				BackgroundColor3 = Color3.fromRGB(32, 36, 48),
				BorderSizePixel = 0,
				Position = UDim2.new(1, -132, 0.5, -10),
				Size = UDim2.new(0, 120, 0, 20),
				Font = Enum.Font.Gotham,
				Text = key and ("[ " .. key.Name .. " ]") or "[ unbound ]",
				TextColor3 = Color3.fromRGB(120, 190, 255),
				TextSize = 10,
				AutoButtonColor = false,
				ZIndex = 4,
			})
			create("UICorner", { Parent = keyBtn, CornerRadius = UDim.new(0, 4) })

			keyBtn.MouseButton1Click:Connect(function()
				listening = true
				getgenv().BOBBY_KeybindCapturing = true
				keyBtn.Text = "[ press key ]"
				keyBtn.TextColor3 = Color3.fromRGB(255, 205, 100)
			end)

			UserInputService.InputBegan:Connect(function(input, processed)
				if listening and input.UserInputType == Enum.UserInputType.Keyboard then
					if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
						key = nil
						keyBtn.Text = "[ unbound ]"
						keyBtn.TextColor3 = Color3.fromRGB(120, 190, 255)
					else
						key = input.KeyCode
						keyBtn.Text = "[ " .. key.Name .. " ]"
						keyBtn.TextColor3 = Color3.fromRGB(120, 190, 255)
					end
					listening = false
					getgenv().BOBBY_KeybindCapturing = false
					autoSave()
					return
				end

				if getgenv().BOBBY_KeybindCapturing then return end
				if not processed and key and input.KeyCode == key then
					if onPressed then task.spawn(onPressed) end
				end
			end)

			getgenv().BOBBY_ConfigControls["keybind:" .. tostring(label)] = {
				getKey = function() return key and key.Name or nil end,
				setKey = function(v)
					local enum = type(v) == "string" and Enum.KeyCode[v] or nil
					key = enum
					keyBtn.Text = enum and ("[ " .. enum.Name .. " ]") or "[ unbound ]"
				end,
			}

			return Frame4
		end

		page.addSlider = function(_, label, min, max, callback, default)
			local Frame4 = create("Frame", {
				Name = "Slider_" .. label,
				Parent = Container,
				BackgroundColor3 = Color3.fromRGB(22, 24, 32),
				BorderSizePixel = 0,
				Size = UDim2.new(1, -6, 0, 52),
			})
			create("UICorner", { Parent = Frame4, CornerRadius = UDim.new(0, 6) })

			create("TextLabel", {
				Parent = Frame4,
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0, 6),
				Size = UDim2.new(0.7, 0, 0, 16),
				Font = Enum.Font.Gotham,
				Text = label,
				TextColor3 = Color3.fromRGB(220, 226, 238),
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
			})

			local Value = create("TextLabel", {
				Parent = Frame4,
				BackgroundTransparency = 1,
				Position = UDim2.new(1, -60, 0, 6),
				Size = UDim2.new(0, 48, 0, 16),
				Font = Enum.Font.GothamBold,
				Text = tostring(default or min),
				TextColor3 = Color3.fromRGB(120, 190, 255),
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Right,
			})

			local Bar = create("TextButton", {
				Parent = Frame4,
				BackgroundColor3 = Color3.fromRGB(38, 42, 54),
				BorderSizePixel = 0,
				Position = UDim2.new(0, 12, 0, 28),
				Size = UDim2.new(1, -24, 0, 10),
				Text = "",
				AutoButtonColor = false,
				ClipsDescendants = false,
				ZIndex = 1,
			})
			create("UICorner", { Parent = Bar, CornerRadius = UDim.new(1, 0) })

			local Fill = create("Frame", {
				Parent = Bar,
				BackgroundColor3 = Color3.fromRGB(60, 130, 246),
				BorderSizePixel = 0,
				Size = UDim2.new(0, 0, 1, 0),
				ZIndex = 3,
			})
			create("UICorner", { Parent = Fill, CornerRadius = UDim.new(1, 0) })

			local current = math.clamp(tonumber(default) or min, min, max)
			local dragging = false

			local function setValue(v)
				current = math.clamp(math.floor(tonumber(v) or min), min, max)
				local ratio = (current - min) / math.max(max - min, 1)
				Fill.Size = UDim2.new(ratio, 0, 1, 0)
				Value.Text = tostring(current)
				if callback then task.spawn(callback, current) end
			end

			setValue(current)

			local function fromInput(input)
				local x = math.clamp((input.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
				setValue(min + (max - min) * x)
			end

			Bar.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					fromInput(input)
				end
			end)

			UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					if dragging then dragging = false; autoSave() end
				end
			end)

			UserInputService.InputChanged:Connect(function(input)
				if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					fromInput(input)
				end
			end)

			getgenv().BOBBY_ConfigControls["slider:" .. tostring(label)] = {
				get = function() return current end,
				set = function(v) setValue(v) end,
			}

			return Frame4
		end

		page.addButton = function(_, label, callback)
			local Btn = create("TextButton", {
				Name = "Btn_" .. tostring(label),
				Parent = Container,
				BackgroundColor3 = Color3.fromRGB(28, 32, 44),
				BorderSizePixel = 0,
				Size = UDim2.new(1, -6, 0, 32),
				Font = Enum.Font.GothamMedium,
				Text = tostring(label),
				TextColor3 = Color3.fromRGB(120, 190, 255),
				TextSize = 12,
			})
			create("UICorner", { Parent = Btn, CornerRadius = UDim.new(0, 6) })

			Btn.MouseButton1Click:Connect(function()
				if callback then task.spawn(callback) end
			end)

			return Btn
		end

		page.addTextBox = function(_, label, placeholder, callback)
			local Frame4 = create("Frame", {
				Name = "TextBox_" .. label,
				Parent = Container,
				BackgroundColor3 = Color3.fromRGB(22, 24, 32),
				BorderSizePixel = 0,
				Size = UDim2.new(1, -6, 0, 36),
			})
			create("UICorner", { Parent = Frame4, CornerRadius = UDim.new(0, 6) })

			create("TextLabel", {
				Parent = Frame4,
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0, 0),
				Size = UDim2.new(0.45, 0, 1, 0),
				Font = Enum.Font.Gotham,
				Text = label,
				TextColor3 = Color3.fromRGB(220, 226, 238),
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
			})

			local Box = create("TextBox", {
				Parent = Frame4,
				BackgroundColor3 = Color3.fromRGB(38, 42, 54),
				BorderSizePixel = 0,
				Position = UDim2.new(0.5, 0, 0.5, -12),
				Size = UDim2.new(0.5, -12, 0, 24),
				Font = Enum.Font.Gotham,
				Text = "",
				TextColor3 = Color3.fromRGB(240, 245, 255),
				TextSize = 11,
				ClearTextOnFocus = false,
			})
			create("UICorner", { Parent = Box, CornerRadius = UDim.new(0, 4) })

			Box.PlaceholderText = placeholder or ""
			Box.PlaceholderColor3 = Color3.fromRGB(120, 128, 148)

			Box.FocusLost:Connect(function()
				if callback then task.spawn(callback, Box.Text) end
				autoSave()
			end)

			getgenv().BOBBY_ConfigControls["textbox:" .. tostring(label)] = {
				get = function() return Box.Text end,
				set = function(v)
					Box.Text = tostring(v or "")
					if callback then task.spawn(callback, Box.Text) end
				end,
			}

			return Frame4
		end

		page.addLabel = function(_, text, subtitle)
			local Frame4 = create("Frame", {
				Name = "Label_" .. text,
				Parent = Container,
				BackgroundColor3 = Color3.fromRGB(18, 20, 28),
				BorderSizePixel = 0,
				Size = UDim2.new(1, -6, 0, subtitle and 42 or 26),
			})
			create("UICorner", { Parent = Frame4, CornerRadius = UDim.new(0, 6) })

			create("TextLabel", {
				Parent = Frame4,
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0, subtitle and 5 or 0),
				Size = UDim2.new(1, -24, 0, subtitle and 16 or 26),
				Font = Enum.Font.GothamBold,
				Text = text,
				TextColor3 = Color3.fromRGB(120, 190, 255),
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
			})

			if subtitle and subtitle ~= "" then
				create("TextLabel", {
					Parent = Frame4,
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 12, 0, 22),
					Size = UDim2.new(1, -24, 0, 14),
					Font = Enum.Font.Gotham,
					Text = subtitle,
					TextColor3 = Color3.fromRGB(150, 160, 180),
					TextSize = 10,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
			end
		end

		page.addSeparator = function()
			create("Frame", {
				Parent = Container,
				BackgroundColor3 = Color3.fromRGB(38, 42, 54),
				BorderSizePixel = 0,
				Size = UDim2.new(1, -12, 0, 1),
			})
		end

		table.insert(lib.Pages, page)
		return page
	end

	return lib
end

-- ============================================================
-- State table
-- ============================================================

_G.TargetName = _G.TargetName or ""

local state = {
	value1 = Players,
	value2 = RunService,
	value3 = UserInputService,
	value4 = localPlayer,
	value5 = currentCamera,
	value107 = localPlayer,
	value18 = 1,
	value19 = false,
	value23 = nil,
	value35 = {
		Enabled = false,
		Visible = false,
		Radius = 115,
		Filled = false,
		FillTransparency = 0.5,
		Transparency = 1,
		Thickness = 1,
		ShowFOV = false,
		Color = Color3.fromRGB(60, 130, 246),
	},
	value40 = { Enabled = false, HitPart = "Head" },
	NoclipEnabled = false,
	NoclipConnection = nil,
	NoclipCharConnection = nil,
	FlyEnabled = false,
	FlySpeed = 1,
	FlyConnection = nil,
	AutoReloadEnabled = false,
	AutoReloadConnection = nil,
	InfiniteZoomEnabled = false,
	NoJumpCooldownEnabled = false,
	NoJumpCooldownConnection = nil,
}

state.value110 = function(query)
	if not query or query == "" then return nil end
	local direct = Players:FindFirstChild(query)
	if direct then return direct end
	for _, p in ipairs(Players:GetPlayers()) do
		if p == state.value107 then continue end
		if p.Name:lower():find(query:lower(), 1, true) or p.DisplayName:lower():find(query:lower(), 1, true) then
			return p
		end
	end
	return nil
end

-- ============================================================
-- Auto Reload
-- ============================================================

local function startAutoReload()
	if state.AutoReloadConnection then
		state.AutoReloadConnection:Disconnect()
		state.AutoReloadConnection = nil
	end

	state.AutoReloadConnection = state.value2.Heartbeat:Connect(function()
		if not state.AutoReloadEnabled then return end

		local char = localPlayer.Character
		if not char then return end

		local tool = char:FindFirstChildOfClass("Tool")
		if not tool then return end

		local ammo = tool:GetAttribute("Ammo") or tool:GetAttribute("CurrentAmmo")
			or tool:GetAttribute("Bullets") or tool:GetAttribute("Clip")
			or tool:GetAttribute("AmmoCount") or tool:GetAttribute("Magazine")

		if ammo ~= nil and tonumber(ammo) ~= nil and tonumber(ammo) <= 0 then
			local rs = game:GetService("ReplicatedStorage")
			local mainEvent = rs:FindFirstChild("MainEvent")
			if mainEvent then
				pcall(function()
					mainEvent:FireServer("Reload", tool)
				end)
			end
			pcall(function() tool:Activate() end)
		end
	end)
end

local function stopAutoReload()
	if state.AutoReloadConnection then
		state.AutoReloadConnection:Disconnect()
		state.AutoReloadConnection = nil
	end
end

-- ============================================================
-- Infinite Zoom
-- ============================================================

local function applyInfiniteZoom()
	local cam = workspace.CurrentCamera
	if not cam then return end

	pcall(function()
		localPlayer.CameraMinZoomDistance = 0.5
		localPlayer.CameraMaxZoomDistance = 5000
	end)
end

local function stopInfiniteZoom()
	local cam = workspace.CurrentCamera
	if cam then
		pcall(function()
			localPlayer.CameraMinZoomDistance = 0.5
			localPlayer.CameraMaxZoomDistance = 400
		end)
	end
end

-- ============================================================
-- No Jump Cooldown
-- ============================================================

local function startNoJumpCooldown()
	if state.NoJumpCooldownConnection then
		state.NoJumpCooldownConnection:Disconnect()
		state.NoJumpCooldownConnection = nil
	end

	state.NoJumpCooldownConnection = state.value2.Heartbeat:Connect(function()
		if not state.NoJumpCooldownEnabled then return end

		local char = localPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then return end

		pcall(function()
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		end)

		for _, attr in ipairs({ "JumpCooldown", "LastJump", "JumpTime", "CanJump", "JumpDebounce" }) do
			pcall(function()
				if hum:GetAttribute(attr) ~= nil then
					hum:SetAttribute(attr, attr == "CanJump" and true or 0)
				end
			end)
		end
	end)
end

local function stopNoJumpCooldown()
	if state.NoJumpCooldownConnection then
		state.NoJumpCooldownConnection:Disconnect()
		state.NoJumpCooldownConnection = nil
	end
end

-- ============================================================
-- Window
-- ============================================================

local window = UI:CreateWindow("bobby.noob")
getgenv().__BOBBY_NOOB_INSTANCE = window

local Legit = window:addPage("Legit")
local Movement = window:addPage("Movement")
local Strafe = window:addPage("Strafe")
local Visuals = window:addPage("Visuals")
local Teleport = window:addPage("Teleport")
local Utility = window:addPage("Utility")
local Configs = window:addPage("Configs")

-- ============================================================
-- Legit page
-- ============================================================

Legit:addLabel("Silent Aim")

local FOVCircle = nil
if typeof(Drawing) == "table" and typeof(Drawing.new) == "function" then
	pcall(function()
		FOVCircle = Drawing.new("Circle")
		FOVCircle.Color = state.value35.Color
		FOVCircle.Thickness = 1
		FOVCircle.Filled = false
		FOVCircle.Transparency = 1
		FOVCircle.Radius = state.value35.Radius
		FOVCircle.Visible = false
	end)
end
state.value41 = FOVCircle

local fovHighlights = {}

local function clearFOVHighlights()
	for k, hl in pairs(fovHighlights) do
		pcall(function() hl:Destroy() end)
		fovHighlights[k] = nil
	end
end

local function isKnocked(character)
	local bodyEffects = character:FindFirstChild("BodyEffects")
	if not bodyEffects then return false end
	local ko = bodyEffects:FindFirstChild("K.O") or bodyEffects:FindFirstChild("KO")
	if not ko then return false end
	if typeof(ko.Value) == "boolean" then return ko.Value end
	if typeof(ko.Value) == "number" then return ko.Value > 0 end
	return false
end

local function getSilentAimTarget()
	if not state.value40.Enabled then return nil end
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local mouse = state.value3:GetMouseLocation()
	local bestRadius = tonumber(state.value35.Radius) or 115
	local bestPart = nil

	for _, player in ipairs(state.value1:GetPlayers()) do
		if player ~= state.value4 then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 and not isKnocked(character) then
				local part = character:FindFirstChild(state.value40.HitPart or "Head") or character:FindFirstChild("Head")
				if part then
					local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
					if onScreen and screenPos.Z > 0 then
						local dist = (Vector2.new(screenPos.X, screenPos.Y) - mouse).Magnitude
						if dist <= bestRadius then
							bestRadius = dist
							bestPart = part
						end
					end
				end
			end
		end
	end

	return bestPart
end

local silentAimState = getgenv().__BOBBY_SILENT_AIM or {}
getgenv().__BOBBY_SILENT_AIM = silentAimState
silentAimState.Enabled = false
silentAimState.GetTarget = getSilentAimTarget
silentAimState.OriginalGetAim = silentAimState.OriginalGetAim
silentAimState.HookInstalled = silentAimState.HookInstalled == true

if not silentAimState.HookInstalled then
	pcall(function()
		local modules = ReplicatedStorage:FindFirstChild("Modules")
		modules = modules and modules:FindFirstChild("GunHandler")
		if not modules then return end
		local module = require(modules)
		if type(module) ~= "table" or type(module.getAim) ~= "function" then return end
		silentAimState.OriginalGetAim = silentAimState.OriginalGetAim or module.getAim
		local original = silentAimState.OriginalGetAim

		module.getAim = function(...)
			local packed = table.pack(...)
			local origin = nil
			local maxDist = nil

			for _, v in ipairs({ ... }) do
				if origin == nil and typeof(v) == "Vector3" then
					origin = v
				elseif maxDist == nil and type(v) == "number" then
					maxDist = v
				end
			end

			if silentAimState.Enabled and origin then
				local target = silentAimState.GetTarget and silentAimState.GetTarget()
				if target and target.Parent then
					local dir = target.Position - origin
					local mag = dir.Magnitude
					if mag > 0 then
						return dir.Unit, maxDist and math.min(mag, maxDist) or mag
					end
				end
			end

			return original(table.unpack(packed, 1, packed.n))
		end

		silentAimState.HookInstalled = true
	end)
end

local function updateFOVVisuals()
	if not state.value35.ShowFOV or not state.value40.Enabled then
		clearFOVHighlights()
		return
	end
	local cam = workspace.CurrentCamera
	if not cam then clearFOVHighlights(); return end
	local mouse = state.value3:GetMouseLocation()
	local radius = tonumber(state.value35.Radius) or 115
	local active = {}

	for _, player in ipairs(state.value1:GetPlayers()) do
		if player ~= state.value4 and player.Character then
			local character = player.Character
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local head = character:FindFirstChild("Head")
			if humanoid and humanoid.Health > 0 and head and not isKnocked(character) then
				local screenPos, onScreen = cam:WorldToViewportPoint(head.Position)
				if onScreen and screenPos.Z > 0 and (Vector2.new(screenPos.X, screenPos.Y) - mouse).Magnitude <= radius then
					active[player] = true
					local hl = fovHighlights[player]
					if not hl or not hl.Parent then
						hl = Instance.new("Highlight")
						hl.Name = "BobbyNoob_FOV"
						hl.FillColor = state.value35.Color
						hl.FillTransparency = 0.78
						hl.OutlineColor = state.value35.Color
						hl.OutlineTransparency = 0
						hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						hl.Parent = game:GetService("CoreGui")
						fovHighlights[player] = hl
					end
					hl.Adornee = character
				end
			end
		end
	end

	for k, hl in pairs(fovHighlights) do
		if not active[k] then
			pcall(function() hl:Destroy() end)
			fovHighlights[k] = nil
		end
	end
end

Legit:addToggle("Silent Aim", false, function(on)
	state.value40.Enabled = on
	state.value35.Enabled = on
	if not on then
		state.value35.Visible = false
		if state.value41 then state.value41.Visible = false end
		clearFOVHighlights()
	end
end, false, nil, true)

Legit:addToggle("Show FOV", false, function(on)
	state.value35.ShowFOV = on
	state.value35.Visible = on and state.value40.Enabled
	if not on then clearFOVHighlights() end
end, false, nil, true)

Legit:addSlider("FOV Size", 20, 1000, function(v)
	state.value35.Radius = math.clamp(tonumber(v) or 115, 20, 1000)
end, 115)

Legit:addSeparator()
Legit:addLabel("Target bone")
Legit:addToggle("Aim at Head", true, function(on)
	state.value40.HitPart = on and "Head" or "UpperTorso"
end, false, nil, true)

Legit:addSeparator()

local camlock = {
	Enabled = false,
	Target = nil,
	Connection = nil,
}

local function isValidCamlockTarget(player)
	if not player or player.Parent ~= state.value1 or not player.Character then return false end
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	local head = player.Character:FindFirstChild("Head")
	return humanoid and humanoid.Health > 0 and hrp ~= nil and head ~= nil
end

local function getNearestCamlockPlayer()
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local best = nil

	for _, player in ipairs(state.value1:GetPlayers()) do
		if player ~= state.value4 and player.Character then
			local hrp = player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local screenPos, onScreen = cam:WorldToViewportPoint(hrp.Position)
				local dist = (state.value3:GetMouseLocation() - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
				if onScreen and (best == nil or dist < best.dist) then
					best = { player = player, dist = dist }
				end
			end
		end
	end

	return best and best.player or nil
end

local function stopCamlock()
	camlock.Enabled = false
	camlock.Target = nil
	if camlock.Connection then
		camlock.Connection:Disconnect()
		camlock.Connection = nil
	end
end

local function startCamlock()
	stopCamlock()
	camlock.Enabled = true
	local target = getNearestCamlockPlayer()
	if not isValidCamlockTarget(target) then
		camlock.Enabled = false
		return
	end
	camlock.Target = target

	camlock.Connection = state.value2.RenderStepped:Connect(function()
		if not camlock.Enabled then return end
		local t = camlock.Target
		if not isValidCamlockTarget(t) then
			t = getNearestCamlockPlayer()
			camlock.Target = t
		end
		if not isValidCamlockTarget(t) then return end
		local cam = workspace.CurrentCamera
		local head = t.Character:FindFirstChild("Head")
		if cam and head then
			cam.CFrame = CFrame.lookAt(cam.CFrame.Position, head.Position)
		end
	end)
end

Legit:addToggle("Camlock", false, function(on)
	if on then startCamlock() else stopCamlock() end
end, true, Enum.KeyCode.C)

state.value2.RenderStepped:Connect(function()
	if state.value41 then
		local show = state.value35.Enabled and state.value35.ShowFOV
		state.value41.Visible = show
		if show then
			state.value41.Position = state.value3:GetMouseLocation()
			state.value41.Radius = state.value35.Radius
			state.value41.Filled = false
			state.value41.Color = state.value35.Color
			state.value41.Transparency = state.value35.Transparency
		end
	end

	if state.value35.Enabled then
		silentAimState.Enabled = true
		updateFOVVisuals()
	else
		silentAimState.Enabled = false
		clearFOVHighlights()
	end
end)

-- ============================================================
-- Movement page
-- ============================================================

Movement:addLabel("Movement")

local function stopFly()
	if state.FlyConnection then
		state.FlyConnection:Disconnect()
		state.FlyConnection = nil
	end
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		pcall(function() humanoid.PlatformStand = false end)
	end
end

local function startFly()
	stopFly()
	state.FlyConnection = state.value2.Stepped:Connect(function(_, deltaTime)
		if not state.FlyEnabled then return end
		local character = localPlayer.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local cam = workspace.CurrentCamera
		if not humanoidRootPart or not humanoid or not cam then return end

		local vector = Vector3.zero

		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			vector = vector + cam.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			vector = vector - cam.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			vector = vector - cam.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			vector = vector + cam.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			vector = vector + Vector3.new(0, 1, 0)
		end

		if vector.Magnitude > 0 then
			local step = vector.Unit * (tonumber(state.FlySpeed) or 1) * 4 * deltaTime
			local seatPart = humanoid.SeatPart
			local model = seatPart and seatPart:FindFirstAncestorWhichIsA("Model")

			if model and model ~= character and model.PrimaryPart then
				pcall(function()
					model:PivotTo(model:GetPivot() + step)
				end)
			else
				humanoidRootPart.CFrame = humanoidRootPart.CFrame + step
			end
		end

		humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
	end)
end

Movement:addToggle("Fly", false, function(on)
	state.FlyEnabled = on
	if on then startFly() else stopFly() end
end, true, Enum.KeyCode.F)

Movement:addSlider("Fly Speed", 1, 200, function(v)
	state.FlySpeed = math.clamp(tonumber(v) or 1, 1, 200)
end, 1)

Movement:addSeparator()

Movement:addToggle("Walkspeed", true, function(on)
	state.value19 = on
	if state.value23 then
		state.value23:Disconnect()
		state.value23 = nil
	end
	if on then
		state.value23 = state.value2.Heartbeat:Connect(function(dt)
			if not state.value19 then return end
			local character = localPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if not character or not humanoid or not hrp then return end
			local dir = humanoid.MoveDirection
			if dir.Magnitude > 0 then
				local step = (tonumber(state.value18) or 1) * 4 * dt
				hrp.CFrame = hrp.CFrame + dir.Unit * step
			end
		end)
	end
end, true, nil)

Movement:addSlider("Walkspeed Amount", 1, 200, function(v)
	state.value18 = math.clamp(tonumber(v) or 1, 1, 200)
end, 50)

Movement:addSeparator()

local function applyNoclipToCharacter(character)
	if not character then return end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			part.CanCollide = false
		end
	end
end

local function startNoclip()
	if state.NoclipConnection then
		state.NoclipConnection:Disconnect()
		state.NoclipConnection = nil
	end
	if state.NoclipCharConnection then
		state.NoclipCharConnection:Disconnect()
		state.NoclipCharConnection = nil
	end

	applyNoclipToCharacter(localPlayer.Character)

	state.NoclipConnection = state.value2.Stepped:Connect(function()
		if not state.NoclipEnabled then return end
		local character = localPlayer.Character
		if not character then return end
		applyNoclipToCharacter(character)
	end)

	state.NoclipCharConnection = localPlayer.CharacterAdded:Connect(function(character)
		if not state.NoclipEnabled then return end
		character:WaitForChild("HumanoidRootPart", 5)
		applyNoclipToCharacter(character)
	end)
end

local function stopNoclip()
	if state.NoclipConnection then
		state.NoclipConnection:Disconnect()
		state.NoclipConnection = nil
	end
	if state.NoclipCharConnection then
		state.NoclipCharConnection:Disconnect()
		state.NoclipCharConnection = nil
	end

	local character = localPlayer.Character
	if character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = true
			end
		end
	end
end

Movement:addToggle("Noclip", false, function(on)
	state.NoclipEnabled = on
	if on then startNoclip() else stopNoclip() end
end, true, Enum.KeyCode.N)

Movement:addSeparator()
Movement:addLabel("Mobility")

Movement:addToggle("Auto Reload", false, function(on)
	state.AutoReloadEnabled = on
	if on then startAutoReload() else stopAutoReload() end
end)

Movement:addToggle("Infinite Zoom", false, function(on)
	state.InfiniteZoomEnabled = on
	if on then applyInfiniteZoom() else stopInfiniteZoom() end
end, true, nil, true)

Movement:addToggle("No Jump Cooldown", false, function(on)
	state.NoJumpCooldownEnabled = on
	if on then startNoJumpCooldown() else stopNoJumpCooldown() end
end)

-- ============================================================
-- Strafe page
-- ============================================================

Strafe:addLabel("Strafe")

local strafeState = {
	Enabled = false,
	Active = false,
	Returning = false,
	AutoShoot = true,
	AutoEquip = false,
	CatalogOpen = false,
	SelectedGun = "LMG",
	CatalogButtons = {},
	CatalogHolder = nil,
	CatalogScroll = nil,
	CatalogToggleBtn = nil,
	Speed = 15,
	Radius = 12,
	Height = 5,
	TargetMode = "Nearest",
	ManualTargetName = "",
	LockedTarget = nil,
	StartCFrame = nil,
	Connection = nil,
	ShootConnection = nil,
	CamConnection = nil,
	DeathCheckConnection = nil,
	EquipCooldown = 0,
	Angle = 0,
	RadiusFactor = 1.0,
	LOSBlocked = false,
	JitterScale = 2.5,
	DirFlipChance = 0.02,
	SpeedVarChance = 0.05,
	RadiusVarChance = 0.05,
	CurrentAngularSpeed = 15,
	CurrentRadiusMul = 1.0,
	Direction = 1,
	DodgeEnabled = true,
	DodgeThreshold = 10,
	DodgeDistance = 60,
	DodgeCooldown = 0.8,
	LastDodge = 0,
	LastHealth = nil,
	VerticalBounceEnabled = true,
	VerticalBounceAmount = 3,
	VerticalBounceSpeed = 2,
	VerticalBouncePhase = 0,
	HitboxShrinkEnabled = false,
	HitboxShrinkScale = 0.5,
	OriginalSizes = {},
	JitterAmplifyEnabled = false,
	JitterAmplifyMultiplier = 2,
	PanicEscapeKey = Enum.KeyCode.G,
	PanicEscapeDistance = 150,
	PanicEscapeDuration = 2,
	ShotSnapshot = nil,
	ShotInterval = 0.12,
	LastShotAt = 0,
	ShotFreezeUntil = 0,
	ShotFreezeCFrame = nil,
}

local function isStrafeTargetAlive(player)
	if not player or not player.Character then return false end
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp or hum.Health <= 0 then return false end
	local be = player.Character:FindFirstChild("BodyEffects")
	if be then
		local ko = be:FindFirstChild("K.O") or be:FindFirstChild("KO")
		if ko and ko.Value == true then return false end
	end
	return true
end

local function findPlayerByQuery(query)
	if not query or query == "" then return nil end
	query = query:gsub("^%s+", ""):gsub("%s+$", "")
	if query == "" then return nil end
	local exact = Players:FindFirstChild(query)
	if exact and exact ~= localPlayer then return exact end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= localPlayer then
			if p.Name:lower():find(query:lower(), 1, true)
				or p.DisplayName:lower():find(query:lower(), 1, true) then
				return p
			end
		end
	end
	return nil
end

local function getNearestStrafePlayer()
	local myChar = localPlayer.Character
	local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
	if not myHrp then return nil end

	local best, bestDist = nil, math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= localPlayer and isStrafeTargetAlive(p) then
			local hrp = p.Character:FindFirstChild("HumanoidRootPart")
			local dist = (hrp.Position - myHrp.Position).Magnitude
			if dist < bestDist then bestDist = dist; best = p end
		end
	end
	return best
end

local function getPlayerNearestCursor()
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local mouse = UserInputService:GetMouseLocation()
	local best, bestDist = nil, math.huge

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= localPlayer and isStrafeTargetAlive(p) then
			local hrp = p.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local screenPos, onScreen = cam:WorldToViewportPoint(hrp.Position)
				if onScreen and screenPos.Z > 0 then
					local dist = (Vector2.new(screenPos.X, screenPos.Y) - mouse).Magnitude
					if dist < bestDist then
						bestDist = dist
						best = p
					end
				end
			end
		end
	end

	return best
end

local function getStrafeTarget()
	if strafeState.LockedTarget and isStrafeTargetAlive(strafeState.LockedTarget) then
		return strafeState.LockedTarget
	end
	if strafeState.TargetMode == "Manual" then
		local player = findPlayerByQuery(strafeState.ManualTargetName)
		if isStrafeTargetAlive(player) then return player end
		return nil
	end
	return getNearestStrafePlayer()
end

local function hasLineOfSight(targetChar)
	local myChar = localPlayer.Character
	local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local targetHrp = targetChar and (targetChar:FindFirstChild("Head") or targetChar:FindFirstChild("HumanoidRootPart"))
	if not myHrp or not targetHrp then return true end

	local origin = myHrp.Position
	local direction = targetHrp.Position - origin

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { myChar, targetChar }
	params.IgnoreWater = true

	local result = workspace:Raycast(origin, direction, params)
	return result == nil
end

local function isOnGround(hrp)
	if not hrp then return false end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { localPlayer.Character }
	params.IgnoreWater = true

	local result = workspace:Raycast(hrp.Position, Vector3.new(0, -6, 0), params)
	return result ~= nil
end

-- ============================================================
-- Gun Catalog + Equip
-- ============================================================

local GUN_CATALOG = {
	"LMG",
	"SilencerAR",
	"SilencedAR",
	"AR",
	"AUG",
	"AK47",
	"AK-47",
	"M4A1",
	"M16",
	"MP5",
	"Uzi",
	"P90",
	"Vector",
	"Scar",
	"SCAR-H",
	"Famas",
	"G36",
	"Tommy",
	"TommyGun",
	"Minigun",
}

local function toolMatchesName(tool, wanted)
	if not tool or not wanted then return false end
	local n = tool.Name:lower()
	local w = wanted:lower()
	if n == w then return true end
	if n:find(w, 1, true) then return true end
	local stripped = n:gsub("[%s%-_]", "")
	local wStripped = w:gsub("[%s%-_]", "")
	if stripped == wStripped or stripped:find(wStripped, 1, true) then return true end
	return false
end

local function findToolByName(wanted)
	local char = localPlayer.Character
	if not char then return nil end

	local equipped = char:FindFirstChildOfClass("Tool")
	if equipped and toolMatchesName(equipped, wanted) then
		return equipped
	end

	local backpack = localPlayer:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") and toolMatchesName(child, wanted) then
				return child
			end
		end
	end

	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Tool") and toolMatchesName(child, wanted) then
			return child
		end
	end

	return nil
end

local function equipSelectedGun()
	local char = localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return false end

	local wanted = strafeState.SelectedGun
	if not wanted or wanted == "" then return false end

	local equipped = char:FindFirstChildOfClass("Tool")
	if equipped and toolMatchesName(equipped, wanted) then
		return true
	end

	local tool = findToolByName(wanted)
	if not tool then return false end

	pcall(function() hum:EquipTool(tool) end)
	return true
end

local function getEquippedTool()
	local char = localPlayer.Character
	if not char then return nil end
	return char:FindFirstChildOfClass("Tool")
end

local function unequipTool()
	local char = localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return false end
	local equipped = getEquippedTool()
	if not equipped then return true end
	pcall(function() hum:UnequipTools() end)
	return true
end

local shootRemote = nil
local function findShootRemote()
	if shootRemote and shootRemote.Parent then return shootRemote end
	local rs = game:GetService("ReplicatedStorage")
	for _, name in ipairs({ "MainEvent", "GunGiverCMDS", "GunCommand", "ShootGun", "GunRemote" }) do
		local found = rs:FindFirstChild(name, true)
		if found and found:IsA("RemoteEvent") then
			shootRemote = found
			return found
		end
	end
	return nil
end

local function autoShootTarget(target)
	if not target or not target.Character then return end
	local targetHrp = target.Character:FindFirstChild("HumanoidRootPart")
	if not targetHrp then return end

	local myChar = localPlayer.Character
	local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
	if not myHum or myHum.Health <= 0 then return end

	local tool = myChar:FindFirstChildOfClass("Tool")
	if not tool or not tool:FindFirstChild("Handle") then return end

	local remote = findShootRemote()
	if not remote then return end

	local snap = strafeState.ShotSnapshot
	local now = tick()

	if not snap or now >= snap.expire then
		snap = {
			origin = tool.Handle.CFrame.Position,
			target = targetHrp.Position,
			expire = now + 0.15,
		}
		strafeState.ShotSnapshot = snap
	end

	pcall(function()
		remote:FireServer(
			"ShootGun",
			tool.Handle,
			snap.origin,
			snap.target,
			targetHrp,
			Vector3.zero
		)
	end)

	pcall(function() tool:Activate() end)
end

local stopStrafe

local function disableStrafeToggle()
	local ctrl = getgenv().BOBBY_ConfigControls["toggle:Strafe"]
	if ctrl and type(ctrl.set) == "function" then
		pcall(ctrl.set, false)
	end
end

stopStrafe = function(returnHome)
	if strafeState.Returning then return end
	strafeState.Returning = true

	if strafeState.Connection then strafeState.Connection:Disconnect(); strafeState.Connection = nil end
	if strafeState.ShootConnection then strafeState.ShootConnection:Disconnect(); strafeState.ShootConnection = nil end
	if strafeState.CamConnection then strafeState.CamConnection:Disconnect(); strafeState.CamConnection = nil end
	if strafeState.DeathCheckConnection then strafeState.DeathCheckConnection:Disconnect(); strafeState.DeathCheckConnection = nil end

	strafeState.Active = false
	strafeState.Angle = 0
	strafeState.RadiusFactor = 1.0
	strafeState.LOSBlocked = false
	strafeState.LastHealth = nil
	strafeState.VerticalBouncePhase = 0
	strafeState.ShotSnapshot = nil
	strafeState.LastShotAt = 0
	strafeState.ShotFreezeUntil = 0

	local char = localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then pcall(function() hum.PlatformStand = false end) end

	pcall(unequipTool)
	pcall(stopHitboxShrink)

	strafeState.LastDodge = 0

	local noclipWasOn = state.NoclipEnabled

	local myHrp = char and char:FindFirstChild("HumanoidRootPart")
	if myHrp then
		pcall(function()
			myHrp.AssemblyLinearVelocity = Vector3.zero
			myHrp.AssemblyAngularVelocity = Vector3.zero
		end)
	end

	if noclipWasOn and char then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				pcall(function() part.CanCollide = true end)
			end
		end
	end

	if returnHome and strafeState.StartCFrame and myHrp then
		local targetCF = strafeState.StartCFrame

		pcall(function()
			myHrp.CFrame = targetCF + Vector3.new(0, 5, 0)
			myHrp.AssemblyLinearVelocity = Vector3.zero
			myHrp.AssemblyAngularVelocity = Vector3.zero
		end)

		task.spawn(function()
			local startTick = tick()
			local settled = false
			while tick() - startTick < 1.2 do
				if isOnGround(myHrp) then
					settled = true
					break
				end
				task.wait(0.05)
			end

			if not settled then
				pcall(function()
					myHrp.CFrame = CFrame.new(targetCF.Position + Vector3.new(0, 15, 0))
					myHrp.AssemblyLinearVelocity = Vector3.zero
					myHrp.AssemblyAngularVelocity = Vector3.zero
				end)
				task.wait(0.3)
			end

			if noclipWasOn and state.NoclipEnabled then
				local char2 = localPlayer.Character
				if char2 then
					local h2 = char2:FindFirstChild("HumanoidRootPart")
					if h2 and isOnGround(h2) then
						for _, part in ipairs(char2:GetDescendants()) do
							if part:IsA("BasePart") then
								pcall(function() part.CanCollide = false end)
							end
						end
					else
						task.wait(0.3)
						local h3 = char2:FindFirstChild("HumanoidRootPart")
						if h3 and isOnGround(h3) then
							for _, part in ipairs(char2:GetDescendants()) do
								if part:IsA("BasePart") then
									pcall(function() part.CanCollide = false end)
								end
							end
						end
					end
				end
			end
		end)
	end

	strafeState.StartCFrame = nil
	strafeState.LockedTarget = nil

	task.delay(1.5, function()
		strafeState.Returning = false
	end)
end

local function resetStrafeFromDeath()
    if not strafeState.Active then return end

    local returnCF = strafeState.StartCFrame

    stopStrafe(false)

    local ctrl = getgenv().BOBBY_ConfigControls["toggle:Strafe"]
    if ctrl and type(ctrl.set) == "function" then
        pcall(ctrl.set, false)
    end

    strafeState.Enabled = false

    task.spawn(function()
        local newChar = localPlayer.CharacterAdded:Wait()
        local newHrp = newChar:WaitForChild("HumanoidRootPart", 5)
        if newHrp and returnCF then
            task.wait(0.35)
            pcall(function()
                newHrp.CFrame = returnCF
                newHrp.AssemblyLinearVelocity = Vector3.zero
                newHrp.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end)
end

localPlayer.CharacterAdded:Connect(function(character)
    local hum = character:WaitForChild("Humanoid", 5)
    if not hum then return end
    hum.Died:Connect(function()
        resetStrafeFromDeath()
    end)
end)

if localPlayer.Character then
    local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Died:Connect(function()
            resetStrafeFromDeath()
        end)
    end
end

local function attachTargetDeathWatch(target)
	if strafeState.DeathCheckConnection then
		strafeState.DeathCheckConnection:Disconnect()
		strafeState.DeathCheckConnection = nil
	end
	if not target then return end

	local function bind(char)
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		strafeState.DeathCheckConnection = hum.Died:Connect(function()
			task.defer(function()
				local ctrl = getgenv().BOBBY_ConfigControls["toggle:Strafe"]
				if ctrl and type(ctrl.set) == "function" then
					pcall(function() ctrl.set(false) end)
				end
				if strafeState.Active then
					stopStrafe(true)
				end
			end)
		end)
	end

	if target.Character then bind(target.Character) end
	target.CharacterAdded:Once(function(char)
		if strafeState.Active then bind(char) end
	end)
end

local function randomRange(a, b)
	return a + math.random() * (b - a)
end

-- ============================================================
-- Anti-Hit systems
-- ============================================================

local function applyHitboxShrink()
	local char = localPlayer.Character
	if not char then return end
	local scale = strafeState.HitboxShrinkScale
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			if not strafeState.OriginalSizes[part] then
				strafeState.OriginalSizes[part] = part.Size
			end
			local orig = strafeState.OriginalSizes[part]
			part.Size = Vector3.new(
				math.max(orig.X * scale, 0.05),
				math.max(orig.Y * scale, 0.05),
				math.max(orig.Z * scale, 0.05)
			)
		end
	end
end

local function restoreHitbox()
	local char = localPlayer.Character
	if not char then return end
	for part, orig in pairs(strafeState.OriginalSizes) do
		if part and part.Parent then
			pcall(function() part.Size = orig end)
		end
	end
	table.clear(strafeState.OriginalSizes)
end

local hitboxCharConn
local function startHitboxShrink()
	if hitboxCharConn then hitboxCharConn:Disconnect() end
	applyHitboxShrink()
	hitboxCharConn = localPlayer.CharacterAdded:Connect(function()
		task.wait(0.3)
		if strafeState.HitboxShrinkEnabled then
			applyHitboxShrink()
		end
	end)
end

local function stopHitboxShrink()
	if hitboxCharConn then
		hitboxCharConn:Disconnect()
		hitboxCharConn = nil
	end
	restoreHitbox()
end

task.spawn(function()
	while true do
		task.wait(0.1)

		if not strafeState.DodgeEnabled then
			strafeState.LastHealth = nil
			continue
		end
		if not strafeState.Enabled or not strafeState.Active then
			strafeState.LastHealth = nil
			continue
		end

		local char = localPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then
			strafeState.LastHealth = nil
			continue
		end

		if strafeState.LastHealth == nil then
			strafeState.LastHealth = hum.Health
			continue
		end

		local delta = strafeState.LastHealth - hum.Health
		strafeState.LastHealth = hum.Health

		if delta >= strafeState.DodgeThreshold and tick() - strafeState.LastDodge >= strafeState.DodgeCooldown then
			strafeState.LastDodge = tick()

			local hrp = char:FindFirstChild("HumanoidRootPart")
			local target = getStrafeTarget()

			if hrp then
				local escapeDir
				if target and target.Character then
					local tHrp = target.Character:FindFirstChild("HumanoidRootPart")
					if tHrp then
						escapeDir = hrp.Position - tHrp.Position
						if escapeDir.Magnitude > 0.01 then
							escapeDir = escapeDir.Unit
						else
							escapeDir = nil
						end
					end
				end
				if not escapeDir then
					escapeDir = Vector3.new(math.random() - 0.5, 0.5, math.random() - 0.5).Unit
				end

				pcall(function()
					hrp.CFrame = CFrame.new(hrp.Position + escapeDir * strafeState.DodgeDistance)
					hrp.AssemblyLinearVelocity = Vector3.zero
					hrp.AssemblyAngularVelocity = Vector3.zero
				end)
			end
		end
	end
end)

-- ============================================================
-- Panic Escape keybind
-- ============================================================

local panicCooldown = 0
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode ~= strafeState.PanicEscapeKey then return end
	if not strafeState.Enabled or not strafeState.Active then return end
	if tick() - panicCooldown < 1.5 then return end
	panicCooldown = tick()

	local char = localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then return end

	local target = getStrafeTarget()
	local escapeDir
	if target and target.Character then
		local tHrp = target.Character:FindFirstChild("HumanoidRootPart")
		if tHrp then
			escapeDir = hrp.Position - tHrp.Position
			if escapeDir.Magnitude > 0.01 then
				escapeDir = escapeDir.Unit
			else
				escapeDir = nil
			end
		end
	end
	if not escapeDir then
		escapeDir = Vector3.new(0, 1, 0)
	end

	pcall(function()
		hrp.CFrame = CFrame.new(hrp.Position + escapeDir * strafeState.PanicEscapeDistance + Vector3.new(0, 30, 0))
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end)
end)

-- ============================================================
-- startStrafe
-- ============================================================

local function startStrafe()
	stopStrafe(false)

	local myChar = localPlayer.Character
	local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
	if myHrp then
		strafeState.StartCFrame = myHrp.CFrame
	end

	strafeState.Active = true
	strafeState.Direction = math.random() < 0.5 and 1 or -1
	strafeState.CurrentAngularSpeed = strafeState.Speed * randomRange(0.7, 1.3)
	strafeState.CurrentRadiusMul = randomRange(0.85, 1.15)
	strafeState.VerticalBouncePhase = 0

	strafeState.Connection = state.value2.Heartbeat:Connect(function(dt)
		if not strafeState.Enabled or not strafeState.Active then return end
		local now = tick()

		if strafeState.ShotFreezeUntil > 0 and now < strafeState.ShotFreezeUntil then
			return
		end

		local target = getStrafeTarget()
		if not target then return end

		local myChar2 = localPlayer.Character
		local myHrp2 = myChar2 and myChar2:FindFirstChild("HumanoidRootPart")
		if not myHrp2 then return end
		local targetChar = target.Character
		local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
		if not targetHrp then return end

		local clearLOS = hasLineOfSight(targetChar)
		strafeState.LOSBlocked = not clearLOS

		local goal = clearLOS and 1.0 or 0.3
		strafeState.RadiusFactor = strafeState.RadiusFactor
			+ (goal - strafeState.RadiusFactor) * math.clamp(dt * 4, 0, 1)

		if math.random() < strafeState.DirFlipChance then
			strafeState.Direction = -strafeState.Direction
		end
		if math.random() < strafeState.SpeedVarChance then
			strafeState.CurrentAngularSpeed = strafeState.Speed * randomRange(0.6, 1.4)
		end
		if math.random() < strafeState.RadiusVarChance then
			strafeState.CurrentRadiusMul = randomRange(0.8, 1.2)
		end

		local effectiveRadius = math.max(
			3,
			strafeState.Radius * strafeState.RadiusFactor * strafeState.CurrentRadiusMul
		)

		strafeState.Angle = strafeState.Angle
			+ (strafeState.CurrentAngularSpeed * strafeState.Direction * dt)

		local verticalOffset = 0
		if strafeState.VerticalBounceEnabled then
			strafeState.VerticalBouncePhase = strafeState.VerticalBouncePhase + dt * strafeState.VerticalBounceSpeed
			verticalOffset = math.sin(strafeState.VerticalBouncePhase) * strafeState.VerticalBounceAmount
		end

		local center = targetHrp.Position + Vector3.new(0, strafeState.Height + verticalOffset, 0)
		local offset = Vector3.new(
			math.cos(strafeState.Angle) * effectiveRadius,
			0,
			math.sin(strafeState.Angle) * effectiveRadius
		)

		local jitterScale = strafeState.JitterScale
		if strafeState.JitterAmplifyEnabled then
			jitterScale = jitterScale * strafeState.JitterAmplifyMultiplier
		end

		local jitter = Vector3.new(
			randomRange(-jitterScale, jitterScale),
			randomRange(-jitterScale * 0.4, jitterScale * 0.4),
			randomRange(-jitterScale, jitterScale)
		)

		local newPos = center + offset + jitter
		local lookAt = CFrame.lookAt(newPos, targetHrp.Position)

		pcall(function()
			myHrp2.CFrame = lookAt
			myHrp2.AssemblyLinearVelocity = Vector3.zero
			myHrp2.AssemblyAngularVelocity = Vector3.zero
		end)
	end)

	strafeState.CamConnection = state.value2.RenderStepped:Connect(function()
		if not strafeState.Enabled or not strafeState.Active then return end
		local target = getStrafeTarget()
		if not target or not target.Character then return end
		local head = target.Character:FindFirstChild("Head") or target.Character:FindFirstChild("HumanoidRootPart")
		if not head then return end
		local cam = workspace.CurrentCamera
		if cam then
			cam.CameraType = Enum.CameraType.Custom
			cam.CFrame = CFrame.lookAt(cam.CFrame.Position, head.Position)
		end
	end)

	strafeState.ShootConnection = state.value2.Heartbeat:Connect(function()
		if not strafeState.Enabled or not strafeState.Active then return end
		if not strafeState.AutoShoot then return end

		local now = tick()
		if now - strafeState.LastShotAt < strafeState.ShotInterval then return end

		local char = localPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then return end

		if strafeState.AutoEquip then
			local wanted = strafeState.SelectedGun
			local equipped = char:FindFirstChildOfClass("Tool")
			local hasCorrect = equipped and toolMatchesName(equipped, wanted)
			if not hasCorrect then
				if now >= strafeState.EquipCooldown then
					strafeState.EquipCooldown = now + 0.35
					pcall(equipSelectedGun)
				end
				return
			end
		end

		if strafeState.LOSBlocked then return end

		local target = getStrafeTarget()
		if not target then return end

		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		strafeState.ShotFreezeUntil = now + 0.1
		strafeState.ShotFreezeCFrame = hrp.CFrame

		strafeState.LastShotAt = now
		pcall(autoShootTarget, target)
	end)

	local current = getStrafeTarget()
	if current then attachTargetDeathWatch(current) end

	if strafeState.AutoEquip then
		pcall(equipSelectedGun)
	end
end

-- ============================================================
-- Strafe page controls
-- ============================================================

Strafe:addToggle("Strafe", false, function(on)
	strafeState.Enabled = on
	if on then startStrafe() else stopStrafe(true) end
end)

Strafe:addKeybind("Strafe Key (nearest to cursor)", Enum.KeyCode.X, function()
	local picked = getPlayerNearestCursor()
	if picked then
		strafeState.LockedTarget = picked
		strafeState.ManualTargetName = picked.Name
		strafeState.TargetMode = "Manual"
	end
	if not strafeState.Enabled then
		strafeState.Enabled = true
	end
	if strafeState.Active then
		stopStrafe(true)
		disableStrafeToggle()
	else
		startStrafe()
		if strafeState.LockedTarget then
			attachTargetDeathWatch(strafeState.LockedTarget)
		end
	end
end)

Strafe:addToggle("Auto Shoot", true, function(on)
	strafeState.AutoShoot = on
end)

Strafe:addToggle("Auto-Equip Gun", false, function(on)
	strafeState.AutoEquip = on
	if on then
		pcall(equipSelectedGun)
	end
end)

local catalogToggleBtn = Strafe:addButton("Gun Catalog: " .. strafeState.SelectedGun, function()
	strafeState.CatalogOpen = not strafeState.CatalogOpen

	local holder = strafeState.CatalogHolder
	if not holder then return end
	holder.Visible = strafeState.CatalogOpen
	holder:TweenSize(
		UDim2.new(1, 0, 0, strafeState.CatalogOpen and 180 or 0),
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Quad,
		0.18,
		true
	)
end)

do
	local parentFrame = catalogToggleBtn.Parent
	if parentFrame then
		local holder = create("Frame", {
			Name = "GunCatalogHolder",
			Parent = parentFrame,
			BackgroundColor3 = Color3.fromRGB(18, 20, 28),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 0),
			ClipsDescendants = true,
			Visible = false,
		})
		create("UICorner", { Parent = holder, CornerRadius = UDim.new(0, 6) })

		local scroll = create("ScrollingFrame", {
			Name = "CatalogScroll",
			Parent = holder,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			CanvasSize = UDim2.new(0, 0, 0, 0),
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = Color3.fromRGB(60, 130, 246),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		})
		create("UIListLayout", {
			Parent = scroll,
			Padding = UDim.new(0, 3),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})

		strafeState.CatalogHolder = holder
		strafeState.CatalogScroll = scroll
		strafeState.CatalogToggleBtn = catalogToggleBtn

		local function refreshCatalogHighlight()
			for name, btn in pairs(strafeState.CatalogButtons) do
				if btn and btn.Parent then
					if name == strafeState.SelectedGun then
						btn.BackgroundColor3 = Color3.fromRGB(30, 46, 78)
						btn.TextColor3 = Color3.fromRGB(120, 190, 255)
					else
						btn.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
						btn.TextColor3 = Color3.fromRGB(200, 205, 220)
					end
				end
			end
			if catalogToggleBtn and catalogToggleBtn.Parent then
				catalogToggleBtn.Text = "Gun Catalog: " .. strafeState.SelectedGun
			end
		end

		local function isGunOwned(gunName)
			local char = localPlayer.Character
			if char then
				local tool = char:FindFirstChildOfClass("Tool")
				if tool and toolMatchesName(tool, gunName) then return true end
			end
			local bp = localPlayer:FindFirstChildOfClass("Backpack")
			if bp then
				for _, c in ipairs(bp:GetChildren()) do
					if c:IsA("Tool") and toolMatchesName(c, gunName) then return true end
				end
			end
			return false
		end

		for i, gunName in ipairs(GUN_CATALOG) do
			local hasGun = isGunOwned(gunName)
			local btn = create("TextButton", {
				Name = "Gun_" .. gunName,
				Parent = scroll,
				BackgroundColor3 = Color3.fromRGB(28, 32, 44),
				BorderSizePixel = 0,
				Size = UDim2.new(1, -8, 0, 26),
				Position = UDim2.new(0, 4, 0, 0),
				Font = Enum.Font.Gotham,
				Text = (hasGun and "  ✓ " or "  ○ ") .. gunName,
				TextColor3 = Color3.fromRGB(200, 205, 220),
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
				LayoutOrder = i,
			})
			create("UICorner", { Parent = btn, CornerRadius = UDim.new(0, 4) })

			btn.MouseButton1Click:Connect(function()
				strafeState.SelectedGun = gunName
				refreshCatalogHighlight()
				if strafeState.AutoEquip then
					pcall(equipSelectedGun)
				end
			end)

			strafeState.CatalogButtons[gunName] = btn
		end

		task.spawn(function()
			while catalogToggleBtn and catalogToggleBtn.Parent do
				for name, btn in pairs(strafeState.CatalogButtons) do
					if btn and btn.Parent then
						local has = isGunOwned(name)
						local prefix = has and "  ✓ " or "  ○ "
						local newText = prefix .. name
						if btn.Text ~= newText then
							btn.Text = newText
						end
					end
				end
				task.wait(2)
			end
		end)

		refreshCatalogHighlight()
	end
end

Strafe:addSeparator()

Strafe:addTextBox("Target Username", "type username...", function(text)
	strafeState.ManualTargetName = tostring(text or "")
end)

Strafe:addButton("Strafe Target", function()
	local player = findPlayerByQuery(strafeState.ManualTargetName)
	if not player then
		notify("Player not found: " .. tostring(strafeState.ManualTargetName), false)
		return
	end

	strafeState.TargetMode = "Manual"
	strafeState.ManualTargetName = player.Name
	strafeState.LockedTarget = player
	strafeState.Enabled = true
	if not strafeState.Active then startStrafe() end
	attachTargetDeathWatch(player)
end)

Strafe:addButton("Bring", function()
	local player = findPlayerByQuery(strafeState.ManualTargetName)
	if not player or not player.Character then
		notify("Bring failed: player not found", false)
		return
	end

	task.spawn(function()
		local myChar = localPlayer.Character
		local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
		if not myHrp then return end

		local originalCFrame = myHrp.CFrame
		local followUntil = tick() + 1.5

		while tick() < followUntil do
			local targetChar = player.Character
			local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")

			if targetHrp and targetHrp.Parent then
				pcall(function()
					myHrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, 3)
					myHrp.AssemblyLinearVelocity = Vector3.zero
					myHrp.AssemblyAngularVelocity = Vector3.zero
				end)
			else
				break
			end

			task.wait(0.05)
		end

		task.wait(0.2)
		pcall(function()
			myHrp.CFrame = originalCFrame
			myHrp.AssemblyLinearVelocity = Vector3.zero
			myHrp.AssemblyAngularVelocity = Vector3.zero
		end)
	end)
end)

Strafe:addButton("Clear Target", function()
	strafeState.ManualTargetName = ""
	strafeState.LockedTarget = nil
	strafeState.TargetMode = "Nearest"
	strafeState.Enabled = false
	stopStrafe(true)
	local box = Strafe.Container:FindFirstChild("TextBox_Target Username", true)
	if box then
		local input = box:FindFirstChildWhichIsA("TextBox", true)
		if input then input.Text = "" end
	end
end)

Strafe:addSeparator()
Strafe:addLabel("Tuning")

Strafe:addSlider("Strafe Speed", 1, 60, function(v)
	strafeState.Speed = math.clamp(tonumber(v) or 15, 1, 60)
end, 15)

Strafe:addSlider("Strafe Radius", 2, 30, function(v)
	strafeState.Radius = math.clamp(tonumber(v) or 12, 2, 30)
end, 12)

Strafe:addSlider("Strafe Height", -3, 10, function(v)
	strafeState.Height = math.clamp(tonumber(v) or 5, -3, 10)
end, 5)

Strafe:addSeparator()
Strafe:addLabel("Anti-Aim")

Strafe:addSlider("Jitter", 0, 10, function(v)
	strafeState.JitterScale = math.clamp(tonumber(v) or 2.5, 0, 10)
end, 2.5)

Strafe:addSlider("Direction Flip %", 0, 20, function(v)
	strafeState.DirFlipChance = math.clamp(tonumber(v) or 2, 0, 20) / 100
end, 2)

Strafe:addSlider("Speed Variance %", 0, 30, function(v)
	strafeState.SpeedVarChance = math.clamp(tonumber(v) or 5, 0, 30) / 100
end, 5)

Strafe:addSeparator()
Strafe:addLabel("Anti-Hit")

Strafe:addToggle("Dodge on Damage", true, function(on)
	strafeState.DodgeEnabled = on
	if not on then strafeState.LastHealth = nil end
end)

Strafe:addSlider("Dodge Threshold (HP)", 1, 50, function(v)
	strafeState.DodgeThreshold = math.clamp(tonumber(v) or 10, 1, 50)
end, 10)

Strafe:addSlider("Dodge Distance", 10, 200, function(v)
	strafeState.DodgeDistance = math.clamp(tonumber(v) or 60, 10, 200)
end, 60)

Strafe:addSlider("Dodge Cooldown (x100ms)", 2, 50, function(v)
	strafeState.DodgeCooldown = math.clamp(tonumber(v) or 8, 2, 50) / 10
end, 8)

Strafe:addSeparator()

Strafe:addToggle("Vertical Bounce", true, function(on)
	strafeState.VerticalBounceEnabled = on
	if not on then strafeState.VerticalBouncePhase = 0 end
end)

Strafe:addSlider("Bounce Amount", 0, 10, function(v)
	strafeState.VerticalBounceAmount = math.clamp(tonumber(v) or 3, 0, 10)
end, 3)

Strafe:addSlider("Bounce Speed", 0, 10, function(v)
	strafeState.VerticalBounceSpeed = math.clamp(tonumber(v) or 2, 0, 10)
end, 2)

Strafe:addSeparator()

Strafe:addToggle("Jitter Amplify", false, function(on)
	strafeState.JitterAmplifyEnabled = on
end)

Strafe:addSlider("Jitter Multiplier", 1, 5, function(v)
	strafeState.JitterAmplifyMultiplier = math.clamp(tonumber(v) or 2, 1, 5)
end, 2)

Strafe:addSeparator()

Strafe:addToggle("Hitbox Shrink", false, function(on)
	strafeState.HitboxShrinkEnabled = on
	if on then
		startHitboxShrink()
	else
		stopHitboxShrink()
	end
end)

Strafe:addSlider("Hitbox Scale %", 20, 100, function(v)
	strafeState.HitboxShrinkScale = math.clamp(tonumber(v) or 50, 20, 100) / 100
	if strafeState.HitboxShrinkEnabled then
		restoreHitbox()
		applyHitboxShrink()
	end
end, 50)

Strafe:addSeparator()
Strafe:addLabel("Shot Stability")

Strafe:addSlider("Shot Interval (x10ms)", 5, 30, function(v)
	strafeState.ShotInterval = math.clamp(tonumber(v) or 12, 5, 30) / 100
end, 12)

Strafe:addSeparator()
Strafe:addLabel("Panic")
Strafe:addLabel("Press G to escape", "150 studs away + 30 up")

-- ============================================================
-- Visuals page
-- ============================================================

local espSettings = {
	Enabled = false,
	Box = true,
	Name = false,
	Distance = false,
	HealthBar = false,
	Outline = false,
	BoxColor = Color3.fromRGB(60, 130, 246),
	NameColor = Color3.fromRGB(255, 255, 255),
	DistanceColor = Color3.fromRGB(180, 200, 230),
	HealthColor = Color3.fromRGB(60, 220, 120),
}

local espStore = {}

local function destroyESP(player)
	local data = espStore[player]
	if not data then return end
	for _, drawing in pairs(data) do
		pcall(function() drawing.Visible = false end)
		pcall(function() drawing:Remove() end)
	end
	espStore[player] = nil
end

local function createESP(player)
	destroyESP(player)
	if not player or player == localPlayer then return end
	if typeof(Drawing) ~= "table" then return end

	if not pcall(function()
		local box = Drawing.new("Square")
		box.Thickness = 1
		box.Filled = false
		box.Color = espSettings.BoxColor
		box.Visible = false

		local outline = Drawing.new("Square")
		outline.Thickness = 3
		outline.Filled = false
		outline.Color = Color3.new(0, 0, 0)
		outline.Visible = false

		local name = Drawing.new("Text")
		name.Size = 14
		name.Center = true
		name.Color = espSettings.NameColor
		name.Visible = false
		name.Font = 0
		name.Outline = false
		name.OutlineColor = Color3.new(0, 0, 0)

		local dist = Drawing.new("Text")
		dist.Size = 13
		dist.Center = true
		dist.Color = espSettings.DistanceColor
		dist.Visible = false
		dist.Font = 0
		dist.Outline = false
		dist.OutlineColor = Color3.new(0, 0, 0)

		local hp = Drawing.new("Square")
		hp.Thickness = 1
		hp.Filled = true
		hp.Color = espSettings.HealthColor
		hp.Visible = false

		local hpOutline = Drawing.new("Square")
		hpOutline.Thickness = 3
		hpOutline.Filled = false
		hpOutline.Color = Color3.new(0, 0, 0)
		hpOutline.Visible = false

		espStore[player] = {
			Box = box,
			Outline = outline,
			Name = name,
			Distance = dist,
			Health = hp,
			HealthOutline = hpOutline,
		}
	end) then
		destroyESP(player)
	end
end

local function hideESP(data)
	for _, drawing in pairs(data) do
		if drawing then pcall(function() drawing.Visible = false end) end
	end
end

local function updateESP(player, data)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not hrp or not humanoid or humanoid.Health <= 0 then
		hideESP(data)
		return
	end

	local cam = workspace.CurrentCamera
	local myHrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not cam or not myHrp then hideESP(data); return end

	pcall(function()
		local pos, onScreen = cam:WorldToViewportPoint(hrp.Position)
		local topPos = cam:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
		local botPos = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))

		if not onScreen or pos.Z <= 0 then hideESP(data); return end

		local height = math.abs(topPos.Y - botPos.Y)
		local width = height / 2
		if height <= 1 or width <= 1 then hideESP(data); return end

		data.Box.Position = Vector2.new(pos.X - width / 2, topPos.Y)
		data.Box.Size = Vector2.new(width, height)
		data.Box.Color = espSettings.BoxColor
		data.Box.Visible = espSettings.Enabled and espSettings.Box

		data.Outline.Position = data.Box.Position
		data.Outline.Size = data.Box.Size
		data.Outline.Visible = espSettings.Enabled and espSettings.Box and espSettings.Outline

		if espSettings.Name then
			data.Name.Position = Vector2.new(pos.X, topPos.Y - 16)
			data.Name.Text = player.Name
			data.Name.Color = espSettings.NameColor
			data.Name.Outline = espSettings.Outline
			data.Name.Visible = espSettings.Enabled
		else
			data.Name.Visible = false
		end

		if espSettings.Distance then
			data.Distance.Position = Vector2.new(pos.X, botPos.Y + 4)
			data.Distance.Text = tostring(math.floor((myHrp.Position - hrp.Position).Magnitude)) .. " studs"
			data.Distance.Color = espSettings.DistanceColor
			data.Distance.Outline = espSettings.Outline
			data.Distance.Visible = espSettings.Enabled
		else
			data.Distance.Visible = false
		end

		if espSettings.HealthBar then
			local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
			local barH = height * ratio
			data.Health.Position = Vector2.new(pos.X - width / 2 - 6, topPos.Y + height - barH)
			data.Health.Size = Vector2.new(3, barH)
			data.Health.Color = espSettings.HealthColor
			data.Health.Visible = espSettings.Enabled
			data.HealthOutline.Position = data.Health.Position
			data.HealthOutline.Size = data.Health.Size
			data.HealthOutline.Visible = espSettings.Enabled and espSettings.Outline
		else
			data.Health.Visible = false
			data.HealthOutline.Visible = false
		end
	end)
end

local espAccumulator = 0
state.value2.RenderStepped:Connect(function(dt)
	if not espSettings.Enabled then
		for _, data in pairs(espStore) do hideESP(data) end
		return
	end
	espAccumulator = espAccumulator + dt
	if espAccumulator < 1 / 120 then return end
	espAccumulator = 0

	for player, data in pairs(espStore) do
		if player.Parent ~= Players then
			destroyESP(player)
		elseif not (data.Box and data.Outline and data.Name and data.Distance and data.Health and data.HealthOutline) then
			destroyESP(player)
			if player ~= localPlayer then createESP(player) end
		else
			pcall(updateESP, player, data)
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= localPlayer and not espStore[player] then
			pcall(createESP, player)
		end
	end
end)

Visuals:addLabel("ESP")

Visuals:addToggle("Enable ESP", false, function(on)
	espSettings.Enabled = on
	if not on then
		for _, data in pairs(espStore) do hideESP(data) end
	end
end, false, nil, true)

Visuals:addToggle("Box", true, function(on) espSettings.Box = on end, false, nil, true)
Visuals:addToggle("Name", false, function(on) espSettings.Name = on end, false, nil, true)
Visuals:addToggle("Distance", false, function(on) espSettings.Distance = on end, false, nil, true)
Visuals:addToggle("Health Bar", false, function(on) espSettings.HealthBar = on end, false, nil, true)
Visuals:addToggle("Text Outline", false, function(on) espSettings.Outline = on end, false, nil, true)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.15)
		if espSettings.Enabled and player ~= localPlayer then
			pcall(createESP, player)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	pcall(destroyESP, player)
end)

-- ============================================================
-- Spy Chat
-- ============================================================

local spyChatState = {
	Enabled = false,
	Log = {},
	MaxLines = 200,
	Frame = nil,
	Label = nil,
	Scrolling = nil,
	Connections = {},
}

local function spyChatAddLine(text, color)
	if not spyChatState.Enabled then return end

	table.insert(spyChatState.Log, { text = text, color = color or Color3.fromRGB(220, 226, 238), time = os.time() })
	while #spyChatState.Log > spyChatState.MaxLines do
		table.remove(spyChatState.Log, 1)
	end

	if spyChatState.Label then
		local joined = {}
		for _, entry in ipairs(spyChatState.Log) do
			table.insert(joined, entry.text)
		end
		spyChatState.Label.Text = table.concat(joined, "\n")

		task.defer(function()
			if spyChatState.Scrolling then
				spyChatState.Scrolling.CanvasSize = UDim2.new(0, 0, 0, spyChatState.Label.TextBounds.Y + 20)
				spyChatState.Scrolling.CanvasPosition = Vector2.new(0, math.max(0, spyChatState.Label.TextBounds.Y))
			end
		end)
	end
end

local function spyChatBuildUI()
	if spyChatState.Frame and spyChatState.Frame.Parent then return end

	local gui = game:GetService("CoreGui")
	local existing = gui:FindFirstChild("BobbyNoob_SpyChat")
	if existing then existing:Destroy() end

	local screen = create("ScreenGui", {
		Name = "BobbyNoob_SpyChat",
		Parent = gui,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
	})

	local frame = create("Frame", {
		Name = "ChatFrame",
		Parent = screen,
		BackgroundColor3 = Color3.fromRGB(12, 13, 18),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 20, 0.5, -150),
		Size = UDim2.new(0, 420, 0, 300),
		Active = true,
		Draggable = true,
	})
	create("UICorner", { Parent = frame, CornerRadius = UDim.new(0, 8) })
	create("UIStroke", { Parent = frame, Color = Color3.fromRGB(60, 130, 246), Thickness = 1 })

	local title = create("TextLabel", {
		Name = "Title",
		Parent = frame,
		BackgroundColor3 = Color3.fromRGB(22, 24, 32),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 24),
		Font = Enum.Font.GothamBold,
		Text = "  spy chat",
		TextColor3 = Color3.fromRGB(120, 190, 255),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	create("UICorner", { Parent = title, CornerRadius = UDim.new(0, 8) })

	local closeBtn = create("TextButton", {
		Parent = title,
		BackgroundColor3 = Color3.fromRGB(200, 55, 70),
		BorderSizePixel = 0,
		Position = UDim2.new(1, -22, 0, 4),
		Size = UDim2.new(0, 16, 0, 16),
		Font = Enum.Font.GothamBold,
		Text = "X",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 10,
	})
	create("UICorner", { Parent = closeBtn, CornerRadius = UDim.new(1, 0) })
	closeBtn.MouseButton1Click:Connect(function()
		local ctrl = getgenv().BOBBY_ConfigControls["toggle:Spy Chat"]
		if ctrl and type(ctrl.set) == "function" then
			pcall(ctrl.set, false)
		end
	end)

	local scroll = create("ScrollingFrame", {
		Name = "Scroll",
		Parent = frame,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 6, 0, 28),
		Size = UDim2.new(1, -12, 1, -34),
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Color3.fromRGB(60, 130, 246),
		CanvasSize = UDim2.new(0, 0, 0, 0),
	})

	local label = create("TextLabel", {
		Name = "Content",
		Parent = scroll,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 4, 0, 4),
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Code,
		Text = "",
		TextColor3 = Color3.fromRGB(220, 226, 238),
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		RichText = true,
	})

	spyChatState.Frame = frame
	spyChatState.Scrolling = scroll
	spyChatState.Label = label
end

local function spyChatDestroyUI()
	if spyChatState.Frame and spyChatState.Frame.Parent then
		spyChatState.Frame.Parent:Destroy()
	end
	spyChatState.Frame = nil
	spyChatState.Scrolling = nil
	spyChatState.Label = nil
end

local function spyChatDisconnect()
	for _, conn in ipairs(spyChatState.Connections) do
		pcall(function() conn:Disconnect() end)
	end
	table.clear(spyChatState.Connections)
end

local function spyChatStart()
	spyChatBuildUI()
	spyChatDisconnect()

	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(spyChatState.Connections, player.Chatted:Connect(function(message)
			spyChatAddLine(
				string.format("<font color='rgb(120,190,255)'>[%s]</font> %s", player.Name, message),
				Color3.fromRGB(220, 226, 238)
			)
		end))
	end

	table.insert(spyChatState.Connections, Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(message)
			spyChatAddLine(
				string.format("<font color='rgb(120,190,255)'>[%s]</font> %s", player.Name, message),
				Color3.fromRGB(220, 226, 238)
			)
		end)
	end))

	pcall(function()
		local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
		if chatEvents then
			local onMessageDoneFiltering = chatEvents:FindFirstChild("OnMessageDoneFiltering")
			if onMessageDoneFiltering and onMessageDoneFiltering:IsA("RemoteEvent") then
				table.insert(spyChatState.Connections, onMessageDoneFiltering.OnClientEvent:Connect(function(data)
					if type(data) ~= "table" then return end
					local from = data.FromSpeaker or "?"
					local msg = data.Message or ""
					local channel = data.Channel or ""
					local prefix = channel ~= "" and ("[" .. channel .. "] ") or ""
					spyChatAddLine(
						string.format("<font color='rgb(120,190,255)'>[%s]</font> %s%s", from, prefix, msg),
						Color3.fromRGB(220, 226, 238)
					)
				end))
			end
		end
	end)

	pcall(function()
		local candidates = {
				"ChatEvent", "ChatRemote", "SendMessage", "ChatService",
				"DefaultChatSystemChatEvents", "Chat", "ChatMain",
				"MainEvent", "ChatLog", "MessageEvent",
			}
		for _, name in ipairs(candidates) do
			for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
				if obj.Name == name and obj:IsA("RemoteEvent") then
					pcall(function()
						table.insert(spyChatState.Connections, obj.OnClientEvent:Connect(function(...)
							local args = { ... }
							local text = nil
							local speaker = nil
							for _, v in ipairs(args) do
								if type(v) == "string" and #v > 0 and #v < 500 then
									if not speaker then speaker = v else text = v end
								end
							end
							if text then
								spyChatAddLine(
									string.format("<font color='rgb(120,190,255)'>[%s]</font> %s", speaker or "?", text),
									Color3.fromRGB(220, 226, 238)
								)
							end
						end))
					end)
				end
			end
		end
	end)

	spyChatAddLine("<font color='rgb(120,190,255)'>[spy]</font> spy chat enabled — press P to toggle", Color3.fromRGB(120, 190, 255))
end

local function spyChatStop()
	spyChatDisconnect()
	spyChatDestroyUI()
end

-- ============================================================
-- Teleport page
-- ============================================================

local teleports = {
	{ name = "Uphill Gunstore", pos = CFrame.new(481.3, 48.07, -620.15) },
	{ name = "Downhill Gunstore", pos = CFrame.new(-578.58, 8.31, -736.39) },
	{ name = "Bank", pos = CFrame.new(-432.14, 38.96, -284.1) },
	{ name = "Safe 1", pos = CFrame.new(-117, -57, 147) },
	{ name = "School", pos = CFrame.new(-531.35, 21.75, 252.48) },
	{ name = "Da Casino", pos = CFrame.new(-863.47, 21.6, -152.93) },
	{ name = "Basketball Court", pos = CFrame.new(-896.56, 22, -528.73) },
	{ name = "FoodsMart", pos = CFrame.new(-906.58, 22.01, -653.22) },
	{ name = "Military Base", pos = CFrame.new(-50.41, 25.25, -868.92) },
	{ name = "Da Boxing", pos = CFrame.new(-232.07, 22.07, -1119.95) },
	{ name = "Hospital", pos = CFrame.new(98.4, 22.8, -484.89) },
	{ name = "Police Station", pos = CFrame.new(-265.5, 21.8, -96.52) },
	{ name = "Church", pos = CFrame.new(205.82, 23.78, -58.47) },
}

Teleport:addLabel("Teleport to player")
Teleport:addTextBox("Player name", "type username...", function(text)
	local query = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if query == "" then return end
	local target = state.value110(query)
	local myHrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	local theirHrp = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")

	if target and myHrp and theirHrp then
		myHrp.CFrame = theirHrp.CFrame * CFrame.new(0, 0, 3)
	end
end)

Teleport:addSeparator()
Teleport:addLabel("Locations")

for _, spot in ipairs(teleports) do
	Teleport:addButton(spot.name, function()
		local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.CFrame = spot.pos end
	end)
end

-- ============================================================
-- Utility page
-- ============================================================

Utility:addLabel("Utility")

Utility:addKeybind("Toggle GUI", Enum.KeyCode.Insert, function()
	local sg = window.ScreenGui
	if sg and sg.Parent then
		sg.Enabled = not sg.Enabled
	end
end)

Utility:addSeparator()
Utility:addLabel("Spy Chat")

Utility:addToggle("Spy Chat", false, function(on)
	spyChatState.Enabled = on
	if on then
		spyChatStart()
	else
		spyChatStop()
	end
end, true, Enum.KeyCode.P)

Utility:addButton("Clear Spy Chat", function()
	table.clear(spyChatState.Log)
	if spyChatState.Label then spyChatState.Label.Text = "" end
end)

Utility:addSeparator()
Utility:addLabel("Void")

local voidState = {
	Enabled = false,
	Active = false,
	Mode = "Void",
	ReturnCFrame = nil,
	Connection = nil,
	CharConnection = nil,
}

local function voidCFrame()
	if voidState.Mode == "Deep Void" then
		local angle = math.random() * math.pi * 2
		local radius = 1e13 + math.random() * 9e13
		return CFrame.new(
			math.cos(angle) * radius,
			1e13 + math.random() * 9e13,
			math.sin(angle) * radius
		)
	end
	local angle = math.random() * math.pi * 2
	local radius = 12000 + math.random() * 4000
	return CFrame.new(
		math.cos(angle) * radius,
		5000 + math.random() * 2000,
		math.sin(angle) * radius
	)
end

local function stopVoid(returnHome)
	if voidState.Connection then
		voidState.Connection:Disconnect()
		voidState.Connection = nil
	end
	if voidState.CharConnection then
		voidState.CharConnection:Disconnect()
		voidState.CharConnection = nil
	end
	voidState.Active = false

	if returnHome and voidState.ReturnCFrame then
		local char = localPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			pcall(function()
				hrp.CFrame = voidState.ReturnCFrame
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
			end)
		end
	end

	voidState.ReturnCFrame = nil

	local cam = workspace.CurrentCamera
	local char = localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if cam and hum then
		cam.CameraType = Enum.CameraType.Custom
		cam.CameraSubject = hum
	end
end

local function startVoid()
	stopVoid(false)

	local char = localPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	voidState.ReturnCFrame = hrp.CFrame
	voidState.Active = true

	local targetCFrame = voidCFrame()

	voidState.Connection = state.value2.Heartbeat:Connect(function()
		if not voidState.Active or not voidState.Enabled then return end
		local c = localPlayer.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if not r then return end

		pcall(function()
			if (r.Position - targetCFrame.Position).Magnitude > 1 then
				r.CFrame = targetCFrame
			end
			r.AssemblyLinearVelocity = Vector3.zero
			r.AssemblyAngularVelocity = Vector3.zero
		end)
	end)

	voidState.CharConnection = localPlayer.CharacterAdded:Connect(function(newChar)
		if not voidState.Enabled then return end
		local newHrp = newChar:WaitForChild("HumanoidRootPart", 5)
		if not newHrp then return end
		task.wait(0.2)
		pcall(function()
			newHrp.CFrame = targetCFrame
		end)
	end)
end

Utility:addToggle("Hide in Void", false, function(on)
	voidState.Enabled = on
	if on then
		startVoid()
	else
		stopVoid(true)
	end
end)

Utility:addKeybind("Void Key", Enum.KeyCode.V, function()
	if not voidState.Enabled then
		voidState.Enabled = true
		startVoid()
	else
		voidState.Enabled = false
		stopVoid(true)
	end
end)

Utility:addSeparator()
Utility:addLabel("Void Mode")

Utility:addButton("Void (Standard)", function()
	voidState.Mode = "Void"
	if voidState.Enabled and voidState.Active then
		stopVoid(false)
		startVoid()
	end
end)

Utility:addButton("Void (Deep)", function()
	voidState.Mode = "Deep Void"
	if voidState.Enabled and voidState.Active then
		stopVoid(false)
		startVoid()
	end
end)

Utility:addSeparator()
Utility:addLabel("Combat Utility")

local antiStompEnabled = false
local antiStompConn = nil

Utility:addToggle("Anti Stomp", false, function(on)
	antiStompEnabled = on
	if antiStompConn then
		antiStompConn:Disconnect()
		antiStompConn = nil
	end
	if not on then return end

	local function stompCheck()
		local char = localPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health > 15 then return end
		for _, name in ipairs({
				"Head", "RightHand", "LeftHand", "LowerTorso", "UpperTorso",
				"LeftLowerLeg", "RightLowerLeg", "RightFoot", "LeftFoot",
				"LeftUpperLeg", "RightUpperLeg", "RightUpperArm", "RightLowerArm",
				"LeftLowerArm", "LeftUpperArm",
			}) do
			local part = char:FindFirstChild(name)
			if part then pcall(function() part:Destroy() end) end
		end
	end

	stompCheck()
	antiStompConn = state.value2.RenderStepped:Connect(stompCheck)
end)

local stompSpamEnabled = false
local stompSpamConn = nil
local lastStompAt = 0

Utility:addToggle("Stomp Spam (hold E)", false, function(on)
	stompSpamEnabled = on
	if stompSpamConn then
		stompSpamConn:Disconnect()
		stompSpamConn = nil
	end
	if not on then return end

	stompSpamConn = state.value2.Heartbeat:Connect(function()
		if not stompSpamEnabled then return end
		if not UserInputService:IsKeyDown(Enum.KeyCode.E) then return end

		local interval = 0.18 + math.random() * 0.06
		if tick() - lastStompAt < interval then return end

		local char = localPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then return end

		local mainEvent = ReplicatedStorage:FindFirstChild("MainEvent")
		if not mainEvent then return end

		lastStompAt = tick()
		pcall(function()
			mainEvent:FireServer("Stomp")
		end)
	end)
end)

local autoRespawnEnabled = false
local autoRespawnConn = nil

Utility:addToggle("Auto Respawn", false, function(on)
	autoRespawnEnabled = on
	if autoRespawnConn then
		autoRespawnConn:Disconnect()
		autoRespawnConn = nil
	end
	if not on then return end

	autoRespawnConn = localPlayer.CharacterAdded:Connect(function(character)
		if not autoRespawnEnabled then return end
		task.wait(1.5)
		local hum = character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health <= 0 then
			pcall(function() hum.Health = 0 end)
		end
	end)
end)

local deathSpawnEnabled = false
local lastDeathCFrame = nil

localPlayer.CharacterAdded:Connect(function(character)
	local hum = character:WaitForChild("Humanoid", 5)
	if hum then
		hum.Died:Connect(function()
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then lastDeathCFrame = hrp.CFrame end
		end)
	end

	if deathSpawnEnabled and lastDeathCFrame then
		local hrp = character:WaitForChild("HumanoidRootPart", 5)
		if hrp then
			task.wait(0.3)
			pcall(function()
				hrp.CFrame = lastDeathCFrame
			end)
		end
	end
end)

Utility:addToggle("Respawn at Death Spot", false, function(on)
	deathSpawnEnabled = on
	if on then
		local char = localPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then lastDeathCFrame = hrp.CFrame end
	end
end)

Utility:addSeparator()
Utility:addLabel("Actions")

Utility:addButton("Rejoin", function()
	TeleportService:Teleport(game.PlaceId, localPlayer)
end)

Utility:addButton("Reset Character", function()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.Health = 0 end
end)

-- ============================================================
-- Fall rescue — 3-tier auto-recovery
-- ============================================================

task.spawn(function()
	while true do
		task.wait(0.15)

		local char = localPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then continue end

		local y = hrp.Position.Y

		if y < -50 and y > -100 then
			pcall(function()
				hrp.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 20, 0))
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
			end)
		end

		if y <= -100 and y > -1000 then
			pcall(function()
				hrp.CFrame = CFrame.new(hrp.Position.X, 50, hrp.Position.Z)
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
			end)
		end

		if y <= -1000 then
			pcall(function()
				hrp.CFrame = CFrame.new(0, 100, 0)
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
			end)
		end
	end
end)

-- ============================================================
-- Configs page
-- ============================================================

Configs:addLabel("Configs")

local configName = tostring(getgenv().BOBBY_ConfigName or "")
local configButtons = {}
local configListHolder = nil
local configListVisible = false
local selectedConfig = ""

local configNameBox = Configs:addTextBox("Config Name", "enter name...", function(text)
	local safe = tostring(text or ""):gsub("[^%w%._%-]", "_")
	configName = safe
	getgenv().BOBBY_ConfigName = safe
	selectedConfig = safe
	for k, btn in pairs(configButtons) do
		if btn and btn.Parent and btn:IsA("TextButton") then
			btn.TextColor3 = k == safe and Color3.fromRGB(120, 190, 255) or Color3.fromRGB(200, 205, 220)
		end
	end
end)

local function getConfigTextBox()
	return configNameBox and configNameBox:FindFirstChildWhichIsA("TextBox", true)
end

local function syncConfigNameBox()
	local box = getConfigTextBox()
	if box then box.Text = configName end
end

local function clearConfigButtons()
	for _, btn in pairs(configButtons) do
		if btn and btn.Parent then pcall(function() btn:Destroy() end) end
	end
	table.clear(configButtons)
end

local function setConfigName(name)
	configName = tostring(name or "")
	getgenv().BOBBY_ConfigName = configName
	syncConfigNameBox()
	for k, btn in pairs(configButtons) do
		if btn and btn.Parent and btn:IsA("TextButton") then
			btn.TextColor3 = k == configName and Color3.fromRGB(120, 190, 255) or Color3.fromRGB(200, 205, 220)
		end
	end
end

local function refreshConfigList()
	if not configListHolder then return end
	clearConfigButtons()

	local names = listConfigs()
	if #names == 0 then
		local empty = create("TextLabel", {
			Parent = configListHolder,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -8, 0, 26),
			Font = Enum.Font.Gotham,
			Text = "no configs found",
			TextColor3 = Color3.fromRGB(140, 148, 165),
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		table.insert(configButtons, empty)
		return
	end

	for i, name in ipairs(names) do
		local btn = create("TextButton", {
			Name = "Cfg_" .. name,
			Parent = configListHolder,
			BackgroundColor3 = Color3.fromRGB(28, 32, 44),
			BorderSizePixel = 0,
			Size = UDim2.new(1, -8, 0, 26),
			Font = Enum.Font.Gotham,
			Text = "  " .. name,
			TextColor3 = (name == configName or name == selectedConfig) and Color3.fromRGB(120, 190, 255) or Color3.fromRGB(200, 205, 220),
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutoButtonColor = false,
			LayoutOrder = i,
		})
		create("UICorner", { Parent = btn, CornerRadius = UDim.new(0, 4) })
		table.insert(configButtons, btn)

		btn.MouseButton1Click:Connect(function()
			selectedConfig = name
			setConfigName(name)
		end)
	end

	setConfigName(configName)
end

Configs:addButton("Save Config", function()
	if tostring(configName or "") == "" then
		notify("Enter a config name first", false)
		return
	end
	local saved = sanitize(configName)
	configName = saved
	getgenv().BOBBY_ConfigName = saved
	local ok = saveConfig(saved)
	refreshConfigList()
	setConfigName(saved)
	notify(ok and ("Saved: " .. saved) or ("Save failed: " .. saved), ok)
end)

Configs:addButton("Load Config", function()
	local name = sanitize(selectedConfig ~= "" and selectedConfig or configName)
	if name == "" then
		notify("Select a config first", false)
		return
	end
	local ok = applyConfig(name)
	notify(ok and ("Loaded: " .. name) or ("Load failed: " .. name), ok)
	if ok then
		selectedConfig = name
		setConfigName(name)
		refreshConfigList()
	end
end)

Configs:addButton("Show Configs", function()
	if not configListHolder then return end
	configListVisible = not configListVisible
	configListHolder.Visible = configListVisible
	configListHolder:TweenSize(
		UDim2.new(1, 0, 0, configListVisible and 160 or 0),
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Quad,
		0.2,
		true
	)
	if configListVisible then
		refreshConfigList()
	end
end)

Configs:addButton("Delete Config", function()
	local name = sanitize(selectedConfig ~= "" and selectedConfig or configName)
	if name == "" then
		notify("Select a config first", false)
		return
	end
	deleteConfig(name)
	notify("Deleted: " .. name, true)
	if name == configName then
		configName = ""
		getgenv().BOBBY_ConfigName = ""
		syncConfigNameBox()
	end
	selectedConfig = ""
	refreshConfigList()
end)

local listBtn = Configs.Container:FindFirstChild("Btn_Show Configs", true)
if listBtn then
	configListHolder = create("Frame", {
		Name = "ConfigListHolder",
		Parent = listBtn.Parent,
		BackgroundColor3 = Color3.fromRGB(18, 20, 28),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		ClipsDescendants = true,
		Visible = false,
	})
	create("UICorner", { Parent = configListHolder, CornerRadius = UDim.new(0, 6) })

	local configScroll = create("ScrollingFrame", {
		Parent = configListHolder,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Color3.fromRGB(60, 130, 246),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})
	create("UIListLayout", { Parent = configScroll, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder })
end

refreshConfigList()
setConfigName(configName)

-- ============================================================
-- Final bootstrap
-- ============================================================

print("[bobby.noob] loaded — Insert toggles the menu, P toggles spy chat")
print("[bobby.noob] Strafe: anti-hit (dodge/bounce/jitter) + shot stability")
print("[bobby.noob] Noclip-safe strafe return + 3-tier fall rescue active")
