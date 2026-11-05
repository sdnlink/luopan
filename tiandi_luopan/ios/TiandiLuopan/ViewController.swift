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
        
        // RootContentView owns the sensor lifecycle and starts it only for an
        // active feature tab. Starting here as well caused duplicate startup
        // work and could present the location prompt before SwiftUI had
        // rendered the feature that needs it.
    }
    
    deinit {
        // 多窗口（Stage Manager）：关掉一个窗口的宿主控制器，不代表 App 不再需要传感器。
        // 只有当前没有任何前台活跃场景时才停，否则另一个窗口里的罗盘会被误停。
        let hasActiveScene = UIApplication.shared.connectedScenes
            .contains { $0.activationState == .foregroundActive }
        guard !hasActiveScene else { return }
        UIApplication.shared.isIdleTimerDisabled = false
        CompassMotionManager.shared.stop()
    }
}
