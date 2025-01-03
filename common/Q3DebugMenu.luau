
-- Simple pseudo-IMGUI debug menu renderer.
-- Author: @AnotherSubatomo (GitHub)

--!native
--!strict

type valid = string | number | boolean | Vector3
type value = valid | {[string]: valid}

local Player = game.Players.LocalPlayer
local New = Instance.new
local Hex = Color3.fromHex
local Rechild = function(Parent: Instance, Children: {Instance})
	for _, Child: Instance in Children do Child.Parent = Parent end
end

local PADDING_SIZE = UDim.new(0, 10)

local UI = New 'ScreenGui' do
	UI.ResetOnSpawn = false
	UI.Parent = Player.PlayerGui
end

local Menu = New 'TextLabel' do
	Menu.Size = UDim2.fromOffset(120, 180)
	Menu.Position = UDim2.fromOffset(10, 10)
	Menu.AutomaticSize = "XY"
	Menu.TextXAlignment = "Left"
	Menu.TextYAlignment = "Top"
	Menu.BorderSizePixel = 0
	Menu.BackgroundTransparency = 1
	--Menu.BackgroundColor3 = Hex '2b2b2b'
	Menu.TextColor3 = Hex 'fa8e00' -- Hex 'fff7f0'
	Menu.FontFace = Font.fromName(
		Enum.Font.RobotoMono.Name,
		Enum.FontWeight.Regular,
		Enum.FontStyle.Normal
	)
	Menu.TextSize = 12
	Menu.Parent = UI
	
	local Padding = New 'UIPadding' do
		Padding.PaddingTop = PADDING_SIZE
		Padding.PaddingBottom = PADDING_SIZE
		Padding.PaddingRight = PADDING_SIZE
		Padding.PaddingLeft = PADDING_SIZE
		Padding.Parent = Menu
	end
end

local Q3DebugMenu = {}
Q3DebugMenu.Enabled = false
-- This is where we'll pile up fields until .render()
-- get's called, where it's contents are flushed.
local FieldBucket = {}
local RenderContent = ""

function Q3DebugMenu.add(name: string, value: value) : ()
	if not Q3DebugMenu.Enabled then return end
	FieldBucket[name] = value
end

function Q3DebugMenu.render() : ()
	if not Q3DebugMenu.Enabled then
		UI.Enabled = false
		return
	end
	
	for name: string, value: value in FieldBucket do
		render_field(name, value, 0)
	end
	
	Menu.Text = RenderContent
	UI.Enabled = true
	
	table.clear(FieldBucket)
	RenderContent = ""
end

local function tabs(n: number) : string return string.rep('\t', n) end

function render_field(name: string, value: value, level: number) : ()
	level = level or 0
	if typeof(value) == "table" then
		RenderContent ..= `\n{tabs(level)}{name}:`
		for metaname: string, metavalue: value in value do
			render_field(metaname, metavalue, level+1)
		end
		return
	else
		RenderContent ..= `\n{tabs(level)}{name}: {tostring(value)}`
	end
end

return Q3DebugMenu