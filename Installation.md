# Installation

Because the FMOD-enabled MAME executable and related binaries are too large to distribute through GitHub, the required executable files are hosted separately.

You will need to download and install the FMOD-enabled MAME build before using the Lua scripts in this repository.

## 1. Download Official MAME 0.287

First, download the official **MAME 0.287 Windows 64-bit** package.

Official MAME download:

https://github.com/mamedev/mame/releases/download/mame0287/mame0287b_x64.exe

Run the official MAME installer and extract the files to a folder of your choice.

For example:

```text
C:\MAME\
```

---

## 2. Install the FMOD-enabled MAME Files

Download the FMOD-enabled MAME files from the following cloud storage:

https://mega.nz/folder/vBVCXD6T#Az-hF_kmc7Bc8JaE4R33dg

The archive contains:

```text
mame.exe
fmod.dll
```

Extract these files into the folder where you installed the official MAME 0.287 package.

If Windows asks whether you want to replace the existing `mame.exe`, allow it.

After installation, the folder should contain the FMOD-enabled MAME executable along with the normal MAME files and directories.

For example:

```text
C:\MAME\
 ├─ mame.exe          ← FMOD-enabled version
 ├─ fmod.dll
 ├─ artwork\
 ├─ bgfx\
 ├─ cfg\
 ├─ ini\
 ├─ plugins\
 ├─ roms\
 └─ ...
```

> **Important:** The `mame.exe` included in the cloud archive is a custom build with FMOD support. The standard MAME executable from the official package does not include this FMOD functionality.

---

## 3. Download the Lua Scripts

Download the latest Lua scripts and source files from this GitHub repository:

https://github.com/opa-jp/mame-fmod-lua

Place the downloaded files directly into the **same MAME directory** used in the previous steps.

The repository contains the Lua scripts and configuration files required for FMOD sample replacement and XInput vibration.

---

## 4. Final Directory Structure

After completing the installation, your MAME directory should look similar to this:

```text
MAME/
├─ mame.exe
├─ fmod.dll
├─ plugins/
│  └─ fmod/
│     ├─ src/
│     ├─ ...
│     └─ ...
├─ roms/
├─ cfg/
├─ ini/
└─ ...
```

The exact directory contents may vary depending on your MAME installation.

---

## 5. Enable the Plugin

Start the FMOD-enabled MAME executable.

From the game selection screen:

1. Open **General Settings**.
2. Open **Plugins**.
3. Enable **FMOD Sound Replace**.
4. Select **Save**.
5. Restart MAME.

Once MAME has restarted, launch a supported game and verify that the FMOD sample replacement is working.

For the included Space Harrier example, the main BGM should be replaced by the supplied FMOD sample.

If you are using an XInput-compatible controller with vibration support, supported sound effects can also trigger controller vibration.

---

## Updating the Lua Scripts

When a new version of the Lua scripts is released, you normally only need to download the latest files from GitHub and replace the existing Lua/configuration files.

The FMOD-enabled `mame.exe` and `fmod.dll` do not need to be downloaded again unless a new version of the custom MAME build is released.

---

## Important Notes

- The official MAME package is required as the base installation.
- The FMOD-enabled `mame.exe` and `fmod.dll` are distributed separately because of GitHub file-size limitations.
- The GitHub repository contains the Lua scripts, source code, configuration files, and other project files.
- No game ROMs are included.
- You are responsible for obtaining and using ROMs and other copyrighted game data legally.
- This project is experimental. Use it at your own risk.