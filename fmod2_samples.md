# `fmod2_samples.txt` Format

`fmod2_samples.txt` defines the relationship between MAME sound data numbers and FMOD sample files.

It specifies which sample file should be played, its playback priority, FMOD channel, volume, loop settings, and playback position.

## Format

```text
#num file flag[8bit] priority channel volume loop_start loop_length start_position
```

The general format is:

```text
<data number> <sample file> <flag> <priority,channel,volume,loop_start,loop_length,start_position>
```

### Parameters

| Parameter        | Description                                  |
| ---------------- | -------------------------------------------- |
| `#num`           | Sound data number received from the game     |
| `file`           | Sample file to play (`wav`, `mp3`, or `ogg`) |
| `flag`           | Playback control flags                       |
| `priority`       | Sample priority, `0–255`                     |
| `channel`        | FMOD channel, `0–40`                         |
| `volume`         | Playback volume in percent                   |
| `loop_start`     | Loop start position in samples               |
| `loop_length`    | Loop length in samples                       |
| `start_position` | Playback start position in samples           |

---

## Flag

The flag field is an 8-bit value.

```text
bit 1:  loop
bit 10: stop
bit 20: fadeout
bit 40: false
bit 80: true
```

These flags can be combined when necessary.

For example:

```text
0x80
```

represents a normal active/data entry.

---

## Channel

The channel range is:

```text
0–40
```

Special channel ranges are reserved for converting samples into XInput vibration:

```text
10–19  samples → vibration (L motor)
20–29  samples → vibration (R motor)
30–39  samples → vibration (both motors)
```

This makes it possible to use a sound sample as the source waveform for controller vibration.

For example:

```text
channel 10–19
```

routes the sample waveform to the left XInput motor.

---

# Example: Space Harrier

The following configuration is an example for **Space Harrier**.

The main BGM has been replaced with an external music track.

```text
// Original BGM to be replaced
// Space Harrier - Stage 1 ｜ Epic Rock Cover
// https://www.youtube.com/watch?v=ickZdrnsG34

[default]
0x80 data    0x80

0xad 0xad.ogg    1,0,16,6522,9531915,6522
0xb0 0xad.ogg    1,0,16,6522,9531915,5298933
0xae 0xad.ogg    1,0,16,6522,9531915,1062075
0xaf 0xad.ogg    1,0,16,6522,9531915,3706604
0xb1 0xad.ogg    1,0,16,6522,9531915,7418402
```

Several different game sound-data values can therefore point to different positions in the same music file.

This is useful when the game changes the BGM or sound state by writing different sound numbers.

---

## Timing Samples

Some entries are used without an actual audible sample.

For example:

```text
0xa3 0xa3.ogg 1,0,80
0xa4 0xa4.ogg 1,0,80
0xa5 0xa5.ogg 1,0,80
0xa6 0xa6.ogg 1,0,80
```

In this example, the files are not necessarily intended to provide audible sound.

They can be used as **timing markers** to detect events such as the beginning of a boss battle and to control when the replaced BGM should stop.

> The corresponding audio files do not have to contain meaningful audio if they are only being used for timing purposes.

---

## Passing Through Original MAME Samples

A sound entry can also be passed through without replacing it with an external sample:

```text
0xd0 data 0x80
0xb5 data 0x80
0xb6 data 0x80
```

The `data` keyword indicates that the original sound data should continue to be handled rather than being replaced by an external FMOD sample.

This is useful when only selected sounds need to be replaced.

---

## Example: Sound Effect Replacement

An external WAV file can be assigned to a sound number:

```text
0xa0 0xa0.wav 0,20,70
```

This can be used to replace a specific sound effect.

Additional parameters can be used when necessary:

```text
0xa0 0xa0.wav 0,20,70 vp:60
```

For example, this entry can be used for an explosion/boom effect while also providing additional vibration-related configuration.

---

# BGM Looping

The BGM entries demonstrate how a single music file can be used with different playback positions.

For example:

```text
0xad 0xad.ogg 1,0,50,6522,9531915,6522
0xb0 0xad.ogg 1,0,50,6522,9531915,5298933
0xae 0xad.ogg 1,0,50,6522,9531915,1062075
```

The parameters define:

```text
loop_start
loop_length
start_position
```

This allows the same audio file to start at different positions depending on the sound data sent by the game.

This can be useful when recreating the behavior of an original arcade BGM system with an external music track.

---

# Sound Data Used for Investigation

Some entries are currently marked with comments such as:

```text
// ?
```

or:

```text
// enemy3 visible
```

These entries are useful during reverse engineering and testing.

The sound-data values are obtained by monitoring the address used by the game to communicate with its sound system and observing the values sent during gameplay.

Once the values are understood, they can be assigned to external samples or left as original MAME data.

---

# Example Configuration

A simplified configuration looks like this:

```text
[default]

# Keep original MAME data
0xb5 data 0x80

# Replace with external sample
0xa0 explosion.wav 0,20,100

# Play external BGM
0xad bgm.ogg 1,0,50,6522,9531915,6522

# Use a different starting position in the same BGM
0xb0 bgm.ogg 1,0,50,6522,9531915,5298933
```

The exact values depend on the game, sample format, and desired playback behavior.

---

## Sample File Location

The sample files referenced by `fmod2_samples.txt` must be placed in the appropriate FMOD sample directory used by the plugin.

For example:

```text
ad.ogg
a0.wav
a3.ogg
```

The filename in `fmod2_samples.txt` must match the actual sample file.

Supported formats:

```text
WAV
MP3
OGG
```

---

## Notes

This file is intentionally flexible because different arcade games use very different sound systems.

You may need to determine:

* Which address is used for sound communication
* Which values correspond to individual sounds
* Which values represent BGM changes
* Which sounds should remain handled by MAME
* Appropriate FMOD channels
* Loop start and loop length
* Playback start positions
* Sample priorities and volume levels

For game-specific Lua scripts, see the corresponding files under:

```text
plugins/fmod/src/
```

This configuration format is intended primarily for experimentation and custom sound replacement.

**Use at your own risk.**
