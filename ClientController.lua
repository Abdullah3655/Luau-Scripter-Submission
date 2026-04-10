local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ScreenGui = playerGui:WaitForChild("ServerMenu")

--// ===================== NOTIFICATIONS =====================

local NotificationFrame = ScreenGui:WaitForChild("NotificationFrame")
local ErrorTemplate = NotificationFrame:WaitForChild("ErrorText")
local NotificationTemplate = NotificationFrame:WaitForChild("NotificationText")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local ShowNotificationEvent = RemoteEvents:WaitForChild("ShowNotificationEvent")
local ShowErrorEvent = RemoteEvents:WaitForChild("ShowErrorEvent")

-- Display time for notifications
local NotificationDisplayTime = 5

-- Function to create and display notification using TweenService to make it look smooth
local function createMessage(template, text)
	local new = template:Clone()
	new.Visible = true
	new.Text = text
	new.Parent = NotificationFrame

	-- Fade in
	new.TextTransparency = 1
	TweenService:Create(new, TweenInfo.new(0.3), {
		TextTransparency = 0
	}):Play()

	-- Auto remove after time
	task.delay(NotificationDisplayTime, function()
		local tween = TweenService:Create(new, TweenInfo.new(0.3), {
			TextTransparency = 1
		})
		tween:Play()
		tween.Completed:Wait()
		new:Destroy()
	end)
end

-- Function to show error message
local function showError(message)
	createMessage(ErrorTemplate, message)
end

-- Function to show normal notification
local function showNotification(message)
	createMessage(NotificationTemplate, message)
end

ShowNotificationEvent.OnClientEvent:Connect(function(message)
	showNotification(message)
end)

ShowErrorEvent.OnClientEvent:Connect(function(message)
	showError(message)
end)

--// ===================== SERVER LIST =====================

local JoinServerEvent = RemoteEvents:WaitForChild("JoinServerEvent")

local RemoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions")
local DisplayServerList = RemoteFunctions:WaitForChild("DisplayServerList")

local ServerList = ScreenGui:WaitForChild("ServerList")
local ServerScrollingFrame = ServerList:WaitForChild("ServerList")
local ServerTemplate = ServerScrollingFrame:WaitForChild("ServerTemplate")

-- Storing frames so if the server is not gone, it doesn't delete it and clone it again
-- It will just change the values it currently has
local renderedFrames = {}   

local REFRESH_TIME = 5 -- seconds

-- Render or update a single server frame
local function renderServer(serverData)
	local key = serverData.joinCode
	local frame = renderedFrames[key]

	if not frame then
		frame = ServerTemplate:Clone()
		frame.Visible = true
		frame.Parent = ServerScrollingFrame
		renderedFrames[key] = frame
	end

	frame:SetAttribute("JoinCode", key)

	frame.PlayerCount.Text = string.format("(%d/%d)", serverData.PlayerCount, serverData.MaxPlayerCount)

	local owner = serverData.OwnerData or {}

	frame.OwnerName.Text = owner.OwnerDisplayName or "Unknown"
	frame.PlayerImage.Image = owner.OwnerAvatar 

	frame.ServerName.Text = serverData.Name or "Unnamed Server"
	frame.Description.Text = serverData.Description or "No description"
	frame.ServerImage.Image = serverData.Image and ("rbxassetid://" .. tostring(serverData.Image)) or ""

	-- Only connecting the event once by checking the bolean JoinConnected attribute on the frame
	-- Using the JoinCode attribute that I stored in it the server joinCode above
	if not frame:GetAttribute("JoinConnected") then
		frame.JoinServerButton.MouseButton1Click:Connect(function()
			local joinCode = frame:GetAttribute("JoinCode")
			if joinCode then
				JoinServerEvent:FireServer(joinCode)
			end
		end)
		frame:SetAttribute("JoinConnected", true)
	end
end

-- Update all servers
local function updateServerList(newServerData)
	local alive = {}

	for _, server in ipairs(newServerData) do

		-- Skip empty servers
		if server.PlayerCount and server.PlayerCount <= 0 then
			continue
		end

		local joinCode = server.joinCode
		if joinCode then
			alive[joinCode] = true
			renderServer(server)
		end
	end

	-- Remove frames that no longer exist
	for joinCode, frame in pairs(renderedFrames) do
		if not alive[joinCode] then
			frame:Destroy()
			renderedFrames[joinCode] = nil
		end
	end
end

-- Fetch server list from server
local function fetchServers()
	local success, serverData = pcall(function()
		return DisplayServerList:InvokeServer()
	end)

	if success and serverData then
		updateServerList(serverData)
	end
end

-- Auto refresh loop
task.spawn(function()
	while true do
		task.wait(REFRESH_TIME)
		fetchServers()
	end
end)

-- Initial fetch
task.delay(1,function()
	fetchServers()
end)

--// ===================== JOIN BY CODE =====================

local JoinByCode = ServerList:WaitForChild("JoinByCode")
local JoinByCodeServerButton = JoinByCode:WaitForChild("JoinByCodeServerButton")
local CodeInput = JoinByCode:WaitForChild("CodeInput")

-- Sends request to join a server by joinCode provided by the player
JoinByCodeServerButton.MouseButton1Click:Connect(function()
	local joinCode = CodeInput.Text
	JoinServerEvent:FireServer(joinCode)
end)

--// ===================== CREATE SERVER =====================

local CreateServer1 = ScreenGui:WaitForChild("CreateServer")
local CreateServer2 = CreateServer1:WaitForChild("CreateServer")
local CreateServerButton = CreateServer2:WaitForChild("CreateServerButton")
local DescriptionInput = CreateServer2:WaitForChild("DescriptionInput")
local NameInput = CreateServer2:WaitForChild("NameInput")
local ServerSize = CreateServer2:WaitForChild("ServerSize")
local ServerImage = CreateServer2:WaitForChild("ServerImage")
local PictureInput = ServerImage:WaitForChild("PictureInput")

local CreateServerEvent = RemoteEvents:WaitForChild("CreateServerEvent")

-- Sends request to create a server and passing data provided by the player
CreateServerButton.MouseButton1Click:Connect(function()
	local ServerData = {
		Name = NameInput.Text,
		Description = DescriptionInput.Text,
		MaxPlayerCount = ServerSize.Text,
		Image = PictureInput.Text
	}
	CreateServerEvent:FireServer(ServerData)
end)
