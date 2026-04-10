-- This is the main gui script

local CreateB = script.Parent.CreateServerB
local ListB = script.Parent.ServerListB

local ScaleFactor = 1.07
local OriginalSize = CreateB.Size

-- Frames
local Create = script.Parent.Parent.CreateServer
local ServerList = script.Parent.Parent.ServerList

-- Close buttons
local closeCreate = Create.Close
local closeServerList = ServerList.Close

-- Tweens
local TweenService = game:GetService("TweenService")
local BlurTweenInfo = TweenInfo.new(.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false)
local BlurTweenIn = TweenService:Create(game.Lighting.MenuBlur, BlurTweenInfo, { Size = 30 })
local BlurTweenOut = TweenService:Create(game.Lighting.MenuBlur, BlurTweenInfo, { Size = 0 })

-- Change menus for server list
local codeButton = ServerList.JoinByCode_Button
local CodeFrame = ServerList.JoinByCode
local serverlist = ServerList.ServerList_Button
local ServerListFrame = ServerList.ServerList

-- Reset buttons
local function resetButtons()
	codeButton.UIStroke.Enabled = false
	codeButton.Selected_UIGradient.Enabled = false
	serverlist.UIStroke.Enabled = false
	serverlist.Selected_UIGradient.Enabled = false
end

-- Join by Code Button
codeButton.Activated:Connect(function()
	CodeFrame.Visible = true
	ServerListFrame.Visible = false
	game.ReplicatedStorage.SFX.ButtonPressed:Play()

	resetButtons()
	codeButton.UIStroke.Enabled = true
	codeButton.Selected_UIGradient.Enabled = true
end)

codeButton.MouseEnter:Connect(function()
	game.ReplicatedStorage.SFX.ButtonHover:Play()
	codeButton.UIStroke.Enabled = true
	codeButton.Selected_UIGradient.Enabled = true
end)

codeButton.MouseLeave:Connect(function()
	if not CodeFrame.Visible then
		codeButton.UIStroke.Enabled = false
		codeButton.Selected_UIGradient.Enabled = false
	end
end)

-- Server List Button
serverlist.Activated:Connect(function()
	CodeFrame.Visible = false
	ServerListFrame.Visible = true
	game.ReplicatedStorage.SFX.ButtonPressed:Play()

	resetButtons()
	serverlist.UIStroke.Enabled = true
	serverlist.Selected_UIGradient.Enabled = true
end)

serverlist.MouseEnter:Connect(function()
	game.ReplicatedStorage.SFX.ButtonHover:Play()
	serverlist.UIStroke.Enabled = true
	serverlist.Selected_UIGradient.Enabled = true
end)

serverlist.MouseLeave:Connect(function()
	if not ServerListFrame.Visible then
		serverlist.UIStroke.Enabled = false
		serverlist.Selected_UIGradient.Enabled = false
	end
end)

-- Button Functions

function ClickList()
	if not Create.Visible then
		BlurTweenIn:Play()
		task.wait(0.3)
	end

	ServerList.Visible = true
	Create.Visible = false
	game.ReplicatedStorage.SFX.ButtonPressed:Play()
end

ListB.Activated:Connect(ClickList)

function ClickCreateServer()
	if not ServerList.Visible then
		BlurTweenIn:Play()
		task.wait(0.3)
	end

	ServerList.Visible = false
	Create.Visible = true
	game.ReplicatedStorage.SFX.ButtonPressed:Play()
end

CreateB.Activated:Connect(ClickCreateServer)

-- Close buttons
closeCreate.Activated:Connect(function()
	BlurTweenOut:Play()
	task.wait(0.15)
end)

closeServerList.Activated:Connect(function()
	BlurTweenOut:Play()
	task.wait(0.15)
end)

-- Animations
function ButtonColorHover(button)
	local ts = game:GetService("TweenService")
	local tweenInfo = TweenInfo.new(.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	ts:Create(button, tweenInfo, {BackgroundColor3 = Color3.fromRGB(61, 62, 124)}):Play()
end

function ButtonColorNoHover(button)
	local ts = game:GetService("TweenService")
	local tweenInfo = TweenInfo.new(.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	ts:Create(button, tweenInfo, {BackgroundColor3 = Color3.fromRGB(111, 111, 111)}):Play()
end
