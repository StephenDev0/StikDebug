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

void runDebugServerCommand(int pid, DebugProxyHandle* debug_proxy, LogFuncC logger, DebugAppCallback callback) {
    // enable QStartNoAckMode
    char *disableResponse = NULL;
    debug_proxy_send_ack(debug_proxy);
    debug_proxy_send_ack(debug_proxy);
    DebugserverCommandHandle *disableAckCommand = debugserver_command_new("QStartNoAckMode", NULL, 0);
    IdeviceFfiError* err = debug_proxy_send_command(debug_proxy, disableAckCommand, &disableResponse);
    debugserver_command_free(disableAckCommand);
    logger("QStartNoAckMode result = %s, err = %d", disableResponse, err);
    idevice_string_free(disableResponse);
    debug_proxy_set_ack_mode(debug_proxy, false);
    
    if(callback) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        callback(pid, debug_proxy, semaphore);
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        err = debug_proxy_send_raw(debug_proxy, "\x03", 1);
        usleep(500);
    } else {
        // Send vAttach command with PID in hex
        char attach_command[64];
        snprintf(attach_command, sizeof(attach_command), "vAttach;%" PRIx64, pid);
        
        DebugserverCommandHandle *attach_cmd = debugserver_command_new(attach_command, NULL, 0);
        if (attach_cmd == NULL) {
            logger("Failed to create attach command");
            return;
        }
        
        char *attach_response = NULL;
        err = debug_proxy_send_command(debug_proxy, attach_cmd, &attach_response);
        debugserver_command_free(attach_cmd);
        
        if (err) {
            logger("Failed to attach to process: %d", err);
        } else if (attach_response != NULL) {
            logger("Attach response: %s", attach_response);
            idevice_string_free(attach_response);
        }
        
    }

    // Send detach command
    DebugserverCommandHandle *detach_cmd = debugserver_command_new("D", NULL, 0);
    if (detach_cmd == NULL) {
        logger("Failed to create detach command");
    } else {
        char *detach_response = NULL;
        err = debug_proxy_send_command(debug_proxy, detach_cmd, &detach_response);
        debugserver_command_free(detach_cmd);
        
        if (err) {
            logger("Failed to detach from process: %d", err->code);
            idevice_error_free(err);
        } else if (detach_response != NULL) {
            logger("Detach response: %s", detach_response);
            idevice_string_free(detach_response);
        }
    }
}

int debug_app(IdeviceProviderHandle* tcp_provider, const char *bundle_id, LogFuncC logger, DebugAppCallback callback) {
    // Initialize logger
    idevice_init_logger(Info, Disabled, NULL);
    IdeviceFfiError* err = 0;
    
    CoreDeviceProxyHandle *core_device = NULL;
    err = core_device_proxy_connect(tcp_provider, &core_device);
    if (err != NULL) {
      fprintf(stderr, "Failed to connect to CoreDeviceProxy: [%d] %s\n",
              err->code, err->message);
      idevice_error_free(err);
      return 1;
    }

    uint16_t rsd_port;
    err = core_device_proxy_get_server_rsd_port(core_device, &rsd_port);
    if (err != NULL) {
      fprintf(stderr, "Failed to get server RSD port: [%d] %s\n", err->code,
              err->message);
      idevice_error_free(err);
      core_device_proxy_free(core_device);
      return 1;
    }
    printf("Server RSD Port: %d\n", rsd_port);

    printf("\n=== Creating TCP Tunnel Adapter ===\n");

    AdapterHandle *adapter = NULL;
    err = core_device_proxy_create_tcp_adapter(core_device, &adapter);
    if (err != NULL) {
      fprintf(stderr, "Failed to create TCP adapter: [%d] %s\n", err->code,
              err->message);
      idevice_error_free(err);
      return 1;
    }

    AdapterStreamHandle *stream = NULL;
    err = adapter_connect(adapter, rsd_port, (ReadWriteOpaque **)&stream);
    if (err != NULL) {
      fprintf(stderr, "Failed to connect to RSD port: [%d] %s\n", err->code,
              err->message);
      idevice_error_free(err);
      adapter_free(adapter);
      return 1;
    }
    printf("Successfully connected to RSD port\n");

    printf("\n=== Performing RSD Handshake ===\n");

    RsdHandshakeHandle *handshake = NULL;
    err = rsd_handshake_new((ReadWriteOpaque *)stream, &handshake);
    if (err != NULL) {
      fprintf(stderr, "Failed to perform RSD handshake: [%d] %s\n", err->code,
              err->message);
      idevice_error_free(err);
      adapter_close(stream);
      adapter_free(adapter);
      return 1;
    }
    
    // Create RemoteServerClient
    RemoteServerHandle *remote_server = NULL;
    err = remote_server_connect_rsd(adapter, handshake, &remote_server);
    if (err != NULL) {
      fprintf(stderr, "Failed to create remote server: [%d] %s", err->code,
              err->message);
      idevice_error_free(err);
      adapter_free(adapter);
      rsd_handshake_free(handshake);
      return 1;
    }

    printf("\n=== Testing Process Control ===\n");

    // Create ProcessControlClient
    ProcessControlHandle *process_control = NULL;
    err = process_control_new(remote_server, &process_control);
    if (err != NULL) {
      fprintf(stderr, "Failed to create process control client: [%d] %s",
              err->code, err->message);
      idevice_error_free(err);
      remote_server_free(remote_server);
      return 1;
    }

    // Launch application
    uint64_t pid;
    err = process_control_launch_app(process_control, bundle_id, NULL, 0, NULL, 0,
                                     true, false, &pid);
    if (err != NULL) {
      fprintf(stderr, "Failed to launch app: [%d] %s", err->code, err->message);
      idevice_error_free(err);
      process_control_free(process_control);
      remote_server_free(remote_server);
      return 1;
    }
    printf("Successfully launched app with PID: %llu\n", pid);

    printf("\n=== Setting up Debug Proxy ===\n");

    DebugProxyHandle *debug_proxy = NULL;
    err = debug_proxy_connect_rsd(adapter, handshake, &debug_proxy);
    if (err != NULL) {
      fprintf(stderr, "Failed to create debug proxy client: [%d] %s\n", err->code,
              err->message);
      idevice_error_free(err);
      rsd_handshake_free(handshake);
      adapter_free(adapter);
      return 1;
    }
    
    runDebugServerCommand((int)pid, debug_proxy, logger, callback);
    
    /*****************************************************************
     * Cleanup
     *****************************************************************/
    debug_proxy_free(debug_proxy);
    process_control_free(process_control);
    remote_server_free(remote_server);
    rsd_handshake_free(handshake);
    adapter_free(adapter);
    
    logger("Debug session completed");
    return 0;
}


int debug_app_pid(IdeviceProviderHandle* tcp_provider, int pid, LogFuncC logger, DebugAppCallback callback) {
    IdeviceFfiError* err = 0;
    
    CoreDeviceProxyHandle *core_device = NULL;
    err = core_device_proxy_connect(tcp_provider, &core_device);
    if (err != NULL) {
      fprintf(stderr, "Failed to connect to CoreDeviceProxy: [%d] %s\n",
              err->code, err->message);
      idevice_error_free(err);
      return 1;
    }

    uint16_t rsd_port;
    err = core_device_proxy_get_server_rsd_port(core_device, &rsd_port);
    if (err != NULL) {
      fprintf(stderr, "Failed to get server RSD port: [%d] %s\n", err->code,
              err->message);
      idevice_error_free(err);
      core_device_proxy_free(core_device);
      return 1;
    }
    printf("Server RSD Port: %d\n", rsd_port);

    printf("\n=== Creating TCP Tunnel Adapter ===\n");

    AdapterHandle *adapter = NULL;
    err = core_device_proxy_create_tcp_adapter(core_device, &adapter);
    if (err != NULL) {
      fprintf(stderr, "Failed to create TCP adapter: [%d] %s\n", err->code,
              err->message);
      idevice_error_free(err);
      return 1;
    }

    AdapterStreamHandle *stream = NULL;
    err = adapter_connect(adapter, rsd_port, (ReadWriteOpaque **)&stream);
    if (err != NULL) {
      fprintf(stderr, "Failed to connect to RSD port: [%d] %s\n", err->code,
              err->message);
      idevice_error_free(err);
      adapter_free(adapter);
      return 1;
    }
    printf("Successfully connected to RSD port\n");

    printf("\n=== Performing RSD Handshake ===\n");

    RsdHandshakeHandle *handshake = NULL;
    err = rsd_handshake_new((ReadWriteOpaque *)stream, &handshake);
    if (err != NULL) {
      fprintf(stderr, "Failed to perform RSD handshake: [%d] %s\n", err->code,
              err->message);
      idevice_error_free(err);
      adapter_close(stream);
      adapter_free(adapter);
      return 1;
    }
    
    // Create RemoteServerClient
    RemoteServerHandle *remote_server = NULL;
    err = remote_server_connect_rsd(adapter, handshake, &remote_server);
    if (err != NULL) {
      fprintf(stderr, "Failed to create remote server: [%d] %s", err->code,
              err->message);
      idevice_error_free(err);
      adapter_free(adapter);
      rsd_handshake_free(handshake);
      return 1;
    }

    printf("\n=== Setting up Debug Proxy ===\n");

    DebugProxyHandle *debug_proxy = NULL;
    err = debug_proxy_connect_rsd(adapter, handshake, &debug_proxy);
    if (err != NULL) {
      fprintf(stderr, "Failed to create debug proxy client: [%d] %s\n", err->code,
              err->message);
      idevice_error_free(err);
      rsd_handshake_free(handshake);
      adapter_free(adapter);
      return 1;
    }
    
    
    runDebugServerCommand(pid, debug_proxy, logger, callback);
    
    /*****************************************************************
     * Cleanup
     *****************************************************************/
    debug_proxy_free(debug_proxy);
    rsd_handshake_free(handshake);
    adapter_free(adapter);
    
    logger("Debug session completed");
    return 0;
}
