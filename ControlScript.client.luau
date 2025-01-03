
--!native
--!strict

local Q3Engine = script:FindFirstChild('Q3MovementEngine') :: ModuleScript
local QWEngine = script:FindFirstChild('QWMovementEngine') :: ModuleScript

-- * Choose any of the movement engine to run
local MovementEngine = require(QWEngine) :: () -> ()

MovementEngine()