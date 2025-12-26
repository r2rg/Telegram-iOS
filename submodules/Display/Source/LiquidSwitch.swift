import SwiftUI
import LiquidGlassMetal

@available(iOS 17.0, *)
struct LiquidSwitchModifier: ViewModifier, Animatable {
    var lensCenter: CGPoint
    var activeProgress: CGFloat
    var deformation: CGFloat
    
    let restSize = CGSize(width: 10, height: 20)
    let activeSize = CGSize(width: 57, height: 37)
    
    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get {
            AnimatablePair(lensCenter.x, AnimatablePair(activeProgress, deformation))
        }
        set {
            lensCenter.x = newValue.first
            activeProgress = newValue.second.first
            deformation = newValue.second.second
        }
    }
    
    func body(content: Content) -> some View {
        let baseWidth = restSize.width + (activeSize.width - restSize.width) * activeProgress
        let baseHeight = restSize.height + (activeSize.height - restSize.height) * activeProgress
        
        let verticalStretch = deformation
        let horizontalSquash = deformation * 0.6
        
        let finalWidth = baseWidth - horizontalSquash
        let finalHeight = baseHeight + verticalStretch
        
        let lensRect = CGRect(
            x: lensCenter.x - (finalWidth / 2),
            y: lensCenter.y - (finalHeight / 2),
            width: finalWidth,
            height: finalHeight
        )
        
        return content.layerEffect(
            ShaderLibrary.liquid.liquidGlass(
                .float4(lensRect.minX, lensRect.minY, lensRect.width, lensRect.height),
                .float(1.3),
                .float(2.0),
                .float(1.0),
                .float(0.0)
            ),
            maxSampleOffset: CGSize(width: 40, height: 40),
            isEnabled: true
        )
    }
}

@available(iOS 17.0, *)
struct LiquidSwitch: View {
    @Binding var isOn: Bool
    
    var frameColor: Color
    var contentColor: Color
    var handleColor: Color
    
    let trackWidth: CGFloat = 63
    let trackHeight: CGFloat = 28
    let knobSize = CGSize(width: 37, height: 24)
    
    @State private var dragOffset: CGFloat = 0.0
    @State private var isDragging: Bool = false
    @State private var currentDeformation: CGFloat = 0.0
    @State private var isAnimatingTap: Bool = false
    
    private let feedback = UIImpactFeedbackGenerator(style: .medium)
    
    init(isOn: Binding<Bool>, frameColor: Color, contentColor: Color, handleColor: Color) {
        self._isOn = isOn
        self.frameColor = frameColor.opacity(0.5)
        self.contentColor = contentColor
        self.handleColor = handleColor
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            ZStack {
                Capsule()
                    .fill(isOn ? contentColor : frameColor)
                    .animation(.linear(duration: 0.25), value: isOn)
                    .frame(width: trackWidth, height: trackHeight)
            }
            .frame(width: trackWidth, height: trackHeight)
            .compositingGroup()
            .modifier(LiquidSwitchModifier(
                lensCenter: CGPoint(
                    x: currentKnobPosition.x,
                    y: (trackHeight / 2)
                ),
                activeProgress: (isDragging || isAnimatingTap) ? 1.0 : 0.0,
                deformation: currentDeformation
            ))
            
            RoundedRectangle(cornerRadius: 100)
                .fill(handleColor)
                .frame(width: (isDragging || isAnimatingTap) ? 57 : knobSize.width,
                       height: (isDragging || isAnimatingTap) ? 37 : knobSize.height)
                .position(CGPoint(x: currentKnobPosition.x, y: trackHeight / 2))
                .opacity((isDragging || isAnimatingTap) ? 0.0 : 1.0)
                .animation(.linear(duration: 0.25), value: isOn)
                .animation(.easeOut(duration: 0.2), value: isDragging)
                .allowsHitTesting(false)
        }
        .frame(width: trackWidth, height: trackHeight)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in handleDragChange(drag) }
                .onEnded { drag in handleDragEnd(drag) }
        )
    }
    
    private var currentKnobPosition: CGPoint {
        let center = trackWidth / 2
        let halfTrack = trackWidth / 2
        let minX = center - halfTrack + (knobSize.width / 2) + 2
        let maxX = center + halfTrack - (knobSize.width / 2) - 2
        
        if isDragging {
            let startX = isOn ? maxX : minX
            let currentX = startX + dragOffset
            return CGPoint(x: min(max(currentX, minX), maxX), y: 0)
        } else {
            return CGPoint(x: isOn ? maxX : minX, y: 0)
        }
    }
    
    private func handleDragChange(_ drag: DragGesture.Value) {
        if !isDragging {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { isDragging = true }
        }
        self.dragOffset = drag.translation.width
        
        let sensitivity: CGFloat = 120.0
        let maxStretch: CGFloat = 12.0
        let rawVelocity = abs(drag.translation.width) / sensitivity
        
        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.6)) {
            currentDeformation = min(rawVelocity * 4.0, maxStretch)
        }
        
        let center = trackWidth / 2
        let halfTrack = trackWidth / 2
        let minX = center - halfTrack + (knobSize.width / 2)
        let maxX = center + halfTrack - (knobSize.width / 2)
        
        let startX = isOn ? maxX : minX
        let currentX = startX + dragOffset
        let threshold: CGFloat = 5.0
        
        if isOn && currentX <= (minX + threshold) { triggerHaptic(); isOn = false }
        if !isOn && currentX >= (maxX - threshold) { triggerHaptic(); isOn = true }
    }
    
    private func handleDragEnd(_ drag: DragGesture.Value) {
        if abs(drag.translation.width) < 1 {
            handleTap()
            isDragging = false
            currentDeformation = 0
            dragOffset = 0
            return
        }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.4)) {
            isDragging = false
            currentDeformation = 0
            dragOffset = 0
        }
        
        let travel = trackWidth - knobSize.width
        let movePercent = drag.translation.width / travel
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.4)){
            if isOn && movePercent < -0.5 {
                if isOn { triggerHaptic(); isOn.toggle() }
            } else if !isOn && movePercent > 0.5 {
                if !isOn { triggerHaptic(); isOn.toggle() }
            }
        }
    }
    
    private func handleTap() {
        triggerHaptic()
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
            isAnimatingTap = true
            currentDeformation = 6.0
        }
        
        withAnimation(.linear(duration: 0.14)) {
            isOn.toggle()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isAnimatingTap = false
                currentDeformation = 0.0
            }
        }
    }
    
    private func triggerHaptic() {
        feedback.prepare()
        feedback.impactOccurred()
    }
}

@available(iOS 17.0, *)
final class LiquidSwitchWrapper: UIView {
    final class Model: ObservableObject {
        @Published var isOn: Bool = false
        @Published var frameColor: Color = .gray
        @Published var contentColor: Color = .green
        @Published var handleColor: Color = .white
    }

    let model = Model()
    var onValueChanged: ((Bool) -> Void)?
    
    private var hostingController: UIHostingController<LiquidSwitch>?
    
    private let targetSize = CGSize(width: 63, height: 28)
    private let rightPadding: CGFloat = 16.0

    override init(frame: CGRect) {
        let startFrame = frame == .zero ? CGRect(origin: .zero, size: CGSize(width: 63, height: 28)) : frame
        super.init(frame: startFrame)

        self.translatesAutoresizingMaskIntoConstraints = true
        self.backgroundColor = .clear

        let switchView = LiquidSwitch(
            isOn: Binding(
                get: { self.model.isOn },
                set: { [weak self] value in
                    self?.model.isOn = value
                    self?.onValueChanged?(value)
                }
            ),
            frameColor: model.frameColor,
            contentColor: model.contentColor,
            handleColor: model.handleColor
        )

        let hc = UIHostingController(rootView: switchView)
        hc.view.backgroundColor = .clear
        
        hc.view.translatesAutoresizingMaskIntoConstraints = true
        hc.view.autoresizingMask = []
        
        addSubview(hc.view)
        self.hostingController = hc
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let hcView = hostingController?.view {
            hcView.frame = self.bounds
        }
        forcePositioning()
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        forcePositioning()
    }
    
    private func forcePositioning() {
        guard let superview = self.superview else { return }
        
        let parentWidth = superview.bounds.width
        let parentHeight = superview.bounds.height
        
        var targetCenterY = parentHeight / 2.0
        
        if let sublayers = superview.layer.sublayers {
            let candidates = sublayers.filter {
                $0 !== self.layer &&
                !$0.isHidden &&
                $0.frame.width > parentWidth * 0.8
            }
            
            if let visualBackground = candidates.first {
                targetCenterY = visualBackground.frame.midY
            }
        }
        
        let newX = parentWidth - targetSize.width - rightPadding - 15
        let newY = targetCenterY - (targetSize.height / 2.0) - 0.5
        
        let newFrame = CGRect(x: newX, y: newY, width: targetSize.width, height: targetSize.height)
        
        if abs(self.frame.origin.x - newFrame.origin.x) > 0.5 || abs(self.frame.origin.y - newFrame.origin.y) > 0.5 {
            self.frame = newFrame
        }
    }

    override var intrinsicContentSize: CGSize {
        return targetSize
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return targetSize
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
