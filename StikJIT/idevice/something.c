//
//  something.c
//  StikDebug
//
//  Created by Stephen on 7/29/25.
//

#include "something.h"

#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/fcntl.h>
#include <unistd.h>

static int mmap_file(const char *path, uint8_t **data, size_t *len)
{
    int fd = open(path, O_RDONLY);
    if (fd < 0) {
        perror("open");
        return 0;
    }
    struct stat st;
    if (fstat(fd, &st) != 0) {
        perror("fstat");
        close(fd);
        return 0;
    }
    *len  = (size_t)st.st_size;
    *data = mmap(NULL, *len, PROT_READ, MAP_PRIVATE, fd, 0);
    close(fd);
    if (*data == MAP_FAILED) {
        perror("mmap");
        return 0;
    }
    return 1;
}

static void munmap_file(uint8_t *data, size_t len)
{
    if (data && data != MAP_FAILED) {
        munmap(data, len);
    }
}

int install_ipa(const char *ip,
                const char *pairing_file_path,
                const char *udid,
                const char *ipa_path)
{
    (void)udid;
    idevice_init_logger(Debug, Disabled, NULL);

    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_port   = htons(LOCKDOWN_PORT);
    if (inet_pton(AF_INET, ip, &addr.sin_addr) != 1) {
        fprintf(stderr, "Invalid IP address: %s\n", ip);
        return IPA_ERR_INVALID_IP;
    }

    IdevicePairingFile *pairing_file = NULL;
    IdeviceFfiError *err = idevice_pairing_file_read(pairing_file_path,
                                                     &pairing_file);
    if (err) {
        fprintf(stderr, "Pairing file read failed: [%d] %s\n",
                err->code, err->message);
        idevice_error_free(err);
        return IPA_ERR_PAIRING_READ;
    }

    IdeviceProviderHandle *provider = NULL;
    err = idevice_tcp_provider_new((struct sockaddr *)&addr,
                                   pairing_file,
                                   "IPAInstaller",
                                   &provider);
    if (err) {
        fprintf(stderr, "Provider create failed: [%d] %s\n",
                err->code, err->message);
        idevice_pairing_file_free(pairing_file);
        idevice_error_free(err);
        return IPA_ERR_PROVIDER_CREATE;
    }

    AfcClientHandle *afc = NULL;
    err = afc_client_connect(provider, &afc);
    if (err) {
        fprintf(stderr, "AFC connect failed: [%d] %s\n",
                err->code, err->message);
        idevice_provider_free(provider);
        idevice_pairing_file_free(pairing_file);
        idevice_error_free(err);
        return IPA_ERR_AFC_CONNECT;
    }

    uint8_t *ipa_data = NULL;
    size_t   ipa_len  = 0;
    if (!mmap_file(ipa_path, &ipa_data, &ipa_len)) {
        fprintf(stderr, "Unable to read IPA file\n");
        afc_client_free(afc);
        idevice_provider_free(provider);
        idevice_pairing_file_free(pairing_file);
        return IPA_ERR_IPA_READ;
    }

    const char *slash = strrchr(ipa_path, '/');
    const char *fname = slash ? slash + 1 : ipa_path;
    char dest[256];
    snprintf(dest, sizeof(dest), "/PublicStaging/%s", fname);

    AfcFileHandle *remote = NULL;
    err = afc_file_open(afc, dest, AfcWrOnly, &remote);
    if (err) {
        fprintf(stderr, "AFC open failed: [%d] %s\n",
                err->code, err->message);
        munmap_file(ipa_data, ipa_len);
        afc_client_free(afc);
        idevice_provider_free(provider);
        idevice_pairing_file_free(pairing_file);
        idevice_error_free(err);
        return IPA_ERR_AFC_OPEN;
    }

    err = afc_file_write(remote, ipa_data, ipa_len);
    afc_file_close(remote);
    munmap_file(ipa_data, ipa_len);
    if (err) {
        fprintf(stderr, "AFC write failed: [%d] %s\n",
                err->code, err->message);
        afc_client_free(afc);
        idevice_provider_free(provider);
        idevice_pairing_file_free(pairing_file);
        idevice_error_free(err);
        return IPA_ERR_AFC_WRITE;
    }

    InstallationProxyClientHandle *ipc = NULL;
    err = installation_proxy_connect(provider, &ipc);
    if (err) {
        fprintf(stderr, "installation_proxy connect failed: [%d] %s\n",
                err->code, err->message);
        afc_client_free(afc);
        idevice_provider_free(provider);
        idevice_pairing_file_free(pairing_file);
        idevice_error_free(err);
        return IPA_ERR_INSTALLPROXY_CONNECT;
    }

    err = installation_proxy_install(ipc, dest, NULL);
    installation_proxy_client_free(ipc);
    afc_client_free(afc);
    idevice_provider_free(provider);

    if (err) {
        fprintf(stderr, "IPA install failed: [%d] %s\n",
                err->code, err->message);
        idevice_error_free(err);
        return IPA_ERR_INSTALL;
    }

    fprintf(stderr, "IPA installed successfully\n");
    return IPA_OK;
}
