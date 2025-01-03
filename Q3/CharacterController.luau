
-- Barebones reimplementation of Unity's CharacterController object.
-- Author: @AnotherSubatomo (GitHub)

--!native
--!strict

local function CharacterInternal_Move(self: CharacterController, to: Vector3) : ()
	local model = self.__model :: Character
	--model:TranslateBy(to);
	model.Humanoid:Move(to, false);
end

local function CharacterInternal_Jump(self: CharacterController) : ()
	local model = self.__model :: Character
	model.Humanoid.Jump = true
end

local function CharacterController(m: Character) : CharacterController
	local obj = {
		isGrounded = true,
		Move = CharacterInternal_Move,
		Jump = CharacterInternal_Jump,
		velocity = Vector3.zero,
		__model = m,
		__connections = {}
	}
	
	--m.PrimaryPart.Anchored = true

	obj.__connections[1] = m.Humanoid:GetPropertyChangedSignal('FloorMaterial'):Connect( function ()
		obj.isGrounded = m.Humanoid.FloorMaterial ~= Enum.Material.Air
	end)

	obj.__connections[2] = m.PrimaryPart:GetPropertyChangedSignal('AssemblyLinearVelocity'):Connect( function()
		obj.velocity = m.PrimaryPart.AssemblyLinearVelocity
	end)

	return obj
end

export type Character = Model & {Humanoid: Humanoid, PrimaryPart: BasePart}
export type CharacterController = {
	isGrounded: boolean,
	Move: typeof(CharacterInternal_Move),
	Jump: typeof(CharacterInternal_Jump),
	velocity: Vector3,
	__model: Character,
	__connections: {RBXScriptConnection}
}

return CharacterController