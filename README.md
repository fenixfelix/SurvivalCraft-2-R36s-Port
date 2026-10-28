# Survivalcraft 2 / R36S — local APK preparer

This preparer asks for the user's own APK and creates the existing DarkOSRE ARM64 port locally. It does not contain an APK, complete game assemblies, the complete game source tree, or a standalone game content package. It does include binary patches that contain replacement bytes derived from the adapted build. These patches still require rights review before public distribution. Requiring a personal APK is not a legal clearance.

## Prepare on Windows

Requirements: Windows 10/11 with Windows PowerShell 5.1 and .NET Framework available. No Python, Tcl/Tk, SDK, administrator account or internet connection is required during preparation. This is not a standalone executable: the BAT opens a local PowerShell script using built-in Windows components.

1. Extract **all files** from this ZIP to a new folder on your PC. Do not run it from inside the ZIP viewer.
2. Double-click **Start-Windows.bat**.
3. Click **Select APK** and choose your own supported Survivalcraft 2 APK.
4. Click **Choose folder** and select the folder where a NEW `Survivalcraft2_R36S` folder should be created.
5. Click **Prepare port**. Wait for the completion message.
6. Follow the R36S installation instructions below.

Your APK remains unchanged. Nothing is uploaded. The included recipe is checked before use, the APK is checked by size and SHA-256, the original assemblies are recovered and verified, and every reconstructed assembly is verified again. An existing output folder is never overwritten.

## Supported APK

This prototype supports only the exact Android **2.2.10.4** APK used to build the existing port:

```text
Size: 27614197 bytes
SHA-256: b1150d0dc94e464ada92f47d9b7f47bb5ec7516a4660e95c5f9349e2a8e250cb
```

The APK supplied in the original development archive had a name ending in `-free.apk`. That filename does not establish its source, license, authenticity or purchase status. The preparer does not verify purchase. Use only a copy whose use is authorized. Do not purchase a different version expecting this exact-version prototype to support it. No APK download links are provided by this kit.

Different versions, split APK bundles, XAPK files and repackaged APKs are rejected. A matching version number alone is not enough; the bytes must match.

## Install on the R36S

1. Close the game and shut down the R36S before removing its SD card.
2. Open the generated `Survivalcraft2_R36S` folder on your PC.
3. For a new installation, copy these three items into the `ports` folder your system uses:
   - `Survivalcraft 2.sh`
   - `Survivalcraft 2 - Diagnostico.sh`
   - the complete `survivalcraft2` folder
4. Safely eject the card, insert it into the R36S and refresh the Ports list or restart the menu.
5. Start **Survivalcraft 2**.

Target: DarkOSRE ARM64 on R36S with the system's SDL2, EGL and GLES libraries. The runtime is included. No Wine, Box64 or gptokeyb is needed for this port. Compatibility with other operating systems is not established by this prototype.

Already have a working installation? Back up the entire existing `survivalcraft2` folder first. This creates the same build, not an update or a bug fix. Do not overwrite or delete `survivalcraft2/userdata`; it holds worlds and settings. The generated installation contains game content and is for local use, not a public release bundle.

## Controls

Hold Select + Start for about one second to exit. When editing a text field, use the in-game keyboard:

| Button | Keyboard action |
| --- | --- |
| D-pad / left stick | Move selection |
| A | Insert selected key |
| X | Delete last character |
| Y | Toggle letter case |
| L1 / R1 | Switch keyboard page |
| Start | Confirm |
| B | Cancel |

## Troubleshooting

- **Unsupported APK:** the selected package is not the exact supported file. No output is published or installed. Do not rename another APK to try to force compatibility.
- **Output folder already exists:** select another parent folder or move the previous output aside. There is no reason to delete saves.
- **Missing recipe:** the public tools-only bundle cannot produce the port by itself. It needs a matching recipe whose distribution is authorized.
- **Recipe checksum mismatch:** use matching unmodified tool/recipe files. Do not disable the checksum.
- **Window did not open:** open a terminal in this folder and run the command below to see the actual error. Python is not required.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\Prepare-Port.ps1
```

The launcher sets execution policy only for the new process; it does not change the stored machine/user policy. Organization-managed settings may still prevent scripts from running.

If the game fails to launch on the console, run **Survivalcraft 2 - Diagnostico** and inspect `survivalcraft2/log.txt`. Review logs for personal information before sharing.

## Command-line mode

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Prepare-Port.ps1 -Cli -Apk "C:\Games\my-copy.apk" -Output "C:\Games\SC2-new"
```

## Publication status

- `Public-Tools-Only.zip` contains the new preparer scripts and English documentation, without the recipe, runtime or patch bytes. It is a tools-only package and is not sufficient for a new player to install the game.
- `port_recipe.zip` contains three differential patches, runtime/support files and a checksum manifest. Its patches total 1,982,473 literal replacement bytes before compression. Some of those bytes can represent adapted or original game expression; a binary delta is not automatically copyright-free.
- The complete prototype and the recipe are **not cleared for public release**. The generated game folder also contains protected game material.
- Written permission covering adaptation/patch distribution, or another established legal basis reviewed for this project, is still needed before presenting the recipe as distributable.
- The .NET runtime has its own MIT license and third-party notices. Both remain in the generated runtime folder. This does not license the game or its patches.

No licensing assurance is implied by the tool's checksums. See VALIDATION.md for exactly what was tested.
