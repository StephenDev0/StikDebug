> [!CAUTION]
> **WARNING:** There are known critical issues with **iOS 26.4 Developer Beta 1**. The `lockdownd` service appears to be dropping connections, which interferes with how the device connects to itself (loopback/pairing issues) and prevents JIT from functioning. **DO NOT UPDATE** if you rely on StikDebug. These issues and possible fixes are currently being investigated.

<div align="center">
   <img width="217" height="217" src="/assets/StikJIT.png" alt="Logo">
</div>

<div align="center">
  <h1><b>StikDebug</b></h1>
  <p><i>An on-device debugger/JIT enabler for iOS versions 17.4+ powered by <a href="https://github.com/jkcoxsin/idevice">idevice</a>.</i></p>
</div>

<h6 align="center">
  <a href="https://discord.gg/ZnNcrRT3M8">
    <img src="https://img.shields.io/badge/Discord-join%20us-7289DA?logo=discord&logoColor=white&style=for-the-badge&labelColor=23272A" />
  </a>
  <a href="https://github.com/StephenDev0/StikDebug/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/StephenDev0/StikDebug?label=License&color=5865F2&style=for-the-badge&labelColor=23272A" />
  </a>
  <a href="https://github.com/StephenDev0/StikDebug/stargazers">
    <img src="https://img.shields.io/github/stars/StephenDev0/StikDebug?label=Stars&color=FEE75C&style=for-the-badge&labelColor=23272A" />
  </a>
  <a href="https://github.com/StephenDev0/StikDebug/releases">
    <img src="https://img.shields.io/github/v/release/StephenDev0/StikDebug?label=Latest&color=00BFFF&style=for-the-badge&labelColor=23272A" />
  </a>
  <br />
</h6>

## Features
- **JIT:** Enable Just In Time coplation in sideloaded apps that have the `get-task-allow` entitlement.
- **App Launching:** Launch every app installed on your device.
- **Console:** Live app and system logs.
- **Scripts:** Manage automation scripts (mainly used for iOS 26 JIT). 
- **Profiles:** Install/remove profile and see when apps will expire.
- **Device Info:** View detailed device metadata.
- **Processes:** Inspect running apps/processes and terminate them.
- **Location Simulator:** Simulate the GPS location of your device.

## Download
> [!WARNING]
> **Notice:** StikDebug is no longer available on the App Store. Please use the official download methods below.

<div align="center" style="display: flex; justify-content: center; align-items: center; gap: 16px; flex-wrap: wrap;">
   <a href="https://stikstore.app/altdirect/?url=https://stikdebug.xyz/index.json" target="_blank">
     <img src="https://github.com/stikstore/altdirect/blob/main/assets/png/AltSource_Blue.png" alt="Add AltSource" width="200">
   </a>
   <a href="https://github.com/StephenDev0/StikDebug/releases/download/2.3.7/StikDebug-2.3.7.ipa" target="_blank">
     <img src="https://github.com/stikstore/altdirect/blob/main/assets/png/Download_Blue.png" alt="Download .ipa" width="200">
   </a>
</div>

## Compatibility

| iOS Version              | Status               | Notes                                                                 |
|--------------------------|----------------------|-----------------------------------------------------------------------|
| 1.0 – 17.3.X             | Not supported      | Uses Different Connection Protocols                                                                |
| 17.4 – 18.x              | Fully supported      | Stable                                                                |
| 26.0 – 26.3              | Supported            | Limited App Availability (Developers need to update their apps to work.)                                        |
| 26.4 Developer Beta 1    | Critical issues   | lockdownd drops connections → JIT broken; do not update               |
| iOS 26.4+ betas / future | Untested / partial   | Check [Discord](https://discord.gg/ZnNcrRT3M8), [releases](https://github.com/StephenDev0/StikDebug/releases), or [@StephenDev0 on X](https://x.com/stephendev0) for updates                                 |

## How to Enable JIT

StikDebug enables **JIT** for sideloaded apps on iOS 17.4+ without needing a computer after the initial pairing setup.

### Requirements
- StikDebug installed (via AltSource, direct .ipa, or self-built)
- A valid **pairing file** (.plist / .mobiledevicepairing) for your device
- SideStore / AltStore / similar sideload tool (for app refreshing)
- A loopback vpn such as [LocalDevVPN](https://apps.apple.com/us/app/localdevvpn/id6755608044)

### Steps
1. **Obtain a pairing file**  
   - Detailed guide: [Pairing File Instructions](https://github.com/StephenDev0/StikDebug-Guide/blob/main/pairing_file.md) (or ask in Discord).

2. **Set up VPN**  
   - Launch LocalDevVPN and enable the vpn.

4. **Enable JIT for an app**  
   - Launch StikDebug and press the `Enable JIT` button.
   - Select your sideloaded app from the list in StikDebug.  

**Troubleshooting**  
- "Connection dropped" or loopback errors → Check iOS version compatibility / beta warnings.  
- Heartbeat erros → Ensure that the vpn is on and that you are connecected to Wi-Fi.
- Pairing file issues → Regenerate file with device unlocked & trusted.  
- Still stuck? Join the [Discord](https://discord.gg/ZnNcrRT3M8) with logs/screenshots.

<!-- 
## Screenshots

<div align="center">
  <img src="screenshots/pairing-import.png" width="320" alt="Pairing file import screen">
  <img src="screenshots/app-list.png" width="320" alt="Sideloaded apps list">
  <img src="screenshots/jit-enabled.png" width="320" alt="JIT successfully enabled">
  <img src="screenshots/processes.png" width="320" alt="Process management tab">
</div>

(Add images to a /screenshots/ folder in the repo and uncomment when ready.)
-->

## Building from Source
> [!NOTE]
> StikDebug is an open-source Xcode project written mostly in Swift. Building yourself lets you modify code, debug, or create custom versions. Requires a Mac with Xcode.

### Requirements
- macOS (latest recommended)
- Xcode 16+ (Xcode 26+ preferred for iOS 26+ support)
- iOS device on iOS 17.4+ (for testing)
- Git
- Basic Xcode/Swift knowledge

### Steps
1. **Clone the repo**
   ```bash
   git clone https://github.com/StephenDev0/StikDebug.git
   cd StikDebug
   ```

2. **Open in Xcode**
   - Launch Xcode
   - Open `StikDebug.xcodeproj`

3. **Configure signing**
   - Select the **StikDebug** target
   - Go to **Signing & Capabilities**
   - Sign in with your Apple ID (free or paid developer account)
   - Set a unique **Bundle Identifier** (e.g., `com.yourname.StikDebug`)

4. **Build & install**
   - Select your connected device
   - Press **Cmd + R** (or Product → Run)
   - Trust the certificate on device: Settings → General → VPN & Device Management

After install, follow the JIT setup steps above (pairing import, etc.).

## Contributing

Thank you for your interest in contributing to this project. Contributions of all kinds are welcome.

### Reporting Bugs
If you discover a bug, please open an issue and include:
- A clear and descriptive title
- Steps to reproduce the issue
- Expected behavior vs. actual behavior
- Relevant logs, screenshots, or environment details (iOS version, device model, etc.)

### Suggesting Features
To propose a new feature, open a feature request issue and provide:
- A clear description of the feature
- The problem it solves or the use case it addresses
- Any relevant examples or implementation ideas

### Code Contributions (Best Practices)
- Follow normal Swift and SwiftUI style.
- Write clear and easy to understand code.
- Keep your changes consistent with how the project is already set up.
- Make sure everything builds and works without errors.

We appreciate your time and effort in helping improve this project.

## Code Help
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/stephendev0/stikdebug)
## License
StikDebug is licensed under **AGPL-3.0**. See [`LICENSE`](LICENSE) for details.
