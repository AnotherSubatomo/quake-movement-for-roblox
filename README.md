# Quake Movement For Roblox
A port of Quake's movement mechanics to Roblox.

![Last Commit](https://img.shields.io/github/last-commit/AnotherSubatomo/quake-movement-for-roblox/main
) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

There are two versions of the port, [one](/QW/) based on QuakeWorld, and [one](/Q3/) based on [@IsaiahKelly](https://www.github.com/IsaiahKelly)'s port of Quake III.

### Notes
- Movement gravity has not been *properly* implemented.

- `m_PlayerFriction` is actually the player's speed during a time frame.

- The debug menu can be toggled with the `Q` key.

- Default script values have been changed in a way to emulate what (I personally) deemed to be the "intended behavior". Feel free to change the configurations.

- While the ports try to stay faithful to the original, some modifications (in my perspective) just had to be done to work with the Roblox environment.

- Because of the previous two notes, deviations in expected behavior are very much possible.

- Quake uses a Z-up coordinate system while Roblox uses a Y-up coordinate system, keep that in mind if you plan on making your own ports. (Both are right-handed though)

- If you plan on contributing or understanding how this works, please take a look at [`default.project.json`](default.project.json) first and understand the file hirarchy. (But in summary, the files at [`common`](/common/) are files that can be found at both versions of the port.)

---

## Getting Started
To build the place from scratch, use:

```bash
rojo build -o "quake-movement-for-roblox.rbxlx"
```

Next, open `quake-movement-for-roblox.rbxlx` in Roblox Studio and start the Rojo server:

```bash
rojo serve
```

For more help, check out [the Rojo documentation](https://rojo.space/docs).