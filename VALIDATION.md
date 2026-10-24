# Validation and limits

## Completed

- Recovered the original managed assemblies from the Xamarin gzip bundle inside the supplied APK.
- Generated COPY/ADD differential patches for the three port assemblies.
- Applied each patch with an independent Python reference decoder and compared the result byte for byte with the existing build.
- Executed the actual PowerShell/C# preparation path using PowerShell 7.4.6 on Linux x86-64 with the supplied APK. Preparation completed successfully.
- Compared all 199 generated runtime/launcher/game files against the supplied working build: byte-identical.
- Verified that no APK, complete source tree or userdata folder was copied into the generated installation.
- Verified rejection of an unsupported APK, an existing output folder, a missing recipe, and an altered recipe. Existing data was preserved and no partial output was committed in these rejection tests.

## Not completed

- The Windows Forms interface has not been run or visually inspected on Windows.
- Windows PowerShell 5.1 / .NET Framework execution has not been tested on a real Windows computer; the code uses compatible APIs and includes explicit compilation references for that host.
- No new physical R36S test was performed. The generated files match the build supplied by the user; this does not fix its known bugs or establish compatibility with other firmware.
- The supported APK's authenticity and the user's rights are not established by this technical validation.
- No right to publicly distribute the patches or game has been established.

## Patch contents

| Assembly | Bytes copied from user's original assembly | Literal replacement bytes | Compressed patch bytes |
| --- | ---: | ---: | ---: |
| Survivalcraft.dll | 23,072,854 | 1,441,194 | 574,023 |
| Engine.dll | 157,280 | 500,640 | 210,618 |
| EntitySystem.dll | 15,681 | 40,639 | 20,310 |

These are actual measured payload sizes. Literal replacement data is not certified as independent work. A differential patch may contain protected expression even when the complete original file is absent.
