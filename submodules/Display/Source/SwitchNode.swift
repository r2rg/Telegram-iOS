import Foundation
import UIKit
import AsyncDisplayKit
import SwiftUI

private final class SwitchNodeViewLayer: CALayer {
    override func setNeedsDisplay() {
    }
}

private final class SwitchNodeView: UISwitch {
    override class var layerClass: AnyClass {
        if #available(iOS 26.0, *) {
            return super.layerClass
        } else {
            return SwitchNodeViewLayer.self
        }
    }
}

open class SwitchNode: ASDisplayNode {
    public var valueUpdated: ((Bool) -> Void)?
    
    public var frameColor = UIColor(rgb: 0xe0e0e0) {
        didSet {
            guard isNodeLoaded, oldValue != frameColor else { return }
            if let switchView = self.view as? UISwitch {
                switchView.tintColor = frameColor
            } else if #available(iOS 17.0, *), let wrapper = self.view as? LiquidSwitchWrapper {
                wrapper.model.frameColor = Color(frameColor)
            }
        }
    }
    
    public var handleColor = UIColor(rgb: 0xffffff) {
        didSet {
            guard isNodeLoaded, oldValue != handleColor else { return }
            if #available(iOS 17.0, *), let wrapper = self.view as? LiquidSwitchWrapper {
                wrapper.model.handleColor = Color(handleColor)
            }
        }
    }
    
    public var contentColor = UIColor(rgb: 0x42d451) {
        didSet {
            guard isNodeLoaded, oldValue != contentColor else { return }
            if let switchView = self.view as? UISwitch {
                switchView.onTintColor = contentColor
            } else if #available(iOS 17.0, *), let wrapper = self.view as? LiquidSwitchWrapper {
                wrapper.model.contentColor = Color(contentColor)
            }
        }
    }
    
    private var _isOn: Bool = false
    public var isOn: Bool {
        get {
            return self._isOn
        } set(value) {
            if (value != self._isOn) {
                self._isOn = value
                if self.isNodeLoaded {
                    if let switchView = self.view as? UISwitch {
                        switchView.setOn(value, animated: false)
                    } else if #available(iOS 17.0, *), let wrapper = self.view as? LiquidSwitchWrapper {
                         wrapper.model.isOn = value
                    }
                }
            }
        }
    }
    
    override public init() {
        super.init()
        
        self.setViewBlock({
            if #available(iOS 26.0, *) {
                return SwitchNodeView()
            } else if #available(iOS 17.0, *) {
                return LiquidSwitchWrapper()
            } else {
                return SwitchNodeView()
            }
        })
    }
    
    override open func didLoad() {
        super.didLoad()
        
        self.view.isAccessibilityElement = false
        
        if let switchView = self.view as? UISwitch {
            switchView.backgroundColor = self.backgroundColor
            switchView.tintColor = self.frameColor
            switchView.onTintColor = self.contentColor
            
            switchView.setOn(self._isOn, animated: false)
            
            switchView.addTarget(self, action: #selector(switchValueChanged(_:)), for: .valueChanged)
        } else if #available(iOS 17.0, *), let wrapper = self.view as? LiquidSwitchWrapper {
            wrapper.backgroundColor = .clear
            wrapper.model.isOn = self._isOn
            wrapper.model.frameColor = Color(self.frameColor)
            wrapper.model.contentColor = Color(self.contentColor)
            wrapper.model.handleColor = Color(self.handleColor)
            
            wrapper.onValueChanged = { [weak self] isOn in
                self?._isOn = isOn
                self?.valueUpdated?(isOn)
            }
        }
    }
    
    public func setOn(_ value: Bool, animated: Bool) {
        self._isOn = value
        if self.isNodeLoaded {
            if let switchView = self.view as? UISwitch {
                switchView.setOn(value, animated: animated)
            } else if #available(iOS 17.0, *), let wrapper = self.view as? LiquidSwitchWrapper {
                if animated {
                    withAnimation { wrapper.model.isOn = value }
                } else {
                    wrapper.model.isOn = value
                }
            }
        }
    }
    
    override open func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        if #available(iOS 26.0, *) {
            return CGSize(width: 63.0, height: 28.0)
        } else if #available(iOS 17.0, *) {
            return CGSize(width: 63.0, height: 28.0)
        } else {
            return CGSize(width: 51.0, height: 31.0)
        }
    }
    
    @objc func switchValueChanged(_ view: UISwitch) {
        self._isOn = view.isOn
        self.valueUpdated?(view.isOn)
    }
}
