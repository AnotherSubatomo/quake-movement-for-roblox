
--[=[
	A modified yet faithful Luau rendition of IsaiahKelly's
	port of the Quake III strafe jumping mechanics.
	https://github.com/IsaiahKelly/quake3-movement-for-unity/
		
	* Modifications are made obvious with the tag '<modification>'
	
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
local m_Gravity: float = 100;
local m_JumpForce: float = 8;

local m_AutoBunnyHop: boolean = false;

local m_AirControl: float = 0.3;
local m_GroundSettings: MovementSettings = MovementSettings(21, 14, 10);
local m_AirSettings: MovementSettings = MovementSettings(30, 2, 2);
local m_StrafeSettings: MovementSettings = MovementSettings(1, 50, 50);

local m_Character: CharacterController;
local m_MoveDirectionNorm: Vector3 = Vector3.zero;
local m_PlayerVelocity: Vector3 = Vector3.zero;

-- Returns player's current speed.
local Speed = function() : (float) return m_Character.velocity.Magnitude; end

-- Used to queue the next jump just before hitting the ground.
local m_JumpQueued: boolean = false;

-- Used to display real time friction values.
local m_PlayerFriction = 0;

local m_MoveInput: Vector3;
local m_Tran: Transform;

-- Returns the current frametime.
local frameTime: float = 0;

-- * The following modification allows the program to
--   consistently keep track of Player properties (states)
--   and consistently apply changes.
-- <modification>
local player: Player = game.Players.LocalPlayer
-- The real player character model.
local r_Character: Character;
local playerDied = true;

local function _HumanoidDied() : ()
	player.CharacterAdded:Wait()
	playerDied = true
end

local function PlayerExists() : boolean
	return player.Character and true or false
end

local function SetupPlayerVariables() : ()
	r_Character = player.Character :: Character
	
	if playerDied then
		warn('Generating character!')
		r_Character.Humanoid.Died:Connect(_HumanoidDied)
		m_Character = CharacterController(r_Character)
		MouseLook.Init(r_Character)
		playerDied = false
	end
	
	m_Tran = r_Character:GetPivot()
	
	r_Character.Humanoid.JumpHeight = m_JumpForce
	r_Character.Humanoid.Jump = m_JumpQueued
	workspace.Gravity = m_Gravity -- TEMPFIX
end

local function UpdateMoveInput() : ()
	local sideMove: float, forwardMove: float;
	
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
	
	m_MoveInput = Vec3(sideMove, 0, forwardMove);
end
-- </modification>

-- Called to start the engine up.
-- * Function has been heavily modified from the original.
local function Start() : ()
	Run.PreRender:Connect(Update)
end

-- Function that gets ran every frame.
function Update(deltaTime: float) : ()
	-- * The following modifications allow us to ensure that the
	--   player's character (which relevant states are tied to) exists
	--   and the 'frameTime' and 'm_MoveInput' is up to date.
	if not PlayerExists() then return end
	SetupPlayerVariables();
	
	MouseLook.UpdateCursorLock(cmd.lockMouse);
	if (cmd.lockMouse) then MouseLook.Look() end
	
	frameTime = deltaTime;
	UpdateMoveInput();
	QueueJump();

	if (m_Character.isGrounded) then
		GroundMove();
	else
		AirMove();
	end
	
	-- * The following modification should keep the movement speed accurate to the original port.
	r_Character.Humanoid.WalkSpeed = m_PlayerFriction
	
	-- Move the character.
	-- * The frameTime multiplication doesn't matter here.
	m_Character:Move(m_PlayerVelocity --[[* frameTime]])
	
	-- <modification> Set-up update debugger and tell it to render results.
	Q3DebugMenu.Enabled = cmd.debug
	Q3DebugMenu.add("PlayerVelocity", m_PlayerVelocity)
	Q3DebugMenu.add("PlayerFriction", m_PlayerFriction)
	Q3DebugMenu.add("usercmd", cmd)
	Q3DebugMenu.add("JumpQueued", m_JumpQueued)
	Q3DebugMenu.add("IsGrounded", m_Character.isGrounded)
	Q3DebugMenu.add("MoveInput", m_MoveInput)
	Q3DebugMenu.add("MoveDirNorm", m_MoveDirectionNorm)
	Q3DebugMenu.render()
end

-- Queues the next jump.
function QueueJump() : ()
	if (m_AutoBunnyHop) then
		m_JumpQueued = cmd.jump;
		return
	end

	if (cmd.jump and not m_JumpQueued) then
		m_JumpQueued = true;
	end

	if (not cmd.jump) then
		m_JumpQueued = false;
	end
end

function AirMove() : ()
	local accel: float;

	local wishDir = Vec3(m_MoveInput.X, 0, m_MoveInput.Z);
	wishDir = TransformDirection(m_Tran, wishDir);

	local wishSpeed: float = wishDir.Magnitude;
	wishSpeed *= m_AirSettings.MaxSpeed;

	wishDir = Normalize(wishDir);
	m_MoveDirectionNorm = wishDir;

	-- CPM Air control.
	local wishSpeed2: float = wishSpeed;
	if (m_PlayerVelocity:Dot(wishDir) < 0) then
		accel = m_AirSettings.Deceleration;
	else
		accel = m_AirSettings.Acceleration;
	end

	-- If the player is ONLY strafing left or right
	if (m_MoveInput.Z == 0 and m_MoveInput.X ~= 0) then
		if (wishSpeed > m_StrafeSettings.MaxSpeed) then
			wishSpeed = m_StrafeSettings.MaxSpeed;
		end
		accel = m_StrafeSettings.Acceleration;
	end

	Accelerate(wishDir, wishSpeed, accel);
	if (m_AirControl > 0) then
		AirControl(wishDir, wishSpeed2);
	end

	-- Apply gravity
	m_PlayerVelocity = Vec3(
		m_PlayerVelocity.X,
		m_PlayerVelocity.Y - m_Gravity * frameTime,
		m_PlayerVelocity.Z
	)
end

-- Air control occurs when the player is in the air, it allows players to move side
-- to side much faster rather than being 'sluggish' when it comes to cornering.
function AirControl(targetDir: Vector3, targetSpeed: float) : ()
	-- Only control air movement when moving forward or backward.
	if (math.abs(m_MoveInput.Z) < 0.001 or math.abs(targetSpeed) < 0.001) then
		return;
	end
	
	local zSpeed: float = m_PlayerVelocity.Y;
	m_PlayerVelocity = Vec3(m_PlayerVelocity.X, 0, m_PlayerVelocity.Z);
	-- [[ Next two lines are equivalent to idTech's VectorNormalize() ]]
	local speed: float = m_PlayerVelocity.Magnitude;
	m_PlayerVelocity = Normalize(m_PlayerVelocity);
	
	local dot: float = m_PlayerVelocity:Dot(targetDir);
	local k: float = 32;
	k *= m_AirControl * dot * dot * frameTime;
	
	-- Change direction while slowing down.
	if (dot > 0) then
		m_PlayerVelocity = Vec3(
			m_PlayerVelocity.X * (speed + targetDir.X * k),
			m_PlayerVelocity.Y * (speed + targetDir.Y * k),
			m_PlayerVelocity.Z * (speed + targetDir.Z * k)
		)
		
		m_PlayerVelocity = Normalize(m_PlayerVelocity);
		m_MoveDirectionNorm = m_PlayerVelocity;
	end
	
	m_PlayerVelocity = Vec3(
		m_PlayerVelocity.X * speed,
		zSpeed, -- Note this line
		m_PlayerVelocity.Z * speed
	)
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
		m_Character:Jump(); --> a modification
		m_PlayerVelocity_Y = m_JumpForce;
		m_JumpQueued = false;
	end

	m_PlayerVelocity = Vec3(
		m_PlayerVelocity.X,
		m_PlayerVelocity_Y,
		m_PlayerVelocity.Z
	)
	
end

function ApplyFriction(t: number) : ()
	
	-- Equivalent to VectorCopy();
	local vec: Vector3 = Vec3(m_PlayerVelocity.X, 0, m_PlayerVelocity.Z);
	local speed: float = vec.Magnitude;
	local drop: float = 0;
	
	local control = 0;
	
	-- Only apply friction when grounded.
	if (m_Character.isGrounded) then
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

	local currentSpeed: float = m_PlayerVelocity:Dot(targetDir);
	local addSpeed: float = targetSpeed - currentSpeed;

	if (addSpeed <= 0) then return end

	local accelSpeed: float = accel * frameTime * targetSpeed;
	if (accelSpeed > addSpeed) then accelSpeed = addSpeed end
	
	m_PlayerVelocity = Vec3(
		m_PlayerVelocity.X + accelSpeed * targetDir.X,
		m_PlayerVelocity.Y,
		m_PlayerVelocity.Z + accelSpeed * targetDir.Z
	)
	
end

return Start