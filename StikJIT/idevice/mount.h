//
//  mount.h
//  StikDebug
//
//  Created by s s on 2025/12/6.
//

#ifndef MOUNT_H
#define MOUNT_H
#include "idevice.h"
#include <Foundation/Foundation.h>
size_t getMountedDeviceCount(AdapterHandle* adapter, RsdHandshakeHandle* handshake, NSError** error);
int mountPersonalDDI(AdapterHandle* adapter, RsdHandshakeHandle* handshake, NSString* imagePath, NSString* trustcachePath, NSString* manifestPath, NSError** error);
#endif
