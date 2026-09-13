//
//  Addon.swift
//  TrollRoute
//
//  Developed by son3ra1n.
//

import Foundation
import UIKit

var currentUIAlertController: UIAlertController?

extension UIApplication {
    func alert(title: String = "Error", body: String, animated: Bool = true, withButton: Bool = true) {
        DispatchQueue.main.async {
            currentUIAlertController = UIAlertController(title: title, message: body, preferredStyle: .alert)
            if withButton { currentUIAlertController?.addAction(.init(title: "OK", style: .cancel)) }
            self.present(alert: currentUIAlertController!)
        }
    }
    func present(alert: UIAlertController) {
        if let windowScene = self.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           var topController = windowScene.windows.first?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            topController.present(alert, animated: true)
        }
    }
}

func checkSandbox() -> Bool {
    let fileManager = FileManager.default
    fileManager.createFile(atPath: "/var/mobile/trollroutetemp", contents: nil)
    if fileManager.fileExists(atPath: "/var/mobile/trollroutetemp") {
        do {
            try fileManager.removeItem(atPath: "/var/mobile/trollroutetemp")
        } catch {
            print("Failed to remove sandbox check file")
        }
        return false
    }
    
    return true
}

func successVibrate() {
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
}
