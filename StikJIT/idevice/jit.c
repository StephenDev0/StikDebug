//
//  jit.c
//  StikJIT
//
//  Created by Stephen on 3/27/25.
//

// Jackson Coxson

#include <arpa/inet.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <CoreFoundation/CoreFoundation.h>
#include <limits.h>

#include "jit.h"

int debug_app(TcpProviderHandle* tcp_provider, const char *bundle_id, LogFuncC logger) {
    // Initialize logger
    idevice_init_logger(Debug, Disabled, NULL);
    IdeviceErrorCode err = IdeviceSuccess;
    
    // Connect to CoreDeviceProxy
    CoreDeviceProxyHandle *core_device = NULL;
    err = core_device_proxy_connect_tcp(tcp_provider, &core_device);
    if (err != IdeviceSuccess) {
        logger("Failed to connect to CoreDeviceProxy: %d", err);
        return 1;
    }
    
    // Get server RSD port
    uint16_t rsd_port;
    err = core_device_proxy_get_server_rsd_port(core_device, &rsd_port);
    if (err != IdeviceSuccess) {
        logger("Failed to get server RSD port: %d", err);
        core_device_proxy_free(core_device);
        return 1;
    }
    logger("Server RSD Port: %d", rsd_port);
    
    /*****************************************************************
     * Create TCP Tunnel Adapter
     *****************************************************************/
    logger("=== Creating TCP Tunnel Adapter ===");
    
    AdapterHandle *adapter = NULL;
    err = core_device_proxy_create_tcp_adapter(core_device, &adapter);
    if (err != IdeviceSuccess) {
        logger("Failed to create TCP adapter: %d", err);
        core_device_proxy_free(core_device);
        return 1;
    }
    
    // Connect to RSD port
    err = adapter_connect(adapter, rsd_port);
    if (err != IdeviceSuccess) {
        logger("Failed to connect to RSD port: %d", err);
        adapter_free(adapter);
        return 1;
    }
    logger("Successfully connected to RSD port");
    
    /*****************************************************************
     * XPC Device Setup
     *****************************************************************/
    logger("=== Setting up XPC Device ===");
    
    XPCDeviceAdapterHandle *xpc_device = NULL;
    err = xpc_device_new(adapter, &xpc_device);
    if (err != IdeviceSuccess) {
        logger("Failed to create XPC device: %d", err);
        adapter_free(adapter);
        return 1;
    }
    
    // Get DebugProxy service
    XPCServiceHandle *debug_service = NULL;
    err = xpc_device_get_service(xpc_device, "com.apple.internal.dt.remote.debugproxy", &debug_service);
    if (err != IdeviceSuccess) {
        logger("Failed to get debug proxy service: %d", err);
        xpc_device_free(xpc_device);
        return 1;
    }
    
    // Get ProcessControl service
    XPCServiceHandle *pc_service = NULL;
    err = xpc_device_get_service(xpc_device, "com.apple.instruments.dtservicehub", &pc_service);
    if (err != IdeviceSuccess) {
        logger("Failed to get process control service: %d", err);
        xpc_device_free(xpc_device);
        return 1;
    }
    
    /*****************************************************************
     * Process Control - Launch App
     *****************************************************************/
    logger("=== Launching App ===");
    uint64_t pid;
    
    // Get the adapter back from the XPC device

    AdapterHandle *pc_adapter = NULL;
    err = xpc_device_adapter_into_inner(xpc_device, &pc_adapter);
    if (err != IdeviceSuccess) {
        logger("Failed to extract adapter: %d", err);
        xpc_device_free(xpc_device);
        return 1;
    }
    
    // Connect to process control port
    err = adapter_connect(pc_adapter, pc_service->port);
    if (err != IdeviceSuccess) {
        logger("Failed to connect to process control port: %d", err);
        adapter_free(pc_adapter);
        xpc_service_free(pc_service);
        xpc_service_free(debug_service);
        return 1;
    }
    logger("Successfully connected to process control port");
    
    // Create RemoteServerClient
    RemoteServerAdapterHandle *remote_server = NULL;
    err = remote_server_adapter_new(pc_adapter, &remote_server);
    if (err != IdeviceSuccess) {
        logger("Failed to create remote server: %d", err);
        adapter_free(pc_adapter);
        xpc_service_free(pc_service);
        xpc_service_free(debug_service);
        return 1;
    }
    
    // Create ProcessControlClient
    ProcessControlAdapterHandle *process_control = NULL;
    err = process_control_new(remote_server, &process_control);
    if (err != IdeviceSuccess) {
        logger("Failed to create process control client: %d", err);
        remote_server_free(remote_server);
        xpc_service_free(pc_service);
        xpc_service_free(debug_service);
        return 1;
    }

        
    // Launch application

    err = process_control_launch_app(process_control, bundle_id, NULL, 0, NULL, 0,
                                     true, false, &pid);
    if (err != IdeviceSuccess) {
        logger("Failed to launch app: %d", err);
        process_control_free(process_control);
        remote_server_free(remote_server);
        xpc_service_free(pc_service);
        xpc_service_free(debug_service);
        return 1;
    }
    
    logger("Successfully launched app with PID: %" PRIu64 "", pid);
   
    // Disable memory limit for PID
    err = process_control_disable_memory_limit(process_control, pid);
    if (err != IdeviceSuccess) {
        logger("failed to disable memory limit: %d", err);
    }
    
    /*****************************************************************
     * Debug Proxy - Attach to Process
     *****************************************************************/
    logger("=== Attaching Debugger ===");
    
    // Get the adapter back from the remote server
    AdapterHandle *debug_adapter = NULL;
    err = remote_server_adapter_into_inner(remote_server, &debug_adapter);
    if (err != IdeviceSuccess) {
        logger("Failed to extract adapter: %d", err);
        xpc_service_free(debug_service);
        process_control_free(process_control);
        remote_server_free(remote_server);
        xpc_service_free(pc_service);
        return 1;
    }
    
    // Connect to debug proxy port
    err = adapter_connect(debug_adapter, debug_service->port);
    if (err != IdeviceSuccess) {
        logger("Failed to connect to debug proxy port: %d", err);
        adapter_free(debug_adapter);
        xpc_service_free(debug_service);
        process_control_free(process_control);
        remote_server_free(remote_server);
        xpc_service_free(pc_service);
        return 1;
    }
    logger("Successfully connected to debug proxy port");
    
    // Create DebugProxyClient
    DebugProxyAdapterHandle *debug_proxy = NULL;
    err = debug_proxy_adapter_new(debug_adapter, &debug_proxy);
    if (err != IdeviceSuccess) {
        logger("Failed to create debug proxy client: %d", err);
        adapter_free(debug_adapter);
        xpc_service_free(debug_service);
        process_control_free(process_control);
        remote_server_free(remote_server);
        xpc_service_free(pc_service);
        return 1;
    }
    
    // Send vAttach command with PID in hex
    char attach_command[64];
    snprintf(attach_command, sizeof(attach_command), "vAttach;%" PRIx64, pid);
    
    DebugserverCommandHandle *attach_cmd = debugserver_command_new(attach_command, NULL, 0);
    if (attach_cmd == NULL) {
        logger("Failed to create attach command");
        debug_proxy_free(debug_proxy);
        xpc_service_free(debug_service);
        process_control_free(process_control);
        remote_server_free(remote_server);
        xpc_service_free(pc_service);
        return 1;
    }
    
    char *attach_response = NULL;
    err = debug_proxy_send_command(debug_proxy, attach_cmd, &attach_response);
    debugserver_command_free(attach_cmd);
    
    if (err != IdeviceSuccess) {
        logger("Failed to attach to process: %d", err);
    } else if (attach_response != NULL) {
        logger("Attach response: %s", attach_response);
        idevice_string_free(attach_response);
    }
    
    // Send detach command
    DebugserverCommandHandle *detach_cmd = debugserver_command_new("D", NULL, 0);
    if (detach_cmd == NULL) {
        logger("Failed to create detach command");
    } else {
        char *detach_response = NULL;
        err = debug_proxy_send_command(debug_proxy, detach_cmd, &detach_response);
        err = debug_proxy_send_command(debug_proxy, detach_cmd, &detach_response);
        err = debug_proxy_send_command(debug_proxy, detach_cmd, &detach_response);
        debugserver_command_free(detach_cmd);
        
        if (err != IdeviceSuccess) {
            logger("Failed to detach from process: %d", err);
        } else if (detach_response != NULL) {
            logger("Detach response: %s", detach_response);
            idevice_string_free(detach_response);
        }
    }
    
    /*****************************************************************
     * Cleanup
     *****************************************************************/
    debug_proxy_free(debug_proxy);
    xpc_service_free(debug_service);
    xpc_service_free(pc_service);
    
    logger("Debug session completed");
    return 0;
}


int debug_app_pid(TcpProviderHandle* tcp_provider, int pid, LogFuncC logger) {
    // Connect to CoreDeviceProxy
    CoreDeviceProxyHandle *core_device = NULL;
    IdeviceErrorCode err = core_device_proxy_connect_tcp(tcp_provider, &core_device);
    if (err != IdeviceSuccess) {
        logger("Failed to connect to CoreDeviceProxy: %d", err);
        return 1;
    }
    
    // Get server RSD port
    uint16_t rsd_port;
    err = core_device_proxy_get_server_rsd_port(core_device, &rsd_port);
    if (err != IdeviceSuccess) {
        logger("Failed to get server RSD port: %d", err);
        core_device_proxy_free(core_device);
        return 1;
    }
    logger("Server RSD Port: %d", rsd_port);
    
    /*****************************************************************
     * Create TCP Tunnel Adapter
     *****************************************************************/
    logger("=== Creating TCP Tunnel Adapter ===");
    
    AdapterHandle *adapter = NULL;
    err = core_device_proxy_create_tcp_adapter(core_device, &adapter);
    if (err != IdeviceSuccess) {
        logger("Failed to create TCP adapter: %d", err);
        core_device_proxy_free(core_device);
        return 1;
    }
    
    // Connect to RSD port
    err = adapter_connect(adapter, rsd_port);
    if (err != IdeviceSuccess) {
        logger("Failed to connect to RSD port: %d", err);
        adapter_free(adapter);
        return 1;
    }
    logger("Successfully connected to RSD port");
    
    /*****************************************************************
     * XPC Device Setup
     *****************************************************************/
    logger("=== Setting up XPC Device ===");
    
    XPCDeviceAdapterHandle *xpc_device = NULL;
    err = xpc_device_new(adapter, &xpc_device);
    if (err != IdeviceSuccess) {
        logger("Failed to create XPC device: %d", err);
        adapter_free(adapter);
        return 1;
    }
    
    // Get DebugProxy service
    XPCServiceHandle *debug_service = NULL;
    err = xpc_device_get_service(xpc_device, "com.apple.internal.dt.remote.debugproxy", &debug_service);
    if (err != IdeviceSuccess) {
        logger("Failed to get debug proxy service: %d", err);
        xpc_device_free(xpc_device);
        return 1;
    }
    
    // Get ProcessControl service
    XPCServiceHandle *pc_service = NULL;
    err = xpc_device_get_service(xpc_device, "com.apple.instruments.dtservicehub", &pc_service);
    if (err != IdeviceSuccess) {
        logger("Failed to get process control service: %d", err);
        xpc_device_free(xpc_device);
        return 1;
    }
    
    /*****************************************************************
     * Process Control - Launch App
     *****************************************************************/
    logger("=== Launching App ===");

    // Get the adapter back from the XPC device

    AdapterHandle *pc_adapter = NULL;
    err = xpc_device_adapter_into_inner(xpc_device, &pc_adapter);
    if (err != IdeviceSuccess) {
        logger("Failed to extract adapter: %d", err);
        xpc_device_free(xpc_device);
        return 1;
    }
    
    // Connect to process control port
    err = adapter_connect(pc_adapter, pc_service->port);
    if (err != IdeviceSuccess) {
        logger("Failed to connect to process control port: %d", err);
        adapter_free(pc_adapter);
        xpc_service_free(pc_service);
        xpc_service_free(debug_service);
        return 1;
    }
    logger("Successfully connected to process control port");
    
    // Create RemoteServerClient
    RemoteServerAdapterHandle *remote_server = NULL;
    err = remote_server_adapter_new(pc_adapter, &remote_server);
    if (err != IdeviceSuccess) {
        logger("Failed to create remote server: %d", err);
        adapter_free(pc_adapter);
        xpc_service_free(pc_service);
        xpc_service_free(debug_service);
        return 1;
    }
    
    // Create ProcessControlClient
    ProcessControlAdapterHandle *process_control = NULL;
    err = process_control_new(remote_server, &process_control);
    if (err != IdeviceSuccess) {
        logger("Failed to create process control client: %d", err);
        remote_server_free(remote_server);
        xpc_service_free(pc_service);
        xpc_service_free(debug_service);
        return 1;
    }
   
    // Disable memory limit for PID
    err = process_control_disable_memory_limit(process_control, pid);
    if (err != IdeviceSuccess) {
        logger("failed to disable memory limit: %d", err);
    }
    
    /*****************************************************************
     * Debug Proxy - Attach to Process
     *****************************************************************/
    logger("=== Attaching Debugger ===");
    
    // Get the adapter back from the remote server
    AdapterHandle *debug_adapter = NULL;
    err = remote_server_adapter_into_inner(remote_server, &debug_adapter);
    if (err != IdeviceSuccess) {
        logger("Failed to extract adapter: %d", err);
        xpc_service_free(debug_service);
        process_control_free(process_control);
        remote_server_free(remote_server);
        xpc_service_free(pc_service);
        return 1;
    }
    
    // Connect to debug proxy port
    err = adapter_connect(debug_adapter, debug_service->port);
    if (err != IdeviceSuccess) {
        logger("Failed to connect to debug proxy port: %d", err);
        adapter_free(debug_adapter);
        xpc_service_free(debug_service);
        process_control_free(process_control);
        remote_server_free(remote_server);
        xpc_service_free(pc_service);
        return 1;
    }
    logger("Successfully connected to debug proxy port");
    
    // Create DebugProxyClient
    DebugProxyAdapterHandle *debug_proxy = NULL;
    err = debug_proxy_adapter_new(debug_adapter, &debug_proxy);
    if (err != IdeviceSuccess) {
        logger("Failed to create debug proxy client: %d", err);
        adapter_free(debug_adapter);
        xpc_service_free(debug_service);
        process_control_free(process_control);
        remote_server_free(remote_server);
        xpc_service_free(pc_service);
        return 1;
    }
    
    // Send vAttach command with PID in hex
    char attach_command[64];
    snprintf(attach_command, sizeof(attach_command), "vAttach;%" PRIx64, pid);
    
    DebugserverCommandHandle *attach_cmd = debugserver_command_new(attach_command, NULL, 0);
    if (attach_cmd == NULL) {
        logger("Failed to create attach command");
        debug_proxy_free(debug_proxy);
        xpc_service_free(debug_service);
        process_control_free(process_control);
        remote_server_free(remote_server);
        xpc_service_free(pc_service);
        return 1;
    }
    
    char *attach_response = NULL;
    err = debug_proxy_send_command(debug_proxy, attach_cmd, &attach_response);
    debugserver_command_free(attach_cmd);
    
    if (err != IdeviceSuccess) {
        logger("Failed to attach to process: %d", err);
    } else if (attach_response != NULL) {
        logger("Attach response: %s", attach_response);
        idevice_string_free(attach_response);
    }
    
    // Send detach command
    DebugserverCommandHandle *detach_cmd = debugserver_command_new("D", NULL, 0);
    if (detach_cmd == NULL) {
        logger("Failed to create detach command");
    } else {
        char *detach_response = NULL;
        err = debug_proxy_send_command(debug_proxy, detach_cmd, &detach_response);
        err = debug_proxy_send_command(debug_proxy, detach_cmd, &detach_response);
        err = debug_proxy_send_command(debug_proxy, detach_cmd, &detach_response);
        debugserver_command_free(detach_cmd);
        
        if (err != IdeviceSuccess) {
            logger("Failed to detach from process: %d", err);
        } else if (detach_response != NULL) {
            logger("Detach response: %s", detach_response);
            idevice_string_free(detach_response);
        }
    }
    
    /*****************************************************************
     * Cleanup
     *****************************************************************/
    debug_proxy_free(debug_proxy);
    xpc_service_free(debug_service);
    xpc_service_free(pc_service);
    
    logger("Debug session completed");
    return 0;
}
