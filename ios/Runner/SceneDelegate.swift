import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var privacyCover: UIView?

  override init() {
    super.init()
    NotificationCenter.default.addObserver(self, selector: #selector(hideForPrivacy(_:)),
      name: UIApplication.willResignActiveNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(showAfterActivation(_:)),
      name: UIApplication.didBecomeActiveNotification, object: nil)
  }

  @objc private func hideForPrivacy(_ notification: Notification) {
    guard let window = window else { return }
    privacyCover?.removeFromSuperview()
    let cover = UIView(frame: window.bounds)
    cover.backgroundColor = UIColor(red: 13/255, green: 19/255, blue: 28/255, alpha: 1)
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(cover)
    privacyCover = cover
  }

  @objc private func showAfterActivation(_ notification: Notification) {
    privacyCover?.removeFromSuperview()
    privacyCover = nil
  }

  deinit { NotificationCenter.default.removeObserver(self) }
}
