// Jackson Coxson
// Bindings to idevice - https://github.com/jkcoxson/idevice

#ifdef _WIN32
  #ifndef WIN32_LEAN_AND_MEAN
  #define WIN32_LEAN_AND_MEAN
  #endif
  #include <winsock2.h>
  #include <ws2tcpip.h>
  typedef int                idevice_socklen_t;
  typedef struct sockaddr    idevice_sockaddr;
#else
  #include <sys/types.h>
  #include <sys/socket.h>
  typedef socklen_t          idevice_socklen_t;
  typedef struct sockaddr    idevice_sockaddr;
#endif


#ifndef IDEVICE_H
#define IDEVICE_H

#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

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

typedef enum IdeviceLoggerError {
  Success = 0,
  FileError = -1,
  AlreadyInitialized = -2,
  InvalidPathString = -3,
} IdeviceLoggerError;

typedef enum IdeviceLogLevel {
  Disabled = 0,
  ErrorLevel = 1,
  Warn = 2,
  Info = 3,
  Debug = 4,
  Trace = 5,
} IdeviceLogLevel;

typedef struct AdapterHandle AdapterHandle;

typedef struct AdapterStreamHandle AdapterStreamHandle;

typedef struct AfcClientHandle AfcClientHandle;

/**
 * Handle for an open file on the device
 */
typedef struct AfcFileHandle AfcFileHandle;

typedef struct AmfiClientHandle AmfiClientHandle;

/**
 * Opaque handle to an AppServiceClient
 */
typedef struct AppServiceHandle AppServiceHandle;

typedef struct CoreDeviceProxyHandle CoreDeviceProxyHandle;

/**
 * Opaque handle to a DebugProxyClient
 */
typedef struct DebugProxyHandle DebugProxyHandle;

typedef struct DiagnosticsRelayClientHandle DiagnosticsRelayClientHandle;

/**
 * Opaque handle to an AppServiceClient
 */
typedef struct DiagnosticsServiceHandle DiagnosticsServiceHandle;

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

/**
 * An opaque FFI handle for a [`ScreenshotClient`].
 *
 * This type wraps a [`ScreenshotClient`] that communicates with
 * a connected device to capture screenshots through the DVT (Device Virtualization Toolkit) service.
 */
typedef struct ScreenshotClientHandle ScreenshotClientHandle;

typedef struct SpringBoardServicesClientHandle SpringBoardServicesClientHandle;

typedef struct SysdiagnoseStreamHandle SysdiagnoseStreamHandle;

typedef struct SyslogRelayClientHandle SyslogRelayClientHandle;

typedef struct TcpEatObject TcpEatObject;

typedef struct TcpFeedObject TcpFeedObject;

typedef struct UsbmuxdAddrHandle UsbmuxdAddrHandle;

typedef struct UsbmuxdConnectionHandle UsbmuxdConnectionHandle;

typedef struct UsbmuxdDeviceHandle UsbmuxdDeviceHandle;

typedef struct UsbmuxdListenerHandle UsbmuxdListenerHandle;

typedef struct Vec_u64 Vec_u64;

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
 * C-compatible app list entry
 */
typedef struct AppListEntryC {
  int is_removable;
  char *name;
  int is_first_party;
  char *path;
  char *bundle_identifier;
  int is_developer_app;
  char *bundle_version;
  int is_internal;
  int is_hidden;
  int is_app_clip;
  char *version;
} AppListEntryC;

/**
 * C-compatible launch response
 */
typedef struct LaunchResponseC {
  uint32_t process_identifier_version;
  uint32_t pid;
  char *executable_url;
  uint32_t *audit_token;
  uintptr_t audit_token_len;
} LaunchResponseC;

/**
 * C-compatible process token
 */
typedef struct ProcessTokenC {
  uint32_t pid;
  char *executable_url;
} ProcessTokenC;

/**
 * C-compatible signal response
 */
typedef struct SignalResponseC {
  uint32_t pid;
  char *executable_url;
  uint64_t device_timestamp;
  uint32_t signal;
} SignalResponseC;

/**
 * C-compatible icon data
 */
typedef struct IconDataC {
  uint8_t *data;
  uintptr_t data_len;
  double icon_width;
  double icon_height;
  double minimum_width;
  double minimum_height;
} IconDataC;

/**
 * Represents a debugserver command
 */
typedef struct DebugserverCommandHandle {
  char *name;
  char **argv;
  uintptr_t argv_count;
} DebugserverCommandHandle;

/**
 * Stub to avoid header problems
 */
typedef void *plist_t;

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
 * Creates an Idevice object from a socket file descriptor
 *
 * # Safety
 * The socket FD must be valid.
 * The pointers must be valid and non-null.
 */
struct IdeviceFfiError *idevice_from_fd(int32_t fd,
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
struct IdeviceFfiError *idevice_new_tcp_socket(const idevice_sockaddr *addr,
                                               idevice_socklen_t addr_len,
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
                                              const struct IdevicePairingFile *pairing_file,
                                              bool legacy);

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
 * Frees data allocated by this library
 *
 * # Arguments
 * * [`data`] - The data to free
 *
 * # Safety
 * `data` must be a valid pointer to data that was allocated by this library,
 * or NULL (in which case this function does nothing)
 */
void idevice_data_free(uint8_t *data, uintptr_t len);

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
 * Closes the adapter stream connection
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
struct IdeviceFfiError *adapter_stream_close(struct AdapterStreamHandle *handle);

/**
 * Stops the entire adapter TCP stack
 *
 * # Arguments
 * * [`handle`] - The adapter handle
 *
 * # Returns
 * Null on success, an IdeviceFfiError otherwise
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library
 */
struct IdeviceFfiError *adapter_close(struct AdapterHandle *handle);

/**
 * Sends data through the adapter stream
 *
 * # Arguments
 * * [`handle`] - The adapter stream handle
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
 * Receives data from the adapter stream
 *
 * # Arguments
 * * [`handle`] - The adapter stream handle
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
 * Creates a new AppServiceClient using RSD connection
 *
 * # Arguments
 * * [`provider`] - An adapter created by this library
 * * [`handshake`] - An RSD handshake from the same provider
 * * [`handle`] - Pointer to store the newly created handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `provider` and `handshake` must be valid pointers to handles allocated by this library
 * `handle` must be a valid pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *app_service_connect_rsd(struct AdapterHandle *provider,
                                                struct RsdHandshakeHandle *handshake,
                                                struct AppServiceHandle **handle);

/**
 * Creates a new AppServiceClient from a socket
 *
 * # Arguments
 * * [`socket`] - The socket to use for communication
 * * [`handle`] - Pointer to store the newly created handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `socket` must be a valid pointer to a handle allocated by this library
 * `handle` must be a valid pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *app_service_new(struct ReadWriteOpaque *socket,
                                        struct AppServiceHandle **handle);

/**
 * Frees an AppServiceClient handle
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library or NULL
 */
void app_service_free(struct AppServiceHandle *handle);

/**
 * Lists applications on the device
 *
 * # Arguments
 * * [`handle`] - The AppServiceClient handle
 * * [`app_clips`] - Include app clips
 * * [`removable_apps`] - Include removable apps
 * * [`hidden_apps`] - Include hidden apps
 * * [`internal_apps`] - Include internal apps
 * * [`default_apps`] - Include default apps
 * * [`apps`] - Pointer to store the array of apps (caller must free)
 * * [`count`] - Pointer to store the number of apps
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `handle`, `apps`, and `count` must be valid pointers
 */
struct IdeviceFfiError *app_service_list_apps(struct AppServiceHandle *handle,
                                              int app_clips,
                                              int removable_apps,
                                              int hidden_apps,
                                              int internal_apps,
                                              int default_apps,
                                              struct AppListEntryC **apps,
                                              uintptr_t *count);

/**
 * Frees an array of AppListEntryC structures
 *
 * # Safety
 * `apps` must be a valid pointer to an array allocated by app_service_list_apps
 * `count` must match the count returned by app_service_list_apps
 */
void app_service_free_app_list(struct AppListEntryC *apps, uintptr_t count);

/**
 * Launches an application
 *
 * # Arguments
 * * [`handle`] - The AppServiceClient handle
 * * [`bundle_id`] - Bundle identifier of the app to launch
 * * [`argv`] - NULL-terminated array of arguments
 * * [`argc`] - Number of arguments
 * * [`kill_existing`] - Whether to kill existing instances
 * * [`start_suspended`] - Whether to start suspended
 * * [`stdio_uuid`] - The UUID received from openstdiosocket, null for none
 * * [`response`] - Pointer to store the launch response (caller must free)
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * All pointer parameters must be valid
 */
struct IdeviceFfiError *app_service_launch_app(struct AppServiceHandle *handle,
                                               const char *bundle_id,
                                               const char *const *argv,
                                               uintptr_t argc,
                                               int kill_existing,
                                               int start_suspended,
                                               const uint8_t *stdio_uuid,
                                               struct LaunchResponseC **response);

/**
 * Frees a LaunchResponseC structure
 *
 * # Safety
 * `response` must be a valid pointer allocated by app_service_launch_app
 */
void app_service_free_launch_response(struct LaunchResponseC *response);

/**
 * Lists running processes
 *
 * # Arguments
 * * [`handle`] - The AppServiceClient handle
 * * [`processes`] - Pointer to store the array of processes (caller must free)
 * * [`count`] - Pointer to store the number of processes
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * All pointer parameters must be valid
 */
struct IdeviceFfiError *app_service_list_processes(struct AppServiceHandle *handle,
                                                   struct ProcessTokenC **processes,
                                                   uintptr_t *count);

/**
 * Frees an array of ProcessTokenC structures
 *
 * # Safety
 * `processes` must be a valid pointer allocated by app_service_list_processes
 * `count` must match the count returned by app_service_list_processes
 */
void app_service_free_process_list(struct ProcessTokenC *processes, uintptr_t count);

/**
 * Uninstalls an application
 *
 * # Arguments
 * * [`handle`] - The AppServiceClient handle
 * * [`bundle_id`] - Bundle identifier of the app to uninstall
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * All pointer parameters must be valid
 */
struct IdeviceFfiError *app_service_uninstall_app(struct AppServiceHandle *handle,
                                                  const char *bundle_id);

/**
 * Sends a signal to a process
 *
 * # Arguments
 * * [`handle`] - The AppServiceClient handle
 * * [`pid`] - Process ID
 * * [`signal`] - Signal number
 * * [`response`] - Pointer to store the signal response (caller must free)
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * All pointer parameters must be valid
 */
struct IdeviceFfiError *app_service_send_signal(struct AppServiceHandle *handle,
                                                uint32_t pid,
                                                uint32_t signal,
                                                struct SignalResponseC **response);

/**
 * Frees a SignalResponseC structure
 *
 * # Safety
 * `response` must be a valid pointer allocated by app_service_send_signal
 */
void app_service_free_signal_response(struct SignalResponseC *response);

/**
 * Fetches an app icon
 *
 * # Arguments
 * * [`handle`] - The AppServiceClient handle
 * * [`bundle_id`] - Bundle identifier of the app
 * * [`width`] - Icon width
 * * [`height`] - Icon height
 * * [`scale`] - Icon scale
 * * [`allow_placeholder`] - Whether to allow placeholder icons
 * * [`icon_data`] - Pointer to store the icon data (caller must free)
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * All pointer parameters must be valid
 */
struct IdeviceFfiError *app_service_fetch_app_icon(struct AppServiceHandle *handle,
                                                   const char *bundle_id,
                                                   float width,
                                                   float height,
                                                   float scale,
                                                   int allow_placeholder,
                                                   struct IconDataC **icon_data);

/**
 * Frees an IconDataC structure
 *
 * # Safety
 * `icon_data` must be a valid pointer allocated by app_service_fetch_app_icon
 */
void app_service_free_icon_data(struct IconDataC *icon_data);

/**
 * Creates a new DiagnosticsServiceClient using RSD connection
 *
 * # Arguments
 * * [`provider`] - An adapter created by this library
 * * [`handshake`] - An RSD handshake from the same provider
 * * [`handle`] - Pointer to store the newly created handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `provider` and `handshake` must be valid pointers to handles allocated by this library
 * `handle` must be a valid pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *diagnostics_service_connect_rsd(struct AdapterHandle *provider,
                                                        struct RsdHandshakeHandle *handshake,
                                                        struct DiagnosticsServiceHandle **handle);

/**
 * Creates a new DiagnostisServiceClient from a socket
 *
 * # Arguments
 * * [`socket`] - The socket to use for communication
 * * [`handle`] - Pointer to store the newly created handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `socket` must be a valid pointer to a handle allocated by this library
 * `handle` must be a valid pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *diagnostics_service_new(struct ReadWriteOpaque *socket,
                                                struct DiagnosticsServiceHandle **handle);

/**
 * Captures a sysdiagnose from the device.
 * Note that this will take a LONG time to return while the device collects enough information to
 * return to the service. This function returns a stream that can be called on to get the next
 * chunk of data. A typical sysdiagnose is roughly 1-2 GB.
 *
 * # Arguments
 * * [`handle`] - The handle to the client
 * * [`dry_run`] - Whether or not to do a dry run with a simple .txt file from the device
 * * [`preferred_filename`] - The name the device wants to save the sysdaignose as
 * * [`expected_length`] - The size in bytes of the sysdiagnose
 * * [`stream_handle`] - The handle that will be set to capture bytes for
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * Pointers must be all valid. Handle must be allocated by this library. Preferred filename must
 * be freed `idevice_string_free`.
 */
struct IdeviceFfiError *diagnostics_service_capture_sysdiagnose(struct DiagnosticsServiceHandle *handle,
                                                                bool dry_run,
                                                                char **preferred_filename,
                                                                uintptr_t *expected_length,
                                                                struct SysdiagnoseStreamHandle **stream_handle);

/**
 * Gets the next packet from the stream.
 * Data will be set to 0 when there is no more data to get from the stream.
 *
 * # Arguments
 * * [`handle`] - The handle to the stream
 * * [`data`] - A pointer to the bytes
 * * [`len`] - The length of the bytes written
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * Pass valid pointers. The handle must be allocated by this library.
 */
struct IdeviceFfiError *sysdiagnose_stream_next(struct SysdiagnoseStreamHandle *handle,
                                                uint8_t **data,
                                                uintptr_t *len);

/**
 * Frees a DiagnostisServiceClient handle
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library or NULL
 */
void diagnostics_service_free(struct DiagnosticsServiceHandle *handle);

/**
 * Frees a SysdiagnoseStreamHandle handle
 *
 * # Safety
 * `handle` must be a valid pointer to a handle allocated by this library or NULL
 */
void sysdiagnose_stream_free(struct SysdiagnoseStreamHandle *handle);

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
 * Creates a new DebugProxyClient
 *
 * # Arguments
 * * [`socket`] - The socket to use for communication. Any object that supports ReadWrite.
 * * [`handle`] - Pointer to store the newly created DebugProxyClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `socket` must be a valid pointer to a handle allocated by this library
 * `handle` must be a valid pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *debug_proxy_new(struct ReadWriteOpaque *socket,
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
 * Automatically creates and connects to Diagnostics Relay, returning a client handle
 *
 * # Arguments
 * * [`provider`] - An IdeviceProvider
 * * [`client`] - On success, will be set to point to a newly allocated DiagnosticsRelayClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `provider` must be a valid pointer to a handle allocated by this library
 * `client` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *diagnostics_relay_client_connect(struct IdeviceProviderHandle *provider,
                                                         struct DiagnosticsRelayClientHandle **client);

/**
 * Automatically creates and connects to Diagnostics Relay, returning a client handle
 *
 * # Arguments
 * * [`socket`] - An IdeviceSocket handle
 * * [`client`] - On success, will be set to point to a newly allocated DiagnosticsRelayClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `socket` must be a valid pointer to a handle allocated by this library. The socket is consumed,
 * and may not be used again.
 * `client` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *diagnostics_relay_client_new(struct IdeviceHandle *socket,
                                                     struct DiagnosticsRelayClientHandle **client);

/**
 * Queries the device IO registry
 *
 * # Arguments
 * * `client` - A valid DiagnosticsRelayClient handle
 * * `current_plane` - A string to search by or null
 * * `entry_name` - A string to search by or null
 * * `entry_class` - A string to search by or null
 * * `res` - Will be set to a pointer of a plist dictionary node on search success
 *
 * # Returns
 * An IdeviceFfiError on error, null on success. Note that res can be null on success
 * if the search resulted in no values.
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 */
struct IdeviceFfiError *diagnostics_relay_client_ioregistry(struct DiagnosticsRelayClientHandle *client,
                                                            const char *current_plane,
                                                            const char *entry_name,
                                                            const char *entry_class,
                                                            plist_t *res);

/**
 * Requests MobileGestalt information from the device
 *
 * # Arguments
 * * `client` - A valid DiagnosticsRelayClient handle
 * * `keys` - Optional list of specific keys to request. If None, requests all available keys
 * * `res` - Will be set to a pointer of a plist dictionary node on search success
 *
 * # Returns
 * An IdeviceFfiError on error, null on success. Note that res can be null on success
 * if the search resulted in no values.
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 */
struct IdeviceFfiError *diagnostics_relay_client_mobilegestalt(struct DiagnosticsRelayClientHandle *client,
                                                               const char *const *keys,
                                                               uintptr_t keys_len,
                                                               plist_t *res);

/**
 * Requests gas gauge information from the device
 *
 * # Arguments
 * * `client` - A valid DiagnosticsRelayClient handle
 * * `res` - Will be set to a pointer of a plist dictionary node on search success
 *
 * # Returns
 * An IdeviceFfiError on error, null on success. Note that res can be null on success
 * if the search resulted in no values.
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 */
struct IdeviceFfiError *diagnostics_relay_client_gasguage(struct DiagnosticsRelayClientHandle *client,
                                                          plist_t *res);

/**
 * Requests nand information from the device
 *
 * # Arguments
 * * `client` - A valid DiagnosticsRelayClient handle
 * * `res` - Will be set to a pointer of a plist dictionary node on search success
 *
 * # Returns
 * An IdeviceFfiError on error, null on success. Note that res can be null on success
 * if the search resulted in no values.
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 */
struct IdeviceFfiError *diagnostics_relay_client_nand(struct DiagnosticsRelayClientHandle *client,
                                                      plist_t *res);

/**
 * Requests all available information from the device
 *
 * # Arguments
 * * `client` - A valid DiagnosticsRelayClient handle
 * * `res` - Will be set to a pointer of a plist dictionary node on search success
 *
 * # Returns
 * An IdeviceFfiError on error, null on success. Note that res can be null on success
 * if the search resulted in no values.
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 */
struct IdeviceFfiError *diagnostics_relay_client_all(struct DiagnosticsRelayClientHandle *client,
                                                     plist_t *res);

/**
 * Restarts the device
 *
 * # Arguments
 * * `client` - A valid DiagnosticsRelayClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success.
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 */
struct IdeviceFfiError *diagnostics_relay_client_restart(struct DiagnosticsRelayClientHandle *client);

/**
 * Shuts down the device
 *
 * # Arguments
 * * `client` - A valid DiagnosticsRelayClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success.
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 */
struct IdeviceFfiError *diagnostics_relay_client_shutdown(struct DiagnosticsRelayClientHandle *client);

/**
 * Puts the device to sleep
 *
 * # Arguments
 * * `client` - A valid DiagnosticsRelayClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success.
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 */
struct IdeviceFfiError *diagnostics_relay_client_sleep(struct DiagnosticsRelayClientHandle *client);

/**
 * Requests WiFi diagnostics from the device
 *
 * # Arguments
 * * `client` - A valid DiagnosticsRelayClient handle
 * * `res` - Will be set to a pointer of a plist dictionary node on search success
 *
 * # Returns
 * An IdeviceFfiError on error, null on success. Note that res can be null on success
 * if the search resulted in no values.
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 */
struct IdeviceFfiError *diagnostics_relay_client_wifi(struct DiagnosticsRelayClientHandle *client,
                                                      plist_t *res);

/**
 * Puts the device to sleep
 *
 * # Arguments
 * * `client` - A valid DiagnosticsRelayClient handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success.
 *
 * # Safety
 * `client` must be a valid pointer to a handle allocated by this library
 */
struct IdeviceFfiError *diagnostics_relay_client_goodbye(struct DiagnosticsRelayClientHandle *client);

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
void diagnostics_relay_client_free(struct DiagnosticsRelayClientHandle *handle);

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
 * Creates a new [`ScreenshotClient`] associated with a given [`RemoteServerHandle`].
 *
 * # Arguments
 * * `server` - A pointer to a valid [`RemoteServerHandle`], previously created by this library.
 * * `handle` - A pointer to a location where the newly created [`ScreenshotClientHandle`] will be stored.
 *
 * # Returns
 * * `null_mut()` on success.
 * * A pointer to an [`IdeviceFfiError`] on failure.
 *
 * # Safety
 * - `server` must be a non-null pointer to a valid remote server handle allocated by this library.
 * - `handle` must be a non-null pointer to a writable memory location where the handle will be stored.
 * - The returned handle must later be freed using [`screenshot_client_free`].
 */
struct IdeviceFfiError *screenshot_client_new(struct RemoteServerHandle *server,
                                              struct ScreenshotClientHandle **handle);

/**
 * Frees a [`ScreenshotClientHandle`].
 *
 * This releases all memory associated with the handle.
 * After calling this function, the handle pointer must not be used again.
 *
 * # Arguments
 * * `handle` - Pointer to a [`ScreenshotClientHandle`] previously returned by [`screenshot_client_new`].
 *
 * # Safety
 * - `handle` must either be `NULL` or a valid pointer created by this library.
 * - Double-freeing or using the handle after freeing causes undefined behavior.
 */
void screenshot_client_free(struct ScreenshotClientHandle *handle);

/**
 * Captures a screenshot from the connected device.
 *
 * On success, this function writes a pointer to the PNG-encoded screenshot data and its length
 * into the provided output arguments. The caller is responsible for freeing this data using
 * `idevice_data_free`.
 *
 * # Arguments
 * * `handle` - A pointer to a valid [`ScreenshotClientHandle`].
 * * `data` - Output pointer where the screenshot buffer pointer will be written.
 * * `len` - Output pointer where the buffer length (in bytes) will be written.
 *
 * # Returns
 * * `null_mut()` on success.
 * * A pointer to an [`IdeviceFfiError`] on failure.
 *
 * # Safety
 * - `handle` must be a valid pointer to a [`ScreenshotClientHandle`].
 * - `data` and `len` must be valid writable pointers.
 * - The data returned through `*data` must be freed by the caller with `idevice_data_free`.
 */
struct IdeviceFfiError *screenshot_client_take_screenshot(struct ScreenshotClientHandle *handle,
                                                          uint8_t **data,
                                                          uintptr_t *len);

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
struct IdeviceFfiError *installation_proxy_connect(struct IdeviceProviderHandle *provider,
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
                                                   plist_t options);

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
                                                                 plist_t options,
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
                                                   plist_t options);

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
                                                                 plist_t options,
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
                                                     plist_t options);

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
                                                                   plist_t options,
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
                                                                    const plist_t *capabilities,
                                                                    size_t capabilities_len,
                                                                    plist_t options,
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
                                                  plist_t options,
                                                  plist_t **out_result,
                                                  size_t *out_result_len);

/**
 * Connects to lockdownd service using provider
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
                                            plist_t *out_plist);

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
 * Initializes the global logger
 *
 * # Safety
 * Pass a valid file path string
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
                                                   plist_t **devices,
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
                                                                        plist_t *identifiers);

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
struct IdeviceFfiError *idevice_tcp_provider_new(const idevice_sockaddr *ip,
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
 * Gets the pairing file for the device
 *
 * # Arguments
 * * [`provider`] - A pointer to the provider
 * * [`pairing_file`] - A pointer to the newly allocated pairing file
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `provider` must be a valid, non-null pointer to the provider
 */
struct IdeviceFfiError *idevice_provider_get_pairing_file(struct IdeviceProviderHandle *provider,
                                                          struct IdevicePairingFile **pairing_file);

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
 * Clones an RSD handshake
 *
 * # Safety
 * Pass a valid pointer allocated by this library
 */
struct RsdHandshakeHandle *rsd_handshake_clone(struct RsdHandshakeHandle *handshake);

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
 * # Safety
 * Pass valid pointers.
 */
struct IdeviceFfiError *idevice_tcp_stack_into_sync_objects(const char *our_ip,
                                                            const char *their_ip,
                                                            struct TcpFeedObject **feeder,
                                                            struct TcpEatObject **tcp_receiver,
                                                            struct AdapterHandle **adapter_handle);

/**
 * Feed the TCP stack with data
 * # Safety
 * Pass valid pointers. Data is cloned out of slice.
 */
struct IdeviceFfiError *idevice_tcp_feed_object_write(struct TcpFeedObject *object,
                                                      const uint8_t *data,
                                                      uintptr_t len);

/**
 * Block on getting a block of data to write to the underlying stream.
 * Write this to the stream as is, and free the data with idevice_data_free
 *
 * # Safety
 * Pass valid pointers
 */
struct IdeviceFfiError *idevice_tcp_eat_object_read(struct TcpEatObject *object,
                                                    uint8_t **data,
                                                    uintptr_t *len);

/**
 * # Safety
 * Pass a valid pointer allocated by this library
 */
void idevice_free_tcp_feed_object(struct TcpFeedObject *object);

/**
 * # Safety
 * Pass a valid pointer allocated by this library
 */
void idevice_free_tcp_eat_object(struct TcpEatObject *object);

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
struct IdeviceFfiError *idevice_usbmuxd_new_tcp_connection(const idevice_sockaddr *addr,
                                                           idevice_socklen_t addr_len,
                                                           uint32_t tag,
                                                           struct UsbmuxdConnectionHandle **out);

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
 * Connects to a usbmuxd instance over the default connection for the platform
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
struct IdeviceFfiError *idevice_usbmuxd_new_default_connection(uint32_t tag,
                                                               struct UsbmuxdConnectionHandle **usbmuxd_connection);

/**
 * Gets a list of connected devices from usbmuxd.
 *
 * The returned list must be freed with `idevice_usbmuxd_device_list_free`.
 *
 * # Arguments
 * * `usbmuxd_conn` - A valid connection to usbmuxd.
 * * `devices` - A pointer to a C-style array of `UsbmuxdDeviceHandle` pointers. On success, this will be filled.
 * * `count` - A pointer to an integer. On success, this will be filled with the number of devices found.
 *
 * # Returns
 * An `IdeviceFfiError` on error, `null` on success.
 *
 * # Safety
 * * `usbmuxd_conn` must be a valid pointer.
 * * `devices` and `count` must be valid, non-null pointers.
 */
struct IdeviceFfiError *idevice_usbmuxd_get_devices(struct UsbmuxdConnectionHandle *usbmuxd_conn,
                                                    struct UsbmuxdDeviceHandle ***devices,
                                                    int *count);

/**
 * Connects to a service on a given device.
 *
 * This function consumes the `UsbmuxdConnectionHandle`. The handle will be invalid after this call
 * and must not be used again. The caller is NOT responsible for freeing it.
 * A new `IdeviceHandle` is returned on success, which must be freed by the caller.
 *
 * # Arguments
 * * `usbmuxd_connection` - The connection to use. It will be consumed.
 * * `device_id` - The ID of the device to connect to.
 * * `port` - The TCP port on the device to connect to.
 * * `idevice` - On success, points to the new device connection handle.
 *
 * # Returns
 * An `IdeviceFfiError` on error, `null` on success.
 *
 * # Safety
 * * `usbmuxd_connection` must be a valid pointer allocated by this library and never used again.
 *   The value is consumed.
 * * `idevice` must be a valid, non-null pointer.
 */
struct IdeviceFfiError *idevice_usbmuxd_connect_to_device(struct UsbmuxdConnectionHandle *usbmuxd_connection,
                                                          uint32_t device_id,
                                                          uint16_t port,
                                                          const char *label,
                                                          struct IdeviceHandle **idevice);

/**
 * Reads the pairing record for a given device UDID.
 *
 * The returned `PairingFileHandle` must be freed with `idevice_pair_record_free`.
 *
 * # Arguments
 * * `usbmuxd_conn` - A valid connection to usbmuxd.
 * * `udid` - The UDID of the device.
 * * `pair_record` - On success, points to the new pairing file handle.
 *
 * # Returns
 * An `IdeviceFfiError` on error, `null` on success.
 *
 * # Safety
 * * `usbmuxd_conn` must be a valid pointer.
 * * `udid` must be a valid, null-terminated C string.
 * * `pair_record` must be a valid, non-null pointer.
 */
struct IdeviceFfiError *idevice_usbmuxd_get_pair_record(struct UsbmuxdConnectionHandle *usbmuxd_conn,
                                                        const char *udid,
                                                        struct IdevicePairingFile **pair_record);

/**
 * Saves the pairing record for a given device UDID.
 *
 * # Arguments
 * * `usbmuxd_conn` - A valid connection to usbmuxd.
 * * `device_id` - The muxer ID for the device
 * * `udid` - The UDID of the device.
 * * `pair_record` - The bytes of the pairing record plist to save
 * * `pair_record_len` - the length of the pairing record bytes
 *
 * # Returns
 * An `IdeviceFfiError` on error, `null` on success.
 *
 * # Safety
 * * `usbmuxd_conn` must be a valid pointer.
 * * `udid` must be a valid, null-terminated C string.
 * * `pair_record` must be a valid, non-null pointer.
 */
struct IdeviceFfiError *idevice_usbmuxd_save_pair_record(struct UsbmuxdConnectionHandle *usbmuxd_conn,
                                                         const char *udid,
                                                         uint8_t *pair_record,
                                                         uintptr_t pair_record_len);

/**
 * Listens on the socket for connections and disconnections
 *
 * # Safety
 * Pass valid pointers. Free the stream with ``idevice_usbmuxd_listener_handle_free``.
 * The stream must outlive the usbmuxd connection, and the usbmuxd connection cannot
 * be used for other requests.
 */
struct IdeviceFfiError *idevice_usbmuxd_listen(struct UsbmuxdConnectionHandle *usbmuxd_conn,
                                               struct UsbmuxdListenerHandle **stream_handle);

/**
 * Frees a stream created by ``listen`` or does nothing on null
 *
 * # Safety
 * Pass a valid pointer.
 */
void idevice_usbmuxd_listener_handle_free(struct UsbmuxdListenerHandle *stream_handle);

/**
 * Gets the next event from the stream.
 * Connect will be set to true if the event is a connection event,
 * and the connection_device will be filled with the device information.
 * If connection is false, the mux ID of the device will be filled.
 *
 * # Arguments
 * * `stream_handle` - The handle to the stream returned by listen
 * * `connect` - The bool that will be set
 * * `connection_device` - The pointer that will be filled on a connect event
 * * `disconnection_id` - The mux ID that will be set on a disconnect event
 *
 * # Safety
 * Pass valid pointers
 */
struct IdeviceFfiError *idevice_usbmuxd_listener_next(struct UsbmuxdListenerHandle *stream_handle,
                                                      bool *connect,
                                                      struct UsbmuxdDeviceHandle **connection_device,
                                                      uint32_t *disconnection_id);

/**
 * Reads the BUID (Boot-Unique ID) from usbmuxd.
 *
 * The returned string must be freed with `idevice_string_free`.
 *
 * # Arguments
 * * `usbmuxd_conn` - A valid connection to usbmuxd.
 * * `buid` - On success, points to a newly allocated, null-terminated C string.
 *
 * # Returns
 * An `IdeviceFfiError` on error, `null` on success.
 *
 * # Safety
 * * `usbmuxd_conn` must be a valid pointer.
 * * `buid` must be a valid, non-null pointer.
 */
struct IdeviceFfiError *idevice_usbmuxd_get_buid(struct UsbmuxdConnectionHandle *usbmuxd_conn,
                                                 char **buid);

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
struct IdeviceFfiError *idevice_usbmuxd_tcp_addr_new(const idevice_sockaddr *addr,
                                                     idevice_socklen_t addr_len,
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
 * Creates a default UsbmuxdAddr struct for the platform
 *
 * # Arguments
 * * [`usbmuxd_addr`] - On success, will be set to point to a newly allocated UsbmuxdAddr handle
 *
 * # Returns
 * An IdeviceFfiError on error, null on success
 *
 * # Safety
 * `usbmuxd_addr` must be a valid, non-null pointer to a location where the handle will be stored
 */
struct IdeviceFfiError *idevice_usbmuxd_default_addr_new(struct UsbmuxdAddrHandle **usbmuxd_addr);

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

/**
 * Frees a list of devices returned by `idevice_usbmuxd_get_devices`.
 *
 * # Arguments
 * * `devices` - The array of device handles to free.
 * * `count` - The number of elements in the array.
 *
 * # Safety
 * `devices` must be a valid pointer to an array of `count` device handles
 * allocated by this library, or NULL.
 */
void idevice_usbmuxd_device_list_free(struct UsbmuxdDeviceHandle **devices, int count);

/**
 * Frees a usbmuxd device
 *
 * # Arguments
 * * `device` - The device handle to free.
 *
 * # Safety
 * `device` must be a valid pointer to the device handle
 * allocated by this library, or NULL.
 */
void idevice_usbmuxd_device_free(struct UsbmuxdDeviceHandle *device);

/**
 * Gets the UDID from a device handle.
 * The returned string must be freed by the caller using `idevice_string_free`.
 *
 * # Safety
 * `device` must be a valid pointer to a `UsbmuxdDeviceHandle`.
 */
char *idevice_usbmuxd_device_get_udid(const struct UsbmuxdDeviceHandle *device);

/**
 * Gets the device ID from a device handle.
 *
 * # Safety
 * `device` must be a valid pointer to a `UsbmuxdDeviceHandle`.
 */
uint32_t idevice_usbmuxd_device_get_device_id(const struct UsbmuxdDeviceHandle *device);

/**
 * Gets the connection type (UsbmuxdConnectionType) from a device handle.
 *
 * # Returns
 * The enum value of the connection type, or 0 for null device handles
 *
 * # Safety
 * `device` must be a valid pointer to a `UsbmuxdDeviceHandle`.
 */
uint8_t idevice_usbmuxd_device_get_connection_type(const struct UsbmuxdDeviceHandle *device);

#endif  /* IDEVICE_H */



/**
 * @file plist/plist.h
 * @brief Main include of libplist
 * \internal
 *
 * Copyright (c) 2012-2023 Nikias Bassen, All Rights Reserved.
 * Copyright (c) 2008-2009 Jonathan Beck, All Rights Reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#ifndef LIBPLIST_H
#define LIBPLIST_H

#ifdef __cplusplus
extern "C"
{
#endif

#if _MSC_VER && _MSC_VER < 1700
    typedef __int8 int8_t;
    typedef __int16 int16_t;
    typedef __int32 int32_t;
    typedef __int64 int64_t;

    typedef unsigned __int8 uint8_t;
    typedef unsigned __int16 uint16_t;
    typedef unsigned __int32 uint32_t;
    typedef unsigned __int64 uint64_t;

#else
#include <stdint.h>
#endif

/*{{{ deprecation macros */
#ifdef __llvm__
  #if defined(__has_extension)
    #if (__has_extension(attribute_deprecated_with_message))
      #ifndef PLIST_WARN_DEPRECATED
        #define PLIST_WARN_DEPRECATED(x) __attribute__((deprecated(x)))
      #endif
    #else
      #ifndef PLIST_WARN_DEPRECATED
        #define PLIST_WARN_DEPRECATED(x) __attribute__((deprecated))
      #endif
    #endif
  #else
    #ifndef PLIST_WARN_DEPRECATED
      #define PLIST_WARN_DEPRECATED(x) __attribute__((deprecated))
    #endif
  #endif
#elif (__GNUC__ > 4 || (__GNUC__ == 4 && (__GNUC_MINOR__ >= 5)))
  #ifndef PLIST_WARN_DEPRECATED
    #define PLIST_WARN_DEPRECATED(x) __attribute__((deprecated(x)))
  #endif
#elif defined(_MSC_VER)
  #ifndef PLIST_WARN_DEPRECATED
    #define PLIST_WARN_DEPRECATED(x) __declspec(deprecated(x))
  #endif
#else
  #define PLIST_WARN_DEPRECATED(x)
  #pragma message("WARNING: You need to implement DEPRECATED for this compiler")
#endif
/*}}}*/

#ifndef PLIST_API
  #ifdef LIBPLIST_STATIC
    #define PLIST_API
  #elif defined(_WIN32)
    #define PLIST_API __declspec(dllimport)
  #else
    #define PLIST_API
  #endif
#endif

#include <sys/types.h>
#include <stdarg.h>
#include <stdio.h>

    /**
     * libplist : A library to handle Apple Property Lists
     * \defgroup PublicAPI Public libplist API
     */
    /*@{*/


    /**
     * The basic plist abstract data type.
     */
    typedef void *plist_t;

    /**
     * The plist dictionary iterator.
     */
    typedef void* plist_dict_iter;

    /**
     * The plist array iterator.
     */
    typedef void* plist_array_iter;

    /**
     * The enumeration of plist node types.
     */
    typedef enum
    {
        PLIST_NONE =-1, /**< No type */
        PLIST_BOOLEAN,  /**< Boolean, scalar type */
        PLIST_INT,      /**< Integer, scalar type */
        PLIST_REAL,     /**< Real, scalar type */
        PLIST_STRING,   /**< ASCII string, scalar type */
        PLIST_ARRAY,    /**< Ordered array, structured type */
        PLIST_DICT,     /**< Unordered dictionary (key/value pair), structured type */
        PLIST_DATE,     /**< Date, scalar type */
        PLIST_DATA,     /**< Binary data, scalar type */
        PLIST_KEY,      /**< Key in dictionaries (ASCII String), scalar type */
        PLIST_UID,      /**< Special type used for 'keyed encoding' */
        PLIST_NULL,     /**< NULL type */
    } plist_type;

    /* for backwards compatibility */
    #define PLIST_UINT PLIST_INT

    /**
     * libplist error values
     */
    typedef enum
    {
        PLIST_ERR_SUCCESS      =  0,  /**< operation successful */
        PLIST_ERR_INVALID_ARG  = -1,  /**< one or more of the parameters are invalid */
        PLIST_ERR_FORMAT       = -2,  /**< the plist contains nodes not compatible with the output format */
        PLIST_ERR_PARSE        = -3,  /**< parsing of the input format failed */
        PLIST_ERR_NO_MEM       = -4,  /**< not enough memory to handle the operation */
        PLIST_ERR_IO           = -5,  /**< I/O error */
        PLIST_ERR_UNKNOWN      = -255 /**< an unspecified error occurred */
    } plist_err_t;

    /**
     * libplist format types
     */
    typedef enum
    {
        PLIST_FORMAT_NONE    = 0,  /**< No format */
        PLIST_FORMAT_XML     = 1,  /**< XML format */
        PLIST_FORMAT_BINARY  = 2,  /**< bplist00 format */
        PLIST_FORMAT_JSON    = 3,  /**< JSON format */
        PLIST_FORMAT_OSTEP   = 4,  /**< OpenStep "old-style" plist format */
        /* 5-9 are reserved for possible future use */
        PLIST_FORMAT_PRINT   = 10, /**< human-readable output-only format */
        PLIST_FORMAT_LIMD    = 11, /**< "libimobiledevice" output-only format (ideviceinfo) */
        PLIST_FORMAT_PLUTIL  = 12, /**< plutil-style output-only format */
    } plist_format_t;

    /**
     * libplist write options
     */
    typedef enum
    {
        PLIST_OPT_NONE      = 0, /**< Default value to use when none of the options is needed. */
        PLIST_OPT_COMPACT   = 1 << 0, /**< Use a compact representation (non-prettified). Only valid for #PLIST_FORMAT_JSON and #PLIST_FORMAT_OSTEP. */
        PLIST_OPT_PARTIAL_DATA = 1 << 1, /**< Print 24 bytes maximum of #PLIST_DATA values. If the data is longer than 24 bytes,  the first 16 and last 8 bytes will be written. Only valid for #PLIST_FORMAT_PRINT. */
        PLIST_OPT_NO_NEWLINE = 1 << 2, /**< Do not print a final newline character. Only valid for #PLIST_FORMAT_PRINT, #PLIST_FORMAT_LIMD, and #PLIST_FORMAT_PLUTIL. */
        PLIST_OPT_INDENT = 1 << 3, /**< Indent each line of output. Currently only #PLIST_FORMAT_PRINT and #PLIST_FORMAT_LIMD are supported. Use #PLIST_OPT_INDENT_BY() macro to specify the level of indentation. */
    } plist_write_options_t;

    /** To be used with #PLIST_OPT_INDENT - encodes the level of indentation for OR'ing it into the #plist_write_options_t bitfield. */
    #define PLIST_OPT_INDENT_BY(x) ((x & 0xFF) << 24)


    /********************************************
     *                                          *
     *          Creation & Destruction          *
     *                                          *
     ********************************************/

    /**
     * Create a new root plist_t type #PLIST_DICT
     *
     * @return the created plist
     * @sa #plist_type
     */
    PLIST_API plist_t plist_new_dict(void);

    /**
     * Create a new root plist_t type #PLIST_ARRAY
     *
     * @return the created plist
     * @sa #plist_type
     */
    PLIST_API plist_t plist_new_array(void);

    /**
     * Create a new plist_t type #PLIST_STRING
     *
     * @param val the sting value, encoded in UTF8.
     * @return the created item
     * @sa #plist_type
     */
    PLIST_API plist_t plist_new_string(const char *val);

    /**
     * Create a new plist_t type #PLIST_BOOLEAN
     *
     * @param val the boolean value, 0 is false, other values are true.
     * @return the created item
     * @sa #plist_type
     */
    PLIST_API plist_t plist_new_bool(uint8_t val);

    /**
     * Create a new plist_t type #PLIST_INT with an unsigned integer value
     *
     * @param val the unsigned integer value
     * @return the created item
     * @sa #plist_type
     * @note The value is always stored as uint64_t internally.
     *    Use #plist_get_uint_val or #plist_get_int_val to get the unsigned or signed value.
     */
    PLIST_API plist_t plist_new_uint(uint64_t val);

    /**
     * Create a new plist_t type #PLIST_INT with a signed integer value
     *
     * @param val the signed integer value
     * @return the created item
     * @sa #plist_type
     * @note The value is always stored as uint64_t internally.
     *    Use #plist_get_uint_val or #plist_get_int_val to get the unsigned or signed value.
     */
    PLIST_API plist_t plist_new_int(int64_t val);

    /**
     * Create a new plist_t type #PLIST_REAL
     *
     * @param val the real value
     * @return the created item
     * @sa #plist_type
     */
    PLIST_API plist_t plist_new_real(double val);

    /**
     * Create a new plist_t type #PLIST_DATA
     *
     * @param val the binary buffer
     * @param length the length of the buffer
     * @return the created item
     * @sa #plist_type
     */
    PLIST_API plist_t plist_new_data(const char *val, uint64_t length);

    /**
     * Create a new plist_t type #PLIST_DATE
     *
     * @param sec The number of seconds since 01/01/1970 (UNIX timestamp)
     * @return the created item
     * @sa #plist_type
     */
    PLIST_API plist_t plist_new_unix_date(int64_t sec);

    /**
     * Create a new plist_t type #PLIST_UID
     *
     * @param val the unsigned integer value
     * @return the created item
     * @sa #plist_type
     */
    PLIST_API plist_t plist_new_uid(uint64_t val);

    /**
     * Create a new plist_t type #PLIST_NULL
     * @return the created item
     * @sa #plist_type
     * @note This type is not valid for all formats, e.g. the XML format
     *     does not support it.
     */
    PLIST_API plist_t plist_new_null(void);

    /**
     * Destruct a plist_t node and all its children recursively
     *
     * @param plist the plist to free
     */
    PLIST_API void plist_free(plist_t plist);

    /**
     * Return a copy of passed node and it's children
     *
     * @param node the plist to copy
     * @return copied plist
     */
    PLIST_API plist_t plist_copy(plist_t node);


    /********************************************
     *                                          *
     *            Array functions               *
     *                                          *
     ********************************************/

    /**
     * Get size of a #PLIST_ARRAY node.
     *
     * @param node the node of type #PLIST_ARRAY
     * @return size of the #PLIST_ARRAY node
     */
    PLIST_API uint32_t plist_array_get_size(plist_t node);

    /**
     * Get the nth item in a #PLIST_ARRAY node.
     *
     * @param node the node of type #PLIST_ARRAY
     * @param n the index of the item to get. Range is [0, array_size[
     * @return the nth item or NULL if node is not of type #PLIST_ARRAY
     */
    PLIST_API plist_t plist_array_get_item(plist_t node, uint32_t n);

    /**
     * Get the index of an item. item must be a member of a #PLIST_ARRAY node.
     *
     * @param node the node
     * @return the node index or UINT_MAX if node index can't be determined
     */
    PLIST_API uint32_t plist_array_get_item_index(plist_t node);

    /**
     * Set the nth item in a #PLIST_ARRAY node.
     * The previous item at index n will be freed using #plist_free
     *
     * @param node the node of type #PLIST_ARRAY
     * @param item the new item at index n. The array is responsible for freeing item when it is no longer needed.
     * @param n the index of the item to get. Range is [0, array_size[. Assert if n is not in range.
     */
    PLIST_API void plist_array_set_item(plist_t node, plist_t item, uint32_t n);

    /**
     * Append a new item at the end of a #PLIST_ARRAY node.
     *
     * @param node the node of type #PLIST_ARRAY
     * @param item the new item. The array is responsible for freeing item when it is no longer needed.
     */
    PLIST_API void plist_array_append_item(plist_t node, plist_t item);

    /**
     * Insert a new item at position n in a #PLIST_ARRAY node.
     *
     * @param node the node of type #PLIST_ARRAY
     * @param item the new item to insert. The array is responsible for freeing item when it is no longer needed.
     * @param n The position at which the node will be stored. Range is [0, array_size[. Assert if n is not in range.
     */
    PLIST_API void plist_array_insert_item(plist_t node, plist_t item, uint32_t n);

    /**
     * Remove an existing position in a #PLIST_ARRAY node.
     * Removed position will be freed using #plist_free.
     *
     * @param node the node of type #PLIST_ARRAY
     * @param n The position to remove. Range is [0, array_size[. Assert if n is not in range.
     */
    PLIST_API void plist_array_remove_item(plist_t node, uint32_t n);

    /**
     * Remove a node that is a child node of a #PLIST_ARRAY node.
     * node will be freed using #plist_free.
     *
     * @param node The node to be removed from its #PLIST_ARRAY parent.
     */
    PLIST_API void plist_array_item_remove(plist_t node);

    /**
     * Create an iterator of a #PLIST_ARRAY node.
     * The allocated iterator should be freed with the standard free function.
     *
     * @param node The node of type #PLIST_ARRAY
     * @param iter Location to store the iterator for the array.
     */
    PLIST_API void plist_array_new_iter(plist_t node, plist_array_iter *iter);

    /**
     * Increment iterator of a #PLIST_ARRAY node.
     *
     * @param node The node of type #PLIST_ARRAY.
     * @param iter Iterator of the array
     * @param item Location to store the item. The caller must *not* free the
     *          returned item. Will be set to NULL when no more items are left
     *          to iterate.
     */
    PLIST_API void plist_array_next_item(plist_t node, plist_array_iter iter, plist_t *item);


    /********************************************
     *                                          *
     *         Dictionary functions             *
     *                                          *
     ********************************************/

    /**
     * Get size of a #PLIST_DICT node.
     *
     * @param node the node of type #PLIST_DICT
     * @return size of the #PLIST_DICT node
     */
    PLIST_API uint32_t plist_dict_get_size(plist_t node);

    /**
     * Create an iterator of a #PLIST_DICT node.
     * The allocated iterator should be freed with the standard free function.
     *
     * @param node The node of type #PLIST_DICT.
     * @param iter Location to store the iterator for the dictionary.
     */
    PLIST_API void plist_dict_new_iter(plist_t node, plist_dict_iter *iter);

    /**
     * Increment iterator of a #PLIST_DICT node.
     *
     * @param node The node of type #PLIST_DICT
     * @param iter Iterator of the dictionary
     * @param key Location to store the key, or NULL. The caller is responsible
     *		for freeing the the returned string.
     * @param val Location to store the value, or NULL. The caller must *not*
     *		free the returned value. Will be set to NULL when no more
     *		key/value pairs are left to iterate.
     */
    PLIST_API void plist_dict_next_item(plist_t node, plist_dict_iter iter, char **key, plist_t *val);

    /**
     * Get key associated key to an item. Item must be member of a dictionary.
     *
     * @param node the item
     * @param key a location to store the key. The caller is responsible for freeing the returned string.
     */
    PLIST_API void plist_dict_get_item_key(plist_t node, char **key);

    /**
     * Get the nth item in a #PLIST_DICT node.
     *
     * @param node the node of type #PLIST_DICT
     * @param key the identifier of the item to get.
     * @return the item or NULL if node is not of type #PLIST_DICT. The caller should not free
     *		the returned node.
     */
    PLIST_API plist_t plist_dict_get_item(plist_t node, const char* key);

    /**
     * Get key node associated to an item. Item must be member of a dictionary.
     *
     * @param node the item
     * @return the key node of the given item, or NULL.
     */
    PLIST_API plist_t plist_dict_item_get_key(plist_t node);

    /**
     * Set item identified by key in a #PLIST_DICT node.
     * The previous item identified by key will be freed using #plist_free.
     * If there is no item for the given key a new item will be inserted.
     *
     * @param node the node of type #PLIST_DICT
     * @param item the new item associated to key
     * @param key the identifier of the item to set.
     */
    PLIST_API void plist_dict_set_item(plist_t node, const char* key, plist_t item);

    /**
     * Remove an existing position in a #PLIST_DICT node.
     * Removed position will be freed using #plist_free
     *
     * @param node the node of type #PLIST_DICT
     * @param key The identifier of the item to remove. Assert if identifier is not present.
     */
    PLIST_API void plist_dict_remove_item(plist_t node, const char* key);

    /**
     * Merge a dictionary into another. This will add all key/value pairs
     * from the source dictionary to the target dictionary, overwriting
     * any existing key/value pairs that are already present in target.
     *
     * @param target pointer to an existing node of type #PLIST_DICT
     * @param source node of type #PLIST_DICT that should be merged into target
     */
    PLIST_API void plist_dict_merge(plist_t *target, plist_t source);

    /**
     * Get a boolean value from a given #PLIST_DICT entry.
     *
     * The value node can be of type #PLIST_BOOLEAN, but also
     * #PLIST_STRING (either 'true' or 'false'),
     * #PLIST_INT with a numerical value of 0 or >= 1,
     * or #PLIST_DATA with a single byte with a value of 0 or >= 1.
     *
     * @note This function returns 0 if the dictionary does not contain an
     * entry for the given key, if the value node is of any other than
     * the above mentioned type, or has any mismatching value.
     *
     * @param dict A node of type #PLIST_DICT
     * @param key The key to look for in dict
     * @return 0 or 1 depending on the value of the node.
     */
    PLIST_API uint8_t plist_dict_get_bool(plist_t dict, const char *key);

    /**
     * Get a signed integer value from a given #PLIST_DICT entry.
     * The value node can be of type #PLIST_INT, but also
     * #PLIST_STRING with a numerical value as string (decimal or hexadecimal),
     * or #PLIST_DATA with a size of 1, 2, 4, or 8 bytes in little endian byte order.
     *
     * @note This function returns 0 if the dictionary does not contain an
     * entry for the given key, if the value node is of any other than
     * the above mentioned type, or has any mismatching value.
     *
     * @param dict A node of type #PLIST_DICT
     * @param key The key to look for in dict
     * @return Signed integer value depending on the value of the node.
     */
    PLIST_API int64_t plist_dict_get_int(plist_t dict, const char *key);

    /**
     * Get an unsigned integer value from a given #PLIST_DICT entry.
     * The value node can be of type #PLIST_INT, but also
     * #PLIST_STRING with a numerical value as string (decimal or hexadecimal),
     * or #PLIST_DATA with a size of 1, 2, 4, or 8 bytes in little endian byte order.
     *
     * @note This function returns 0 if the dictionary does not contain an
     * entry for the given key, if the value node is of any other than
     * the above mentioned type, or has any mismatching value.
     *
     * @param dict A node of type #PLIST_DICT
     * @param key The key to look for in dict
     * @return Signed integer value depending on the value of the node.
     */
    PLIST_API uint64_t plist_dict_get_uint(plist_t dict, const char *key);

    /**
     * Copy a node from *source_dict* to *target_dict*.
     * The node is looked up in *source_dict* with given *key*, unless *alt_source_key*
     * is non-NULL, in which case it is looked up with *alt_source_key*.
     * The entry in *target_dict* is **always** created with *key*.
     *
     * @param target_dict The target dictionary to copy to.
     * @param source_dict The source dictionary to copy from.
     * @param key The key for the node to copy.
     * @param alt_source_key The alternative source key for lookup in *source_dict* or NULL.
     *
     * @result PLIST_ERR_SUCCESS on success or PLIST_ERR_INVALID_ARG if the source dictionary does not contain
     *     any entry with given key or alt_source_key.
     */
    PLIST_API plist_err_t plist_dict_copy_item(plist_t target_dict, plist_t source_dict, const char *key, const char *alt_source_key);

    /**
     * Copy a boolean value from *source_dict* to *target_dict*.
     * The node is looked up in *source_dict* with given *key*, unless *alt_source_key*
     * is non-NULL, in which case it is looked up with *alt_source_key*.
     * The entry in *target_dict* is **always** created with *key*.
     *
     * @note The boolean value from *source_dict* is retrieved with #plist_dict_get_bool,
     *     but is **always** created as #PLIST_BOOLEAN in *target_dict*.
     *
     * @param target_dict The target dictionary to copy to.
     * @param source_dict The source dictionary to copy from.
     * @param key The key for the node to copy.
     * @param alt_source_key The alternative source key for lookup in *source_dict* or NULL.
     *
     * @result PLIST_ERR_SUCCESS on success or PLIST_ERR_INVALID_ARG if the source dictionary does not contain
     *     any entry with given key or alt_source_key.
     */
    PLIST_API plist_err_t plist_dict_copy_bool(plist_t target_dict, plist_t source_dict, const char *key, const char *alt_source_key);

    /**
     * Copy a signed integer value from *source_dict* to *target_dict*.
     * The node is looked up in *source_dict* with given *key*, unless *alt_source_key*
     * is non-NULL, in which case it is looked up with *alt_source_key*.
     * The entry in *target_dict* is **always** created with *key*.
     *
     * @note The signed integer value from *source_dict* is retrieved with #plist_dict_get_int,
     *     but is **always** created as #PLIST_INT.
     *
     * @param target_dict The target dictionary to copy to.
     * @param source_dict The source dictionary to copy from.
     * @param key The key for the node value to copy.
     * @param alt_source_key The alternative source key for lookup in *source_dict* or NULL.
     *
     * @result PLIST_ERR_SUCCESS on success or PLIST_ERR_INVALID_ARG if the source dictionary does not contain
     *     any entry with given key or alt_source_key.
     */
    PLIST_API plist_err_t plist_dict_copy_int(plist_t target_dict, plist_t source_dict, const char *key, const char *alt_source_key);

    /**
     * Copy an unsigned integer value from *source_dict* to *target_dict*.
     * The node is looked up in *source_dict* with given *key*, unless *alt_source_key*
     * is non-NULL, in which case it is looked up with *alt_source_key*.
     * The entry in *target_dict* is **always** created with *key*.
     *
     * @note The unsigned integer value from *source_dict* is retrieved with #plist_dict_get_uint,
     *     but is **always** created as #PLIST_INT.
     *
     * @param target_dict The target dictionary to copy to.
     * @param source_dict The source dictionary to copy from.
     * @param key The key for the node value to copy.
     * @param alt_source_key The alternative source key for lookup in *source_dict* or NULL.
     *
     * @result PLIST_ERR_SUCCESS on success or PLIST_ERR_INVALID_ARG if the source dictionary does not contain
     *     any entry with given key or alt_source_key.
     */
    PLIST_API plist_err_t plist_dict_copy_uint(plist_t target_dict, plist_t source_dict, const char *key, const char *alt_source_key);

    /**
     * Copy a #PLIST_DATA node from *source_dict* to *target_dict*.
     * The node is looked up in *source_dict* with given *key*, unless *alt_source_key*
     * is non-NULL, in which case it is looked up with *alt_source_key*.
     * The entry in *target_dict* is **always** created with *key*.
     *
     * @note This function is like #plist_dict_copy_item, except that it fails
     *     if the source node is not of type #PLIST_DATA.
     *
     * @param target_dict The target dictionary to copy to.
     * @param source_dict The source dictionary to copy from.
     * @param key The key for the node value to copy.
     * @param alt_source_key The alternative source key for lookup in *source_dict* or NULL.
     *
     * @result PLIST_ERR_SUCCESS on success or PLIST_ERR_INVALID_ARG if the source dictionary does not contain
     *     any entry with given key or alt_source_key, or if it is not of type #PLIST_DATA.
     */
    PLIST_API plist_err_t plist_dict_copy_data(plist_t target_dict, plist_t source_dict, const char *key, const char *alt_source_key);

    /**
     * Copy a #PLIST_STRING node from *source_dict* to *target_dict*.
     * The node is looked up in *source_dict* with given *key*, unless *alt_source_key*
     * is non-NULL, in which case it is looked up with *alt_source_key*.
     * The entry in *target_dict* is **always** created with *key*.
     *
     * @note This function is like #plist_dict_copy_item, except that it fails
     *     if the source node is not of type #PLIST_STRING.
     *
     * @param target_dict The target dictionary to copy to.
     * @param source_dict The source dictionary to copy from.
     * @param key The key for the node value to copy.
     * @param alt_source_key The alternative source key for lookup in *source_dict* or NULL.
     *
     * @result PLIST_ERR_SUCCESS on success or PLIST_ERR_INVALID_ARG if the source dictionary does not contain
     *     any entry with given key or alt_source_key, or if it is not of type #PLIST_STRING.
     */
    PLIST_API plist_err_t plist_dict_copy_string(plist_t target_dict, plist_t source_dict, const char *key, const char *alt_source_key);

    /********************************************
     *                                          *
     *                Getters                   *
     *                                          *
     ********************************************/

    /**
     * Get the parent of a node
     *
     * @param node the parent (NULL if node is root)
     */
    PLIST_API plist_t plist_get_parent(plist_t node);

    /**
     * Get the #plist_type of a node.
     *
     * @param node the node
     * @return the type of the node
     */
    PLIST_API plist_type plist_get_node_type(plist_t node);

    /**
     * Get the value of a #PLIST_KEY node.
     * This function does nothing if node is not of type #PLIST_KEY
     *
     * @param node the node
     * @param val a pointer to a C-string. This function allocates the memory,
     *            caller is responsible for freeing it.
     * @note Use plist_mem_free() to free the allocated memory.
     */
    PLIST_API void plist_get_key_val(plist_t node, char **val);

    /**
     * Get the value of a #PLIST_STRING node.
     * This function does nothing if node is not of type #PLIST_STRING
     *
     * @param node the node
     * @param val a pointer to a C-string. This function allocates the memory,
     *            caller is responsible for freeing it. Data is UTF-8 encoded.
     * @note Use plist_mem_free() to free the allocated memory.
     */
    PLIST_API void plist_get_string_val(plist_t node, char **val);

    /**
     * Get a pointer to the buffer of a #PLIST_STRING node.
     *
     * @note DO NOT MODIFY the buffer. Mind that the buffer is only available
     *   until the plist node gets freed. Make a copy if needed.
     *
     * @param node The node
     * @param length If non-NULL, will be set to the length of the string
     *
     * @return Pointer to the NULL-terminated buffer.
     */
    PLIST_API const char* plist_get_string_ptr(plist_t node, uint64_t* length);

    /**
     * Get the value of a #PLIST_BOOLEAN node.
     * This function does nothing if node is not of type #PLIST_BOOLEAN
     *
     * @param node the node
     * @param val a pointer to a uint8_t variable.
     */
    PLIST_API void plist_get_bool_val(plist_t node, uint8_t * val);

    /**
     * Get the unsigned integer value of a #PLIST_INT node.
     * This function does nothing if node is not of type #PLIST_INT
     *
     * @param node the node
     * @param val a pointer to a uint64_t variable.
     */
    PLIST_API void plist_get_uint_val(plist_t node, uint64_t * val);

    /**
     * Get the signed integer value of a #PLIST_INT node.
     * This function does nothing if node is not of type #PLIST_INT
     *
     * @param node the node
     * @param val a pointer to a int64_t variable.
     */
    PLIST_API void plist_get_int_val(plist_t node, int64_t * val);

    /**
     * Get the value of a #PLIST_REAL node.
     * This function does nothing if node is not of type #PLIST_REAL
     *
     * @param node the node
     * @param val a pointer to a double variable.
     */
    PLIST_API void plist_get_real_val(plist_t node, double *val);

    /**
     * Get the value of a #PLIST_DATA node.
     * This function does nothing if node is not of type #PLIST_DATA
     *
     * @param node the node
     * @param val a pointer to an unallocated char buffer. This function allocates the memory,
     *            caller is responsible for freeing it.
     * @param length the length of the buffer
     * @note Use plist_mem_free() to free the allocated memory.
     */
    PLIST_API void plist_get_data_val(plist_t node, char **val, uint64_t * length);

    /**
     * Get a pointer to the data buffer of a #PLIST_DATA node.
     *
     * @note DO NOT MODIFY the buffer. Mind that the buffer is only available
     *   until the plist node gets freed. Make a copy if needed.
     *
     * @param node The node
     * @param length Pointer to a uint64_t that will be set to the length of the buffer
     *
     * @return Pointer to the buffer
     */
    PLIST_API const char* plist_get_data_ptr(plist_t node, uint64_t* length);

    /**
     * Get the value of a #PLIST_DATE node.
     * This function does nothing if node is not of type #PLIST_DATE
     *
     * @param node the node
     * @param sec a pointer to an int64_t variable. Represents the number of seconds since 01/01/1970 (UNIX timestamp).
     */
    PLIST_API void plist_get_unix_date_val(plist_t node, int64_t *sec);

    /**
     * Get the value of a #PLIST_UID node.
     * This function does nothing if node is not of type #PLIST_UID
     *
     * @param node the node
     * @param val a pointer to a uint64_t variable.
     */
    PLIST_API void plist_get_uid_val(plist_t node, uint64_t * val);


    /********************************************
     *                                          *
     *                Setters                   *
     *                                          *
     ********************************************/

    /**
     * Set the value of a node.
     * Forces type of node to #PLIST_KEY
     *
     * @param node the node
     * @param val the key value
     */
    PLIST_API void plist_set_key_val(plist_t node, const char *val);

    /**
     * Set the value of a node.
     * Forces type of node to #PLIST_STRING
     *
     * @param node the node
     * @param val the string value. The string is copied when set and will be
     *		freed by the node.
     */
    PLIST_API void plist_set_string_val(plist_t node, const char *val);

    /**
     * Set the value of a node.
     * Forces type of node to #PLIST_BOOLEAN
     *
     * @param node the node
     * @param val the boolean value
     */
    PLIST_API void plist_set_bool_val(plist_t node, uint8_t val);

    /**
     * Set the value of a node.
     * Forces type of node to #PLIST_INT
     *
     * @param node the node
     * @param val the unsigned integer value
     */
    PLIST_API void plist_set_uint_val(plist_t node, uint64_t val);

    /**
     * Set the value of a node.
     * Forces type of node to #PLIST_INT
     *
     * @param node the node
     * @param val the signed integer value
     */
    PLIST_API void plist_set_int_val(plist_t node, int64_t val);

    /**
     * Set the value of a node.
     * Forces type of node to #PLIST_REAL
     *
     * @param node the node
     * @param val the real value
     */
    PLIST_API void plist_set_real_val(plist_t node, double val);

    /**
     * Set the value of a node.
     * Forces type of node to #PLIST_DATA
     *
     * @param node the node
     * @param val the binary buffer. The buffer is copied when set and will
     *		be freed by the node.
     * @param length the length of the buffer
     */
    PLIST_API void plist_set_data_val(plist_t node, const char *val, uint64_t length);

    /**
     * Set the value of a node.
     * Forces type of node to #PLIST_DATE
     *
     * @param node the node
     * @param sec the number of seconds since 01/01/1970 (UNIX timestamp)
     */
    PLIST_API void plist_set_unix_date_val(plist_t node, int64_t sec);

    /**
     * Set the value of a node.
     * Forces type of node to #PLIST_UID
     *
     * @param node the node
     * @param val the unsigned integer value
     */
    PLIST_API void plist_set_uid_val(plist_t node, uint64_t val);


    /********************************************
     *                                          *
     *            Import & Export               *
     *                                          *
     ********************************************/

    /**
     * Export the #plist_t structure to XML format.
     *
     * @param plist the root node to export
     * @param plist_xml a pointer to a C-string. This function allocates the memory,
     *            caller is responsible for freeing it. Data is UTF-8 encoded.
     * @param length a pointer to an uint32_t variable. Represents the length of the allocated buffer.
     * @return PLIST_ERR_SUCCESS on success or a #plist_err_t on failure
     * @note Use plist_mem_free() to free the allocated memory.
     */
    PLIST_API plist_err_t plist_to_xml(plist_t plist, char **plist_xml, uint32_t * length);

    /**
     * Export the #plist_t structure to binary format.
     *
     * @param plist the root node to export
     * @param plist_bin a pointer to a char* buffer. This function allocates the memory,
     *            caller is responsible for freeing it.
     * @param length a pointer to an uint32_t variable. Represents the length of the allocated buffer.
     * @return PLIST_ERR_SUCCESS on success or a #plist_err_t on failure
     * @note Use plist_mem_free() to free the allocated memory.
     */
    PLIST_API plist_err_t plist_to_bin(plist_t plist, char **plist_bin, uint32_t * length);

    /**
     * Export the #plist_t structure to JSON format.
     *
     * @param plist the root node to export
     * @param plist_json a pointer to a char* buffer. This function allocates the memory,
     *     caller is responsible for freeing it.
     * @param length a pointer to an uint32_t variable. Represents the length of the allocated buffer.
     * @param prettify pretty print the output if != 0
     * @return PLIST_ERR_SUCCESS on success or a #plist_err_t on failure
     * @note Use plist_mem_free() to free the allocated memory.
     */
    PLIST_API plist_err_t plist_to_json(plist_t plist, char **plist_json, uint32_t* length, int prettify);

    /**
     * Export the #plist_t structure to OpenStep format.
     *
     * @param plist the root node to export
     * @param plist_openstep a pointer to a char* buffer. This function allocates the memory,
     *     caller is responsible for freeing it.
     * @param length a pointer to an uint32_t variable. Represents the length of the allocated buffer.
     * @param prettify pretty print the output if != 0
     * @return PLIST_ERR_SUCCESS on success or a #plist_err_t on failure
     * @note Use plist_mem_free() to free the allocated memory.
     */
    PLIST_API plist_err_t plist_to_openstep(plist_t plist, char **plist_openstep, uint32_t* length, int prettify);


    /**
     * Import the #plist_t structure from XML format.
     *
     * @param plist_xml a pointer to the xml buffer.
     * @param length length of the buffer to read.
     * @param plist a pointer to the imported plist.
     * @return PLIST_ERR_SUCCESS on success or a #plist_err_t on failure
     */
    PLIST_API plist_err_t plist_from_xml(const char *plist_xml, uint32_t length, plist_t * plist);

    /**
     * Import the #plist_t structure from binary format.
     *
     * @param plist_bin a pointer to the xml buffer.
     * @param length length of the buffer to read.
     * @param plist a pointer to the imported plist.
     * @return PLIST_ERR_SUCCESS on success or a #plist_err_t on failure
     */
    PLIST_API plist_err_t plist_from_bin(const char *plist_bin, uint32_t length, plist_t * plist);

    /**
     * Import the #plist_t structure from JSON format.
     *
     * @param json a pointer to the JSON buffer.
     * @param length length of the buffer to read.
     * @param plist a pointer to the imported plist.
     * @return PLIST_ERR_SUCCESS on success or a #plist_err_t on failure
     */
    PLIST_API plist_err_t plist_from_json(const char *json, uint32_t length, plist_t * plist);

    /**
     * Import the #plist_t structure from OpenStep plist format.
     *
     * @param openstep a pointer to the OpenStep plist buffer.
     * @param length length of the buffer to read.
     * @param plist a pointer to the imported plist.
     * @return PLIST_ERR_SUCCESS on success or a #plist_err_t on failure
     */
    PLIST_API plist_err_t plist_from_openstep(const char *openstep, uint32_t length, plist_t * plist);

    /**
     * Import the #plist_t structure from memory data.
     *
     * This function will look at the first bytes of plist_data
     * to determine if plist_data contains a binary, JSON, OpenStep, or XML plist
     * and tries to parse the data in the appropriate format.
     * @note This is just a convenience function and the format detection is
     *     very basic. It checks with plist_is_binary() if the data supposedly
     *     contains binary plist data, if not it checks if the first bytes have
     *     either '{' or '[' and assumes JSON format, and XML tags will result
     *     in parsing as XML, otherwise it will try to parse as OpenStep.
     *
     * @param plist_data A pointer to the memory buffer containing plist data.
     * @param length Length of the buffer to read.
     * @param plist A pointer to the imported plist.
     * @param format If non-NULL, the #plist_format_t value pointed to will be set to the parsed format.
     * @return PLIST_ERR_SUCCESS on success or a #plist_err_t on failure
     */
    PLIST_API plist_err_t plist_from_memory(const char *plist_data, uint32_t length, plist_t *plist, plist_format_t *format);

    /**
     * Import the #plist_t structure directly from file.
     *
     * This function will look at the first bytes of the file data
     * to determine if it contains a binary, JSON, OpenStep, or XML plist
     * and tries to parse the data in the appropriate format.
     * Uses plist_from_memory() internally.
     *
     * @param filename The name of the file to parse.
     * @param plist A pointer to the imported plist.
     * @param format If non-NULL, the #plist_format_t value pointed to will be set to the parsed format.
     * @return PLIST_ERR_SUCCESS on success or a #plist_err_t on failure
     */
    PLIST_API plist_err_t plist_read_from_file(const char *filename, plist_t *plist, plist_format_t *format);

    /**
     * Write the #plist_t structure to a NULL-terminated string using the given format and options.
     *
     * @param plist The input plist structure
     * @param output Pointer to a char* buffer. This function allocates the memory,
     *     caller is responsible for freeing it.
     * @param length A pointer to a uint32_t value that will receive the lenght of the allocated buffer.
     * @param format A #plist_format_t value that specifies the output format to use.
     * @param options One or more bitwise ORed values of #plist_write_options_t.
     * @return PLIST_ERR_SUCCESS on success or a #plist_err_t on failure.
     * @note Use plist_mem_free() to free the allocated memory.
     * @note #PLIST_FORMAT_BINARY is not supported by this function.
     */
    PLIST_API plist_err_t plist_write_to_string(plist_t plist, char **output, uint32_t* length, plist_format_t format, plist_write_options_t options);

    /**
     * Write the #plist_t structure to a FILE* stream using the given format and options.
     *
     * @param plist The input plist structure
     * @param stream A writeable FILE* stream that the data will be written to.
     * @param format A #plist_format_t value that specifies the output format to use.
     * @param options One or more bitwise ORed values of #plist_write_options_t.
     * @return PLIST_ERR_SUCCESS on success or a #plist_err_t on failure.
     * @note While this function allows all formats to be written to the given stream,
     *     only the formats #PLIST_FORMAT_PRINT, #PLIST_FORMAT_LIMD, and #PLIST_FORMAT_PLUTIL
     *     (basically all output-only formats) are directly and efficiently written to the stream;
     *     the other formats are written to a memory buffer first.
     */
    PLIST_API plist_err_t plist_write_to_stream(plist_t plist, FILE* stream, plist_format_t format, plist_write_options_t options);

    /**
     * Write the #plist_t structure to a file at given path using the given format and options.
     *
     * @param plist The input plist structure
     * @param filename The file name of the file to write to. Existing files will be overwritten.
     * @param format A #plist_format_t value that specifies the output format to use.
     * @param options One or more bitwise ORed values of #plist_write_options_t.
     * @return PLIST_ERR_SUCCESS on success or a #plist_err_t on failure.
     * @note Use plist_mem_free() to free the allocated memory.
     */
    PLIST_API plist_err_t plist_write_to_file(plist_t plist, const char *filename, plist_format_t format, plist_write_options_t options);

    /**
     * Print the given plist in human-readable format to standard output.
     * This is equivalent to
     * <code>plist_write_to_stream(plist, stdout, PLIST_FORMAT_PRINT, PLIST_OPT_PARTIAL_DATA);</code>
     * @param plist The #plist_t structure to print
     * @note For #PLIST_DATA nodes, only a maximum of 24 bytes (first 16 and last 8) are written.
     */
    PLIST_API void plist_print(plist_t plist);

    /**
     * Test if in-memory plist data is in binary format.
     * This function will look at the first bytes of plist_data to determine
     * if it supposedly contains a binary plist.
     * @note The function is not validating the whole memory buffer to check
     * if the content is truly a plist, it is only using some heuristic on
     * the first few bytes of plist_data.
     *
     * @param plist_data a pointer to the memory buffer containing plist data.
     * @param length length of the buffer to read.
     * @return 1 if the buffer is a binary plist, 0 otherwise.
     */
    PLIST_API int plist_is_binary(const char *plist_data, uint32_t length);

    /********************************************
     *                                          *
     *                 Utils                    *
     *                                          *
     ********************************************/

    /**
     * Get a node from its path. Each path element depends on the associated father node type.
     * For Dictionaries, var args are casted to const char*, for arrays, var args are caster to uint32_t
     * Search is breath first order.
     *
     * @param plist the node to access result from.
     * @param length length of the path to access
     * @return the value to access.
     */
    PLIST_API plist_t plist_access_path(plist_t plist, uint32_t length, ...);

    /**
     * Variadic version of #plist_access_path.
     *
     * @param plist the node to access result from.
     * @param length length of the path to access
     * @param v list of array's index and dic'st key
     * @return the value to access.
     */
    PLIST_API plist_t plist_access_pathv(plist_t plist, uint32_t length, va_list v);

    /**
     * Compare two node values
     *
     * @param node_l left node to compare
     * @param node_r rigth node to compare
     * @return TRUE is type and value match, FALSE otherwise.
     */
    PLIST_API char plist_compare_node_value(plist_t node_l, plist_t node_r);

    /** Helper macro used by PLIST_IS_* macros that will evaluate the type of a plist node. */
    #define _PLIST_IS_TYPE(__plist, __plist_type) (__plist && (plist_get_node_type(__plist) == PLIST_##__plist_type))

    /* Helper macros for the different plist types */
    /** Evaluates to true if the given plist node is of type PLIST_BOOLEAN */
    #define PLIST_IS_BOOLEAN(__plist) _PLIST_IS_TYPE(__plist, BOOLEAN)
    /** Evaluates to true if the given plist node is of type PLIST_INT */
    #define PLIST_IS_INT(__plist)     _PLIST_IS_TYPE(__plist, INT)
    /** Evaluates to true if the given plist node is of type PLIST_REAL */
    #define PLIST_IS_REAL(__plist)    _PLIST_IS_TYPE(__plist, REAL)
    /** Evaluates to true if the given plist node is of type PLIST_STRING */
    #define PLIST_IS_STRING(__plist)  _PLIST_IS_TYPE(__plist, STRING)
    /** Evaluates to true if the given plist node is of type PLIST_ARRAY */
    #define PLIST_IS_ARRAY(__plist)   _PLIST_IS_TYPE(__plist, ARRAY)
    /** Evaluates to true if the given plist node is of type PLIST_DICT */
    #define PLIST_IS_DICT(__plist)    _PLIST_IS_TYPE(__plist, DICT)
    /** Evaluates to true if the given plist node is of type PLIST_DATE */
    #define PLIST_IS_DATE(__plist)    _PLIST_IS_TYPE(__plist, DATE)
    /** Evaluates to true if the given plist node is of type PLIST_DATA */
    #define PLIST_IS_DATA(__plist)    _PLIST_IS_TYPE(__plist, DATA)
    /** Evaluates to true if the given plist node is of type PLIST_KEY */
    #define PLIST_IS_KEY(__plist)     _PLIST_IS_TYPE(__plist, KEY)
    /** Evaluates to true if the given plist node is of type PLIST_UID */
    #define PLIST_IS_UID(__plist)     _PLIST_IS_TYPE(__plist, UID)
    /* for backwards compatibility */
    #define PLIST_IS_UINT             PLIST_IS_INT

    /**
     * Helper function to check the value of a PLIST_BOOL node.
     *
     * @param boolnode node of type PLIST_BOOL
     * @return 1 if the boolean node has a value of TRUE or 0 if FALSE.
     */
    PLIST_API int plist_bool_val_is_true(plist_t boolnode);

    /**
     * Helper function to test if a given #PLIST_INT node's value is negative
     *
     * @param intnode node of type PLIST_INT
     * @return 1 if the node's value is negative, or 0 if positive.
     */
    PLIST_API int plist_int_val_is_negative(plist_t intnode);

    /**
     * Helper function to compare the value of a PLIST_INT node against
     * a given signed integer value.
     *
     * @param uintnode node of type PLIST_INT
     * @param cmpval value to compare against
     * @return 0 if the node's value and cmpval are equal,
     *         1 if the node's value is greater than cmpval,
     *         or -1 if the node's value is less than cmpval.
     */
    PLIST_API int plist_int_val_compare(plist_t uintnode, int64_t cmpval);

    /**
     * Helper function to compare the value of a PLIST_INT node against
     * a given unsigned integer value.
     *
     * @param uintnode node of type PLIST_INT
     * @param cmpval value to compare against
     * @return 0 if the node's value and cmpval are equal,
     *         1 if the node's value is greater than cmpval,
     *         or -1 if the node's value is less than cmpval.
     */
    PLIST_API int plist_uint_val_compare(plist_t uintnode, uint64_t cmpval);

    /**
     * Helper function to compare the value of a PLIST_UID node against
     * a given value.
     *
     * @param uidnode node of type PLIST_UID
     * @param cmpval value to compare against
     * @return 0 if the node's value and cmpval are equal,
     *         1 if the node's value is greater than cmpval,
     *         or -1 if the node's value is less than cmpval.
     */
    PLIST_API int plist_uid_val_compare(plist_t uidnode, uint64_t cmpval);

    /**
     * Helper function to compare the value of a PLIST_REAL node against
     * a given value.
     *
     * @note WARNING: Comparing floating point values can give inaccurate
     *     results because of the nature of floating point values on computer
     *     systems. While this function is designed to be as accurate as
     *     possible, please don't rely on it too much.
     *
     * @param realnode node of type PLIST_REAL
     * @param cmpval value to compare against
     * @return 0 if the node's value and cmpval are (almost) equal,
     *         1 if the node's value is greater than cmpval,
     *         or -1 if the node's value is less than cmpval.
     */
    PLIST_API int plist_real_val_compare(plist_t realnode, double cmpval);

    /**
     * Helper function to compare the value of a PLIST_DATE node against
     * a given number of seconds since epoch (UNIX timestamp).
     *
     * @param datenode node of type PLIST_DATE
     * @param cmpval Number of seconds to compare against (UNIX timestamp)
     * @return 0 if the node's date is equal to the supplied values,
     *         1 if the node's date is greater than the supplied values,
     *         or -1 if the node's date is less than the supplied values.
     */
    PLIST_API int plist_unix_date_val_compare(plist_t datenode, int64_t cmpval);

    /**
     * Helper function to compare the value of a PLIST_STRING node against
     * a given value.
     * This function basically behaves like strcmp.
     *
     * @param strnode node of type PLIST_STRING
     * @param cmpval value to compare against
     * @return 0 if the node's value and cmpval are equal,
     *     > 0 if the node's value is lexicographically greater than cmpval,
     *     or < 0 if the node's value is lexicographically less than cmpval.
     */
    PLIST_API int plist_string_val_compare(plist_t strnode, const char* cmpval);

    /**
     * Helper function to compare the value of a PLIST_STRING node against
     * a given value, while not comparing more than n characters.
     * This function basically behaves like strncmp.
     *
     * @param strnode node of type PLIST_STRING
     * @param cmpval value to compare against
     * @param n maximum number of characters to compare
     * @return 0 if the node's value and cmpval are equal,
     *     > 0 if the node's value is lexicographically greater than cmpval,
     *     or < 0 if the node's value is lexicographically less than cmpval.
     */
    PLIST_API int plist_string_val_compare_with_size(plist_t strnode, const char* cmpval, size_t n);

    /**
     * Helper function to match a given substring in the value of a
     * PLIST_STRING node.
     *
     * @param strnode node of type PLIST_STRING
     * @param substr value to match
     * @return 1 if the node's value contains the given substring,
     *     or 0 if not.
     */
    PLIST_API int plist_string_val_contains(plist_t strnode, const char* substr);

    /**
     * Helper function to compare the value of a PLIST_KEY node against
     * a given value.
     * This function basically behaves like strcmp.
     *
     * @param keynode node of type PLIST_KEY
     * @param cmpval value to compare against
     * @return 0 if the node's value and cmpval are equal,
     *     > 0 if the node's value is lexicographically greater than cmpval,
     *     or < 0 if the node's value is lexicographically less than cmpval.
     */
    PLIST_API int plist_key_val_compare(plist_t keynode, const char* cmpval);

    /**
     * Helper function to compare the value of a PLIST_KEY node against
     * a given value, while not comparing more than n characters.
     * This function basically behaves like strncmp.
     *
     * @param keynode node of type PLIST_KEY
     * @param cmpval value to compare against
     * @param n maximum number of characters to compare
     * @return 0 if the node's value and cmpval are equal,
     *     > 0 if the node's value is lexicographically greater than cmpval,
     *     or < 0 if the node's value is lexicographically less than cmpval.
     */
    PLIST_API int plist_key_val_compare_with_size(plist_t keynode, const char* cmpval, size_t n);

    /**
     * Helper function to match a given substring in the value of a
     * PLIST_KEY node.
     *
     * @param keynode node of type PLIST_KEY
     * @param substr value to match
     * @return 1 if the node's value contains the given substring,
     *     or 0 if not.
     */
    PLIST_API int plist_key_val_contains(plist_t keynode, const char* substr);

    /**
     * Helper function to compare the data of a PLIST_DATA node against
     * a given blob and size.
     * This function basically behaves like memcmp after making sure the
     * size of the node's data value is equal to the size of cmpval (n),
     * making this a "full match" comparison.
     *
     * @param datanode node of type PLIST_DATA
     * @param cmpval data blob to compare against
     * @param n size of data blob passed in cmpval
     * @return 0 if the node's data blob and cmpval are equal,
     *     > 0 if the node's value is lexicographically greater than cmpval,
     *     or < 0 if the node's value is lexicographically less than cmpval.
     */
    PLIST_API int plist_data_val_compare(plist_t datanode, const uint8_t* cmpval, size_t n);

    /**
     * Helper function to compare the data of a PLIST_DATA node against
     * a given blob and size, while no more than n bytes are compared.
     * This function basically behaves like memcmp after making sure the
     * size of the node's data value is at least n, making this a
     * "starts with" comparison.
     *
     * @param datanode node of type PLIST_DATA
     * @param cmpval data blob to compare against
     * @param n size of data blob passed in cmpval
     * @return 0 if the node's value and cmpval are equal,
     *     > 0 if the node's value is lexicographically greater than cmpval,
     *     or < 0 if the node's value is lexicographically less than cmpval.
     */
    PLIST_API int plist_data_val_compare_with_size(plist_t datanode, const uint8_t* cmpval, size_t n);

    /**
     * Helper function to match a given data blob within the value of a
     * PLIST_DATA node.
     *
     * @param datanode node of type PLIST_KEY
     * @param cmpval data blob to match
     * @param n size of data blob passed in cmpval
     * @return 1 if the node's value contains the given data blob
     *     or 0 if not.
     */
    PLIST_API int plist_data_val_contains(plist_t datanode, const uint8_t* cmpval, size_t n);

    /**
     * Sort all PLIST_DICT key/value pairs in a property list lexicographically
     * by key. Recurses into the child nodes if necessary.
     *
     * @param plist The property list to perform the sorting operation on.
     */
    PLIST_API void plist_sort(plist_t plist);

    /**
     * Free memory allocated by relevant libplist API calls:
     * - plist_to_xml()
     * - plist_to_bin()
     * - plist_get_key_val()
     * - plist_get_string_val()
     * - plist_get_data_val()
     *
     * @param ptr pointer to the memory to free
     *
     * @note Do not use this function to free plist_t nodes, use plist_free()
     *     instead.
     */
    PLIST_API void plist_mem_free(void* ptr);

    /**
     * Set debug level for the format parsers.
     * @note This function does nothing if libplist was not configured with --enable-debug .
     *
     * @param debug Debug level. Currently, only 0 (off) and 1 (enabled) are supported.
     */
    PLIST_API void plist_set_debug(int debug);

    /**
     * Returns a static string of the libplist version.
     *
     * @return The libplist version as static ascii string
     */
    PLIST_API const char* libplist_version();


    /********************************************
     *                                          *
     *              Deprecated API              *
     *                                          *
     ********************************************/

    /**
     * Create a new plist_t type #PLIST_DATE
     *
     * @deprecated Deprecated. Use plist_new_unix_date instead.
     *
     * @param sec the number of seconds since 01/01/2001
     * @param usec the number of microseconds
     * @return the created item
     * @sa #plist_type
     */
    PLIST_WARN_DEPRECATED("use plist_new_unix_date instead")
    PLIST_API plist_t plist_new_date(int32_t sec, int32_t usec);

    /**
     * Get the value of a #PLIST_DATE node.
     * This function does nothing if node is not of type #PLIST_DATE
     *
     * @deprecated Deprecated. Use plist_get_unix_date_val instead.
     *
     * @param node the node
     * @param sec a pointer to an int32_t variable. Represents the number of seconds since 01/01/2001.
     * @param usec a pointer to an int32_t variable. Represents the number of microseconds
     */
    PLIST_WARN_DEPRECATED("use plist_get_unix_date_val instead")
    PLIST_API void plist_get_date_val(plist_t node, int32_t * sec, int32_t * usec);

    /**
     * Set the value of a node.
     * Forces type of node to #PLIST_DATE
     *
     * @deprecated Deprecated. Use plist_set_unix_date_val instead.
     *
     * @param node the node
     * @param sec the number of seconds since 01/01/2001
     * @param usec the number of microseconds
     */
    PLIST_WARN_DEPRECATED("use plist_set_unix_date_val instead")
    PLIST_API void plist_set_date_val(plist_t node, int32_t sec, int32_t usec);

    /**
     * Helper function to compare the value of a PLIST_DATE node against
     * a given set of seconds and fraction of a second since epoch.
     *
     * @deprecated Deprecated. Use plist_unix_date_val_compare instead.
     *
     * @param datenode node of type PLIST_DATE
     * @param cmpsec number of seconds since epoch to compare against
     * @param cmpusec fraction of a second in microseconds to compare against
     * @return 0 if the node's date is equal to the supplied values,
     *         1 if the node's date is greater than the supplied values,
     *         or -1 if the node's date is less than the supplied values.
     */
    PLIST_WARN_DEPRECATED("use plist_unix_date_val_compare instead")
    PLIST_API int plist_date_val_compare(plist_t datenode, int32_t cmpsec, int32_t cmpusec);

    /*@}*/

#ifdef __cplusplus
}
#endif
#endif
