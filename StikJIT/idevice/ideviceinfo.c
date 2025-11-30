//
//  ideviceinfo.c
//  StikDebug
//
//  Created by Stephen on 8/2/25.
//

#include <stdlib.h>
#include <arpa/inet.h>
#include "ideviceinfo.h"
#include "idevice.h"

static struct IdeviceProviderHandle *   g_provider = NULL;
static struct HeartbeatClientHandle *   g_hb       = NULL;
static struct LockdowndClientHandle *   g_client   = NULL;
static struct IdevicePairingFile *      g_sess_pf  = NULL;

int ideviceinfo_c_init(const char *pairing_file_path) {
    if (g_provider) {
        return 0;
    }

    struct IdevicePairingFile *pf = NULL;
    struct IdeviceFfiError *err = idevice_pairing_file_read(pairing_file_path, &pf);
    if (err) {
        idevice_error_free(err);
        return 1;
    }

    struct sockaddr_in sin = { .sin_family = AF_INET,
                               .sin_port   = htons(LOCKDOWN_PORT) };
    inet_pton(AF_INET, "10.7.0.2", &sin.sin_addr);

    err = idevice_tcp_provider_new((const struct sockaddr *)&sin,
                                   pf,
                                   "ideviceinfo-c",
                                   &g_provider);
    if (err) {
        idevice_error_free(err);
        idevice_pairing_file_free(pf);
        return 2;
    }

    err = heartbeat_connect(g_provider, &g_hb);
    if (!err) {
        heartbeat_send_polo(g_hb);
    } else {
        idevice_error_free(err);
    }

    err = lockdownd_connect(g_provider, &g_client);
    if (err) {
        idevice_error_free(err);
        return 3;
    }

    err = idevice_pairing_file_read(pairing_file_path, &g_sess_pf);
    if (err) {
        idevice_error_free(err);
        lockdownd_client_free(g_client);
        g_client = NULL;
        return 4;
    }

    err = lockdownd_start_session(g_client, g_sess_pf);
    if (err) {
        idevice_error_free(err);
        lockdownd_client_free(g_client);
        g_client = NULL;
        return 4; 
    }

    return 0;
}

char *ideviceinfo_c_get_xml(void) {
    if (!g_client) {
        return NULL;
    }

    void *plist_obj = NULL;
    struct IdeviceFfiError *err = lockdownd_get_value(g_client, NULL, NULL, &plist_obj);
    if (err) {
        idevice_error_free(err);
        return NULL;
    }

    char *xml = NULL;
    uint32_t xml_len = 0;
    if (plist_to_xml(plist_obj, &xml, &xml_len) != 0 || !xml) {
        plist_free(plist_obj);
        return NULL;
    }
    plist_free(plist_obj);
    return xml;
}

void ideviceinfo_c_cleanup(void) {
    if (g_client) {
        lockdownd_client_free(g_client);
        g_client = NULL;
    }
    if (g_sess_pf) {
        idevice_pairing_file_free(g_sess_pf);
        g_sess_pf = NULL;
    }
    if (g_hb) {
        heartbeat_client_free(g_hb);
        g_hb = NULL;
    }
    if (g_provider) {
        idevice_provider_free(g_provider);
        g_provider = NULL;
    }
}
