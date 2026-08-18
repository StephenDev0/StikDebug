# Embedded Loopback VPN Design

## Goal

Remove StikDebug's dependency on the separately installed LocalDevVPN app by embedding an equivalent local Network Extension Packet Tunnel, while removing WiFi as a hard prerequisite and preserving the existing RPPairing/RSD feature set.

## Context and constraints

StikDebug currently creates RPPairing tunnels to `DeviceConnectionContext.targetIPAddress` on port `49152`. The default address is `10.7.0.1`, which is supplied by the external LocalDevVPN virtual interface. JIT, app discovery, device information, debugging, syslog, and location simulation all ultimately depend on this path.

The existing app contains WiFi-only DNS diagnostics and user-facing WiFi error text, but the actual RPPairing FFI calls do not inspect WiFi. The replacement must therefore validate tunnel readiness and RSD connectivity rather than interface type. Internet-dependent DDI downloads remain separate from the local RSD transport.

The reference implementation is the LocalDevVPN Packet Tunnel design: configure a point-to-point IPv4 interface, include only the peer route (`10.7.0.1/32` by default), exclude the default route, and exchange packets through `NEPacketTunnelProvider.packetFlow`. WLocApp is used only as a reference for target layout, VPN manager lifecycle, App Group sharing, and entitlements; its location proxy is out of scope.

## Approved approach

### 1. Add an embedded Packet Tunnel target

Add a `StikDebugTunnel` app extension target to `StikDebug.xcodeproj` with:

- `PacketTunnelProvider` subclassing `NEPacketTunnelProvider`.
- A small constants/configuration module shared with the main app.
- Extension `Info.plist` declaring `com.apple.networkextension.packet-tunnel`.
- Packet Tunnel Network Extension entitlement.
- The existing app group entitlement shared by the main app and extension.

The provider accepts interface and peer IP values from `NETunnelProviderProtocol.providerConfiguration` and/or `startVPNTunnel(options:)`. It configures an IPv4 interface, includes only the peer IP route, excludes the default route, then swaps the source and destination IPv4 addresses for packets read from `packetFlow` before writing them back. This reproduces the LocalDevVPN loopback behavior without carrying ordinary Internet traffic through StikDebug.

The implementation will be an equivalent implementation rather than copying unrelated WLocApp proxy code. If LocalDevVPN source code is reused verbatim, its license and attribution must be preserved; StikDebug is already AGPL-3.0.

### 2. Add main-app VPN lifecycle management

Add `StikDebugVPNManager` in the main app. It owns one `NETunnelProviderManager` identified by the embedded extension bundle identifier and provides:

- `prepare()` to load or create the saved VPN profile.
- `start()` to save/reload the profile and call `startVPNTunnel(options:)`.
- `stop()` to stop the active tunnel.
- `status` derived from `NEVPNStatus`.
- `isTunnelReady()` for non-UI callers.

The manager uses `providerConfiguration` for the interface IP and peer IP, defaults to interface `10.7.0.0` and peer `10.7.0.1`, and configures an on-demand rule only for the peer address. It must not require WiFi or enable a full-device default route. Existing VPNs are not silently destroyed; if another VPN is active, the manager reports a clear conflict and waits for the user to stop it.

The app group is reserved for shared tunnel configuration and diagnostics. Pairing files remain in the existing app-owned store unless the extension later needs them; the Packet Tunnel itself does not read pairing material.

### 3. Gate the RSD layer on transport readiness

Keep `tunnel_create_rppairing` as the RSD transport primitive. Before calling it, `JITEnableContext` ensures the embedded VPN profile is prepared and active. The FFI call still targets the configured peer IP and port `49152`.

The transport readiness abstraction will expose:

```swift
enum DeviceTransportState {
    case unavailable(String)
    case starting
    case ready
}

protocol DeviceTransport {
    func ensureReady() throws
    func makeRPPairingTunnel(
        hostname: String,
        targetIPAddress: String,
        pairingFileURL: URL
    ) throws -> RPPairingTunnel
}
```

The concrete implementation wraps `StikDebugVPNManager` plus the existing FFI tunnel creation. `JITEnableContext` remains responsible for lifecycle and FFI handle ownership, while callers no longer need to know whether the external or embedded VPN is present.

All direct RPPairing entry points must use this path, including:

- the main RSD/debug session;
- debug heartbeat tunnels;
- syslog relay tunnels;
- location simulation in `IdeviceFFIBridge.swift`.

### 4. Replace WiFi diagnostics with transport diagnostics

Remove WiFi from the connection prerequisite and error copy. The old `DNSChecker` will either be removed if unused or reduced to an explicit Internet diagnostics utility that reports DNS/Internet status without blocking RSD.

Connection errors will distinguish:

- VPN profile missing or permission denied;
- VPN starting or disconnected;
- peer route/RPPairing connection failed;
- invalid or expired pairing file;
- RSD service handshake failure;
- ordinary Internet unavailable for DDI/news/map requests.

No code path will call `NWPathMonitor(requiredInterfaceType: .wifi)` to decide whether JIT, debugging, syslog, or location simulation may proceed.

### 5. Preserve existing user flows

The existing start-tunnel call sites continue to call `startTunnelInBackground`, but that function delegates to the embedded VPN manager before establishing RSD. Settings may expose the embedded VPN status and a stop control, while the existing custom peer IP setting remains supported.

The README and localized strings will describe the built-in VPN, remove the external LocalDevVPN installation step, and explain that Internet is only needed when downloading uncached DDI files or using network-backed content.

## Data flow

```text
User action / background reconnect
        |
        v
StikDebugVPNManager.prepare/start
        |
        v
StikDebugTunnel PacketTunnelProvider
  10.7.0.0 interface, route 10.7.0.1/32
        |
        v
JITEnableContext.ensureReady
        |
        v
tunnel_create_rppairing(10.7.0.1:49152)
        |
        v
RSD services: apps, device info, debug proxy, syslog, location
```

The tunnel includes only the peer route, so ordinary network requests continue to use WiFi or cellular according to iOS routing. A cached-DDI JIT session should not need an Internet connection; a first-time DDI download still does.

## Error handling and lifecycle

- VPN profile creation and permission errors are surfaced before FFI tunnel creation.
- Concurrent start requests are coalesced by the VPN manager and `JITEnableContext`.
- A disconnected/reasserting VPN invalidates cached RSD handles; the next operation recreates the tunnel.
- Stopping or losing the VPN frees RSD/adapter handles and sets the published connection state to disconnected.
- Background reconnect attempts are allowed to start the embedded profile, but UI permission prompts remain user-driven.
- No automatic default-route VPN behavior is added.

## Testing strategy

### Unit tests

Test pure configuration and state behavior without Network Extension runtime:

- default interface/peer values;
- custom peer IP propagation;
- peer route is `/32` and default route is excluded;
- WiFi interface status cannot block transport readiness;
- error mapping preserves invalid pairing versus tunnel unavailable;
- repeated `ensureReady()` does not create duplicate starts.

### Build/static checks

- Verify the main app and extension targets are present in the Xcode project.
- Verify both entitlements contain the required Network Extension and App Group entries.
- Verify the extension Info.plist has the packet-tunnel extension point.
- Verify no RSD/JIT call site requires `NWPathMonitor(.wifi)` or references external LocalDevVPN installation.
- Run the available Swift test/build commands on the development machine.

### Real-device acceptance matrix

Test on a physical supported iOS device with a valid pairing file:

1. WiFi on, cellular off, embedded VPN on.
2. WiFi off, cellular on, embedded VPN on.
3. WiFi and cellular both off, embedded VPN on.
4. WiFi and cellular both on.
5. VPN stopped or permission denied.
6. DDI cached with no Internet.
7. DDI missing with cellular-only Internet.
8. Background/foreground transition and VPN restart.

Acceptance requires app discovery, JIT enablement, device info, debug session/heartbeat, syslog, and location simulation to continue using the same pairing and RSD behavior.

## Risks and non-goals

- Network Extension entitlement and distribution/signing support may be unavailable for some sideload profiles. The project will expose signing failures clearly, but cannot solve Apple entitlement policy in code.
- The packet swap loop is intentionally limited to the LocalDevVPN-compatible peer route; this is not a general-purpose VPN or Internet proxy.
- USB/usbmuxd transport is not part of this change.
- WLocApp's HTTPS interception, certificate installation, DNS proxy, and location response mutation are not part of this change.
- The final no-WiFi result cannot be claimed until the real-device matrix is executed.
