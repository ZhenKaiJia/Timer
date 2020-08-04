//
//  CacheManager.swift
//  iOS定时器
//
//  Created by Memebox on 2020/8/4.
//  Copyright © 2020 Justin. All rights reserved.
//

import UIKit

class CacheManager: NSObject {

    private var models = NSMutableDictionary()
    private let semaphore = DispatchSemaphore.init(value: 1)

    static var instance: CacheManager {
        struct Static {
            static let instance: CacheManager = CacheManager()
        }
        return Static.instance
    }

    func valueWithCache(key: String) -> Any? {
        return self.models[key]
    }

    func cacheData(_ data: Any, withKey: String) {
        self.models.setValue(data, forKey: withKey)
    }

    func clearCache(with Key: String) {
        self.models.setValue(nil, forKey: Key)
    }

    func hasCachedValue(with key: String) -> Bool {
        guard !key.isEmpty else {
            return false
        }
        if let _ = models[key] {
            return true
        }
        return false
    }
}
