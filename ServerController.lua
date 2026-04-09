-- This is only the server script, there is also local scripts, but not included here
-- They are in the game tho to make it functional

-- Services
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")
local LocalizationService = game:GetService("LocalizationService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

-- RemoteEvents/RemoteFunctions
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local RemoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions")

local JoinServerEvent = RemoteEvents:WaitForChild("JoinServerEvent")
local CreateServerEvent = RemoteEvents:WaitForChild("CreateServerEvent")
local ShowNotificationEvent = RemoteEvents:WaitForChild("ShowNotificationEvent")
local ShowErrorEvent = RemoteEvents:WaitForChild("ShowErrorEvent")
local DisplayServerList = RemoteFunctions:WaitForChild("DisplayServerList")

local ServerList = MemoryStoreService:GetSortedMap("ActiveServers")

-- ErrorHandling

local ERROR_MESSAGES = {
	NO_NAME = "Please enter a server name.",
	NAME_TOO_LONG = "Server name is too long.",
	DESCRIPTION_TOO_LONG = "Description is too long.",
	NO_MAXPLAYERCOUNT = "Max player count is required.",
	MAXPLAYERCOUNT_INVALID = "Max player count must be a number.",
	MAXPLAYERCOUNT_OUT_OF_RANGE = "Max player count must be between 1 and 50.",
	NOT_FOUND = "Server not found.",
	FULL_SERVER = "This server is full.",
	NO_CODE = "You must provide a join code.",
	INVALID_CODE = "Join code must be only numbers.",
	INVALID_CODE_LENGTH = "Join code must be exactly 8 digits.",
	SYSTEM_ERROR = "Something went wrong.",
	IMAGE_INVALID = "Image ID is invalid"
}

-- Using the prefix so I know it is a game error not internal error from roblox APIs
local GAME_PREFIX = "[GAME_ERROR]"

-- Throws game error with the prefix
local function gameError(code)
	error(GAME_PREFIX .. code)
end

-- It maps the error codes
local function GetFriendlyMessage(errorCode)
	return ERROR_MESSAGES[errorCode] or "Something went wrong."
end

-- It is the main error handling function that returns the game errors and roblox APIs errors
-- It differentiate between them using the game prefix
local function SafeCall(fn, retries)
	retries = retries or 5

	for i = 1, retries do
		local success, result = pcall(fn)

		if success then
			return true, result
		end

		result = tostring(result)

		-- This checks if the game prefix is in the error or not
		if string.find(result, GAME_PREFIX, 1, true) then
			local startPos = string.find(result, GAME_PREFIX, 1, true)
			-- This cuts out the game prefix so I get the code clean
			local code = result:sub(startPos + #GAME_PREFIX)
			return false, code
		end

		task.wait(0.1)
	end

	return false, "SYSTEM_ERROR"
end

-- It gets SafeThumbnail and the reason why I am using it is
-- Roblox APIs are not safe and might throw errors and also to retry if it does
local function SafeThumbnail(userId)
	for i = 1, 5 do
		local thumbSuccess, content, isReady = pcall(function()
			return Players:GetUserThumbnailAsync(
				userId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size180x180
			)
		end)

		if thumbSuccess and content and isReady then
			return content
		end

		task.wait(0.2)
	end

	return "rbxassetid://DEFAULT_IMAGE_ID"
end

-- ServerRepository

-- Time till server gets deleted from the MemoryStore(has to be refreshed before that time ends)
local TTL = 30

-- Adding Max for the characters so players can't just put so many characters and cause problems
local MaxNameCharacters = 20
local MaxDescriptionCharacters = 50

-- Filter server data to store only required fields
-- So no random data stored by mistake or sent by player other than the one that is needed
local function FilterServerData(serverData)
	return {
		accessCode = serverData.accessCode,
		joinCode = serverData.joinCode,
		Name = serverData.Name,
		PlaceId = serverData.PlaceId,
		PlayerCount = serverData.PlayerCount,
		MaxPlayerCount = serverData.MaxPlayerCount,
		Description = serverData.Description,
		Image = serverData.Image,
		OwnerData = {
			OwnerUserId = serverData.OwnerData.OwnerUserId,
			OwnerDisplayName = serverData.OwnerData.OwnerDisplayName,
			OwnerUserName = serverData.OwnerData.OwnerUsername,
			OwnerAvatar = serverData.OwnerData.OwnerAvatar,
			OwnerCountry = serverData.OwnerData.Country,
			OwnerFlag = serverData.OwnerData.OwnerFlag
		}
	}
end

-- Utility to check join code format and validate it
-- Also so players get nice errors for joinCode related errors
local function validateJoinCode(joinCode)
	if not joinCode or joinCode == "" then
		gameError("NO_CODE")
	end

	-- Converts the joinCode to string
	local codeStr = tostring(joinCode)

	-- Check if only digits
	if codeStr:match("%D") then
		gameError("INVALID_CODE")
	end

	-- Check if exactly 8 digits
	if #codeStr ~= 8 then
		gameError("INVALID_CODE_LENGTH")
	end
end

-- Set server data safely using SafeCall function
-- It also handles the errors that might happen to show nice errors to the player
local function SetServerData(joinCode, serverData)
	return SafeCall(function()

		-- Checks if ServerName is provided or not
		if not serverData.Name or serverData.Name == "" then
			gameError("NO_NAME")
		end

		-- Checks if the name is too long or not
		if #serverData.Name > MaxNameCharacters then
			gameError("NAME_TOO_LONG")
		end

		-- Checks if the description is too long or not
		if serverData.Description and #serverData.Description > MaxDescriptionCharacters then
			gameError("DESCRIPTION_TOO_LONG")
		end

		-- Checks if MaxPlayerCount is there or not
		if serverData.MaxPlayerCount == nil or serverData.MaxPlayerCount == "" then
			gameError("NO_MAXPLAYERCOUNT")
		end

		-- Checks if the MaxPlayerCount is invalid or not (a number)
		local maxPlayers = tonumber(serverData.MaxPlayerCount)
		if not maxPlayers then
			gameError("MAXPLAYERCOUNT_INVALID")
		end

		-- Checks if the MaxPlayerCount is out of range (0 - 50)
		if maxPlayers <= 0 or maxPlayers > 50 then
			gameError("MAXPLAYERCOUNT_OUT_OF_RANGE")
		end

		serverData.MaxPlayerCount = maxPlayers

		-- Checks if the imageId is invalid or not (a positive integer number)
		if serverData.Image ~= nil and serverData.Image ~= "" then
			local imageId = tonumber(serverData.Image)
			if not imageId or imageId <= 0 or imageId ~= math.floor(imageId) then
				gameError("IMAGE_INVALID")
			end
			serverData.Image = imageId
		end

		-- Filtering the data before saving so it doesn't contain any unwanted attributes
		local filteredData = FilterServerData(serverData)

		-- Saving the data after all the checks passed and data filtered
		return ServerList:SetAsync(joinCode, filteredData, TTL)
	end)
end

-- Get multiple servers safely using SafeCall function depending on the range provided
local function GetServersData(range)
	return SafeCall(function()
		return ServerList:GetRangeAsync(Enum.SortDirection.Ascending, range)
	end)
end

-- Get single server data safely using SafeCall function
-- It also uses validateJoinCode function to check the joinCode formate
-- There is also strict logic here and basically why I used it here is
-- Because I needed to get nil if the server is not found
-- So I know that the joinCode I generated randomly is not there and I can use for new server creation
-- But also sometimes I need to get error for the player that the server is not found when they try to join it
-- I could have made two functions one for the nil logic and one for the error
-- But that's bad practice to rewrite the code to just change small thing in it
local function GetServerData(joinCode, strict)
	return SafeCall(function()
		validateJoinCode(joinCode)

		local data = ServerList:GetAsync(joinCode)
		if not data then
			if strict then
				gameError("NOT_FOUND")
			else
				return nil
			end
		end
		return data
	end)
end

-- Checks if there is a slot available for a player safely using SafeCall function
-- It uses the validateJoinCode function to check for the joinCode format
-- The UpdateAsync functions returns error strings not an error
-- The reason for that is I want to know if the UpdateAsync it self is successfull or not first
-- Then I check for the game error afterwards that's why I can't throw an error inside UpdateAsync
-- Because it will ruin the logic I am using for the rest of the functions
-- And won't be consistant for the SafeCall function
local function CheckSlot(joinCode)
	return SafeCall(function()
		validateJoinCode(joinCode)

		local errorCode = nil
		local result = ServerList:UpdateAsync(joinCode, function(Data)
			if not Data then
				errorCode = "NOT_FOUND"
				return Data
			end

			if Data.PlayerCount >= Data.MaxPlayerCount then
				errorCode = "FULL_SERVER"
				return Data
			end

			return Data
		end, TTL)

		if errorCode then
			gameError(errorCode)
		end

		return result
	end)
end

-- ServerService

-- The placeId for the servers that are gonna be created
local placeId = 14836976189

-- This generate unique joinCode, so it can be used for a new server that is being created
-- First it generates a random number from 8 digits
-- Making sure it is unique by searching if that code already exists or not
-- By trying to get a server with that code using non strict mode for the GetServerData function(passing false)
-- It also retry if it finds it cuz even tho it is rare, but it still may happen
-- Especially if there are a lot of servers in the game
local function generateUniqueJoinCode()
	for _ = 1, 25 do
		local code = tostring(math.random(10000000, 99999999))

		-- If the code does not exist, it is safe to use
		local success, result = GetServerData(code, false)
		if success and result == nil then
			return code -- safe to use
		end

		-- If there is a system error, it keeps retrying
		if not success then
			warn("System error while checking join code:", result)
		end
	end
	return nil
end

-- Filter text for players so they can't put things against roblox TOS
local function FilterText(text, fromUserId)
	if not text or text == "" then
		return ""
	end

	local success, filterResult = SafeCall(function()
		return TextService:FilterStringAsync(text, fromUserId)
	end)

	if not success then
		warn("FilterStringAsync failed:", filterResult)
		return "[Filtered]"
	end

	local success2, finalText = SafeCall(function()
		return filterResult:GetNonChatStringForBroadcastAsync()
	end)

	if success2 then
		return finalText
	else
		warn("Broadcast filter failed:", finalText)
		return "[Filtered]"
	end
end

-- Getting the country for the player so it can be used to get the flag
-- It returns a country code from 2 letters
local function getCountry(player)
	local success, result = SafeCall(function()
		return LocalizationService:GetCountryRegionForPlayerAsync(player)
	end)

	return success and result or "Unknown"
end

-- Getting the flag for the player
local function getFlagEmoji(countryCode)

	-- validate if there is a code or not and also if it is 2 characters or not
	if not countryCode or #countryCode ~= 2 then
		return "??" -- default
	end

	-- It converts the code to uppercase
	-- Just in case it was sent inconsistant like some lowercase and some uppercase
	countryCode = string.upper(countryCode)

	-- It gets the ASCII code for the first and second letters using string.byte
	-- Then it gets the codes needed for the flag
	-- Honestly don't fully understand the reason why it is done that way, but this is how it is done
	local first = string.byte(countryCode, 1) - 65 + 0x1F1E6
	local second = string.byte(countryCode, 2) - 65 + 0x1F1E6

	-- It gets the flag
	return utf8.char(first, second)
end

-- Create a reserved server for the player safely using SafeCall function when needed
-- It first make a reserved server then generate unique joinCode so it can be assigned to it
-- It sets all the data needed on the serverData table and then send it to SetServerData with the joinCode
-- So the joinCode can be saved as the key and the serverData as value
-- And also checking for all possible errors that might happen
local function CreateServer(player, serverData)
	local ok, accessCode = SafeCall(function()
		return TeleportService:ReserveServerAsync(placeId)
	end)

	if not ok then
		warn("Failed to reserve server")
		return false, "SYSTEM_ERROR"
	end

	local joinCode = generateUniqueJoinCode()
	if not joinCode then
		warn("Failed to generate unique join code")
		return false, "SYSTEM_ERROR"
	end

	serverData.Name = FilterText(serverData.Name, player.UserId)
	serverData.Description = FilterText(serverData.Description, player.UserId)
	serverData.accessCode = accessCode
	serverData.joinCode = joinCode
	serverData.PlaceId = placeId
	serverData.PlayerCount = 1
	serverData.OwnerData = {}
	serverData.OwnerData.OwnerUserId = player.UserId
	serverData.OwnerData.OwnerDisplayName = player.DisplayName
	serverData.OwnerData.OwnerUserName = player.Name

	local thumbUrl = SafeThumbnail(player.UserId)
	serverData.OwnerData.OwnerAvatar = thumbUrl or "rbxassetid://DEFAULT_IMAGE_ID"

	local country = getCountry(player)
	local flag = getFlagEmoji(country)

	serverData.OwnerData.OwnerCountry = country
	serverData.OwnerData.OwnerFlag = flag

	local saveSuccess, saveResult = SetServerData(joinCode, serverData)
	if not saveSuccess then
		return false, saveResult
	end

	local teleportSuccess = SafeCall(function()
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = accessCode
		options:SetTeleportData({
			joinCode = joinCode,
			serverData = serverData
		})

		return TeleportService:TeleportAsync(placeId, { player }, options)
	end)

	if not teleportSuccess then
		warn("Failed to teleport owner to reserved server")
		return false, "SYSTEM_ERROR"
	end

	return true, joinCode
end

-- Join an existing reserved server using its access code safely using SafeCall function when needed
-- It first checks if there is a slot available for the player
-- It gets the server if found using strict mode(passing true)
-- Since it is needed to send that server was not found error to the player if it doesn't find it
-- It gets the accessCode for the reserved server from the serverData so it can teleport the player to it
-- Since joinCodes are only for good looking code for the players, but internally using the accessCode
local function JoinServer(joinCode, player)
	--check repository for server info / max players
	local success, result = CheckSlot(joinCode)

	if not success then
		return false, result
	end

	-- Get the server's access code from the repository
	local serverSuccess, serverData = GetServerData(joinCode, true)
	if not serverSuccess then
		return false, serverData
	end
	local accessCode = serverData.accessCode

	-- Teleport player to the reserved server
	local teleportSuccess = SafeCall(function()
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = accessCode
		return TeleportService:TeleportAsync(placeId, { player }, options)
	end)

	if not teleportSuccess then
		warn("Failed to teleport player to reserved server")
		return false, "SYSTEM_ERROR"
	end

	return true
end

local function GetServerList(range)
	return GetServersData(range)
end

-- Main server script

-- Table for mapping notifications for good notifications for the player
local Notifications = {
	Creating = "Creating server...",
	Teleporting = "Teleporting to server...",
	Spam = "Stop spamming!"
}

-- Cooldown for the requests made by the players so they don't spam
local COOLDOWN = 2 -- seconds

-- Cooldown for the remote function so players don't spam
local SERVERLIST_COOLDOWN = 4 -- seconds

-- Table used to store playerIds for players who has cooldowns on both join or create requests
-- So they don't make too many requests
local Cooldowns = {
	Join = {},
	Create = {}
}

-- Table used to store playerIds for players who still processing their requests
-- Cuz it takes time to handle the request and they might click before it is
local Locks = {
	Join = {},
	Create = {}
}

-- Table used to store playerIds for players that asks for serverList
-- Since serverList uses MemoryStore so too many calls may break it
-- I don't want players to spam the remote function
local ServerListCooldown = {}

-- Checks if the player can request or not
local function canRequest(player, actionTable)
	local lastTime = actionTable[player.UserId]
	local now = os.clock()

	if lastTime and now - lastTime < COOLDOWN then
		return false
	end

	actionTable[player.UserId] = now
	return true
end

-- Handles the request by checking if the player is locked or not and if he is on a cooldown or not
-- It sends notifications to the player by firing the ShowNotificationEvent when needed
-- It also sends the errors to the player by firing the show error event
-- It also calls the function, whatever it is join or create
local function handleRequest(player, actionName, cooldownTable, lockTable, callback, message)
	task.spawn(function ()
		local userId = player.UserId

		if lockTable[userId] then
			warn(player.Name .. " is already processing " .. actionName)
			return
		end

		if not canRequest(player, cooldownTable) then
			ShowNotificationEvent:FireClient(player, Notifications.Spam)
			warn(player.Name .. " is spamming " .. actionName)
			return
		end

		lockTable[userId] = true

		local success, err = callback()

		lockTable[userId] = nil

		if not success then
			ShowErrorEvent:FireClient(player, GetFriendlyMessage(err))
			warn(("Error in %s: %s"):format(actionName, tostring(err)))
		else
			ShowNotificationEvent:FireClient(player, message)
		end
	end)
end

-- Just checking for requests for both the JoinServerEvent
JoinServerEvent.OnServerEvent:Connect(function(player, joinCode)
	handleRequest(player, "JoinServer", Cooldowns.Join, Locks.Join, function()
		return JoinServer(joinCode, player)
	end, Notifications.Teleporting)
end)

-- Just checking for requests for both the CreateServerEvent
CreateServerEvent.OnServerEvent:Connect(function(player, serverData)
	handleRequest(player, "CreateServer", Cooldowns.Create, Locks.Create, function()
		return CreateServer(player, serverData)
	end, Notifications.Creating)
end)

-- Making sure that I don't memory leak
Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId

	for _, actionTable in pairs(Cooldowns) do
		actionTable[userId] = nil
	end

	for _, lockTable in pairs(Locks) do
		lockTable[userId] = nil
	end

	ServerListCooldown[userId] = nil
end)

-- Giving back the servers data to be displayed for the player using remote function
-- So when the client needs the data I give it back immediately no need to make 2 events for this
-- Also having cooldown logic so exploiters don't abuse it to lag servers or break it
DisplayServerList.OnServerInvoke = function(player)
	local now = os.clock()

	if ServerListCooldown[player.UserId] and now - ServerListCooldown[player.UserId] < SERVERLIST_COOLDOWN then
		return {} -- ignore request
	end

	ServerListCooldown[player.UserId] = now

	local success, data = GetServerList(20)

	if not success or type(data) ~= "table" then
		warn(player.Name .. " failed to fetch server list")
		return {}
	end

	local servers = {}

	for _, item in ipairs(data) do
		if type(item) == "table" and type(item.value) == "table" then
			table.insert(servers, item.value)
		end
	end

	return servers
end
