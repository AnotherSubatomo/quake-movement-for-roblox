
-- Simple control bindings and pseudo-implementation of QW's usercmd_t
-- * Derived from @SnarlyZoo's (Roblox) bunny hopper.
-- Author: @AnotherSubatomo (GitHub)

--!native
--!strict

local ContextAction = game:GetService 'ContextActionService'
local KeyCode = Enum.KeyCode
local UserInputState = Enum.UserInputState

local cmd = {
	forwardMove = false;
	backMove = false;

	leftMove = false;
	rightMove = false;

	lastForward = false;
	lastLeft = false;

	jump = false;
	crouch = false;
	lockMouse = false;
	
	debug = true;
}

export type usercmd_t = typeof(cmd)
type UserInputState = Enum.UserInputState

local function OnForward(actionName: string, inputState: UserInputState)
	if inputState == UserInputState.Begin then
		cmd.forwardMove = true
		cmd.lastForward = true
	elseif inputState == UserInputState.End then
		cmd.forwardMove = false
	end
end

local function OnLeft(actionName: string, inputState: UserInputState)
	if inputState == UserInputState.Begin then
		cmd.leftMove = true
		cmd.lastLeft = true
	elseif inputState == UserInputState.End then
		cmd.leftMove = false
	end
end

local function OnBackward(actionName: string, inputState: UserInputState)
	if inputState == UserInputState.Begin then
		cmd.backMove = true
		cmd.lastForward = false
	elseif inputState == UserInputState.End then
		cmd.backMove = false
	end
end

local function OnRight(actionName: string, inputState: UserInputState)
	if inputState == UserInputState.Begin then
		cmd.rightMove = true
		cmd.lastLeft = false
	elseif inputState == UserInputState.End then
		cmd.rightMove = false
	end
end

local function OnJump(actionName: string, inputState: UserInputState)
	if inputState == UserInputState.Begin then
		cmd.jump = true
	elseif inputState == UserInputState.End then
		cmd.jump = false
	end
end

local function OnCrouch(actionName: string, inputState: UserInputState)
	if inputState == UserInputState.Begin then
		cmd.crouch = true
	elseif inputState == UserInputState.End then
		cmd.crouch = false
	end
end

local function OnDebug(actionName: string, inputState: UserInputState)
	if inputState ~= UserInputState.Begin then return end
	cmd.debug = not cmd.debug
end

local function OnLock(actionName: string, inputState: UserInputState)
	if inputState == UserInputState.Begin then
		cmd.lockMouse = true
	elseif inputState == UserInputState.End then
		cmd.lockMouse = false
	end
	-- return "pass" to allow camera to rotate
	return Enum.ContextActionResult.Pass
end

ContextAction:BindAction("Up", OnForward, false, KeyCode.W)
ContextAction:BindAction("Left", OnLeft, false, KeyCode.A)
ContextAction:BindAction("Down", OnBackward, false, KeyCode.S)
ContextAction:BindAction("Right", OnRight, false, KeyCode.D)
ContextAction:BindAction("Jump", OnJump, false, KeyCode.Space)
ContextAction:BindAction("Crouch", OnCrouch, false, KeyCode.LeftControl)
ContextAction:BindAction("LockMouse", OnLock, true, Enum.UserInputType.MouseButton2)
ContextAction:BindAction("Debug", OnDebug, false, KeyCode.Q)

return cmd