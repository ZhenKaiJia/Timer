//
//  TimerManager.swift
//  iOS定时器
//
//  Created by Memebox on 2020/8/4.
//  Copyright © 2020 Justin. All rights reserved.
//

import UIKit

class TimerManager: NSObject {

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
