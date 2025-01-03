
--[=[
	A modified yet faithful Luau port of QuakeWorld's movement mechanics.
	* Codebase largely based on:
		- idSoftware's QuakeWorld client source (https://github.com/id-Software/Quake/tree/master/QW/client/pmove.c)
		- IsaiahKelly's port of Quake III (https://github.com/IsaiahKelly/quake3-movement-for-unity/)
	
	* Modifications are made obvious with the tag '<modification>'
	* Doesn't include AirControl() from IsiahKelly's port.
	
	Author: @AnotherSubatomo (GitHub)
	License: MIT
]=]

--[=[
	TODO:
	* Properly handle custom movement gravity
]=]

--!native
--!strict

local Run = game:GetService('RunService')
local Vec3 = Vector3.new
local btest = bit32.btest

local TransformDirection = function(tran: CFrame, v: Vector3) : Vector3
	local v2 = tran:VectorToWorldSpace(v);
	return Vec3(v2.X, 0, v2.Z);
end

local Normalize = function(v: Vector3) : Vector3
	if v ~= Vector3.zero then v = v.Unit end return v
end

local cmd = require(script.Q3Command)
local Q3DebugMenu = require(script.Q3DebugMenu)
local MouseLook = require(script.MouseLook)
local CharacterController = require(script.CharacterController)
local MovementSettings = require(script.MovementSettings)

type float = number
type Transform = CFrame
type Character = CharacterController.Character
type CharacterController = CharacterController.CharacterController
type MovementSettings = MovementSettings.MovementSettings

local m_Friction: float = 6;
local m_WaterFriction: float = 1;
local m_Gravity: float = 100;
local m_JumpForce: float = 8;

local m_AutoBunnyHop: boolean = false;

local m_GroundSettings: MovementSettings = MovementSettings(21, 14, 10);
local m_AirSettings: MovementSettings = MovementSettings(30, 2, 2);
local m_StrafeSettings: MovementSettings = MovementSettings(1, 50, 50);
local m_SpectatorSettings: MovementSettings = MovementSettings(500, 10, 10);
local m_WaterSettings: MovementSettings = MovementSettings(21, 10, 10);

local m_Controller: CharacterController;
local m_MoveDirectionNorm: Vector3 = Vector3.zero; --> for debug
local m_PlayerVelocity: Vector3 = Vector3.zero;

-- Used to queue the next jump just before hitting the ground.
local m_JumpQueued: boolean = false;
local m_IsGrounded: boolean = false;
local m_InWater: boolean = false;
local m_Spectator: boolean = false;
local m_Dead: boolean = true;

-- Used to display real time friction values.
-- * The "friction" is actually the player's speed in that moment.
local m_PlayerFriction = 0;

-- Also known as the "move direction".
local m_MoveInput: Vector3;
local m_Tran: Transform;

-- Returns the current frametime.
local frameTime: float = 0;

-- * The following modification allows the program to
--   consistently keep track of Player properties (states)
--   and consistently apply changes.
-- <modification>
local player: Player = game.Players.LocalPlayer;
-- The real player character model.
local r_Character: Character;
local newCharacterLoaded = true;

local function _HumanoidDied() : ()
	m_Dead = true
	player.CharacterAdded:Wait()
	newCharacterLoaded = true
end

local function PlayerExists() : boolean
	return player.Character and true or false
end

local function SetupPlayerVariables() : ()
	r_Character = player.Character :: Character
	
	if newCharacterLoaded then
		warn('Generating character!')
		r_Character.Humanoid.Died:Connect(_HumanoidDied)
		m_Controller = CharacterController(r_Character)
		MouseLook.Init(r_Character)
		
		newCharacterLoaded = false
		m_Dead = false
	end
	
	m_Tran = r_Character:GetPivot()
	
	r_Character.Humanoid.JumpHeight = m_JumpForce
	r_Character.Humanoid.Jump = m_JumpQueued
	workspace.Gravity = m_Gravity -- TEMPFIX
end

local function UpdateMoveInput() : ()
	local sideMove: float, forwardMove: float;
	local upMove: float = 0;
	
	if (m_Spectator or m_InWater) then
		upMove = cmd.jump and 1 or cmd.crouch and -1 or 0;
	end
	
	if (cmd.leftMove and cmd.rightMove) then
		if (cmd.lastLeft) then sideMove = -1 else sideMove = 1 end
	else
		if (cmd.leftMove) then sideMove = -1 elseif cmd.rightMove then sideMove = 1 else sideMove = 0 end
	end

	if (cmd.forwardMove and cmd.backMove) then
		if (cmd.lastForward) then forwardMove = -1 else forwardMove = 1 end
	else
		if (cmd.forwardMove) then forwardMove = -1 elseif cmd.backMove then forwardMove = 1 else forwardMove = 0 end
	end
	
	m_MoveInput = Vec3(sideMove, upMove, forwardMove);
end

local function IsUnderwater() : boolean
	local head = r_Character.PrimaryPart
	local min = head.Position - (head.Size/2)
	local max = head.Position + (head.Size/2)
	local region = Region3.new(min,max):ExpandToGrid(4)
	return workspace.Terrain:ReadVoxels(region, 4)[1][1][1] == Enum.Material.Water;
end
-- </modification>

-- Called to start the engine up.
-- * Function has been heavily modified from the original.
local function Start() : ()
	Run.PreRender:Connect(Update)
end

-- Function that gets ran every frame.
function Update(deltaTime: float) : ()
	if not PlayerExists() then return end
	SetupPlayerVariables();
	
	MouseLook.UpdateCursorLock(cmd.lockMouse);
	if (cmd.lockMouse) then MouseLook.Look() end
	
	frameTime = deltaTime;
	PlayerMove();
	
	-- <modification> Set-up update debugger and tell it to render results.
	Q3DebugMenu.Enabled = cmd.debug
	Q3DebugMenu.add("PlayerVelocity", m_PlayerVelocity)
	Q3DebugMenu.add("PlayerFriction", m_PlayerFriction)
	Q3DebugMenu.add("usercmd", cmd)
	Q3DebugMenu.add("JumpQueued", m_JumpQueued)
	Q3DebugMenu.add("IsGrounded", m_IsGrounded)
	Q3DebugMenu.add("InWater", m_InWater)
	Q3DebugMenu.add("IsSpectating", m_Spectator)
	Q3DebugMenu.add("IsDead", m_Dead)
	Q3DebugMenu.add("MoveInput", m_MoveInput)
	Q3DebugMenu.add("MoveDirNorm", m_MoveDirectionNorm)
	--Q3DebugMenu.add("RealVelocity", m_PlayerVelocity * frameTime) -- The velocity per frame
	Q3DebugMenu.render()
end

-- Responsible for managing how the player's movement will go.
function PlayerMove() : ()
	UpdateMoveInput();
	QueueJump();
	
	if (m_Spectator) then
		SpectatorMove();
		return;
	end
	
	-- set isGrounded, and inWater
	CategorizePosition();

	if (m_IsGrounded) then
		GroundMove();
	elseif (m_InWater) then
		WaterMove();
	else
		AirMove();
	end
	
	-- * This should keep the movement speed accurate to the original port.
	r_Character.Humanoid.WalkSpeed = m_PlayerFriction;
	
	-- Move the character.
	-- * The frameTime multiplication doesn't matter here.
	m_Controller:Move(m_PlayerVelocity --[[* frameTime]]);
end

function CategorizePosition() : ()
	m_IsGrounded = r_Character.Humanoid.FloorMaterial ~= Enum.Material.Air;
	m_InWater = IsUnderwater();
end

-- Queues the next jump.
function QueueJump() : ()
	if (m_Dead) then
		m_JumpQueued = false;
		return;
	end
	
	if (not m_IsGrounded) then return end
	
	if (m_AutoBunnyHop) then
		m_JumpQueued = cmd.jump;
		return;
	end

	if (cmd.jump and not m_JumpQueued) then
		m_JumpQueued = true;
	end

	if (not cmd.jump) then
		m_JumpQueued = false;
	end
end

function SpectatorMove() : ()
	
	-- friction
	local speed: float = m_PlayerVelocity.Magnitude;
	if (speed < 1) then
		m_PlayerVelocity = Vector3.zero;
	else
		local drop: float = 0;
		
		local friction: float = m_Friction * 1.5; -- extra friction
		local control: float = speed < m_GroundSettings.Deceleration and m_GroundSettings.Deceleration or speed;
		drop += control * friction * frameTime;
		
		-- scale the velocity
		local newSpeed: float = speed - drop;
		if (newSpeed < 0) then newSpeed = 0 end
		newSpeed /= speed;

		m_PlayerVelocity *= newSpeed; --> equivalent to VectorScale()
	end
	
	-- move
	local wishDir = Vec3(m_MoveInput.X, 0, m_MoveInput.Z);
	wishDir = TransformDirection(m_Tran, wishDir);
	wishDir = Normalize(wishDir);
	wishDir = Vec3(wishDir.X, m_MoveInput.Y, wishDir.Z); -- keep upmove
	m_MoveDirectionNorm = wishDir;

	local wishSpeed = wishDir.Magnitude;
	wishSpeed *= m_GroundSettings.MaxSpeed;
	
	if (wishSpeed > m_SpectatorSettings.MaxSpeed) then
		wishDir *= m_SpectatorSettings.MaxSpeed/wishSpeed; --> equivalent to VectorScale()
		wishSpeed = m_SpectatorSettings.MaxSpeed;
	end
	
	Accelerate(wishDir, wishSpeed, m_SpectatorSettings.Acceleration);
	
	m_Controller:Set(m_PlayerVelocity * frameTime);
	
end

function AirMove() : ()

	local wishDir = Vec3(m_MoveInput.X, 0, m_MoveInput.Z);
	wishDir = TransformDirection(m_Tran, wishDir);

	local wishSpeed: float = wishDir.Magnitude;
	wishSpeed *= m_AirSettings.MaxSpeed;

	wishDir = Normalize(wishDir);
	m_MoveDirectionNorm = wishDir;
	
	if (wishSpeed > m_StrafeSettings.MaxSpeed) then
		wishDir *= m_StrafeSettings.MaxSpeed/wishSpeed; --> equivalent to VectorScale()
		wishSpeed = m_StrafeSettings.MaxSpeed;
	end
	
	AirAccelerate(wishDir, wishSpeed, m_StrafeSettings.Acceleration);
end

-- Handle ground movement.
function GroundMove() : ()
	
	-- Do not apply friction if the player is queueing up the next jump
	if (not m_JumpQueued) then
		ApplyFriction(1.0);
	else
		ApplyFriction(0);
	end

	local wishDir = Vec3(m_MoveInput.X, 0, m_MoveInput.Z);
	wishDir = TransformDirection(m_Tran, wishDir);
	wishDir = Normalize(wishDir);
	m_MoveDirectionNorm = wishDir;

	local wishSpeed = wishDir.Magnitude;
	wishSpeed *= m_GroundSettings.MaxSpeed;

	Accelerate(wishDir, wishSpeed, m_GroundSettings.Acceleration);

	-- Reset the gravity velocity
	local m_PlayerVelocity_Y = -m_Gravity * frameTime;

	if (m_JumpQueued) then
		m_Controller:Jump(); --> a modification
		m_PlayerVelocity_Y = m_JumpForce;
		m_JumpQueued = false;
	end

	m_PlayerVelocity = Vec3(
		m_PlayerVelocity.X,
		m_PlayerVelocity_Y,
		m_PlayerVelocity.Z
	)
	
end

function WaterMove() : ()
	
	local wishDir = Vec3(m_MoveInput.X, 0, m_MoveInput.Z);
	wishDir = TransformDirection(m_Tran, wishDir);
	wishDir = Vec3(wishDir.X, m_MoveInput.Y, wishDir.Z); -- keep upmove
	
	if btest(m_MoveInput.Y) then
		wishDir += Vector3.yAxis * m_WaterSettings.MaxSpeed * m_MoveInput.Y;
	elseif (not btest(m_MoveInput.Z) and not btest(m_MoveInput.X)) then
		wishDir -= Vector3.yAxis * 60; -- drift towards bottom
	else
		wishDir += Vector3.yAxis * m_MoveInput.Y;
	end

	-- next 2 lines are equivalent to VectorNormalize();
	local wishSpeed = wishDir.Magnitude;
	wishDir = Normalize(wishDir);
	m_MoveDirectionNorm = wishDir;
	
	if (wishSpeed > m_WaterSettings.MaxSpeed) then
		wishDir *= m_WaterSettings.MaxSpeed/wishSpeed; --> equivalent to VectorScale()
		wishSpeed = m_WaterSettings.MaxSpeed;
	end
	
	wishSpeed *= 0.7;
	
	-- water acceleration
	Accelerate(wishDir, wishSpeed, m_WaterSettings.Acceleration);
	
	-- Source engine code, commented out as it strayed from Q3.
	--[[local newSpeed: float, addSpeed: float, accelSpeed: float;
	
	-- Water friction
	local speed: float = m_PlayerVelocity.Magnitude;
	if (speed) then
		newSpeed = speed - frameTime * speed * m_WaterFriction * m_PlayerFriction;
		if (newSpeed < 0.1) then newSpeed = 0 end
		m_PlayerVelocity *= newSpeed/speed --> equivalent to VectorScale()
	else
		newSpeed = 0;
	end
	
	-- water acceleration
	if (wishSpeed >- 0.1) then -- old !
		addSpeed = wishSpeed - newSpeed;
		if (addSpeed > 0) then
			wishDir = Normalize(wishDir);
			accelSpeed = m_WaterSettings.Acceleration * wishSpeed * frameTime * m_PlayerFriction;
			if (accelSpeed > addSpeed) then accelSpeed = addSpeed end
			
			m_PlayerVelocity += accelSpeed * wishDir;
		end
	end]]
	
end

function ApplyFriction(t: number) : ()
	
	-- Equivalent to VectorCopy();
	local vec: Vector3 = Vec3(m_PlayerVelocity.X, 0, m_PlayerVelocity.Z);
	local speed: float = vec.Magnitude;
	local drop: float = 0;
	
	local control = 0;
	
	-- Only apply friction when grounded.
	if (m_IsGrounded) then
		local control: float = speed < m_GroundSettings.Deceleration and m_GroundSettings.Deceleration or speed;
		drop = control * m_Friction * frameTime * t;
	end

	local newSpeed: float = speed - drop;
	m_PlayerFriction = newSpeed;
	
	if (newSpeed < 0) then newSpeed = 0 end
	if (speed > 0) then newSpeed /= speed end

	m_PlayerVelocity = Vec3(
		m_PlayerVelocity.X * newSpeed,
		m_PlayerVelocity.Y,
		m_PlayerVelocity.Z * newSpeed
	)
	
end

-- Calculates acceleration based on desired speed and direction.
function Accelerate(targetDir: Vector3, targetSpeed: number, accel: number) : ()
	
	if (not CanAccelerate) then return end
	local currentSpeed: float = m_PlayerVelocity:Dot(targetDir);
	local addSpeed: float = targetSpeed - currentSpeed;

	if (addSpeed <= 0) then return end

	local accelSpeed: float = accel * frameTime * targetSpeed;
	if (accelSpeed > addSpeed) then accelSpeed = addSpeed end
	
	m_PlayerVelocity += accelSpeed * targetDir;
	
end


-- Calculates acceleration based on desired speed and direction with respect to the air settings.
function AirAccelerate(targetDir: Vector3, originalTargetSpeed: number, accel: number) : ()

	if (not CanAccelerate) then return end
	local targetSpeed: float = originalTargetSpeed;

	if (targetSpeed > m_AirSettings.MaxSpeed) then targetSpeed = m_AirSettings.MaxSpeed end

	local currentSpeed: float = m_PlayerVelocity:Dot(targetDir);
	local addSpeed: float = targetSpeed - currentSpeed;

	if (addSpeed <= 0) then return end

	local accelSpeed: float = accel * originalTargetSpeed * frameTime;
	if (accelSpeed > addSpeed) then accelSpeed = addSpeed end

	m_PlayerVelocity += accelSpeed * targetDir;

end

-- * Based on Source engine's gamemovement.cpp
function CanAccelerate() : boolean
	if (m_Dead) then return false end
	return true
end

return Start