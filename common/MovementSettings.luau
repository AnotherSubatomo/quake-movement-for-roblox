
-- Simple struct for storing movement settings.
-- Author: @AnotherSubatomo (GitHub)

--!native
--!strict

function MovementSettings(maxSpeed: float, accel: float, decel: float) : MovementSettings
	return {
		MaxSpeed = maxSpeed;
		Acceleration = accel;
		Deceleration = decel;
	}
end

type float = number
export type MovementSettings = typeof(MovementSettings(1, 1, 1))

return MovementSettings