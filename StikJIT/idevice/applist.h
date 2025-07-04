//
//  applist.h
//  StikJIT
//
//  Created by Stephen on 3/27/25.
//

#ifndef APPLIST_H
#define APPLIST_H
@import Foundation;
@import UIKit;

NSDictionary<NSString*, NSString*>* list_installed_apps(IdeviceProviderHandle* provider, NSString** error);
UIImage* getAppIcon(IdeviceProviderHandle* provider, NSString* bundleID, NSString** error);

#endif /* APPLIST_H */
