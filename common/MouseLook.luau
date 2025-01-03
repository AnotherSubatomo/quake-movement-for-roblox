
-- Roblox rendition of IsaiahKelly's MouseLook.
-- Author: @AnotherSubatomo (GitHub)

-- * Functions that are meant to be ran per frame are labeled with [PERFRAME].

--!native
--!strict

local UserInput = game:GetService 'UserInputService'
local MouseBehavior = Enum.MouseBehavior
type Character = Model & {Humanoid: Humanoid, PrimaryPart: BasePart}

local g_CameraOffset = Vector3.new(1.75, 0, 0);

local MouseLook = {}
MouseLook.Camera = workspace.CurrentCamera :: Camera;
MouseLook.Character = nil :: Character;

-- * [PERFRAME] Used to update the lock-ness of the cursor.
function MouseLook.UpdateCursorLock(should: boolean) : ()
	local behavior = should and MouseBehavior.LockCenter or MouseBehavior.Default;
	if UserInput.MouseBehavior == behavior then return end
	UserInput.MouseBehavior = behavior;
end

-- * [PERFRAME] Used to update and sync the character rotation to the camera.
function MouseLook.Look() : ()
	if not MouseLook.Character then return end
	
	local root = MouseLook.Character.PrimaryPart;
	local _, y = MouseLook.Camera.CFrame.Rotation:ToEulerAnglesYXZ();
	local rotation = CFrame.new(root.Position) * CFrame.Angles(0, y, 0);

	root.CFrame = rotation;
end

-- * Function should be ran everytime the player character is changed.
function MouseLook.Init(char: Character) : ()
	char.Humanoid.CameraOffset = g_CameraOffset;
	char.Humanoid.AutoRotate = false;
	MouseLook.Character = char;
	MouseLook.Camera = workspace.CurrentCamera;
end

return MouseLook