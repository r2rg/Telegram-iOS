import Foundation
import SwiftUI
import Combine
import LiquidGlassMetal

@available(iOS 17.0, *)
final class LiquidSliderBridge: ObservableObject {
    @Published var value: Float = 0.0 {
        didSet {
            if !isUpdatingFromUIKit {
                callback?(value)
            }
        }
    }
    
    @Published var steps: Int = 0
    
    var callback: ((Float) -> Void)?
    
    private var isUpdatingFromUIKit = false
    
    func update(newValue: Float, steps: Int = 0) {
        isUpdatingFromUIKit = true
        self.value = newValue
        self.steps = steps
        isUpdatingFromUIKit = false
    }
}

@available(iOS 17.0, *)
struct LiquidSliderWrapper: View {
    @ObservedObject var bridge: LiquidSliderBridge
    
    init(bridge: LiquidSliderBridge) {
        self.bridge = bridge
    }
    
    var body: some View {
        LiquidSliderImpl(value: $bridge.value, steps: bridge.steps)
    }
}

@available(iOS 17.0, *)
struct LiquidGlassModifier: ViewModifier, Animatable {
    var lensCenter: CGPoint
    var activeProgress: CGFloat
    var deformation: CGFloat
    
    let restSize = CGSize(width: 33, height: 22.5)
    let activeSize = CGSize(width: 57, height: 37)
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(activeProgress, deformation) }
        set {
            activeProgress = newValue.first
            deformation = newValue.second
        }
    }
    
    func body(content: Content) -> some View {
        let baseWidth = restSize.width + (activeSize.width - restSize.width) * activeProgress
        let baseHeight = restSize.height + (activeSize.height - restSize.height) * activeProgress
        
        let verticalChange = deformation * 0.5
        let horizontalChange = deformation * 0.5
     
        let finalWidth = baseWidth - horizontalChange
        let finalHeight = baseHeight + verticalChange
        
        let lensRect = CGRect(
            x: lensCenter.x - (finalWidth / 2),
            y: lensCenter.y - (finalHeight / 2),
            width: finalWidth,
            height: finalHeight
        )
        
        return content.layerEffect(
            ShaderLibrary.liquid.liquidGlass(
                .float4(lensRect.minX, lensRect.minY, lensRect.width, lensRect.height),
                .float(1.0),
                .float(1.0),
                .float(1.5),
                .float(1.0)
            ),
            maxSampleOffset: CGSize(width: 40, height: 40),
            isEnabled: activeProgress > 0
        )
    }
}

@available(iOS 17.0, *)
struct LiquidSliderImpl: View {
    @Binding var value: Float
    var steps: Int = 0

    let height: CGFloat = 44
    let originalBarHeight: CGFloat = 6
    let baseKnobWidth: CGFloat = 37
    let restSize = CGSize(width: 37, height: 24)
    
    @State private var barHeight: CGFloat = 6
    @State private var locationX: CGFloat = 0
    @State private var percentage: CGFloat = 0.5
    @State private var dragOffset: CGFloat = 0
    @State private var touchOffset: CGFloat = 0
    
    @State private var isDragging: Bool = false
    @State private var activeProgress: CGFloat = 0
    @State private var currentDeformation: CGFloat = 0.0
    @State private var lastPeakSpeed: CGFloat = 0.0
    @State private var isBraking: Bool = false
    
    private func getResistedValue(_ pct: CGFloat) -> Float {
        guard steps > 1 else { return Float(pct) }
        let total = CGFloat(steps - 1)
        let rawIdx = pct * total
        let nearest = round(rawIdx)
        let delta = rawIdx - nearest
        
        let limit: CGFloat = 1.0 / 3.0
        let stiff: CGFloat = 0.15
        
        let d = abs(delta)
        let finalDelta: CGFloat
        
        if d < limit {
            finalDelta = delta * stiff
        } else {
            let start = limit * stiff
            let progress = (d - limit) / (0.5 - limit)
            finalDelta = (delta > 0 ? 1 : -1) * (start + (0.5 - start) * progress)
        }
        
        return Float((nearest + finalDelta) / total)
    }
    
    var body: some View {
        GeometryReader { proxy in
            let totalWidth = proxy.size.width
            let sidePadding = baseKnobWidth / 2
            let trackWidth = totalWidth - baseKnobWidth
            
            let currentX = sidePadding + (CGFloat(value) * trackWidth)
            let centerPoint = CGPoint(x: currentX, y: height / 2)
            
            var fillX: CGFloat {
                if percentage > 0.95 && percentage <= 1 {
                    return sidePadding * (1 + 20 * (percentage - 0.95)) + (CGFloat(value) * trackWidth)
                } else if percentage > 1 {
                    return sidePadding * 2 + (CGFloat(value) * trackWidth)
                } else if percentage < 0.05 && percentage >= 0 {
                    return sidePadding * (1 - 20 * (0.05 - percentage)) + (CGFloat(value) * trackWidth)
                } else if percentage < 0 {
                    return (CGFloat(value) * trackWidth)
                }
                return currentX
            }
            
            ZStack {
                if steps > 1 {
                    HStack(spacing: 0) {
                        ForEach(0..<steps, id: \.self) { index in
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 4, height: 4)
                            if (index < steps - 1) { Spacer() }
                        }
                    }
                    .padding(.horizontal, sidePadding)
                    .offset(y: 9)
                }

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: barHeight)
                    
                    Capsule()
                        .fill(Color.blue)
                        .frame(width: fillX, height: barHeight)
                }
                .frame(height: height)
                .background(Color.clear)
                .compositingGroup()
                .modifier(LiquidGlassModifier(
                    lensCenter: centerPoint,
                    activeProgress: activeProgress,
                    deformation: currentDeformation
                ))
                
                RoundedRectangle(cornerRadius: 100, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                    .frame(width: restSize.width, height: restSize.height)
                    .position(centerPoint)
                    .opacity(1.0 - Double(activeProgress))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                if !isDragging {
                                    let currentKnobCenter = sidePadding + (CGFloat(value) * trackWidth)
                                    touchOffset = drag.startLocation.x - currentKnobCenter
                                    
                                    isDragging = true
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        activeProgress = 1.0
                                    }
                                }
                                
                                let speed = abs(drag.velocity.width)
                                let fastThreshold: CGFloat = 50.0
                                
                                if speed > fastThreshold {
                                    isBraking = false
                                    lastPeakSpeed = speed
                                    withAnimation(.interactiveSpring(response: 0.15)) { currentDeformation = 0 }
                                } else if !isBraking && lastPeakSpeed > fastThreshold {
                                    isBraking = true
                                    let intensity = min(lastPeakSpeed / 60.0, 15.0)
                                    withAnimation(.easeOut(duration: 0.3)) { currentDeformation = -intensity }
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.3)) { currentDeformation = intensity }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        if isDragging { withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { currentDeformation = 0 } }
                                    }
                                    lastPeakSpeed = 0
                                }
                                
                                locationX = (drag.location.x - touchOffset) - sidePadding
                                percentage = locationX / trackWidth
                                
                                let rawClamped = min(max(percentage, 0), 1)
                                let newValue = getResistedValue(rawClamped)

                                if steps > 1 {
                                    let oldStep = Int(round(self.value * Float(steps - 1)))
                                    let newStep = Int(round(newValue * Float(steps - 1)))
                                    if oldStep != newStep {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                }
                                
                                self.value = newValue
                                
                                if percentage > 1 {
                                    barHeight = max(barHeight * sqrt(1/percentage), originalBarHeight/2)
                                    dragOffset = min(5, (percentage - 1.0) * 20)
                                } else if percentage < 0 {
                                    barHeight = max(barHeight * sqrt(1/abs(percentage-1)), originalBarHeight/2)
                                    dragOffset = min(5,  percentage * 20)
                                } else {
                                    barHeight = min(barHeight * 1.05, originalBarHeight)
                                    dragOffset = 0
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                                    isDragging = false
                                    activeProgress = 0
                                    currentDeformation = 0
                                    isBraking = false
                                    lastPeakSpeed = 0
                                    barHeight = originalBarHeight
                                    dragOffset = 0
                                    
                                    if steps > 1 {
                                        let stepIndex = round(value * Float(steps - 1))
                                        self.value = stepIndex / Float(steps - 1)
                                    }
                                    percentage = CGFloat(value)
                                    locationX = trackWidth * percentage
                                }
                            }
                    )
            }
        }
        .frame(height: height)
        .offset(x: dragOffset)
    }
}
