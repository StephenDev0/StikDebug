# Embedded Loopback VPN Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Embed a LocalDevVPN-compatible loopback Packet Tunnel in StikDebug, route RPPairing/RSD traffic through it, and remove WiFi as a hard prerequisite without changing the higher-level JIT/debug/location behavior.

**Architecture:** Add a `StikDebugTunnel` Packet Tunnel Extension with a point-to-point IPv4 route for the configured peer (`10.7.0.1` by default), and manage it from the main app through `NETunnelProviderManager`. Move RPPairing tunnel creation behind an `EmbeddedDeviceTransport` so JIT, heartbeat, syslog, and location all share the same readiness gate. Keep ordinary Internet traffic outside the tunnel and report VPN/RSD failures separately from Internet or DDI-download failures.

**Tech Stack:** Swift 5, SwiftUI, NetworkExtension, XCTest/Swift Testing, existing `idevice` FFI, Xcode project format.

## Global Constraints

- Minimum supported iOS target remains 17.4.
- The embedded tunnel includes only the configured peer route and excludes the default route.
- The default peer remains `10.7.0.1:49152`; the existing custom peer IP setting remains supported.
- No RSD/JIT feature may be gated on `NWPathMonitor(requiredInterfaceType: .wifi)`.
- Existing `tunnel_create_rppairing`/RPPairing/RSD behavior remains the protocol implementation.
- The Packet Tunnel Extension does not implement WLocApp's HTTPS interception or location proxy.
- USB/usbmuxd transport is out of scope.
- Every new pure function receives a failing unit test before its implementation; Xcode project, plist, entitlement, and extension wiring are configuration exceptions.
- Real-device acceptance is required before claiming WiFi-free operation; Windows-side checks cannot prove Network Extension runtime behavior.

---

### Task 1: Add testable tunnel configuration and IPv4 packet primitives

**Files:**
- Create: `StikJIT/Tunnel/StikDebugTunnelConfiguration.swift`
- Create: `StikJIT/Tunnel/IPv4PacketRewriter.swift`
- Modify: `StikJITTests/StikJITTests.swift`
- Modify: `StikDebug.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces `StikDebugTunnelConfiguration.default`, `StikDebugTunnelConfiguration(interfaceIP:peerIP:)`, and `providerConfiguration` values for the app and extension.
- Produces `IPv4PacketRewriter.swapEndpoints(in:)` for the Packet Tunnel and unit tests.

- [ ] **Step 1: Write failing tests for the defaults and packet swap.**

Add tests to `StikJITTests/StikJITTests.swift`:

```swift
@Test func embeddedTunnelDefaultsMatchLocalDevVPNEndpoint() {
    let configuration = StikDebugTunnelConfiguration.default

    #expect(configuration.interfaceIP == "10.7.0.0")
    #expect(configuration.peerIP == "10.7.0.1")
    #expect(configuration.peerPrefixLength == 32)
    #expect(configuration.providerConfiguration["interfaceIP"] == "10.7.0.0")
    #expect(configuration.providerConfiguration["peerIP"] == "10.7.0.1")
}

@Test func ipv4PacketRewriterSwapsPacketEndpoints() {
    var packet = [UInt8](repeating: 0, count: 20)
    packet.replaceSubrange(12..<16, with: [10, 7, 0, 2])
    packet.replaceSubrange(16..<20, with: [10, 7, 0, 1])

    IPv4PacketRewriter.swapEndpoints(in: &packet)

    #expect(Array(packet[12..<16]) == [10, 7, 0, 1])
    #expect(Array(packet[16..<20]) == [10, 7, 0, 2])
}

@Test func ipv4PacketRewriterLeavesShortPacketsUnchanged() {
    var packet = [UInt8](repeating: 0, count: 19)
    let original = packet

    IPv4PacketRewriter.swapEndpoints(in: &packet)

    #expect(packet == original)
}
```

- [ ] **Step 2: Run the focused test target and verify it fails because the new types do not exist.**

Run on macOS/Xcode:

```bash
xcodebuild -project StikDebug.xcodeproj -scheme StikDebug -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:StikDebugTests/StikJITTests test
```

Expected: compilation failure identifying the missing `StikDebugTunnelConfiguration` and `IPv4PacketRewriter` symbols.

- [ ] **Step 3: Implement the minimal pure types.**

`StikDebugTunnelConfiguration` must store `interfaceIP`, `peerIP`, and `peerPrefixLength`, expose the constants `interfaceIPKey = "interfaceIP"` and `peerIPKey = "peerIP"`, and build a `[String: String]` provider dictionary. Its default must be interface `10.7.0.0`, peer `10.7.0.1`, prefix `32`.

`IPv4PacketRewriter.swapEndpoints` must return without modifying packets shorter than 20 bytes and must swap bytes 12–15 with bytes 16–19 for every IPv4 packet delivered by the peer-only route. It must not parse or rewrite IPv6 packets. This intentionally matches LocalDevVPN's packet loop; the route restriction ensures only loopback peer traffic enters the loop.

- [ ] **Step 4: Add the files to the main app target and rerun the focused tests.**

Add both Swift files to the `StikDebug` target in `StikDebug.xcodeproj/project.pbxproj`, then rerun the exact command from Step 2.

Expected: the three new tests pass and the existing tests remain green.

- [ ] **Step 5: Commit the tested primitives.**

```bash
git add StikJIT/Tunnel StikJITTests/StikJITTests.swift StikDebug.xcodeproj/project.pbxproj
git commit -m "feat: add loopback tunnel configuration primitives"
```

---

### Task 2: Add the `StikDebugTunnel` Packet Tunnel Extension

**Files:**
- Create: `StikDebugTunnel/PacketTunnelProvider.swift`
- Create: `StikDebugTunnel/Info.plist`
- Create: `StikDebugTunnel/StikDebugTunnel.entitlements`
- Modify: `StikDebug.xcodeproj/project.pbxproj`
- Modify: `StikJIT/Tunnel/StikDebugTunnelConfiguration.swift`

**Interfaces:**
- Consumes: `StikDebugTunnelConfiguration` and `IPv4PacketRewriter` from Task 1.
- Produces: an extension target with bundle identifier `com.stik.stikdebug.tunnel` and a `PacketTunnelProvider` that configures the peer-only route and packet loop.

- [ ] **Step 1: Add the extension resource/configuration entries.**

Create `StikDebugTunnel/Info.plist` with an `NSExtension` dictionary containing:

```xml
<key>NSExtensionPointIdentifier</key>
<string>com.apple.networkextension.packet-tunnel</string>
<key>NSExtensionPrincipalClass</key>
<string>$(PRODUCT_MODULE_NAME).PacketTunnelProvider</string>
```

Create `StikDebugTunnel/StikDebugTunnel.entitlements` with:

```xml
<key>com.apple.developer.networking.networkextension</key>
<array>
    <string>packet-tunnel-provider</string>
</array>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.stik.stikdebug</string>
</array>
```

Add a `PBXNativeTarget` named `StikDebugTunnel` with product type `com.apple.product-type.app-extension`, product name `StikDebugTunnel`, bundle identifier `com.stik.stikdebug.tunnel`, deployment target 17.4, `APPLICATION_EXTENSION_API_ONLY = YES`, the new plist/entitlement paths, and the NetworkExtension framework. Add the target as a dependency of the main `StikDebug` target and add the provider/configuration source files to its source phase.

- [ ] **Step 2: Implement the provider using the tested packet primitive.**

`PacketTunnelProvider.startTunnel` must:

1. Read `interfaceIP` and `peerIP` from `startTunnel(options:)`, falling back to `NETunnelProviderProtocol.providerConfiguration` and then `StikDebugTunnelConfiguration.default`.
2. Configure `NEIPv4Settings(addresses:subnetMasks:)` using the interface IP and `/24` subnet mask.
3. Set `includedRoutes` to one `NEIPv4Route` for the peer IP with subnet mask `255.255.255.255`.
4. Set `excludedRoutes` to `[.default()]`.
5. Call `setTunnelNetworkSettings`; report its error through the completion handler before starting packet reads.
6. Start a recursive `packetFlow.readPackets` loop that calls `IPv4PacketRewriter.swapEndpoints` on each IPv4 packet, writes the packets back, and continues reading.

`stopTunnel` must cancel the packet loop state and call its completion handler. The provider must not configure DNS, HTTP proxy settings, or a default route.

- [ ] **Step 3: Run static target checks.**

Run:

```powershell
rg -n -S "StikDebugTunnel|packet-tunnel-provider|com.stik.stikdebug.tunnel|StikDebugTunnel.entitlements|StikDebugTunnel/Info.plist" StikDebug.xcodeproj/project.pbxproj StikDebugTunnel
```

Expected: one extension target, one packet-tunnel extension point, the correct bundle identifier, both resources, and the Network Extension entitlement are present.

- [ ] **Step 4: Commit the extension scaffold.**

```bash
git add StikDebugTunnel StikJIT/Tunnel/StikDebugTunnelConfiguration.swift StikDebug.xcodeproj/project.pbxproj
git commit -m "feat: embed loopback packet tunnel extension"
```

---

### Task 3: Add the main-app VPN manager and status/error model

**Files:**
- Create: `StikJIT/Utilities/StikDebugVPNManager.swift`
- Create: `StikJIT/Utilities/StikDebugVPNStatus.swift`
- Modify: `StikJITTests/StikJITTests.swift`
- Modify: `StikDebug.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `StikDebugTunnelConfiguration` and the `StikDebugTunnel` bundle identifier from Task 1/2.
- Produces: `StikDebugVPNManager.shared.ensureReady() throws`, `.start() throws`, `.stop()`, `currentStatus`, and `StikDebugVPNError` values that distinguish configuration, competing VPN, timeout, and start failures.

- [ ] **Step 1: Write failing tests for status mapping and provider configuration.**

Add pure tests:

```swift
@Test func vpnStatusMappingRecognizesConnectedAndReasserting() {
    #expect(StikDebugVPNStatus(neStatus: .connected) == .connected)
    #expect(StikDebugVPNStatus(neStatus: .reasserting) == .connecting)
    #expect(StikDebugVPNStatus(neStatus: .disconnected) == .disconnected)
}

@Test func vpnManagerConfigurationUsesEmbeddedExtension() {
    let configuration = StikDebugVPNManager.makeProviderConfiguration(
        for: .default
    )

    #expect(configuration[StikDebugTunnelConfiguration.interfaceIPKey] == "10.7.0.0")
    #expect(configuration[StikDebugTunnelConfiguration.peerIPKey] == "10.7.0.1")
    #expect(StikDebugVPNManager.providerBundleIdentifier == "com.stik.stikdebug.tunnel")
}
```

- [ ] **Step 2: Run the focused tests and verify they fail because the VPN types do not exist.**

Run the same focused `xcodebuild` command from Task 1.

Expected: compilation failure for the missing VPN status and manager symbols.

- [ ] **Step 3: Implement the pure status/error model.**

`StikDebugVPNStatus` must map `.invalid` and `.disconnected` to `.disconnected`, `.connecting` and `.reasserting` to `.connecting`, `.connected` to `.connected`, `.disconnecting` to `.disconnecting`, and unknown values to `.failed`.

`StikDebugVPNError` must provide localized messages for profile creation failure, VPN permission/start failure, a conflicting active VPN, timeout waiting for `.connected`, and a disconnected peer route. It must not mention WiFi.

- [ ] **Step 4: Implement `StikDebugVPNManager`.**

Use `NETunnelProviderManager.loadAllFromPreferences` to find only managers whose `NETunnelProviderProtocol.providerBundleIdentifier` equals `com.stik.stikdebug.tunnel`. Create one if absent, set `localizedDescription` to `StikDebug Local Tunnel`, assign the provider configuration, enable it, and save it back to preferences.

Configure an `NEOnDemandRuleEvaluateConnection` with `interfaceTypeMatch = .any` and a single `NEEvaluateConnectionRule` matching the peer IP. Do not remove or stop managers belonging to other VPNs; throw `StikDebugVPNError.competingVPN` if another manager is connected or connecting.

`ensureReady()` must load/create the manager, return immediately when its status is `.connected`, start it with the interface/peer options otherwise, and wait up to 10 seconds for `.connected` or a terminal failure using `NEVPNStatusDidChange`. It must be safe to call from the background queue used by `startTunnelInBackground` and must coalesce concurrent starts with a lock/semaphore.

- [ ] **Step 5: Add the manager to the main app target and rerun tests.**

Add both files to the `StikDebug` target, run the focused test command, and confirm the status/configuration tests pass.

- [ ] **Step 6: Commit the VPN manager.**

```bash
git add StikJIT/Utilities/StikDebugVPNManager.swift StikJIT/Utilities/StikDebugVPNStatus.swift StikJITTests/StikJITTests.swift StikDebug.xcodeproj/project.pbxproj
git commit -m "feat: manage embedded loopback vpn"
```

---

### Task 4: Move RPPairing creation behind the embedded transport

**Files:**
- Create: `StikJIT/Utilities/DeviceTransport.swift`
- Modify: `StikJIT/Utilities/JITEnableContext.swift`
- Modify: `StikJIT/Utilities/IdeviceFFIBridge.swift`
- Modify: `StikJITTests/StikJITTests.swift`
- Modify: `StikDebug.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `StikDebugVPNManager.ensureReady()` and existing `idevice` FFI symbols.
- Produces: `RPPairingTunnel`, `DeviceTransport`, and `EmbeddedDeviceTransport.shared.makeRPPairingTunnel(hostname:targetIPAddress:pairingFileURL:)`.

- [ ] **Step 1: Write failing tests for transport endpoint validation and error classification.**

Add pure tests for the new endpoint/error helpers:

```swift
@Test func transportEndpointUsesRPPairingPort() throws {
    let endpoint = try RPPairingEndpoint(ip: "10.7.0.1")
    #expect(endpoint.port == 49152)
    #expect(endpoint.ip == "10.7.0.1")
}

@Test func transportEndpointRejectsMalformedIPv4() {
    #expect(throws: DeviceTransportError.invalidIPAddress) {
        try RPPairingEndpoint(ip: "not-an-ip")
    }
}

@Test func transportErrorsDoNotReportWiFiAsTheRootCause() {
    let message = DeviceTransportError.vpnUnavailable("permission denied").errorDescription ?? ""
    #expect(!message.localizedCaseInsensitiveContains("wifi"))
    #expect(message.localizedCaseInsensitiveContains("vpn"))
}
```

- [ ] **Step 2: Run the focused tests and verify they fail because the transport types do not exist.**

Run the focused `xcodebuild` test command from Task 1.

Expected: compilation failure for the missing transport types.

- [ ] **Step 3: Implement endpoint validation and owned tunnel handles.**

`RPPairingEndpoint` must validate an IPv4 address using `inet_pton`, store the address and port `49152`, and expose a `sockaddr_in` conversion used by the FFI call.

`RPPairingTunnel` must own optional adapter/handshake handles and free the handshake before the adapter. Its `free()` method must be idempotent.

`DeviceTransportError` must include invalid IP, pairing file missing/read failure, VPN unavailable, FFI tunnel creation failure, and incomplete handle errors. Its descriptions must identify VPN/RPPairing/RSD layers and must not claim WiFi is required.

- [ ] **Step 4: Implement `EmbeddedDeviceTransport`.**

`makeRPPairingTunnel` must:

1. Call `StikDebugVPNManager.shared.ensureReady()` before touching the RPPairing FFI.
2. Verify the pairing file path exists.
3. Read the pairing file with `rp_pairing_file_read` and always free it with `rp_pairing_file_free`.
4. Build `sockaddr_in` for the validated target IP and port `49152`.
5. Call `tunnel_create_rppairing` with the caller's hostname.
6. Convert FFI errors to `DeviceTransportError.ffiFailure` while freeing the FFI error.
7. Reject and free incomplete adapter/handshake results.

Keep the FFI implementation in this transport so callers do not duplicate VPN readiness, IP parsing, pairing-file lifetime, or error conversion.

- [ ] **Step 5: Migrate `JITEnableContext`.**

Remove its private `TunnelHandles`, `getPairingFile`, and direct `createTunnel` implementation. Use `RPPairingTunnel` and `EmbeddedDeviceTransport.shared.makeRPPairingTunnel` for:

- the persistent `startTunnel()` handle;
- `withFreshDebugTunnel` used by debug sessions;
- heartbeat creation in `DebugHeartbeatKeepAlive`;
- syslog connection paths that currently call `createTunnel`.

Preserve the existing adapter/handshake freeing order and concurrency lock. `pubTunnelConnected` remains true only after RPPairing/RSD setup succeeds.

- [ ] **Step 6: Migrate location simulation.**

In `simulate_location`, remove the duplicate pairing-file read, port setup, and direct `tunnel_create_rppairing` call. Call the transport with hostname `StikDebugLocation`, `deviceIP`, and the supplied pairing file path. Transfer the returned adapter/handshake into `LocationSimulationState` and leave the existing remote-server/location-simulation error status mapping unchanged.

- [ ] **Step 7: Rerun tests and commit the transport migration.**

Run the focused tests and then:

```bash
git add StikJIT/Utilities/DeviceTransport.swift StikJIT/Utilities/JITEnableContext.swift StikJIT/Utilities/IdeviceFFIBridge.swift StikJITTests/StikJITTests.swift StikDebug.xcodeproj/project.pbxproj
git commit -m "refactor: route RSD connections through embedded vpn"
```

---

### Task 5: Remove WiFi gating and external LocalDevVPN UI/documentation

**Files:**
- Modify: `StikJIT/StikJITApp.swift`
- Modify: `StikJIT/Views/SettingsView.swift`
- Modify: `StikJIT/Resources/Localizable.xcstrings`
- Modify: `README.md`
- Modify: `StikDebug.xcodeproj/project.pbxproj` only if new manager files are added to the target here

**Interfaces:**
- Consumes: `StikDebugVPNManager` and transport errors from Tasks 3–4.
- Produces: user flows that start the embedded VPN automatically and no longer instruct users to install or enable external LocalDevVPN/WiFi.

- [ ] **Step 1: Write a static regression check before editing the UI/diagnostic code.**

Use a PowerShell assertion script in the task worktree, without adding it to production sources:

```powershell
$app = Get-Content -Raw StikJIT\StikJITApp.swift
if ($app -match 'requiredInterfaceType:\s*\.wifi') { throw 'WiFi-only path monitor still blocks the app' }
if ($app -match 'Make sure Wi.?Fi and LocalDevVPN') { throw 'External WiFi/LocalDevVPN error copy still exists' }
```

Run it before the production edit and record the expected failure. The failure proves the regression check detects the old behavior.

- [ ] **Step 2: Remove unused WiFi-only diagnostics and stale connection checks.**

Confirm with `rg` that `DNSChecker` and `checkDeviceConnection` have no callers. Remove the unused `DNSChecker` class and the unused WiFi/same-network connection helper from `StikJITApp.swift`. Keep `Network` imported only if another helper in that file still uses it; otherwise remove the import.

Change `startTunnelInBackground` error handling to display the localized transport error. Do not mention WiFi or external LocalDevVPN. Keep DDI download failures separate from tunnel failures.

- [ ] **Step 3: Replace the Settings external link with embedded VPN status/control.**

Remove `SettingsLinks.localDevVPN` and the “Download LocalDevVPN” link. Add a section bound to `StikDebugVPNManager.shared` that displays disconnected/connecting/connected/error state and provides Start/Stop actions. Start calls the manager and surfaces its error; Stop calls `stop()`. The existing pairing-file import continues to call `startTunnelInBackground`, which now starts the embedded VPN through the transport.

- [ ] **Step 4: Update localized strings and README.**

Remove the `Download LocalDevVPN` localization entry. Add localized strings for “Embedded VPN”, “Start VPN”, “Stop VPN”, “VPN connected”, “VPN disconnected”, “VPN permission required”, and the transport error categories used by the manager.

Update `README.md` so Requirements list the embedded VPN capability rather than a separately installed LocalDevVPN app, and update the setup/troubleshooting sections to say that WiFi is not a prerequisite. State that Internet is still required for uncached DDI downloads and network-backed content, while cached RSD/JIT traffic is local to the Packet Tunnel.

- [ ] **Step 5: Rerun the static regression check and commit.**

Run:

```powershell
$app = Get-Content -Raw StikJIT\StikJITApp.swift
if ($app -match 'requiredInterfaceType:\s*\.wifi') { throw 'WiFi-only path monitor still blocks the app' }
if ($app -match 'Make sure Wi.?Fi and LocalDevVPN') { throw 'External WiFi/LocalDevVPN error copy still exists' }
rg -n -S "LocalDevVPN|Download LocalDevVPN|\.wifi|requiredInterfaceType" StikJIT README.md
```

Expected: no RSD/JIT gating or external setup instruction remains; any remaining `LocalDevVPN` match must be a historical attribution or test/documentation reference explicitly marked as such.

```bash
git add StikJIT/StikJITApp.swift StikJIT/Views/SettingsView.swift StikJIT/Resources/Localizable.xcstrings README.md
git commit -m "feat: remove wifi and external vpn requirements"
```

---

### Task 6: Build, test, and validate the project wiring

**Files:**
- Modify: `StikDebug.xcodeproj/project.pbxproj` only if verification identifies a missing source/build phase entry
- Modify: `StikJITTests/StikJITTests.swift` only for a verified regression test discovered during validation

**Interfaces:**
- Consumes: all previous tasks.
- Produces: verified project wiring, test results, and a documented real-device acceptance checklist.

- [ ] **Step 1: Run formatting and repository checks.**

```powershell
git diff --check
git status --short
rg -n -S "tunnel_create_rppairing|10\.7\.0\.1|49152|NWPathMonitor|requiredInterfaceType|LocalDevVPN|packet-tunnel-provider|com.stik.stikdebug.tunnel" StikJIT StikDebugTunnel StikDebug.xcodeproj README.md
```

Confirm that the `tunnel_create_rppairing` implementation call occurs only in `DeviceTransport.swift` (the FFI declaration in `idevice.h` remains), the default peer appears in configuration/tests/UI placeholder as intended, WiFi-only monitoring is absent, and the extension target has the expected Network Extension entries.

- [ ] **Step 2: Run all unit tests on macOS/Xcode.**

```bash
xcodebuild -project StikDebug.xcodeproj -scheme StikDebug -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Expected: existing tests plus the new configuration, packet, status, endpoint, and error tests pass with exit code 0.

- [ ] **Step 3: Build the app and extension for a generic iOS device.**

```bash
xcodebuild -project StikDebug.xcodeproj -scheme StikDebug -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
```

If unsigned build is not supported for the extension, run with the configured development team and record the exact entitlement/signing error rather than treating a simulator build as sufficient.

- [ ] **Step 4: Inspect the built product wiring.**

Verify the archive/build log contains both `StikDebug.app` and `StikDebugTunnel.appex`, the extension Info.plist packet-tunnel point, the app-group entitlement in both products, and the packet-tunnel entitlement in the extension. Verify the main app declares the embedded extension target dependency.

- [ ] **Step 5: Execute the physical-device matrix.**

With a valid pairing file and DDI available, test WiFi-only, cellular-only, both interfaces, and both interfaces disabled while the embedded VPN is connected. Then test VPN denied/stopped, DDI cached offline, DDI uncached with cellular Internet, background/foreground, VPN restart, app discovery, JIT enablement, device info, debug/heartbeat, syslog, and location simulation.

Record for each case whether the failure is VPN status, peer route/RPPairing, RSD, pairing, or ordinary Internet. Do not claim WiFi-free support unless the cellular-only or offline cases pass on a real device.

- [ ] **Step 6: Commit only after verification evidence is captured.**

```bash
git status --short
git log -6 --oneline
```

Create the final implementation commit only after the focused tests, full tests, build, and available device checks have been reviewed. If signing or hardware blocks a check, report that blocker explicitly instead of marking the requirement complete.
