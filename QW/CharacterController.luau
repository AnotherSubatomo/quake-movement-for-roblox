
-- Abstraction layer for setting the player character's position.
-- Author: @AnotherSubatomo (GitHub)

--!native
--!strict

local function CharacterInternal_Move(self: CharacterController, to: Vector3) : ()
	local model = self.__model :: Character
	model.PrimaryPart.Anchored = false
	model.Humanoid:Move(to, false);
end

local function CharacterInternal_Set(self: CharacterController, to: Vector3) : ()
	local model = self.__model :: Character
	model.PrimaryPart.Anchored = true
	model:TranslateBy(to);
end

local function CharacterInternal_Jump(self: CharacterController) : ()
	local model = self.__model :: Character
	model.Humanoid.Jump = true
end

local function CharacterController(character: Character) : CharacterController
	local obj = {
		Move = CharacterInternal_Move,
		Set = CharacterInternal_Set,
		Jump = CharacterInternal_Jump,
		__model = character
	}
	
	return obj
end

export type Character = Model & {Humanoid: Humanoid, PrimaryPart: BasePart}
export type CharacterController = {
	Move: typeof(CharacterInternal_Move),
	Set: typeof(CharacterInternal_Set),
	Jump: typeof(CharacterInternal_Jump),
	__model: Character
}

return CharacterController