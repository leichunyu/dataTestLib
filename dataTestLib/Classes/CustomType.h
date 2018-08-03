//
//  CustomType.h
//  DatatistTracker
//
//  Created by 张继鹏 on 08/10/2016.
//  Copyright © 2016 YunfengQi. All rights reserved.
//

#ifndef CustomType_h
#define CustomType_h

// Debug logging
#ifdef DEBUG_LOGING
#define DatatistDebugLog(fmt,...) NSLog(@"[Datatist] %@",[NSString stringWithFormat:(fmt), ##__VA_ARGS__])
#define DatatistLog(fmt,...) NSLog(@"[Datatist] %@",[NSString stringWithFormat:(fmt), ##__VA_ARGS__])
#else
#define DatatistDebugLog(...)
#define DatatistLog(...)
#endif

#endif /* CustomType_h */
