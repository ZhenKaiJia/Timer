
## 一、介绍
	
iOS常用计时器包括`NSTimer`、`CADisplayLink`、`GCD定时器`。本次主要介绍三种定时器的使用，以及全局定时器的封装。过程主要涉及知识点**定时器**、**多线程**、**锁**、**消息转发**。
    
## 二、使用
![](https://p6-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/2abaa990259d40f8a41e459cf484c20c~tplv-k3u1fbpfcp-zoom-1.image)
    
    
### 1、Timer

#### 第一种 这种会导致循环引用，因为`self`强引用`timer`，`timer`强引用`target`，会导致定时器释放失败。

```
self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(test), userInfo: nil, repeats: true)
```

#### 第二种 这个方法可以解决循环引用问题，但需要注意`timer`要加到`runloop`中才能正常使用。
```
self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: {[weak self] (timer) in
    self?.test()
})
```

#### 第三种 这个方法可以解决循环引用问题，但需要注意`timer`要加到`runloop`中才能正常使用，没有`runloop`只会执行一次。且需要手动唤醒定时器
```
self.timer = Timer.init(timeInterval: 1, repeats: true, block: {[weak self] (timer) in
    guard let self = self else { return }
    self.test()
    RunLoop.main.add(timer, forMode: RunLoop.Mode.common)
})
self.timer?.fire()
```

### 2、CADisplayLink

#### 初始化方法
```
self.link = CADisplayLink.init(target: self, selector: #selector(test))
self.link?.preferredFramesPerSecond = 1
self.link?.add(to: RunLoop.current, forMode: .default)
```
#### 使用`CADisplayLink`注意会出现和`Timer`相同的问题。1、循环引用 2、依赖`runloop`才能正常运行


### 3、GCD定时器

```
// 创建定时器
let queue = DispatchQueue.global()
self.gcdTimer = DispatchSource.makeTimerSource(queue: queue)
// self.gcdTimer?.schedule(wallDeadline: DispatchWallTime.now(), repeating: 1)
self.gcdTimer?.schedule(deadline: DispatchTime.now(), repeating: 1)
self.gcdTimer?.setEventHandler { [weak self] in
	self?.test()
}
self.gcdTimer?.resume()
```

#### 使用GCD定时器需要有一个成员变量持有gcdTimer，否则会立刻释放
#### `wallDeadline`和`deadline` 区别可以参考 [What does DispatchWallTime do on iOS?](https://stackoverflow.com/questions/51863940/what-does-dispatchwalltime-do-on-ios)


## 三、对比结论

>* `Timer`和`CADisplayLink`使用会依赖`runloop`运行，而runloop同时会承担其他任务导致及时不准时。且使用不当容易引起内存泄漏
>* `GCD`直接和系统内核挂钩，且不依赖`runloop`，使用`GCD定时器`会更加准时


## 四、全局定时器封装

#### 接口参数设计
>* 全局定时器可能有多个运行，需要唯一标识
>* 设置定时器的开始时间
>* 设置定时器的间隔时间
>* 设置定时器是否重复执行
>* 设置定时器是否异步执行
>* 回调

```
class TimerManager: NSObject {
	
    /// 每一个key都对应唯一的一个定时器， 固用字典存储
    private var timers = NSMutableDictionary()
    /// 因为涉及到多线程同时读写，为了避免出现错误，执行数据变更时需要加锁操作
    private let semaphore = DispatchSemaphore.init(value: 1)

    static var instance: TimerManager {
        struct Static {
            static let instance: TimerManager = TimerManager()
        }
        return Static.instance
    }

    /// 倒计时消息转发
    /// - Parameters:
    ///   - timerKey: 倒计时key，需要保证唯一
    ///   - targat: 消息转发
    ///   - selector: 方法名
    ///   - start: 开始时间
    ///   - interval: 间隔时间
    ///   - repeats: 是否重复
    ///   - async: 是否异步
    func schedule(timerKey: String, targat: NSObject, selector: Selector, start: DispatchTime = .now(), interval: TimeInterval = 1, repeats: Bool = true, async: Bool = true) {
        self.schedule(timerKey: timerKey, start: start, interval: interval, repeats: repeats, async: async) { [weak targat] in
            /// 检查targat是否能响应selector
            if targat?.responds(to: selector) ?? false {
                targat?.perform(selector)
            }
        }
    }

    /// 倒计时block
    /// - Parameters:
    ///   - timerKey: 倒计时key，需要保证唯一
    ///   - start: 开始时间
    ///   - interval: 间隔时间
    ///   - repeats: 是否重复
    ///   - async: 是否异步
    ///   - eventHandle: 回调
    func schedule(timerKey: String, start: DispatchTime = .now(), interval: TimeInterval = 1, repeats: Bool = true, async: Bool = true, eventHandle: @escaping (() -> Void)) {
        guard !timerKey.isEmpty || start.rawValue <= 0 || interval <= 0 else {
            return
        }
        let timerQueue = async ? DispatchQueue.global() : DispatchQueue.main
        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        semaphore.wait()
        timers[timerKey] = timer
        semaphore.signal()
        timer.schedule(deadline: start, repeating: interval)
        timer.setEventHandler { [weak self] in
            eventHandle()
            if !repeats {
                self?.cancelTask(timerKey: timerKey)
            }
        }
        timer.resume()
    }


    /// 取消定时器
    /// - Parameter timerKey: 定时器标识
    func cancelTask(timerKey: String) {
        guard !timerKey.isEmpty else {
            return
        }
        guard let timer = timers[timerKey] as? DispatchSourceTimer else {
            return
        }
        timer.cancel()
        semaphore.wait()
        timers.removeObject(forKey: timerKey)
        semaphore.signal()
    }
}

```

#### 外部调用
```
/// 消息转发
TimerManager.instance.schedule(timerKey: self.theClassName, targat: self, selector: #selector(test))

/// block回调
TimerManager.instance.schedule(timerKey: self.theClassName) { [weak self] in
	self?.test()
}
```
#### 全局定时器内部没有考虑程序退到后台在回来时间间隔问题，解决方案如下
##### 1、监听通知，对比推出前和进入后的时间差，对数据源进行修改
##### 2、每次处理时间数据的时候保存`NSDate()`,在下次执行数据处理之前先对比之前保存的`NSDate`和当前的时间差，然后在进行数据处理。代码如下
```
@objc func test() {
	/// 如果currentCount是逐渐减少的话需要在这里判断 如果小于0则执行销毁定时器的方法
    // if currentCount <= 0 {
    	// TimerManager.instance.cancelTask(timerKey: self.theClassName)
    // }

	if CacheManager.instance.hasCachedValue(with: self.theClassName) {
		if let cacheDate = CacheManager.instance.valueWithCache(key: self.theClassName) as? NSDate {
            if cacheDate.timeIntervalSinceNow < -2 {
                ///因为时间差是负数 如果是倒计时 就加上时间差 反之则减去时间差
                self.currentCount -= Int(cacheDate.timeIntervalSinceNow) + 1
            }
        }
    }
    CacheManager.instance.cacheData(NSDate(), withKey: self.theClassName)

    currentCount += 1
    print(currentCount)
}
```

## 五、[Demo代码地址](https://github.com/ZhenKaiJia/Timer)









