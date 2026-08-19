# mame-fmod-lua

FMOD audio extension and XInput vibration support for MAME via Lua on Windows.

This project was created as an experiment to make it possible to replace MAME's original sound effects with external **WAV, MP3, or OGG samples**, while also providing XInput rumble support that can be triggered from Lua.

## Features

- Play external FMOD samples from MAME Lua scripts
- Replace in-game sound effects using Lua
- samples list loaded from `fmod2_samples.txt`
- Supports WAV, MP3, and OGG sample files
- Per-channel volume control
- Loop, pause, fade-in, and fade-out support
- Multiple samples per channel
- XInput controller vibration support
- Vibration control from Lua
- Vibration patterns loaded from `vibration.txt`
- Configurable vibration gain, exponent, and threshold

> **Note:** This is an experimental project. Some games cannot be hooked correctly because `lua install_write_tap` does not always receive data from the required address. As a result, sound replacement may not be possible for every game.

FMOD control from Lua has been confirmed to work, so this project is being released as a starting point for further experimentation.

---

## Requirements

Before using the Lua scripts in this repository, you must download and install an FMOD-enabled build of MAME.

Please refer to [Installation.md](Installation.md) for details.

This project does not include copyrighted ROMs or other game assets.

---

# Example: Space Harrier

Sample files and a sample configuration for **Space Harrier** are included as an example.

### Enabling the plugin

1. Start MAME and open the game selection screen.
2. Open **General Settings** near the bottom center of the screen.
3. Open **Plugins**.
4. Enable **FMOD Sound Replace**.
5. Select **Save** and restart MAME.

Start Space Harrier and check whether the main BGM has been replaced by the FMOD sample.

If you are using an XInput controller with vibration support, explosions should also trigger controller vibration.

### Vibration settings

The vibration parameters can be configured from:

**TAB → Plugin Options → FMOD Sound Replace**

- **Vibration Gain**  
  Overall vibration strength compensation.  
  `0.5` = 50%

- **Vibration Expo (Exponent)**  
  Controls the response curve of waveform-based vibration.  
  Increasing this value makes weaker signals weaker, which can produce a more noticeable difference between weak and strong vibration.

- **Vibration Threshold**  
  Sets the lower limit for vibration output.

After changing vibration settings or sample data, the samples need to be reloaded.

Press **HOME** to reload the sample data.

---

# Creating Your Own Lua Sound Replacement Script

If you want to create your own FMOD sample replacement script, the basic idea is:

1. Detect a sound number written by the game.
2. Match that number against `fmod2_samples.txt`.
3. Play the corresponding external sample file.
4. Optionally trigger XInput vibration.

The template is:

```text
plugins/fmod/src/default.lua
```

Copy and rename this file to create a game-specific Lua script.

The script location follows the MAME source tree and ROM name.

For example, for **Hyper Sports Special / 88 Games**:

```text
fmod/src/konami/88games/hypsptsp.lua
```

or, if the parent ROM is used:

```text
fmod/src/konami/88games/88games.lua
```

---

# Finding the Correct Lua Script Location

MAME can be started with the `-console` option.

The console output will show which Lua script locations are being checked:

```text
--- CHECK FMOD USER SCRIPT ---
Trying ROM Name Source: fmod/src/konami/88games/hypsptsp.lua
Trying Parent Source: fmod/src/konami/88games/88games.lua
```

This makes it easier to determine where your Lua script should be placed.

---

# Finding the Sound Trigger Address

The sound replacement is normally triggered by monitoring an address used by the game to communicate with its sound CPU.

For example, looking at the official MAME source for `src/konami/88games.cpp`, you may find:

```cpp
void _88games_state::main_map(address_map &map)
```

and:

```cpp
map(0x5f8c, 0x5f8c).w("soundlatch", FUNC(generic_latch_8_device::write));
```

In this example, `0x5f8c` is the address used to send sound data.

The value written to this address can therefore be used as the trigger for sample replacement.

---

# Testing Sound Data

Starting from `default.lua`, copy it to create your game-specific Lua script.

For example:

```lua
-- set_write_handler(":maincpu", 0x140000, user.sound_replace)
```

Remove the first `--` to enable the line, then replace:

```text
0x140000
```

with the address you found in the MAME source:

```text
0x5f8c
```

Start MAME with `-console`.

When the game plays sounds, the values received from the sound address should appear in the console.

These values can then be used to create your `fmod2_samples.txt` entries and corresponding sample files.

Once the sample mapping is ready, enable:

```lua
if (fmod:play(data) == 1) then data = 0xff end
```

This will attempt to play the FMOD sample corresponding to the received sound number.

From there, the Lua script can be customized using the FMOD API below.

---

# Lua FMOD API

All FMOD functions are accessed through:

```lua
fmod:
```

For example:

```lua
fmod:play(1)
```

### Playback

```text
int play(u16 data)
```

Play the sample associated with `data`.

- `1` = success
- `0` = failed

```text
int is_playing(int channel)
```

Check whether a sample is currently playing on the specified channel.

- `1` = playing
- `0` = not playing

```text
void stop(int channel)
```

Stop playback on a channel.

```text
void stop_all(void)
```

Stop all FMOD playback.

```text
void loop(int channel, int loop)
```

Set the number of loops for the sample playing on the specified channel.

```text
void pause(int channel, bool state)
```

Pause or resume a channel.

- `true` = pause
- `false` = resume

---

## Volume and Channel Control

```text
void volume(int channel, float volume)
```

Set the channel volume.

```text
1.0 = 100%
0.5 = 50%
```

```text
void set_channel_samples(int channel, int poly)
```

Set the number of samples that can play simultaneously on a channel.

The default is one sound at a time.

Because volume control is applied to the channel, avoid playing samples requiring different volume levels on the same channel.

---

## Fade Control

```text
void fade_out(int channel, float time)
```

Fade out the specified channel.

`time` is in milliseconds.

```text
1000.0 = 1 second
```

```text
void fade_in(int channel, float time, float volume)
```

Fade in to the specified volume.

If `volume` is omitted, the default is:

```text
1.0 = 100%
```

---

# Sample File Management

```text
int load_sample_files(const char *tag, int samples_noload)
```

Load the sample definitions from `fmod2_samples.txt`.

```text
int is_samples(int data)
```

Check whether a sample associated with `data` can be loaded.

Return values:

```text
-1 = file could not be loaded
 0 = data number is not defined
 1 = file exists but is too large
 2 = sample is loaded into memory
 3 = possibly a DATA entry
```

```text
int get_channel(int data)
```

Return the channel assigned to the specified sample.

```text
float get_volume(int data)
```

Return the volume configured for the specified sample.

```text
1.0 = 100%
```

---

# FMOD Debug Logging

```text
void log(int level)
```

Display FMOD-side debug information.

---

# XInput Vibration API

XInput vibration functions are accessed through:

```lua
xvib:
```

### Load vibration definitions

```text
int load_vibration_file(void)
```

Load:

```text
vibration.txt
```

Return values:

```text
1 = success
0 = failed
```

### Basic vibration

```text
void rumble(u16 id, float left, float right, int time)
```

Trigger XInput vibration.

- `id` = vibration management ID
- `left` = left motor strength
- `right` = right motor strength
- `time` = duration in milliseconds
- `1.0` = 100%

The configured vibration compensation is applied.

### Raw vibration

```text
void rumble_raw(u16 id, float left, float right, int time)
```

Same as `rumble()`, but bypasses the configured vibration compensation.

### Play a predefined vibration

```text
int xvibe_play(u16 data)
```

Play the vibration pattern associated with `data` in:

```text
vibration.txt
```

---

# About This Project

This project is mainly intended for experimentation and for creating custom sound and vibration experiences in MAME.

The goal is to make it possible to experiment with things such as:

- Replacing original arcade sound effects
- Improving or customizing game audio
- Adding modern controller rumble to older arcade games
- Creating game-specific vibration effects
- Prototyping sound replacement systems with Lua
- Exploring MAME's memory/write handlers and sound communication

If you are interested in creating your own scripts, the official MAME source code is the best place to start when looking for the sound communication addresses used by individual games.

For Lua development, the `default.lua` template included in this repository should provide a simple starting point.

---

## Disclaimer

This project is provided **as-is and for experimental purposes**.

Use it at your own risk.

No copyrighted game ROMs are included. You are responsible for obtaining and using any required ROMs, samples, or other game data legally.

Have fun experimenting with MAME, FMOD, Lua, and XInput vibration!