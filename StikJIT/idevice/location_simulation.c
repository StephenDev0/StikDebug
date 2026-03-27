//
//  location_simulation.c
//  StikDebug
//
//  Created by Stephen on 8/3/25.
//

#include "location_simulation.h"
#include "idevice.h"
#include <arpa/inet.h>
#include <netinet/in.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

static AdapterHandle            *g_adapter       = NULL;
static RsdHandshakeHandle       *g_handshake     = NULL;
static RemoteServerHandle       *g_remote_server = NULL;
static LocationSimulationHandle *g_location_sim  = NULL;

static void cleanup_on_error(void) {
    if (g_location_sim)  { location_simulation_free(g_location_sim);    g_location_sim  = NULL; }
    if (g_remote_server) { remote_server_free(g_remote_server);         g_remote_server = NULL; }
    if (g_handshake)     { rsd_handshake_free(g_handshake);             g_handshake     = NULL; }
    if (g_adapter)       { adapter_free(g_adapter);                    g_adapter       = NULL; }
}

int simulate_location(const char *device_ip,
                      double latitude,
                      double longitude,
                      const char *pairing_file)
{
    IdeviceFfiError *err = NULL;

    if (g_location_sim) {
        if ((err = location_simulation_set(g_location_sim, latitude, longitude))) {
            idevice_error_free(err);
            cleanup_on_error();
        } else {
            return IPA_OK;
        }
    }

    struct sockaddr_in addr = { .sin_family = AF_INET,
                                .sin_port   = htons(LOCKDOWN_PORT) };
    if (inet_pton(AF_INET, device_ip, &addr.sin_addr) != 1) {
        return IPA_ERR_INVALID_IP;
    }

    RpPairingFileHandle *rp_pairing = NULL;
    if ((err = rp_pairing_file_read(pairing_file, &rp_pairing))) {
        idevice_error_free(err);
        return IPA_ERR_PAIRING_READ;
    }

    if ((err = tunnel_create_rppairing(
            (const idevice_sockaddr *)&addr,
            sizeof(addr),
            "StikDebugLocation",
            rp_pairing,
            NULL,
            NULL,
            &g_adapter,
            &g_handshake)))
    {
        idevice_error_free(err);
        rp_pairing_file_free(rp_pairing);
        cleanup_on_error();
        return IPA_ERR_PROVIDER_CREATE;
    }
    rp_pairing_file_free(rp_pairing);

    if ((err = remote_server_connect_rsd(g_adapter,
                                         g_handshake,
                                         &g_remote_server)))
    {
        idevice_error_free(err);
        cleanup_on_error();
        return IPA_ERR_REMOTE_SERVER;
    }

    if ((err = location_simulation_new(g_remote_server,
                                       &g_location_sim))) {
        idevice_error_free(err);
        cleanup_on_error();
        return IPA_ERR_LOCATION_SIM;
    }
    // location_simulation_new takes ownership of g_remote_server.
    g_remote_server = NULL;

    if ((err = location_simulation_set(g_location_sim,
                                       latitude,
                                       longitude))) {
        idevice_error_free(err);
        cleanup_on_error();
        return IPA_ERR_LOCATION_SET;
    }

    return IPA_OK;
}

int clear_simulated_location(void)
{
    IdeviceFfiError *err = NULL;
    if (!g_location_sim) return IPA_ERR_LOCATION_CLEAR;

    err = location_simulation_clear(g_location_sim);
    cleanup_on_error();

    return err ? IPA_ERR_LOCATION_CLEAR : IPA_OK;
}
