import SwiftUI

private class LiquidBundleAnchor {}

@available(iOS 17.0, *)
public extension ShaderLibrary {
    static let liquid: ShaderLibrary = {
        let hostBundle = Bundle(for: LiquidBundleAnchor.self)
        
        if let bundleURL = hostBundle.url(forResource: "LiquidGlassMetalBundle", withExtension: "bundle"),
           let bundle = Bundle(url: bundleURL) {
            return ShaderLibrary.bundle(bundle)
        }
        
        return ShaderLibrary.bundle(hostBundle)
    }()
}
