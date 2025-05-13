# How to Install StikJIT (or StikDebug)

This document outlines the installation process for StikJIT, both with and without SideStore, along with usage instructions, troubleshooting tips, and frequently asked questions.

## StikJIT installation with SideStore or AltStore Classic

1. **Install SideStore or AltStore Classic:**  
   Visit the [SideStore](https://sidestore.io/#get-started) or [AltStore Classic](https://altstore.io) website and follow the provided installation instructions.

2. **Install StosVPN:**  
   It is recommended to install [StosVPN](https://apps.apple.com/us/app/stosvpn/id6744003051).
   
4. **Obtain StikJIT:**  
   Add the source for [SideStore](https://tinyurl.com/SideStoreStikJIT) or [AltStore](https://tinyurl.com/AltstoreStikJIT).

5. **Install via SideStore or AltStore Classic:**  
   Use SideStore or AltStore to install StikJIT.

6. **Installation procedures:**
   Follow the standard installation procedures in the usage guide below.

## StikDebug installation with App Store (US)

1. **Install StikDebug:**
   Install StikDebug from the App Store [here](https://apps.apple.com/us/app/stikdebug/id6744045754)

2. **Installation procedures:**
   Follow the standard installation procedures in the usage guide below or from the official guide [here](https://github.com/StephenDev0/StikDebug-Guide/blob/main/pairing_file.md).
   
## StikDebug installation with AltStore PAL (EU only)

1. **Install StikDebug:**  
   Install StikDebug from AltStore PAL [here](https://tinyurl.com/AltstorePALStikJIT).

2. **Installation procedures:**
   Follow the standard installation procedures in the usage guide below.

4. **Install AltStore Classic:**  
   Next, install AltStore Classic via AltStore PAL. AltStore Classic will automatically detect that StikDebug is installed.

5. **Enabling JIT:**  
   In AltStore Classic, press and hold the desired app, then select the "Enable JIT" option to activate the feature.

## StikJIT installation without SideStore or AltStore

If you prefer not to or cannot use the App Store or SideStore/AltStore (Sources), alternative methods such as Sideloadly are available.

1. **Install StosVPN:**  
   Get the latest version of [StosVPN](https://apps.apple.com/us/app/stosvpn/id6744003051) from the App Store.
   
2. **Download the StikJIT IPA:**  
   Obtain the latest StikJIT IPA from [StikJIT](https://github.com/StephenDev0/StikJIT/releases/latest).

3. **Install via alternative method:**
   Install the downloaded IPA through your preferred method.
   
4. **Installation procedures:**
   Follow the standard installation procedures in the usage guide below.

---

# Post-install Usage Guide

## Pairing Instructions

### Downloads
- **Windows**: [Jitterbugpair-win64.zip](https://github.com/osy/Jitterbug/releases/download/v1.3.1/jitterbugpair-win64.zip)
- **macOS**: [Jitterbugpair-macos.zip](https://github.com/osy/Jitterbug/releases/download/v1.3.1/jitterbugpair-macos.zip)
- **Linux**: [Jitterbugpair-linux.zip](https://github.com/osy/Jitterbug/releases/download/v1.3.1/jitterbugpair-linux.zip)

---

### For Windows

1. **Extract** `jitterbugpair-win64.zip`.
2. **Set a passcode** for your device if you haven't already. Unlock your device and connect it to your computer via cable. When a prompt appears, tap "Trust."
3. Open your device to the homescreen.
4. In File Explorer, locate `jitterbugpair.exe` and run it by double-clicking or right-clicking and selecting "Open".
5. JitterbugPair will generate a **pairing file** in the same folder. This file will have the extension `.mobiledevicepairing`.
6. **Transfer the pairing file** to your iOS device using One/iCloud/Google Drive, email, or any other method. For best results, compress the file into a .zip folder first.

---

### For macOS

1. **Extract** `jitterbugpair-macos.zip`.
2. **Set a passcode** for your device if you haven't already. Unlock your device and connect it to your computer via cable. When a prompt appears, tap "Trust."
3. Open your device to the homescreen.
4. Execute `jitterbugpair` by double-clicking or right-clicking and selecting "Open".
5. If you get the message" "macOS cannot verify that this app is free from malware":
   - Go to System Settings > Privacy & Security
   - Scroll down to the message about the app
   - Click "Open Anyway"
   - If the program doesn't run automatically, try manually runnin git again
6. JitterbugPair will generate a **pairing file** with the extension `.mobiledevicepairing` to your user's home folder.
7. **Transfer the pairing file** to your iOS device using AirDrop, iCloud/One/Google Drive, email, or any other method. For best results, compress the file into a .zip folder first.

---

### For Linux

1. **Extract** `jitterbugpair-linux.zip`.
2. Open a terminal in the extracted directory.
3. Make the program executable:
   ```bash
   chmod +x ./jitterbugpair
   ```
4. **Set a passcode** for your device if you haven't already. Unlock your device, connect it to your computer via cable. If a prompt appears: tap "Trust."
5. Open your device to the homescreen.
6. Execute the program:
   ```bash
   ./jitterbugpair
   ```
7. JitterBugPair will generate a **pairing file** with the extension `.mobiledevicepairing`.
8. **Transfer the pairing file** to your iOS device using your preferred method. For best results, compress the file into a .zip folder first.

> [!TIP]
> When using cloud storage, the file extension might change (usually to .txt). It is always recommended to zip your pairing file before transferring it. StikJIT only accepts `.mobiledevicepairing` or `.plist` files.

---

### Notes

- If you **update or reset your iDevice**, the pairing file will become **invalid**, and you’ll need to repeat the pairing process.
- To prompt StikJIT to ask for the pairing file again, go to **StikJIT > Settings** and tap **Import New Pairing File**.

---

## Standard installation procedures:

1. **Pair your device:**  
   - Follow the instructions in the pairing guide section above to generate a pairing file. In the **Files app** on your iDevice, locate your newly-generated pairing file. (If zipped, long-press your zipped pairing file and select **Uncompress**.)
   - When prompted, import the **unzipped pairing file**.
   - StikJIT or StikDebug will now be **paired** with your iDevice.
   
2. **Enable VPN:**  
   Activate StosVPN for StikJIT or the built-in VPN in StikDebug.

3. **Upload the Pairing File:**  
   When prompted, import the **unzipped pairing file** obtained via JitterbugPair.

## To enable JIT (Every time):

1. **Enable VPN:**  
   Start by activating StosVPN for StikJIT or the built-in VPN in StikDebug. If Wi-Fi is avaliable, leave it on, otherwise disable Wi-Fi and mobile data (Airplane Mode).
   
2. **Activate JIT:**  
   Click the “Enable JIT” button and select an app from the list to activate the JIT functionality. 

---

# Common Issues and Solutions

## Pairing File Issue -9

- **Issue:** This error may occur if the pairing file has been modified or if a new pairing file was created.
- **Solution:**  
  Generate a new pairing file using JitterbugPair and retry the process.

## Keeping the IPA Up-to-Date

- **Issue:** StikJIT/StikDebug is frequently updated with bug fixes.
- **Recommendation:**  
  Check for updates in your installation store method or reinstall the latest IPA (if applicable) every 1–2 days to ensure optimal performance.

## Frequently Asked Questions

- **Does this work with LiveContainer?**  
  Yes, it can be used both standalone or inside LiveContianer.

- **Do I need to be connected to Wi-Fi?**  
The first launch requires Wi-Fi to mount the DDI. After that you can use Wi-Fi or Airplane Mode.

- **Can this be used with a certificate?**  
  Yes, it has to be used with a developer certificate. Distribution and enterprise certificates will **NOT** work.

- **Is this open source?**  
  Yes, the source code is available on [GitHub](https://github.com/StephenDev0/StikJIT).

- **What iOS versions are supported?**  
  Supported versions range from iOS 17.4 to iOS 18.5 Developer Beta 2 (latest version).

- **Will devices with versions below iOS 17.4 work?**  
  No, an update to iOS 17.4 or higher is required.

- **Does iOS 18.4 beta 1 work?**  
  No, Apple broke JIT in this version. You should update. 

- **Is WireGuard still an option, or is StosVPN required?**  
StosVPN is required for StikJIT to work properly. It is not needed for StikDebug because the VPN is built in.

# iDevice Error Codes 

## Main Library Errors
- `Socket` (-1)
- `Ssl` (-2)
- `SslSetup` (-3)
- `Plist` (-4)
- `Utf8` (-5)
- `UnexpectedResponse` (-6)
- `GetProhibited` (-7)
- `SessionInactive` (-8)
- `InvalidHostID` (-9) (New Pairing File)
- `NoEstablishedConnection` (-10)
- `HeartbeatSleepyTime` (-11)
- `HeartbeatTimeout` (-12)
- `NotFound` (-13)
- `CdtunnelPacketTooShort` (-14)
- `CdtunnelPacketInvalidMagic` (-15)
- `PacketSizeMismatch` (-16)
- `Json` (-17)
- `DeviceNotFound` (-18)
- `DeviceLocked` (-19)
- `UsbConnectionRefused` (-20)
- `UsbBadCommand` (-21)
- `UsbBadDevice` (-22)
- `UsbBadVersion` (-23)
- `BadBuildManifest` (-24)
- `ImageNotMounted` (-25)
- `Reqwest` (-26)
- `InternalError` (-27)
- `Xpc` (-28)
- `NsKeyedArchiveError` (-29)
- `UnknownAuxValueType` (-30)
- `UnknownChannel` (-31)
- `AddrParseError` (-32)
- `DisableMemoryLimitFailed` (-33)
- `NotEnoughBytes` (-34)
- `Utf8Error` (-35)
- `InvalidArgument` (-36)
- `UnknownErrorType` (-37)

## FFI-Specific Bindings
- `AdapterIOFailed` (-996)
- `ServiceNotFound` (-997)
- `BufferTooSmall` (-998)
- `InvalidString` (-999)
- `InvalidArg` (-1000)

# Mounting Error Codes
- `DdiFileReadError` (-1) – Reading the DDI files failed; they probably failed to download.
- `InvalidTargetIPAddress` (-2) – Invalid target IP address (shouldn't happen, it's hardcoded).
- `PairingFileParseError` (-3) – Failed to read/parse the pairing file.
- `TcpProviderCreationError` (-4) – Failed to create the TCP provider for the device (shouldn't happen, it's hardcoded).
- `PairingFileParseError` (-5) – Failed to read/parse the pairing file.
- `LockdowndConnectionError` (-6) – Failed to connect to lockdownd (are you on cellular?).
- `SslSessionStartError` (-7) – Failed to start SSL session (bad pairing file?).
- `UniqueChipIdRetrievalError` (-8) – Failed to get the unique chip ID (send idevice logs to jkcoxson).
- `ImageMounterConnectionError` (-9) – Failed to connect to image mounter (are you on 17.0-.4? send idevice logs to jkcoxson).
- `MountFailure` (-10) – Mount failed (send idevice logs to jkcoxson).

