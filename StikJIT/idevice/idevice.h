// Jackson Coxson
// Bindings to idevice - https://github.com/jkcoxson/idevice


#ifndef IDEVICE_H
#define IDEVICE_H

#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <sys/socket.h>
#include "plist.h"

#define LOCKDOWN_PORT 62078

typedef enum AfcFopenMode {
  AfcRdOnly = 1,
  AfcRw = 2,
  AfcWrOnly = 3,
  AfcWr = 4,
  AfcAppend = 5,
  AfcRdAppend = 6,
} AfcFopenMode;

/**
 * Link type for creating hard or symbolic links
 */
typedef enum AfcLinkType {
  Hard = 1,
  Symbolic = 2,
} AfcLinkType;

typedef enum IdeviceLogLevel {
  Disabled = 0,
  ErrorLevel = 1,
  Warn = 2,
  Info = 3,
  Debug = 4,
  Trace = 5,
} IdeviceLogLevel;

typedef enum IdeviceLoggerError {
  Success = 0,
  FileError = -1,
  AlreadyInitialized = -2,
  InvalidPathString = -3,
} IdeviceLoggerError;

typedef struct AdapterHandle AdapterHandle;

typedef struct AdapterStreamHandle AdapterStreamHandle;

typedef struct AfcClientHandle AfcClientHandle;

/**
 * Handle for an open file on the device
 */
typedef struct AfcFileHandle AfcFileHandle;

typedef struct AmfiClientHandle AmfiClientHandle;

typedef struct CoreDeviceProxyHandle CoreDeviceProxyHandle;

/**
 * Opaque handle to a DebugProxyClient
 */
typedef struct DebugProxyHandle DebugProxyHandle;

typedef struct HeartbeatClientHandle HeartbeatClientHandle;

/**
 * Opaque C-compatible handle to an Idevice connection
 */
typedef struct IdeviceHandle IdeviceHandle;

/**
 * Opaque C-compatible handle to a PairingFile
 */
typedef struct IdevicePairingFile IdevicePairingFile;

typedef struct IdeviceProviderHandle IdeviceProviderHandle;

typedef struct IdeviceSocketHandle IdeviceSocketHandle;

typedef struct ImageMounterHandle ImageMounterHandle;

typedef struct InstallationProxyClientHandle InstallationProxyClientHandle;

/**
 * Opaque handle to a ProcessControlClient
 */
typedef struct LocationSimulationHandle LocationSimulationHandle;

typedef struct LockdowndClientHandle LockdowndClientHandle;

typedef struct MisagentClientHandle MisagentClientHandle;

typedef struct OsTraceRelayClientHandle OsTraceRelayClientHandle;

typedef struct OsTraceRelayReceiverHandle OsTraceRelayReceiverHandle;

/**
 * Opaque handle to a ProcessControlClient
 */
typedef struct ProcessControlHandle ProcessControlHandle;

typedef struct ReadWriteOpaque ReadWriteOpaque;

/**
 * Opaque handle to a RemoteServerClient
 */
typedef struct RemoteServerHandle RemoteServerHandle;

/**
 * Opaque handle to an RsdHandshake
 */
typedef struct RsdHandshakeHandle RsdHandshakeHandle;

typedef struct SpringBoardServicesClientHandle SpringBoardServicesClientHandle;

typedef struct SyslogRelayClientHandle SyslogRelayClientHandle;

typedef struct UsbmuxdAddrHandle UsbmuxdAddrHandle;

typedef struct UsbmuxdConnectionHandle UsbmuxdConnectionHandle;

typedef struct Vec_u64 Vec_u64;

typedef struct sockaddr sockaddr;

typedef struct IdeviceFfiError {
  int32_t code;
  const char *message;
} IdeviceFfiError;

/**
 * File information structure for C bindings
 */
typedef struct AfcFileInfo {
  size_t size;
  size_t blocks;
  int64_t creation;
  int64_t modified;
  char *st_nlink;
  char *st_ifmt;
  char *st_link_target;
} AfcFileInfo;

/**
 * Device information structure for C bindings
 */
typedef struct AfcDeviceInfo {
  char *model;
  size_t total_bytes;
  size_t free_bytes;
  size_t block_size;
} AfcDeviceInfo;

/**
 * Represents a debugserver command
 */
typedef struct DebugserverCommandHandle {
  char *name;
  char **argv;
  uintptr_t argv_count;
} DebugserverCommandHandle;

typedef struct SyslogLabel {
  const char *subsystem;
  const char *category;
} SyslogLabel;

typedef struct OsTraceLog {
  uint32_t pid;
  int64_t timestamp;
  uint8_t level;
  const char *image_name;
  const char *filename;
  const char *message;
  const struct SyslogLabel *label;
} OsTraceLog;

/**
 * C-compatible representation of an RSD service
 */
typedef struct CRsdService {
  /**
   * Service name (null-terminated string)
   */
  char *name;
  /**
   * Required entitlement (null-terminated string)
   */
  char *entitlement;
  /**
   * Port number
   */
  uint16_t port;
  /**
   * Whether service uses remote XPC
   */
  bool uses_remote_xpc;
  /**
   * Number of features
   */
  size_t features_count;
  /**
   * Array of feature strings
   */
  char **features;
  /**
   * Service version (-1 if not present)
   */
  int64_t service_version;
} CRsdService;

/**
 * Array of RSD services returned by rsd_get_services
 */
typedef struct CRsdServiceArray {
  /**
   * Array of services
   */
  struct CRsdService *services;
  /**
   * Number of services in array
   */
  size_t count;
} CRsdServiceArray;

/**
 * Creates a new Idevice connection
 *
 * # Arguments
 * * [`socket`] - Socket for communication with the device
 * * [`label`] - Label for the connection
 * * [`idevice`] - On success, will be set to point to a newly allocated Idevice handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `label` must be a valid null-terminated C string
 * `idevice` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *idevice_new(struct IdeviceSocketHandle *socket,
                                    const char *label,
                                    struct IdeviceHandle **idevice);

/**
 * Creates a new Idevice connection
 *
 * # Arguments
 * * [`addr`] - The socket address to connect to
 * * [`addr_len`] - Length of the socket
 * * [`label`] - Label for the connection
 * * [`idevice`] - On success, will be set to point to a newly allocated Idevice handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `addr` must be a valid sockaddr
 * `label` must be a valid null-terminated C string
 * `idevice` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *idevice_new_tcp_socket(const struct sockaddr *addr,
                                               socklen_t addr_len,
                                               const char *label,
                                               struct IdeviceHandle **idevice);

/**
 * Gets the device type
 *
 * # Arguments
 * * [`idevice`] - The Idevice handle
 * * [`device_type`] - On success, will be set to point to a newly allocated string containing the device type
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `idevice` must be a valid, non-null pointer to an Idevice handle
 * `device_type` must be a valid, non-null pointer to a location where the string pointer will be stored
 */
struct IdeviceFfiError *idevice_get_type(struct IdeviceHandle *idevice,
                                         char **device_type);

/**
 * Performs RSD checkin
 *
 * # Arguments
 * * [`idevice`] - The Idevice handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `idevice` must be a valid, non-null pointer to an Idevice handle
 */
struct IdeviceFfiError *idevice_rsd_checkin(struct IdeviceHandle *idevice);

/**
 * Starts a TLS session
 *
 * # Arguments
 * * [`idevice`] - The Idevice handle
 * * [`pairing_file`] - The pairing file to use for TLS
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `idevice` must be a valid, non-null pointer to an Idevice handle
 * `pairing_file` must be a valid, non-null pointer to a pairing file handle
 */
struct IdeviceFfiError *idevice_start_session(struct IdeviceHandle *idevice,
                                              const struct IdevicePairingFile *pairing_file);

/**
 * Frees an Idevice handle
 *
 * # Arguments
 * * [`idevice`] - The Idevice handle to free
 *
 * # Safety
 * `idevice` must be a valid pointer to an Idevice handle that was allocated by this library,
 * or NULL (in which case this function does nothing)
 */
void idevice_free(struct IdeviceHandle *idevice);

/**
 * Frees a string allocated by this library
 *
 * # Arguments
 * * [`string`] - The string to free
 *
 * # Safety
 * `string` must be a valid pointer to a string that was allocated by this library,
 * or NULL (in which case this function does nothing)
 */
void idevice_string_free(char *string);

/**
 * Connects the adapter to a specific port
 *
 * # Arguments
 * * [`adapter_handle`] - The adapter handle
 * * [`port`] - The port to connect to
 * * [`stream_handle`] - A pointer to allocate the new stream to
 *
 * # Returns
 * Null on success, an IdeviceFfiError otherwise
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library.
 * Any stream allocated must be used in the same thread as the adapter. The handles are NOT thread
 * safe.
 */
struct IdeviceFfiError *adapter_connect(struct AdapterHandle *adapter_handle,
                                        uint16_t port,
                                        struct ReadWriteOpaque **stream_handle);

/**
 * Enables PCAP logging for the adapter
 *
 * # Arguments
 * * [`handle`] - The adapter handle
 * * [`path`] - The path to save the PCAP file (null-terminated string)
 *
 * # Returns
 * Null on success, an IdeviceFfiError otherwise
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library
 * `path` must be a valid null-terminated string
 */
struct IdeviceFfiError *adapter_pcap(struct AdapterHandle *handle, const char *path);

/**
 * Closes the adapter connection
 *
 * # Arguments
 * * [`handle`] - The adapter stream handle
 *
 * # Returns
 * Null on success, an IdeviceFfiError otherwise
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library
 */
struct IdeviceFfiError *adapter_close(struct AdapterStreamHandle *handle);

/**
 * Sends data through the adapter
 *
 * # Arguments
 * * [`handle`] - The adapter handle
 * * [`data`] - The data to send
 * * [`length`] - The length of the data
 *
 * # Returns
 * Null on success, an IdeviceFfiError otherwise
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library
 * `data` must be a valid pointer to at least `length` bytes
 */
struct IdeviceFfiError *adapter_send(struct AdapterStreamHandle *handle,
                                     const uint8_t *data,
                                     uintptr_t length);

/**
 * Receives data from the adapter
 *
 * # Arguments
 * * [`handle`] - The adapter handle
 * * [`data`] - Pointer to a buffer where the received data will be stored
 * * [`length`] - Pointer to store the actual length of received data
 * * [`max_length`] - Maximum number of bytes that can be stored in `data`
 *
 * # Returns
 * Null on success, an IdeviceFfiError otherwise
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library
 * `data` must be a valid pointer to at least `max_length` bytes
 * `length` must be a valid pointer to a usize
 */
struct IdeviceFfiError *adapter_recv(struct AdapterStreamHandle *handle,
                                     uint8_t *data,
                                     uintptr_t *length,
                                     uintptr_t max_length);

/**
 * Connects to the AFC service using a TCP provider
 *
 * # Arguments
 * * [`provider`] - An IdeviceProvider
 * * [`client`] - On success, will be set to point to a newly allocated AfcClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `provider` must be a valid pointer to a handle allocated by this library
 * `client` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *afc_client_connect(struct IdeviceProviderHandle *provider,
                                           struct AfcClientHandle **client);

/**
 * Creates a new AfcClient from an existing Idevice connection
 *
 * # Arguments
 * * [`socket`] - An IdeviceSocket handle
 * * [`client`] - On success, will be set to point to a newly allocated AfcClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `socket` must be a valid pointer to a handle allocated by this library
 * `client` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *afc_client_new(struct IdeviceHandle *socket,
                                       struct AfcClientHandle **client);

/**
 * Frees an AfcClient handle
 *
 * # Arguments
 * * [`handle`] - The handle to free
 *
 * # Safety
 * `handle` must be a valid pointer to the handle that was allocated by this library,
 * or NULL (in which case this function does nothing)
 */
void afc_client_free(struct AfcClientHandle *handle);

/**
 * Lists the contents of a directory on the device
 *
 * # Arguments
 * * [`client`] - A valid AfcClient handle
 * * [`path`] - Path to the directory to list (UTF-8 null-terminated)
 * * [`entries`] - Will be set to point to an array of directory entries
 * * [`count`] - Will be set to the number of entries
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * All pointers must be valid and non-null
 * `path` must be a valid null-terminated C string
 */
struct IdeviceFfiError *afc_list_directory(struct AfcClientHandle *client,
                                           const char *path,
                                           char ***entries,
                                           size_t *count);

/**
 * Creates a new directory on the device
 *
 * # Arguments
 * * [`client`] - A valid AfcClient handle
 * * [`path`] - Path of the directory to create (UTF-8 null-terminated)
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `path` must be a valid null-terminated C string
 */
struct IdeviceFfiError *afc_make_directory(struct AfcClientHandle *client, const char *path);

/**
 * Retrieves information about a file or directory
 *
 * # Arguments
 * * [`client`] - A valid AfcClient handle
 * * [`path`] - Path to the file or directory (UTF-8 null-terminated)
 * * [`info`] - Will be populated with file information
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` and `path` must be valid pointers
 * `info` must be a valid pointer to an AfcFileInfo struct
 */
struct IdeviceFfiError *afc_get_file_info(struct AfcClientHandle *client,
                                          const char *path,
                                          struct AfcFileInfo *info);

/**
 * Frees memory allocated by afc_get_file_info
 *
 * # Arguments
 * * [`info`] - Pointer to AfcFileInfo struct to free
 *
 * # Safety
 * `info` must be a valid pointer to an AfcFileInfo struct previously returned by afc_get_file_info
 */
void afc_file_info_free(struct AfcFileInfo *info);

/**
 * Retrieves information about the device's filesystem
 *
 * # Arguments
 * * [`client`] - A valid AfcClient handle
 * * [`info`] - Will be populated with device information
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` and `info` must be valid pointers
 */
struct IdeviceFfiError *afc_get_device_info(struct AfcClientHandle *client,
                                            struct AfcDeviceInfo *info);

/**
 * Frees memory allocated by afc_get_device_info
 *
 * # Arguments
 * * [`info`] - Pointer to AfcDeviceInfo struct to free
 *
 * # Safety
 * `info` must be a valid pointer to an AfcDeviceInfo struct previously returned by afc_get_device_info
 */
void afc_device_info_free(struct AfcDeviceInfo *info);

/**
 * Removes a file or directory
 *
 * # Arguments
 * * [`client`] - A valid AfcClient handle
 * * [`path`] - Path to the file or directory to remove (UTF-8 null-terminated)
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `path` must be a valid null-terminated C string
 */
struct IdeviceFfiError *afc_remove_path(struct AfcClientHandle *client, const char *path);

/**
 * Recursively removes a directory and all its contents
 *
 * # Arguments
 * * [`client`] - A valid AfcClient handle
 * * [`path`] - Path to the directory to remove (UTF-8 null-terminated)
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `path` must be a valid null-terminated C string
 */
struct IdeviceFfiError *afc_remove_path_and_contents(struct AfcClientHandle *client,
                                                     const char *path);

/**
 * Opens a file on the device
 *
 * # Arguments
 * * [`client`] - A valid AfcClient handle
 * * [`path`] - Path to the file to open (UTF-8 null-terminated)
 * * [`mode`] - File open mode
 * * [`handle`] - Will be set to a new file handle on success
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * All pointers must be valid and non-null
 * `path` must be a valid null-terminated C string.
 * The file handle MAY NOT be used from another thread, and is
 * dependant upon the client it was created by.
 */
struct IdeviceFfiError *afc_file_open(struct AfcClientHandle *client,
                                      const char *path,
                                      enum AfcFopenMode mode,
                                      struct AfcFileHandle **handle);

/**
 * Closes a file handle
 *
 * # Arguments
 * * [`handle`] - File handle to close
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library
 */
struct IdeviceFfiError *afc_file_close(struct AfcFileHandle *handle);

/**
 * Reads data from an open file
 *
 * # Arguments
 * * [`handle`] - File handle to read from
 * * [`data`] - Will be set to point to the read data
 * * [`length`] - Will be set to the length of the read data
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * All pointers must be valid and non-null
 */
struct IdeviceFfiError *afc_file_read(struct AfcFileHandle *handle, uint8_t **data, size_t *length);

/**
 * Writes data to an open file
 *
 * # Arguments
 * * [`handle`] - File handle to write to
 * * [`data`] - Data to write
 * * [`length`] - Length of data to write
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * All pointers must be valid and non-null
 * `data` must point to at least `length` bytes
 */
struct IdeviceFfiError *afc_file_write(struct AfcFileHandle *handle,
                                       const uint8_t *data,
                                       size_t length);

/**
 * Creates a hard or symbolic link
 *
 * # Arguments
 * * [`client`] - A valid AfcClient handle
 * * [`target`] - Target path of the link (UTF-8 null-terminated)
 * * [`source`] - Path where the link should be created (UTF-8 null-terminated)
 * * [`link_type`] - Type of link to create
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * All pointers must be valid and non-null
 * `target` and `source` must be valid null-terminated C strings
 */
struct IdeviceFfiError *afc_make_link(struct AfcClientHandle *client,
                                      const char *target,
                                      const char *source,
                                      enum AfcLinkType link_type);

/**
 * Renames a file or directory
 *
 * # Arguments
 * * [`client`] - A valid AfcClient handle
 * * [`source`] - Current path of the file/directory (UTF-8 null-terminated)
 * * [`target`] - New path for the file/directory (UTF-8 null-terminated)
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * All pointers must be valid and non-null
 * `source` and `target` must be valid null-terminated C strings
 */
struct IdeviceFfiError *afc_rename_path(struct AfcClientHandle *client,
                                        const char *source,
                                        const char *target);

/**
 * Frees memory allocated by a file read function allocated by this library
 *
 * # Arguments
 * * [`info`] - Pointer to AfcDeviceInfo struct to free
 *
 * # Safety
 * `info` must be a valid pointer to an AfcDeviceInfo struct previously returned by afc_get_device_info
 */
void afc_file_read_data_free(uint8_t *data,
                             size_t length);

/**
 * Automatically creates and connects to AMFI service, returning a client handle
 *
 * # Arguments
 * * [`provider`] - An IdeviceProvider
 * * [`client`] - On success, will be set to point to a newly allocated AmfiClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `provider` must be a valid pointer to a handle allocated by this library
 * `client` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *amfi_connect(struct IdeviceProviderHandle *provider,
                                     struct AmfiClientHandle **client);

/**
 * Automatically creates and connects to AMFI service, returning a client handle
 *
 * # Arguments
 * * [`socket`] - An IdeviceSocket handle
 * * [`client`] - On success, will be set to point to a newly allocated AmfiClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `socket` must be a valid pointer to a handle allocated by this library. It is consumed, and
 * should not be used again.
 * `client` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *amfi_new(struct IdeviceHandle *socket, struct AmfiClientHandle **client);

/**
 * Shows the option in the settings UI
 *
 * # Arguments
 * * `client` - A valid AmfiClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 */
struct IdeviceFfiError *amfi_reveal_developer_mode_option_in_ui(struct AmfiClientHandle *client);

/**
 * Enables developer mode on the device
 *
 * # Arguments
 * * `client` - A valid AmfiClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 */
struct IdeviceFfiError *amfi_enable_developer_mode(struct AmfiClientHandle *client);

/**
 * Accepts developer mode on the device
 *
 * # Arguments
 * * `client` - A valid AmfiClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 */
struct IdeviceFfiError *amfi_accept_developer_mode(struct AmfiClientHandle *client);

/**
 * Frees a handle
 *
 * # Arguments
 * * [`handle`] - The handle to free
 *
 * # Safety
 * `handle` must be a valid pointer to the handle that was allocated by this library,
 * or NULL (in which case this function does nothing)
 */
void amfi_client_free(struct AmfiClientHandle *handle);

/**
 * Automatically creates and connects to Core Device Proxy, returning a client handle
 *
 * # Arguments
 * * [`provider`] - An IdeviceProvider
 * * [`client`] - On success, will be set to point to a newly allocated CoreDeviceProxy handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `provider` must be a valid pointer to a handle allocated by this library
 * `client` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *core_device_proxy_connect(struct IdeviceProviderHandle *provider,
                                                  struct CoreDeviceProxyHandle **client);

/**
 * Automatically creates and connects to Core Device Proxy, returning a client handle
 *
 * # Arguments
 * * [`socket`] - An IdeviceSocket handle
 * * [`client`] - On success, will be set to point to a newly allocated CoreDeviceProxy handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `socket` must be a valid pointer to a handle allocated by this library. It is consumed and
 * may not be used again.
 * `client` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *core_device_proxy_new(struct IdeviceHandle *socket,
                                              struct CoreDeviceProxyHandle **client);

/**
 * Sends data through the CoreDeviceProxy tunnel
 *
 * # Arguments
 * * [`handle`] - The CoreDeviceProxy handle
 * * [`data`] - The data to send
 * * [`length`] - The length of the data
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library
 * `data` must be a valid pointer to at least `length` bytes
 */
struct IdeviceFfiError *core_device_proxy_send(struct CoreDeviceProxyHandle *handle,
                                               const uint8_t *data,
                                               uintptr_t length);

/**
 * Receives data from the CoreDeviceProxy tunnel
 *
 * # Arguments
 * * [`handle`] - The CoreDeviceProxy handle
 * * [`data`] - Pointer to a buffer where the received data will be stored
 * * [`length`] - Pointer to store the actual length of received data
 * * [`max_length`] - Maximum number of bytes that can be stored in `data`
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library
 * `data` must be a valid pointer to at least `max_length` bytes
 * `length` must be a valid pointer to a usize
 */
struct IdeviceFfiError *core_device_proxy_recv(struct CoreDeviceProxyHandle *handle,
                                               uint8_t *data,
                                               uintptr_t *length,
                                               uintptr_t max_length);

/**
 * Gets the client parameters from the handshake
 *
 * # Arguments
 * * [`handle`] - The CoreDeviceProxy handle
 * * [`mtu`] - Pointer to store the MTU value
 * * [`address`] - Pointer to store the IP address string
 * * [`netmask`] - Pointer to store the netmask string
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library
 * `mtu` must be a valid pointer to a u16
 * `address` and `netmask` must be valid pointers to buffers of at least 16 bytes
 */
struct IdeviceFfiError *core_device_proxy_get_client_parameters(struct CoreDeviceProxyHandle *handle,
                                                                uint16_t *mtu,
                                                                char **address,
                                                                char **netmask);

/**
 * Gets the server address from the handshake
 *
 * # Arguments
 * * [`handle`] - The CoreDeviceProxy handle
 * * [`address`] - Pointer to store the server address string
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library
 * `address` must be a valid pointer to a buffer of at least 16 bytes
 */
struct IdeviceFfiError *core_device_proxy_get_server_address(struct CoreDeviceProxyHandle *handle,
                                                             char **address);

/**
 * Gets the server RSD port from the handshake
 *
 * # Arguments
 * * [`handle`] - The CoreDeviceProxy handle
 * * [`port`] - Pointer to store the port number
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library
 * `port` must be a valid pointer to a u16
 */
struct IdeviceFfiError *core_device_proxy_get_server_rsd_port(struct CoreDeviceProxyHandle *handle,
                                                              uint16_t *port);

/**
 * Creates a software TCP tunnel adapter
 *
 * # Arguments
 * * [`handle`] - The CoreDeviceProxy handle
 * * [`adapter`] - Pointer to store the newly created adapter handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library, and never used again
 * `adapter` must be a valid pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *core_device_proxy_create_tcp_adapter(struct CoreDeviceProxyHandle *handle,
                                                             struct AdapterHandle **adapter);

/**
 * Frees a handle
 *
 * # Arguments
 * * [`handle`] - The handle to free
 *
 * # Safety
 * `handle` must be a valid pointer to the handle that was allocated by this library,
 * or NULL (in which case this function does nothing)
 */
void core_device_proxy_free(struct CoreDeviceProxyHandle *handle);

/**
 * Frees a handle
 *
 * # Arguments
 * * [`handle`] - The handle to free
 *
 * # Safety
 * `handle` must be a valid pointer to the handle that was allocated by this library,
 * or NULL (in which case this function does nothing)
 */
void adapter_free(struct AdapterHandle *handle);

/**
 * Creates a new DebugserverCommand
 *
 * # Safety
 * Caller must free with debugserver_command_free
 */
struct DebugserverCommandHandle *debugserver_command_new(const char *name,
                                                         const char *const *argv,
                                                         uintptr_t argv_count);

/**
 * Frees a DebugserverCommand
 *
 * # Safety
 * `command` must be a valid pointer or NULL
 */
void debugserver_command_free(struct DebugserverCommandHandle *command);

/**
 * Creates a new DebugProxyClient
 *
 * # Arguments
 * * [`provider`] - An adapter created by this library
 * * [`handshake`] - An RSD handshake from the same provider
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `provider` must be a valid pointer to a handle allocated by this library
 * `handshake` must be a valid pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *debug_proxy_connect_rsd(struct AdapterHandle *provider,
                                                struct RsdHandshakeHandle *handshake,
                                                struct DebugProxyHandle **handle);

/**
 * Frees a DebugProxyClient handle
 *
 * # Arguments
 * * [`handle`] - The handle to free
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library or NULL
 */
void debug_proxy_free(struct DebugProxyHandle *handle);

/**
 * Sends a command to the debug proxy
 *
 * # Arguments
 * * [`handle`] - The DebugProxyClient handle
 * * [`command`] - The command to send
 * * [`response`] - Pointer to store the response (caller must free)
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `handle` and `command` must be valid pointers
 * `response` must be a valid pointer to a location where the string will be stored
 */
struct IdeviceFfiError *debug_proxy_send_command(struct DebugProxyHandle *handle,
                                                 struct DebugserverCommandHandle *command,
                                                 char **response);

/**
 * Reads a response from the debug proxy
 *
 * # Arguments
 * * [`handle`] - The DebugProxyClient handle
 * * [`response`] - Pointer to store the response (caller must free)
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `handle` must be a valid pointer
 * `response` must be a valid pointer to a location where the string will be stored
 */
struct IdeviceFfiError *debug_proxy_read_response(struct DebugProxyHandle *handle, char **response);

/**
 * Sends raw data to the debug proxy
 *
 * # Arguments
 * * [`handle`] - The DebugProxyClient handle
 * * [`data`] - The data to send
 * * [`len`] - Length of the data
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `handle` must be a valid pointer
 * `data` must be a valid pointer to `len` bytes
 */
struct IdeviceFfiError *debug_proxy_send_raw(struct DebugProxyHandle *handle,
                                             const uint8_t *data,
                                             uintptr_t len);

/**
 * Reads data from the debug proxy
 *
 * # Arguments
 * * [`handle`] - The DebugProxyClient handle
 * * [`len`] - Maximum number of bytes to read
 * * [`response`] - Pointer to store the response (caller must free)
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `handle` must be a valid pointer
 * `response` must be a valid pointer to a location where the string will be stored
 */
struct IdeviceFfiError *debug_proxy_read(struct DebugProxyHandle *handle,
                                         uintptr_t len,
                                         char **response);

/**
 * Sets the argv for the debug proxy
 *
 * # Arguments
 * * [`handle`] - The DebugProxyClient handle
 * * [`argv`] - NULL-terminated array of arguments
 * * [`argv_count`] - Number of arguments
 * * [`response`] - Pointer to store the response (caller must free)
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `handle` must be a valid pointer
 * `argv` must be a valid pointer to `argv_count` C strings or NULL
 * `response` must be a valid pointer to a location where the string will be stored
 */
struct IdeviceFfiError *debug_proxy_set_argv(struct DebugProxyHandle *handle,
                                             const char *const *argv,
                                             uintptr_t argv_count,
                                             char **response);

/**
 * Sends an ACK to the debug proxy
 *
 * # Arguments
 * * [`handle`] - The DebugProxyClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `handle` must be a valid pointer
 */
struct IdeviceFfiError *debug_proxy_send_ack(struct DebugProxyHandle *handle);

/**
 * Sends a NACK to the debug proxy
 *
 * # Arguments
 * * [`handle`] - The DebugProxyClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `handle` must be a valid pointer
 */
struct IdeviceFfiError *debug_proxy_send_nack(struct DebugProxyHandle *handle);

/**
 * Sets the ACK mode for the debug proxy
 *
 * # Arguments
 * * [`handle`] - The DebugProxyClient handle
 * * [`enabled`] - Whether ACK mode should be enabled
 *
 * # Safety
 * `handle` must be a valid pointer
 */
void debug_proxy_set_ack_mode(struct DebugProxyHandle *handle, int enabled);

/**
 * Frees the IdeviceFfiError
 *
 * # Safety
 * `err` must be a struct allocated by this library
 */
void idevice_error_free(struct IdeviceFfiError *err);

/**
 * Automatically creates and connects to Installation Proxy, returning a client handle
 *
 * # Arguments
 * * [`provider`] - An IdeviceProvider
 * * [`client`] - On success, will be set to point to a newly allocated InstallationProxyClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `provider` must be a valid pointer to a handle allocated by this library
 * `client` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *heartbeat_connect(struct IdeviceProviderHandle *provider,
                                          struct HeartbeatClientHandle **client);

/**
 * Automatically creates and connects to Installation Proxy, returning a client handle
 *
 * # Arguments
 * * [`socket`] - An IdeviceSocket handle
 * * [`client`] - On success, will be set to point to a newly allocated InstallationProxyClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `socket` must be a valid pointer to a handle allocated by this library. The socket is consumed,
 * and may not be used again.
 * `client` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *heartbeat_new(struct IdeviceHandle *socket,
                                      struct HeartbeatClientHandle **client);

/**
 * Sends a polo to the device
 *
 * # Arguments
 * * `client` - A valid HeartbeatClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 */
struct IdeviceFfiError *heartbeat_send_polo(struct HeartbeatClientHandle *client);

/**
 * Sends a polo to the device
 *
 * # Arguments
 * * `client` - A valid HeartbeatClient handle
 * * `interval` - The time to wait for a marco
 * * `new_interval` - A pointer to set the requested marco
 *
 * # Returns
 * An IdeviceFfiError on error, null on success.
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 */
struct IdeviceFfiError *heartbeat_get_marco(struct HeartbeatClientHandle *client,
                                            uint64_t interval,
                                            uint64_t *new_interval);

/**
 * Frees a handle
 *
 * # Arguments
 * * [`handle`] - The handle to free
 *
 * # Safety
 * `handle` must be a valid pointer to the handle that was allocated by this library,
 * or NULL (in which case this function does nothing)
 */
void heartbeat_client_free(struct HeartbeatClientHandle *handle);

/**
 * Automatically creates and connects to Installation Proxy, returning a client handle
 *
 * # Arguments
 * * [`provider`] - An IdeviceProvider
 * * [`client`] - On success, will be set to point to a newly allocated InstallationProxyClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `provider` must be a valid pointer to a handle allocated by this library
 * `client` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *installation_proxy_connect_tcp(struct IdeviceProviderHandle *provider,
                                                       struct InstallationProxyClientHandle **client);

/**
 * Automatically creates and connects to Installation Proxy, returning a client handle
 *
 * # Arguments
 * * [`socket`] - An IdeviceSocket handle
 * * [`client`] - On success, will be set to point to a newly allocated InstallationProxyClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `socket` must be a valid pointer to a handle allocated by this library. The socket is consumed,
 * and may not be used again.
 * `client` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *installation_proxy_new(struct IdeviceHandle *socket,
                                               struct InstallationProxyClientHandle **client);

/**
 * Gets installed apps on the device
 *
 * # Arguments
 * * [`client`] - A valid InstallationProxyClient handle
 * * [`application_type`] - The application type to filter by (optional, NULL for "Any")
 * * [`bundle_identifiers`] - The identifiers to filter by (optional, NULL for all apps)
 * * [`out_result`] - On success, will be set to point to a newly allocated array of PlistRef
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `out_result` must be a valid, non-null pointer to a location where the result will be stored
 */
struct IdeviceFfiError *installation_proxy_get_apps(struct InstallationProxyClientHandle *client,
                                                    const char *application_type,
                                                    const char *const *bundle_identifiers,
                                                    size_t bundle_identifiers_len,
                                                    void **out_result,
                                                    size_t *out_result_len);

/**
 * Frees a handle
 *
 * # Arguments
 * * [`handle`] - The handle to free
 *
 * # Safety
 * `handle` must be a valid pointer to the handle that was allocated by this library,
 * or NULL (in which case this function does nothing)
 */
void installation_proxy_client_free(struct InstallationProxyClientHandle *handle);

/**
 * Installs an application package on the device
 *
 * # Arguments
 * * [`client`] - A valid InstallationProxyClient handle
 * * [`package_path`] - Path to the .ipa package in the AFC jail
 * * [`options`] - Optional installation options as a plist dictionary (can be NULL)
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `package_path` must be a valid C string
 * `options` must be a valid plist dictionary or NULL
 */
struct IdeviceFfiError *installation_proxy_install(struct InstallationProxyClientHandle *client,
                                                   const char *package_path,
                                                   void *options);

/**
 * Installs an application package on the device
 *
 * # Arguments
 * * [`client`] - A valid InstallationProxyClient handle
 * * [`package_path`] - Path to the .ipa package in the AFC jail
 * * [`options`] - Optional installation options as a plist dictionary (can be NULL)
 * * [`callback`] - Progress callback function
 * * [`context`] - User context to pass to callback
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `package_path` must be a valid C string
 * `options` must be a valid plist dictionary or NULL
 */
struct IdeviceFfiError *installation_proxy_install_with_callback(struct InstallationProxyClientHandle *client,
                                                                 const char *package_path,
                                                                 void *options,
                                                                 void (*callback)(uint64_t progress,
                                                                                  void *context),
                                                                 void *context);

/**
 * Upgrades an existing application on the device
 *
 * # Arguments
 * * [`client`] - A valid InstallationProxyClient handle
 * * [`package_path`] - Path to the .ipa package in the AFC jail
 * * [`options`] - Optional upgrade options as a plist dictionary (can be NULL)
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `package_path` must be a valid C string
 * `options` must be a valid plist dictionary or NULL
 */
struct IdeviceFfiError *installation_proxy_upgrade(struct InstallationProxyClientHandle *client,
                                                   const char *package_path,
                                                   void *options);

/**
 * Upgrades an existing application on the device
 *
 * # Arguments
 * * [`client`] - A valid InstallationProxyClient handle
 * * [`package_path`] - Path to the .ipa package in the AFC jail
 * * [`options`] - Optional upgrade options as a plist dictionary (can be NULL)
 * * [`callback`] - Progress callback function
 * * [`context`] - User context to pass to callback
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `package_path` must be a valid C string
 * `options` must be a valid plist dictionary or NULL
 */
struct IdeviceFfiError *installation_proxy_upgrade_with_callback(struct InstallationProxyClientHandle *client,
                                                                 const char *package_path,
                                                                 void *options,
                                                                 void (*callback)(uint64_t progress,
                                                                                  void *context),
                                                                 void *context);

/**
 * Uninstalls an application from the device
 *
 * # Arguments
 * * [`client`] - A valid InstallationProxyClient handle
 * * [`bundle_id`] - Bundle identifier of the application to uninstall
 * * [`options`] - Optional uninstall options as a plist dictionary (can be NULL)
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `bundle_id` must be a valid C string
 * `options` must be a valid plist dictionary or NULL
 */
struct IdeviceFfiError *installation_proxy_uninstall(struct InstallationProxyClientHandle *client,
                                                     const char *bundle_id,
                                                     void *options);

/**
 * Uninstalls an application from the device
 *
 * # Arguments
 * * [`client`] - A valid InstallationProxyClient handle
 * * [`bundle_id`] - Bundle identifier of the application to uninstall
 * * [`options`] - Optional uninstall options as a plist dictionary (can be NULL)
 * * [`callback`] - Progress callback function
 * * [`context`] - User context to pass to callback
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `bundle_id` must be a valid C string
 * `options` must be a valid plist dictionary or NULL
 */
struct IdeviceFfiError *installation_proxy_uninstall_with_callback(struct InstallationProxyClientHandle *client,
                                                                   const char *bundle_id,
                                                                   void *options,
                                                                   void (*callback)(uint64_t progress,
                                                                                    void *context),
                                                                   void *context);

/**
 * Checks if the device capabilities match the required capabilities
 *
 * # Arguments
 * * [`client`] - A valid InstallationProxyClient handle
 * * [`capabilities`] - Array of plist values representing required capabilities
 * * [`capabilities_len`] - Length of the capabilities array
 * * [`options`] - Optional check options as a plist dictionary (can be NULL)
 * * [`out_result`] - Will be set to true if all capabilities are supported, false otherwise
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `capabilities` must be a valid array of plist values or NULL
 * `options` must be a valid plist dictionary or NULL
 * `out_result` must be a valid pointer to a bool
 */
struct IdeviceFfiError *installation_proxy_check_capabilities_match(struct InstallationProxyClientHandle *client,
                                                                    void *const *capabilities,
                                                                    size_t capabilities_len,
                                                                    void *options,
                                                                    bool *out_result);

/**
 * Browses installed applications on the device
 *
 * # Arguments
 * * [`client`] - A valid InstallationProxyClient handle
 * * [`options`] - Optional browse options as a plist dictionary (can be NULL)
 * * [`out_result`] - On success, will be set to point to a newly allocated array of PlistRef
 * * [`out_result_len`] - Will be set to the length of the result array
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `options` must be a valid plist dictionary or NULL
 * `out_result` must be a valid, non-null pointer to a location where the result will be stored
 * `out_result_len` must be a valid, non-null pointer to a location where the length will be stored
 */
struct IdeviceFfiError *installation_proxy_browse(struct InstallationProxyClientHandle *client,
                                                  void *options,
                                                  void **out_result,
                                                  size_t *out_result_len);

/**
 * Creates a new ProcessControlClient from a RemoteServerClient
 *
 * # Arguments
 * * [`server`] - The RemoteServerClient to use
 * * [`handle`] - Pointer to store the newly created ProcessControlClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `server` must be a valid pointer to a handle allocated by this library
 * `handle` must be a valid pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *location_simulation_new(struct RemoteServerHandle *server,
                                                struct LocationSimulationHandle **handle);

/**
 * Frees a ProcessControlClient handle
 *
 * # Arguments
 * * [`handle`] - The handle to free
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library or NULL
 */
void location_simulation_free(struct LocationSimulationHandle *handle);

/**
 * Clears the location set
 *
 * # Arguments
 * * [`handle`] - The LocationSimulation handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * All pointers must be valid or NULL where appropriate
 */
struct IdeviceFfiError *location_simulation_clear(struct LocationSimulationHandle *handle);

/**
 * Sets the location
 *
 * # Arguments
 * * [`handle`] - The LocationSimulation handle
 * * [`latitude`] - The latitude to set
 * * [`longitude`] - The longitude to set
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * All pointers must be valid or NULL where appropriate
 */
struct IdeviceFfiError *location_simulation_set(struct LocationSimulationHandle *handle,
                                                double latitude,
                                                double longitude);

/**
 * Connects to lockdownd service using TCP provider
 *
 * # Arguments
 * * [`provider`] - An IdeviceProvider
 * * [`client`] - On success, will be set to point to a newly allocated LockdowndClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `provider` must be a valid pointer to a handle allocated by this library
 * `client` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *lockdownd_connect(struct IdeviceProviderHandle *provider,
                                          struct LockdowndClientHandle **client);

/**
 * Creates a new LockdowndClient from an existing Idevice connection
 *
 * # Arguments
 * * [`socket`] - An IdeviceSocket handle.
 * * [`client`] - On success, will be set to point to a newly allocated LockdowndClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `socket` must be a valid pointer to a handle allocated by this library. The socket is consumed,
 * and maybe not be used again.
 * `client` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *lockdownd_new(struct IdeviceHandle *socket,
                                      struct LockdowndClientHandle **client);

/**
 * Starts a session with lockdownd
 *
 * # Arguments
 * * `client` - A valid LockdowndClient handle
 * * `pairing_file` - An IdevicePairingFile alocated by this library
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `pairing_file` must be a valid plist_t containing a pairing file
 */
struct IdeviceFfiError *lockdownd_start_session(struct LockdowndClientHandle *client,
                                                struct IdevicePairingFile *pairing_file);

/**
 * Starts a service through lockdownd
 *
 * # Arguments
 * * `client` - A valid LockdowndClient handle
 * * `identifier` - The service identifier to start (null-terminated string)
 * * `port` - Pointer to store the returned port number
 * * `ssl` - Pointer to store whether SSL should be enabled
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `identifier` must be a valid null-terminated string
 * `port` and `ssl` must be valid pointers
 */
struct IdeviceFfiError *lockdownd_start_service(struct LockdowndClientHandle *client,
                                                const char *identifier,
                                                uint16_t *port,
                                                bool *ssl);

/**
 * Gets a value from lockdownd
 *
 * # Arguments
 * * `client` - A valid LockdowndClient handle
 * * `key` - The value to get (null-terminated string)
 * * `domain` - The value to get (null-terminated string)
 * * `out_plist` - Pointer to store the returned plist value
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `value` must be a valid null-terminated string
 * `out_plist` must be a valid pointer to store the plist
 */
struct IdeviceFfiError *lockdownd_get_value(struct LockdowndClientHandle *client,
                                            const char *key,
                                            const char *domain,
                                            void **out_plist);

/**
 * Gets all values from lockdownd
 *
 * # Arguments
 * * `client` - A valid LockdowndClient handle
 * * `out_plist` - Pointer to store the returned plist dictionary
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `out_plist` must be a valid pointer to store the plist
 */
struct IdeviceFfiError *lockdownd_get_all_values(struct LockdowndClientHandle *client,
                                                 const char *domain,
                                                 void **out_plist);

/**
 * Frees a LockdowndClient handle
 *
 * # Arguments
 * * [`handle`] - The handle to free
 *
 * # Safety
 * `handle` must be a valid pointer to the handle that was allocated by this library,
 * or NULL (in which case this function does nothing)
 */
void lockdownd_client_free(struct LockdowndClientHandle *handle);

/**
 * Initializes the logger
 *
 * # Arguments
 * * [`console_level`] - The level to log to the file
 * * [`file_level`] - The level to log to the file
 * * [`file_path`] - If not null, the file to write logs to
 *
 * ## Log Level
 * 0. Disabled
 * 1. Error
 * 2. Warn
 * 3. Info
 * 4. Debug
 * 5. Trace
 *
 * # Returns
 * 0 for success, -1 if the file couldn't be created, -2 if a logger has been initialized, -3 for invalid path string
 *
 * # Safety
 * Pass a valid CString for file_path. Pass valid log levels according to the enum
 */
enum IdeviceLoggerError idevice_init_logger(enum IdeviceLogLevel console_level,
                                            enum IdeviceLogLevel file_level,
                                            char *file_path);

/**
 * Automatically creates and connects to Misagent, returning a client handle
 *
 * # Arguments
 * * [`provider`] - An IdeviceProvider
 * * [`client`] - On success, will be set to point to a newly allocated MisagentClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `provider` must be a valid pointer to a handle allocated by this library
 * `client` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *misagent_connect(struct IdeviceProviderHandle *provider,
                                         struct MisagentClientHandle **client);

/**
 * Installs a provisioning profile on the device
 *
 * # Arguments
 * * [`client`] - A valid MisagentClient handle
 * * [`profile_data`] - The provisioning profile data to install
 * * [`profile_len`] - Length of the profile data
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `profile_data` must be a valid pointer to profile data of length `profile_len`
 */
struct IdeviceFfiError *misagent_install(struct MisagentClientHandle *client,
                                         const uint8_t *profile_data,
                                         size_t profile_len);

/**
 * Removes a provisioning profile from the device
 *
 * # Arguments
 * * [`client`] - A valid MisagentClient handle
 * * [`profile_id`] - The UUID of the profile to remove (C string)
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `profile_id` must be a valid C string
 */
struct IdeviceFfiError *misagent_remove(struct MisagentClientHandle *client,
                                        const char *profile_id);

/**
 * Retrieves all provisioning profiles from the device
 *
 * # Arguments
 * * [`client`] - A valid MisagentClient handle
 * * [`out_profiles`] - On success, will be set to point to an array of profile data
 * * [`out_profiles_len`] - On success, will be set to the number of profiles
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `out_profiles` must be a valid pointer to store the resulting array
 * `out_profiles_len` must be a valid pointer to store the array length
 */
struct IdeviceFfiError *misagent_copy_all(struct MisagentClientHandle *client,
                                          uint8_t ***out_profiles,
                                          size_t **out_profiles_len,
                                          size_t *out_count);

/**
 * Frees profiles array returned by misagent_copy_all
 *
 * # Arguments
 * * [`profiles`] - Array of profile data pointers
 * * [`lens`] - Array of profile lengths
 * * [`count`] - Number of profiles in the array
 *
 * # Safety
 * Must only be called with values returned from misagent_copy_all
 */
void misagent_free_profiles(uint8_t **profiles, size_t *lens, size_t count);

/**
 * Frees a misagent client handle
 *
 * # Arguments
 * * [`handle`] - The handle to free
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library,
 * or NULL (in which case this function does nothing)
 */
void misagent_client_free(struct MisagentClientHandle *handle);

/**
 * Connects to the Image Mounter service using a provider
 *
 * # Arguments
 * * [`provider`] - An IdeviceProvider
 * * [`client`] - On success, will be set to point to a newly allocated ImageMounter handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `provider` must be a valid pointer to a handle allocated by this library
 * `client` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *image_mounter_connect(struct IdeviceProviderHandle *provider,
                                              struct ImageMounterHandle **client);

/**
 * Creates a new ImageMounter client from an existing Idevice connection
 *
 * # Arguments
 * * [`socket`] - An IdeviceSocket handle
 * * [`client`] - On success, will be set to point to a newly allocated ImageMounter handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `socket` must be a valid pointer to a handle allocated by this library
 * `client` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *image_mounter_new(struct IdeviceHandle *socket,
                                          struct ImageMounterHandle **client);

/**
 * Frees an ImageMounter handle
 *
 * # Arguments
 * * [`handle`] - The handle to free
 *
 * # Safety
 * `handle` must be a valid pointer to the handle that was allocated by this library,
 * or NULL (in which case this function does nothing)
 */
void image_mounter_free(struct ImageMounterHandle *handle);

/**
 * Gets a list of mounted devices
 *
 * # Arguments
 * * [`client`] - A valid ImageMounter handle
 * * [`devices`] - Will be set to point to a slice of device plists on success
 * * [`devices_len`] - Will be set to the number of devices copied
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `devices` must be a valid, non-null pointer to a location where the plist will be stored
 */
struct IdeviceFfiError *image_mounter_copy_devices(struct ImageMounterHandle *client,
                                                   void **devices,
                                                   size_t *devices_len);

/**
 * Looks up an image and returns its signature
 *
 * # Arguments
 * * [`client`] - A valid ImageMounter handle
 * * [`image_type`] - The type of image to look up
 * * [`signature`] - Will be set to point to the signature data on success
 * * [`signature_len`] - Will be set to the length of the signature data
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `image_type` must be a valid null-terminated C string
 * `signature` and `signature_len` must be valid pointers
 */
struct IdeviceFfiError *image_mounter_lookup_image(struct ImageMounterHandle *client,
                                                   const char *image_type,
                                                   uint8_t **signature,
                                                   size_t *signature_len);

/**
 * Uploads an image to the device
 *
 * # Arguments
 * * [`client`] - A valid ImageMounter handle
 * * [`image_type`] - The type of image being uploaded
 * * [`image`] - Pointer to the image data
 * * [`image_len`] - Length of the image data
 * * [`signature`] - Pointer to the signature data
 * * [`signature_len`] - Length of the signature data
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * All pointers must be valid and non-null
 * `image_type` must be a valid null-terminated C string
 */
struct IdeviceFfiError *image_mounter_upload_image(struct ImageMounterHandle *client,
                                                   const char *image_type,
                                                   const uint8_t *image,
                                                   size_t image_len,
                                                   const uint8_t *signature,
                                                   size_t signature_len);

/**
 * Mounts an image on the device
 *
 * # Arguments
 * * [`client`] - A valid ImageMounter handle
 * * [`image_type`] - The type of image being mounted
 * * [`signature`] - Pointer to the signature data
 * * [`signature_len`] - Length of the signature data
 * * [`trust_cache`] - Pointer to trust cache data (optional)
 * * [`trust_cache_len`] - Length of trust cache data (0 if none)
 * * [`info_plist`] - Pointer to info plist (optional)
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * All pointers must be valid (except optional ones which can be null)
 * `image_type` must be a valid null-terminated C string
 */
struct IdeviceFfiError *image_mounter_mount_image(struct ImageMounterHandle *client,
                                                  const char *image_type,
                                                  const uint8_t *signature,
                                                  size_t signature_len,
                                                  const uint8_t *trust_cache,
                                                  size_t trust_cache_len,
                                                  const void *info_plist);

/**
 * Unmounts an image from the device
 *
 * # Arguments
 * * [`client`] - A valid ImageMounter handle
 * * [`mount_path`] - The path where the image is mounted
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `mount_path` must be a valid null-terminated C string
 */
struct IdeviceFfiError *image_mounter_unmount_image(struct ImageMounterHandle *client,
                                                    const char *mount_path);

/**
 * Queries the developer mode status
 *
 * # Arguments
 * * [`client`] - A valid ImageMounter handle
 * * [`status`] - Will be set to the developer mode status (1 = enabled, 0 = disabled)
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `status` must be a valid pointer
 */
struct IdeviceFfiError *image_mounter_query_developer_mode_status(struct ImageMounterHandle *client,
                                                                  int *status);

/**
 * Mounts a developer image
 *
 * # Arguments
 * * [`client`] - A valid ImageMounter handle
 * * [`image`] - Pointer to the image data
 * * [`image_len`] - Length of the image data
 * * [`signature`] - Pointer to the signature data
 * * [`signature_len`] - Length of the signature data
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * All pointers must be valid and non-null
 */
struct IdeviceFfiError *image_mounter_mount_developer(struct ImageMounterHandle *client,
                                                      const uint8_t *image,
                                                      size_t image_len,
                                                      const uint8_t *signature,
                                                      size_t signature_len);

/**
 * Queries the personalization manifest from the device
 *
 * # Arguments
 * * [`client`] - A valid ImageMounter handle
 * * [`image_type`] - The type of image to query
 * * [`signature`] - Pointer to the signature data
 * * [`signature_len`] - Length of the signature data
 * * [`manifest`] - Will be set to point to the manifest data on success
 * * [`manifest_len`] - Will be set to the length of the manifest data
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * All pointers must be valid and non-null
 * `image_type` must be a valid null-terminated C string
 */
struct IdeviceFfiError *image_mounter_query_personalization_manifest(struct ImageMounterHandle *client,
                                                                     const char *image_type,
                                                                     const uint8_t *signature,
                                                                     size_t signature_len,
                                                                     uint8_t **manifest,
                                                                     size_t *manifest_len);

/**
 * Queries the nonce from the device
 *
 * # Arguments
 * * [`client`] - A valid ImageMounter handle
 * * [`personalized_image_type`] - The type of image to query (optional)
 * * [`nonce`] - Will be set to point to the nonce data on success
 * * [`nonce_len`] - Will be set to the length of the nonce data
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client`, `nonce`, and `nonce_len` must be valid pointers
 * `personalized_image_type` can be NULL
 */
struct IdeviceFfiError *image_mounter_query_nonce(struct ImageMounterHandle *client,
                                                  const char *personalized_image_type,
                                                  uint8_t **nonce,
                                                  size_t *nonce_len);

/**
 * Queries personalization identifiers from the device
 *
 * # Arguments
 * * [`client`] - A valid ImageMounter handle
 * * [`image_type`] - The type of image to query (optional)
 * * [`identifiers`] - Will be set to point to the identifiers plist on success
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` and `identifiers` must be valid pointers
 * `image_type` can be NULL
 */
struct IdeviceFfiError *image_mounter_query_personalization_identifiers(struct ImageMounterHandle *client,
                                                                        const char *image_type,
                                                                        void **identifiers);

/**
 * Rolls the personalization nonce
 *
 * # Arguments
 * * [`client`] - A valid ImageMounter handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 */
struct IdeviceFfiError *image_mounter_roll_personalization_nonce(struct ImageMounterHandle *client);

/**
 * Rolls the cryptex nonce
 *
 * # Arguments
 * * [`client`] - A valid ImageMounter handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 */
struct IdeviceFfiError *image_mounter_roll_cryptex_nonce(struct ImageMounterHandle *client);

/**
 * Mounts a personalized developer image
 *
 * # Arguments
 * * [`client`] - A valid ImageMounter handle
 * * [`provider`] - A valid provider handle
 * * [`image`] - Pointer to the image data
 * * [`image_len`] - Length of the image data
 * * [`trust_cache`] - Pointer to the trust cache data
 * * [`trust_cache_len`] - Length of the trust cache data
 * * [`build_manifest`] - Pointer to the build manifest data
 * * [`build_manifest_len`] - Length of the build manifest data
 * * [`info_plist`] - Pointer to info plist (optional)
 * * [`unique_chip_id`] - The device's unique chip ID
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * All pointers must be valid (except optional ones which can be null)
 */
struct IdeviceFfiError *image_mounter_mount_personalized(struct ImageMounterHandle *client,
                                                         struct IdeviceProviderHandle *provider,
                                                         const uint8_t *image,
                                                         size_t image_len,
                                                         const uint8_t *trust_cache,
                                                         size_t trust_cache_len,
                                                         const uint8_t *build_manifest,
                                                         size_t build_manifest_len,
                                                         const void *info_plist,
                                                         uint64_t unique_chip_id);

/**
 * Mounts a personalized developer image with progress callback
 *
 * # Arguments
 * * [`client`] - A valid ImageMounter handle
 * * [`provider`] - A valid provider handle
 * * [`image`] - Pointer to the image data
 * * [`image_len`] - Length of the image data
 * * [`trust_cache`] - Pointer to the trust cache data
 * * [`trust_cache_len`] - Length of the trust cache data
 * * [`build_manifest`] - Pointer to the build manifest data
 * * [`build_manifest_len`] - Length of the build manifest data
 * * [`info_plist`] - Pointer to info plist (optional)
 * * [`unique_chip_id`] - The device's unique chip ID
 * * [`callback`] - Progress callback function
 * * [`context`] - User context to pass to callback
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * All pointers must be valid (except optional ones which can be null)
 */
struct IdeviceFfiError *image_mounter_mount_personalized_with_callback(struct ImageMounterHandle *client,
                                                                       struct IdeviceProviderHandle *provider,
                                                                       const uint8_t *image,
                                                                       size_t image_len,
                                                                       const uint8_t *trust_cache,
                                                                       size_t trust_cache_len,
                                                                       const uint8_t *build_manifest,
                                                                       size_t build_manifest_len,
                                                                       const void *info_plist,
                                                                       uint64_t unique_chip_id,
                                                                       void (*callback)(size_t progress,
                                                                                        size_t total,
                                                                                        void *context),
                                                                       void *context);

/**
 * Connects to the relay with the given provider
 *
 * # Arguments
 * * [`provider`] - A provider created by this library
 * * [`client`] - A pointer where the handle will be allocated
 *
 * # Returns
 * 0 for success, an *mut IdeviceFfiError otherwise
 *
 * # Safety
 * None of the arguments can be null. Provider must be allocated by this library.
 */
struct IdeviceFfiError *os_trace_relay_connect(struct IdeviceProviderHandle *provider,
                                               struct OsTraceRelayClientHandle **client);

/**
 * Frees the relay client
 *
 * # Arguments
 * * [`handle`] - The relay client handle
 *
 * # Safety
 * The handle must be allocated by this library
 */
void os_trace_relay_free(struct OsTraceRelayClientHandle *handle);

/**
 * Creates a handle and starts receiving logs
 *
 * # Arguments
 * * [`client`] - The relay client handle
 * * [`receiver`] - A pointer to allocate the new handle to
 * * [`pid`] - An optional pointer to a PID to get logs for. May be null.
 *
 * # Returns
 * 0 for success, an *mut IdeviceFfiError otherwise
 *
 * # Safety
 * The handle must be allocated by this library. It is consumed, and must never be used again.
 */
struct IdeviceFfiError *os_trace_relay_start_trace(struct OsTraceRelayClientHandle *client,
                                                   struct OsTraceRelayReceiverHandle **receiver,
                                                   const uint32_t *pid);

/**
 * Frees the receiver handle
 *
 * # Arguments
 * * [`handle`] - The relay receiver client handle
 *
 * # Safety
 * The handle must be allocated by this library. It is consumed, and must never be used again.
 */
void os_trace_relay_receiver_free(struct OsTraceRelayReceiverHandle *handle);

/**
 * Gets the PID list from the device
 *
 * # Arguments
 * * [`client`] - The relay receiver client handle
 * * [`list`] - A pointer to allocate a list of PIDs to
 *
 * # Returns
 * 0 for success, an *mut IdeviceFfiError otherwise
 *
 * # Safety
 * The handle must be allocated by this library.
 */
struct IdeviceFfiError *os_trace_relay_get_pid_list(struct OsTraceRelayClientHandle *client,
                                                    struct Vec_u64 **list);

/**
 * Gets the next log from the relay
 *
 * # Arguments
 * * [`client`] - The relay receiver client handle
 * * [`log`] - A pointer to allocate the new log
 *
 * # Returns
 * 0 for success, an *mut IdeviceFfiError otherwise
 *
 * # Safety
 * The handle must be allocated by this library.
 */
struct IdeviceFfiError *os_trace_relay_next(struct OsTraceRelayReceiverHandle *client,
                                            struct OsTraceLog **log);

/**
 * Frees a log received from the relay
 *
 * # Arguments
 * * [`log`] - The log to free
 *
 * # Returns
 * 0 for success, an *mut IdeviceFfiError otherwise
 *
 * # Safety
 * The log must be allocated by this library. It is consumed and must not be used again.
 */
void os_trace_relay_free_log(struct OsTraceLog *log);

/**
 * Reads a pairing file from the specified path
 *
 * # Arguments
 * * [`path`] - Path to the pairing file
 * * [`pairing_file`] - On success, will be set to point to a newly allocated pairing file instance
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `path` must be a valid null-terminated C string
 * `pairing_file` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *idevice_pairing_file_read(const char *path,
                                                  struct IdevicePairingFile **pairing_file);

/**
 * Parses a pairing file from a byte buffer
 *
 * # Arguments
 * * [`data`] - Pointer to the buffer containing pairing file data
 * * [`size`] - Size of the buffer in bytes
 * * [`pairing_file`] - On success, will be set to point to a newly allocated pairing file instance
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `data` must be a valid pointer to a buffer of at least `size` bytes
 * `pairing_file` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *idevice_pairing_file_from_bytes(const uint8_t *data,
                                                        uintptr_t size,
                                                        struct IdevicePairingFile **pairing_file);

/**
 * Serializes a pairing file to XML format
 *
 * # Arguments
 * * [`pairing_file`] - The pairing file to serialize
 * * [`data`] - On success, will be set to point to a newly allocated buffer containing the serialized data
 * * [`size`] - On success, will be set to the size of the allocated buffer
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `pairing_file` must be a valid, non-null pointer to a pairing file instance
 * `data` must be a valid, non-null pointer to a location where the buffer pointer will be stored
 * `size` must be a valid, non-null pointer to a location where the buffer size will be stored
 */
struct IdeviceFfiError *idevice_pairing_file_serialize(const struct IdevicePairingFile *pairing_file,
                                                       uint8_t **data,
                                                       uintptr_t *size);

/**
 * Frees a pairing file instance
 *
 * # Arguments
 * * [`pairing_file`] - The pairing file to free
 *
 * # Safety
 * `pairing_file` must be a valid pointer to a pairing file instance that was allocated by this library,
 * or NULL (in which case this function does nothing)
 */
void idevice_pairing_file_free(struct IdevicePairingFile *pairing_file);

/**
 * Creates a new ProcessControlClient from a RemoteServerClient
 *
 * # Arguments
 * * [`server`] - The RemoteServerClient to use
 * * [`handle`] - Pointer to store the newly created ProcessControlClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `server` must be a valid pointer to a handle allocated by this library
 * `handle` must be a valid pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *process_control_new(struct RemoteServerHandle *server,
                                            struct ProcessControlHandle **handle);

/**
 * Frees a ProcessControlClient handle
 *
 * # Arguments
 * * [`handle`] - The handle to free
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library or NULL
 */
void process_control_free(struct ProcessControlHandle *handle);

/**
 * Launches an application on the device
 *
 * # Arguments
 * * [`handle`] - The ProcessControlClient handle
 * * [`bundle_id`] - The bundle identifier of the app to launch
 * * [`env_vars`] - NULL-terminated array of environment variables (format "KEY=VALUE")
 * * [`arguments`] - NULL-terminated array of arguments
 * * [`start_suspended`] - Whether to start the app suspended
 * * [`kill_existing`] - Whether to kill existing instances of the app
 * * [`pid`] - Pointer to store the process ID of the launched app
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * All pointers must be valid or NULL where appropriate
 */
struct IdeviceFfiError *process_control_launch_app(struct ProcessControlHandle *handle,
                                                   const char *bundle_id,
                                                   const char *const *env_vars,
                                                   uintptr_t env_vars_count,
                                                   const char *const *arguments,
                                                   uintptr_t arguments_count,
                                                   bool start_suspended,
                                                   bool kill_existing,
                                                   uint64_t *pid);

/**
 * Kills a running process
 *
 * # Arguments
 * * [`handle`] - The ProcessControlClient handle
 * * [`pid`] - The process ID to kill
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library
 */
struct IdeviceFfiError *process_control_kill_app(struct ProcessControlHandle *handle, uint64_t pid);

/**
 * Disables memory limits for a process
 *
 * # Arguments
 * * [`handle`] - The ProcessControlClient handle
 * * [`pid`] - The process ID to modify
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library
 */
struct IdeviceFfiError *process_control_disable_memory_limit(struct ProcessControlHandle *handle,
                                                             uint64_t pid);

/**
 * Creates a TCP provider for idevice
 *
 * # Arguments
 * * [`ip`] - The sockaddr IP to connect to
 * * [`pairing_file`] - The pairing file handle to use
 * * [`label`] - The label to use with the connection
 * * [`provider`] - A pointer to a newly allocated provider
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `ip` must be a valid sockaddr
 * `pairing_file` is consumed must never be used again
 * `label` must be a valid Cstr
 * `provider` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *idevice_tcp_provider_new(const struct sockaddr *ip,
                                                 struct IdevicePairingFile *pairing_file,
                                                 const char *label,
                                                 struct IdeviceProviderHandle **provider);

/**
 * Frees an IdeviceProvider handle
 *
 * # Arguments
 * * [`provider`] - The provider handle to free
 *
 * # Safety
 * `provider` must be a valid pointer to a IdeviceProvider handle that was allocated this library
 *  or NULL (in which case this function does nothing)
 */
void idevice_provider_free(struct IdeviceProviderHandle *provider);

/**
 * Creates a usbmuxd provider for idevice
 *
 * # Arguments
 * * [`addr`] - The UsbmuxdAddr handle to connect to
 * * [`tag`] - The tag returned in usbmuxd responses
 * * [`udid`] - The UDID of the device to connect to
 * * [`device_id`] - The muxer ID of the device to connect to
 * * [`label`] - The label to use with the connection
 * * [`provider`] - A pointer to a newly allocated provider
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `addr` must be a valid pointer to UsbmuxdAddrHandle created by this library, and never used again
 * `udid` must be a valid CStr
 * `label` must be a valid Cstr
 * `provider` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *usbmuxd_provider_new(struct UsbmuxdAddrHandle *addr,
                                             uint32_t tag,
                                             const char *udid,
                                             uint32_t device_id,
                                             const char *label,
                                             struct IdeviceProviderHandle **provider);

/**
 * Creates a new RemoteServerClient from a ReadWrite connection
 *
 * # Arguments
 * * [`socket`] - The connection to use for communication, an object that implements ReadWrite
 * * [`handle`] - Pointer to store the newly created RemoteServerClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `socket` must be a valid pointer to a handle allocated by this library. It is consumed and may
 * not be used again.
 * `handle` must be a valid pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *remote_server_new(struct ReadWriteOpaque *socket,
                                          struct RemoteServerHandle **handle);

/**
 * Creates a new RemoteServerClient from a handshake and adapter
 *
 * # Arguments
 * * [`provider`] - An adapter created by this library
 * * [`handshake`] - An RSD handshake from the same provider
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `provider` must be a valid pointer to a handle allocated by this library
 * `handshake` must be a valid pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *remote_server_connect_rsd(struct AdapterHandle *provider,
                                                  struct RsdHandshakeHandle *handshake,
                                                  struct RemoteServerHandle **handle);

/**
 * Frees a RemoteServerClient handle
 *
 * # Arguments
 * * [`handle`] - The handle to free
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library or NULL
 */
void remote_server_free(struct RemoteServerHandle *handle);

/**
 * Creates a new RSD handshake from a ReadWrite connection
 *
 * # Arguments
 * * [`socket`] - The connection to use for communication
 * * [`handle`] - Pointer to store the newly created RsdHandshake handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `socket` must be a valid pointer to a ReadWrite handle allocated by this library. It is
 * consumed and may not be used again.
 * `handle` must be a valid pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *rsd_handshake_new(struct ReadWriteOpaque *socket,
                                          struct RsdHandshakeHandle **handle);

/**
 * Gets the protocol version from the RSD handshake
 *
 * # Arguments
 * * [`handle`] - A valid RsdHandshake handle
 * * [`version`] - Pointer to store the protocol version
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library
 * `version` must be a valid pointer to store the version
 */
struct IdeviceFfiError *rsd_get_protocol_version(struct RsdHandshakeHandle *handle,
                                                 size_t *version);

/**
 * Gets the UUID from the RSD handshake
 *
 * # Arguments
 * * [`handle`] - A valid RsdHandshake handle
 * * [`uuid`] - Pointer to store the UUID string (caller must free with rsd_free_string)
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library
 * `uuid` must be a valid pointer to store the string pointer
 */
struct IdeviceFfiError *rsd_get_uuid(struct RsdHandshakeHandle *handle, char **uuid);

/**
 * Gets all available services from the RSD handshake
 *
 * # Arguments
 * * [`handle`] - A valid RsdHandshake handle
 * * [`services`] - Pointer to store the services array
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library
 * `services` must be a valid pointer to store the services array
 * Caller must free the returned array with rsd_free_services
 */
struct IdeviceFfiError *rsd_get_services(struct RsdHandshakeHandle *handle,
                                         struct CRsdServiceArray **services);

/**
 * Checks if a specific service is available
 *
 * # Arguments
 * * [`handle`] - A valid RsdHandshake handle
 * * [`service_name`] - Name of the service to check for
 * * [`available`] - Pointer to store the availability result
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library
 * `service_name` must be a valid C string
 * `available` must be a valid pointer to store the boolean result
 */
struct IdeviceFfiError *rsd_service_available(struct RsdHandshakeHandle *handle,
                                              const char *service_name,
                                              bool *available);

/**
 * Gets information about a specific service
 *
 * # Arguments
 * * [`handle`] - A valid RsdHandshake handle
 * * [`service_name`] - Name of the service to get info for
 * * [`service_info`] - Pointer to store the service information
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library
 * `service_name` must be a valid C string
 * `service_info` must be a valid pointer to store the service info
 * Caller must free the returned service with rsd_free_service
 */
struct IdeviceFfiError *rsd_get_service_info(struct RsdHandshakeHandle *handle,
                                             const char *service_name,
                                             struct CRsdService **service_info);

/**
 * Frees a string returned by RSD functions
 *
 * # Arguments
 * * [`string`] - The string to free
 *
 * # Safety
 * Must only be called with strings returned from RSD functions
 */
void rsd_free_string(char *string);

/**
 * Frees a single service returned by rsd_get_service_info
 *
 * # Arguments
 * * [`service`] - The service to free
 *
 * # Safety
 * Must only be called with services returned from rsd_get_service_info
 */
void rsd_free_service(struct CRsdService *service);

/**
 * Frees services array returned by rsd_get_services
 *
 * # Arguments
 * * [`services`] - The services array to free
 *
 * # Safety
 * Must only be called with arrays returned from rsd_get_services
 */
void rsd_free_services(struct CRsdServiceArray *services);

/**
 * Frees an RSD handshake handle
 *
 * # Arguments
 * * [`handle`] - The handle to free
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library,
 * or NULL (in which case this function does nothing)
 */
void rsd_handshake_free(struct RsdHandshakeHandle *handle);

/**
 * Connects to the Springboard service using a provider
 *
 * # Arguments
 * * [`provider`] - An IdeviceProvider
 * * [`client`] - On success, will be set to point to a newly allocated SpringBoardServicesClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `provider` must be a valid pointer to a handle allocated by this library
 * `client` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *springboard_services_connect(struct IdeviceProviderHandle *provider,
                                                     struct SpringBoardServicesClientHandle **client);

/**
 * Creates a new SpringBoardServices client from an existing Idevice connection
 *
 * # Arguments
 * * [`socket`] - An IdeviceSocket handle
 * * [`client`] - On success, will be set to point to a newly allocated SpringBoardServicesClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `socket` must be a valid pointer to a handle allocated by this library. The socket is consumed,
 * and may not be used again.
 * `client` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *springboard_services_new(struct IdeviceHandle *socket,
                                                 struct SpringBoardServicesClientHandle **client);

/**
 * Gets the icon of the specified app by bundle identifier
 *
 * # Arguments
 * * `client` - A valid SpringBoardServicesClient handle
 * * `bundle_identifier` - The identifiers of the app to get icon
 * * `out_result` - On success, will be set to point to a newly allocated png data
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `out_result` must be a valid, non-null pointer to a location where the result will be stored
 */
struct IdeviceFfiError *springboard_services_get_icon(struct SpringBoardServicesClientHandle *client,
                                                      const char *bundle_identifier,
                                                      void **out_result,
                                                      size_t *out_result_len);

/**
 * Frees an SpringBoardServicesClient handle
 *
 * # Arguments
 * * [`handle`] - The handle to free
 *
 * # Safety
 * `handle` must be a valid pointer to the handle that was allocated by this library,
 * or NULL (in which case this function does nothing)
 */
void springboard_services_free(struct SpringBoardServicesClientHandle *handle);

/**
 * Automatically creates and connects to syslog relay, returning a client handle
 *
 * # Arguments
 * * [`provider`] - An IdeviceProvider
 * * [`client`] - On success, will be set to point to a newly allocated SyslogRelayClient handle
 *
 * # Safety
 * `provider` must be a valid pointer to a handle allocated by this library
 * `client` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *syslog_relay_connect_tcp(struct IdeviceProviderHandle *provider,
                                                 struct SyslogRelayClientHandle **client);

/**
 * Frees a handle
 *
 * # Arguments
 * * [`handle`] - The handle to free
 *
 * # Safety
 * `handle` must be a valid pointer to the handle that was allocated by this library,
 * or NULL (in which case this function does nothing)
 */
void syslog_relay_client_free(struct SyslogRelayClientHandle *handle);

/**
 * Gets the next log message from the relay
 *
 * # Arguments
 * * [`client`] - The SyslogRelayClient handle
 * * [`log_message`] - On success a newly allocated cstring will be set to point to the log message
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 * `log_message` must be a valid, non-null pointer to a location where the log message will be stored
 */
struct IdeviceFfiError *syslog_relay_next(struct SyslogRelayClientHandle *client,
                                          char **log_message);

/**
 * Connects to a usbmuxd instance over TCP
 *
 * # Arguments
 * * [`addr`] - The socket address to connect to
 * * [`addr_len`] - Length of the socket
 * * [`tag`] - A tag that will be returned by usbmuxd responses
 * * [`usbmuxd_connection`] - On success, will be set to point to a newly allocated UsbmuxdConnection handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `addr` must be a valid sockaddr
 * `usbmuxd_connection` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *idevice_usbmuxd_new_tcp_connection(const struct sockaddr *addr,
                                                           socklen_t addr_len,
                                                           uint32_t tag,
                                                           struct UsbmuxdConnectionHandle **usbmuxd_connection);

/**
 * Connects to a usbmuxd instance over unix socket
 *
 * # Arguments
 * * [`addr`] - The socket path to connect to
 * * [`tag`] - A tag that will be returned by usbmuxd responses
 * * [`usbmuxd_connection`] - On success, will be set to point to a newly allocated UsbmuxdConnection handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `addr` must be a valid CStr
 * `usbmuxd_connection` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *idevice_usbmuxd_new_unix_socket_connection(const char *addr,
                                                                   uint32_t tag,
                                                                   struct UsbmuxdConnectionHandle **usbmuxd_connection);

/**
 * Frees a UsbmuxdConnection handle
 *
 * # Arguments
 * * [`usbmuxd_connection`] - The UsbmuxdConnection handle to free
 *
 * # Safety
 * `usbmuxd_connection` must be a valid pointer to a UsbmuxdConnection handle that was allocated by this library,
 * or NULL (in which case this function does nothing)
 */
void idevice_usbmuxd_connection_free(struct UsbmuxdConnectionHandle *usbmuxd_connection);

/**
 * Creates a usbmuxd TCP address struct
 *
 * # Arguments
 * * [`addr`] - The socket address to connect to
 * * [`addr_len`] - Length of the socket
 * * [`usbmuxd_addr`] - On success, will be set to point to a newly allocated UsbmuxdAddr handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `addr` must be a valid sockaddr
 * `usbmuxd_Addr` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *idevice_usbmuxd_tcp_addr_new(const struct sockaddr *addr,
                                                     socklen_t addr_len,
                                                     struct UsbmuxdAddrHandle **usbmuxd_addr);

/**
 * Creates a new UsbmuxdAddr struct with a unix socket
 *
 * # Arguments
 * * [`addr`] - The socket path to connect to
 * * [`usbmuxd_addr`] - On success, will be set to point to a newly allocated UsbmuxdAddr handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `addr` must be a valid CStr
 * `usbmuxd_addr` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *idevice_usbmuxd_unix_addr_new(const char *addr,
                                                      struct UsbmuxdAddrHandle **usbmuxd_addr);

/**
 * Frees a UsbmuxdAddr handle
 *
 * # Arguments
 * * [`usbmuxd_addr`] - The UsbmuxdAddr handle to free
 *
 * # Safety
 * `usbmuxd_addr` must be a valid pointer to a UsbmuxdAddr handle that was allocated by this library,
 * or NULL (in which case this function does nothing)
 */
void idevice_usbmuxd_addr_free(struct UsbmuxdAddrHandle *usbmuxd_addr);

#endif
