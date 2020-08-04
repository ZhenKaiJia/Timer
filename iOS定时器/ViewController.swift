//
//  ViewController.swift
//  iOS定时器
//
//  Created by Memebox on 2020/8/3.
//  Copyright © 2020 Justin. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "首页"

        let button = UIButton()
        button.frame = CGRect(x: 50, y: 100, width: 50, height: 50 )
        button.backgroundColor = UIColor.red
        button.addTarget(self, action: #selector(test), for: .touchUpInside)
        view.addSubview(button)
    }

    @objc func test() {
        let vc = DemoViewController()
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }
}

