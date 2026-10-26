import UIKit
import SwiftUI

// MARK: - 原生 Swift / SwiftUI 宿主控制器 (Pure Swift View Controller)

public class ViewController: UIHostingController<RootContentView> {
    
    public init() {
        super.init(rootView: RootContentView())
    }
    
    @objc required dynamic init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: RootContentView())
    }
    
    override public var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override public var prefersStatusBarHidden: Bool {
        return false
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 18/255.0, green: 18/255.0, blue: 22/255.0, alpha: 1.0)
        
        // 保持屏幕常亮
        UIApplication.shared.isIdleTimerDisabled = true
        
        // 启动高精度传感器
        CompassMotionManager.shared.start()
    }
    
    deinit {
        UIApplication.shared.isIdleTimerDisabled = false
        CompassMotionManager.shared.stop()
    }
}
