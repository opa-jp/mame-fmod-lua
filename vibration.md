# `vibration.txt` Format

`vibration.txt` defines **XInput controller vibration patterns** that can be triggered from MAME Lua scripts.

It allows individual game sound-data numbers to trigger controller vibration with independent left and right motor strengths and durations.

This can be used to add rumble feedback to games that originally had no controller vibration support.

---

## File Structure

A typical `vibration.txt` contains two sections:

```text
[system]
motor 50

[code]
0x87 vibration 0xFFFF,0x0000,500
```

### `[system]`

The `[system]` section contains global vibration settings.

```text
[system]
motor 50
```

`motor` controls the overall vibration strength.

```text
motor 100
```

represents the maximum configured strength.

For example:

```text
motor 50
```

limits the overall vibration strength to approximately 50%.

This provides a convenient way to adjust the vibration strength globally without changing every individual vibration entry.

---

# `[code]` Section

The `[code]` section maps a game sound-data number to an XInput vibration pattern.

Format:

```text
#num    type    LeftMotorSpeed, RightMotorSpeed, StopMSec
```

For example:

```text
0x87    vibration    0xFFFF,0x0000,500
```

### Parameters

| Parameter         | Description                              |
| ----------------- | ---------------------------------------- |
| `#num`            | Sound-data number received from the game |
| `type`            | Vibration command type                   |
| `LeftMotorSpeed`  | Left XInput motor strength               |
| `RightMotorSpeed` | Right XInput motor strength              |
| `StopMSec`        | Vibration duration in milliseconds       |

---

# Motor Strength

The left and right motor values use a hexadecimal range:

```text
0x0000 – 0xFFFF
```

where:

```text
0x0000 = 0%
0xFFFF = 100%
```

For example:

```text
0xFFFF
```

is maximum motor strength.

```text
0x8000
```

is approximately half strength.

The two motors can be controlled independently.

### Left motor only

```text
0xFFFF,0x0000
```

### Right motor only

```text
0x0000,0xFFFF
```

### Both motors

```text
0xFFFF,0xFFFF
```

---

# Vibration Duration

The third parameter specifies how long the vibration lasts, in milliseconds.

For example:

```text
500
```

means approximately:

```text
500 ms = 0.5 seconds
```

Other examples:

```text
80     = 0.08 seconds
300    = 0.30 seconds
500    = 0.50 seconds
1000   = 1.00 second
```

---

# Space Harrier Example

The following configuration is an example for **Space Harrier**:

```text
[system]
motor 50

[code]
0x87    vibration    0xFFFF,0x0000,500
0x89    vibration    0xBFFF,0xFFFF,500
0xa0    vibration    0xDFFF,0xBFFF,80
0xa2    vibration    0xBFFF,0xBFFF,300
0xb6    vibration    0x0000,0xBFFF,300
0xd0    vibration    0x0000,0xDFFF,300
```

These entries associate specific game sound-data values with controller vibration effects.

### `0x87` — Taking a Hit

```text
0x87 vibration 0xFFFF,0x0000,500
```

Uses strong left-motor vibration for 500 ms.

### `0x89` — Falling Down

```text
0x89 vibration 0xBFFF,0xFFFF,500
```

Uses both motors, with a stronger right-motor component.

### `0xa0` — Explosion / Impact

```text
0xa0 vibration 0xDFFF,0xBFFF,80
```

A short vibration effect.

A small amount of interpolation was added because using only waveform-based vibration resulted in a weak initial attack.

### `0xa2`

```text
0xa2 vibration 0xBFFF,0xBFFF,300
```

Balanced vibration on both motors for 300 ms.

### `0xb6`

```text
0xb6 vibration 0x0000,0xBFFF,300
```

Right-motor vibration only.

### `0xd0`

```text
0xd0 vibration 0x0000,0xDFFF,300
```

A stronger right-motor vibration.

---

# Using Vibration with Sound Data

The vibration data can be linked to the same sound-data values used by `fmod2_samples.txt`.

For example, a game may send:

```text
0xa0
```

when an explosion occurs.

The FMOD sample configuration can replace the sound:

```text
0xa0 a0.wav 0,20,180
```

while `vibration.txt` can simultaneously trigger controller vibration:

```text
0xa0 vibration 0xDFFF,0xBFFF,80
```

This allows a single in-game event to produce both:

1. A custom FMOD sound
2. XInput controller vibration

---

# Lua Usage

Vibration definitions are loaded with:

```lua
xvib:load_vibration_file()
```

A predefined vibration pattern can then be played using:

```lua
xvib:xvibe_play(data)
```

For example:

```lua
xvib:xvibe_play(0xa0)
```

will look for the corresponding `0xa0` entry in `vibration.txt`.

---

# Direct Vibration Control

Lua can also control the motors directly without using `vibration.txt`.

```lua
xvib:rumble(id, left, right, time)
```

For example:

```lua
xvib:rumble(1, 1.0, 0.5, 300)
```

The values are normalized:

```text
1.0 = 100%
0.5 = 50%
0.0 = 0%
```

The configured global vibration compensation is applied.

For completely unmodified motor values, use:

```lua
xvib:rumble_raw(id, left, right, time)
```

---

# Creating Your Own Vibration Patterns

To create a vibration effect for another game:

1. Find the sound-data value associated with the desired game event.
2. Add the value to the `[code]` section.
3. Select the desired left and right motor strengths.
4. Set the vibration duration.
5. Test the effect in-game.
6. Adjust the values until the vibration feels appropriate.

For example:

```text
[code]

# Explosion
0xa0 vibration 0xFFFF,0xFFFF,150

# Player damage
0x87 vibration 0xFFFF,0x0000,400

# Enemy attack
0xb6 vibration 0x0000,0xC000,250
```

The comments are optional and can be used to document what each sound-data value represents.

---

## Notes

Vibration strength is affected by the global:

```text
motor
```

setting in `[system]`, as well as the vibration settings configured in the MAME plugin.

If the vibration feels too strong or too weak, adjust the global motor setting first before changing every individual entry.

This file is intended for game-specific vibration mapping and experimentation.

**Use at your own risk.**
