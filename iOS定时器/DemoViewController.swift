//
//  DemoViewController.swift
//  iOS定时器
//
//  Created by Memebox on 2020/8/3.
//  Copyright © 2020 Justin. All rights reserved.
//

import UIKit

class DemoViewController: UIViewController {

    var currentCount = 0

    var timer: Timer?
    var link: CADisplayLink?
    var gcdTimer: DispatchSourceTimer?

    let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        textView.text = "测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试测试"
        textView.frame = CGRect(x: 50, y: 100, width: 100, height: 200)
        self.view.addSubview(textView)
        view.backgroundColor = UIColor.cyan

//        testTimer()
//        testCADisplayLink()
        testGCD()
//        testTimerManager()
    }

    func testTimer() {
        /// 这个会导致循环引用
//        self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(test), userInfo: nil, repeats: true)

//         需要添加到runloop
//        self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: {[weak self] (timer) in
//            self?.test()
//        })

        /// 不会循环引用 但需要添加到runloop 否则只会执行一次
        self.timer = Timer.init(timeInterval: 1, repeats: true, block: {[weak self] (timer) in
            guard let self = self else { return }
            self.test()
//            RunLoop.main.add(timer, forMode: RunLoop.Mode.common)
        })
        self.timer?.fire()
    }

    func testCADisplayLink() {
        /// 会引起循环引用  切依赖runloop会导致不准时  这个时候不会执行deinit方法
        self.link = CADisplayLink.init(target: self, selector: #selector(test))
        self.link?.preferredFramesPerSecond = 1
        self.link?.add(to: RunLoop.current, forMode: .default)
    }

    func testGCD() {
        let queue = DispatchQueue.global()
        self.gcdTimer = DispatchSource.makeTimerSource(queue: queue)
        
//        self.gcdTimer?.schedule(wallDeadline: DispatchWallTime.now(), repeating: 1)
        self.gcdTimer?.schedule(deadline: DispatchTime.now(), repeating: 1)
        self.gcdTimer?.setEventHandler { [weak self] in
            self?.test()
        }
        self.gcdTimer?.resume()
    }

    func testTimerManager() {

        /// 直接调用
        TimerManager.instance.schedule(timerKey: self.theClassName, targat: self, selector: #selector(test))

        /// block调用
//        TimerManager.instance.schedule(timerKey: self.theClassName) { [weak self] in
//            self?.test()
//        }
    }

    @objc func test() {
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

    
    deinit {
        self.timer?.invalidate()
        self.timer = nil

        self.link?.invalidate()
        self.link = nil

        self.gcdTimer?.cancel()

        TimerManager.instance.cancelTask(timerKey: self.theClassName)

        print("deinit \(self.theClassName)")
    }
}

public extension NSObject {
    var theClassName: String {
        return NSStringFromClass(type(of: self)).components(separatedBy: ".").last ?? ""
    }
}

