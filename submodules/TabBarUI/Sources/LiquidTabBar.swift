import Foundation
import UIKit
import SwiftUI
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import TabBarComponent
import LiquidGlassMetal

@available(iOS 17.0, *)
struct LiquidGlassAnimatable: ViewModifier, Animatable {
    var lensRect: CGRect
    
    var animatableData: CGRect.AnimatableData {
        get { lensRect.animatableData }
        set { lensRect.animatableData = newValue }
    }
    
    func body(content: Content) -> some View {
        content.layerEffect(
            ShaderLibrary.liquid.liquidGlassTabBar(
                .float4(lensRect.minX, lensRect.minY, lensRect.width, lensRect.height),
                .float(1.07),
                .float(0.5),
                .float(2.0),
                .float(1.0)
            ),
            maxSampleOffset: CGSize(width: 40, height: 40),
            isEnabled: true
        )
    }
}

public struct LiquidTabItem: Identifiable {
    public let id: AnyHashable
    public let componentItem: TabBarComponent.Item
    
    public init(componentItem: TabBarComponent.Item) {
        self.componentItem = componentItem
        self.id = AnyHashable(ObjectIdentifier(componentItem.item))
    }
}

@available(iOS 17.0, *)
public class LensTabBarModel: ObservableObject {
    @Published var theme: PresentationTheme
    @Published var items: [LiquidTabItem]
    @Published var selectedId: AnyHashable?
    
    public init(theme: PresentationTheme, items: [LiquidTabItem], selectedId: AnyHashable?) {
        self.theme = theme
        self.items = items
        self.selectedId = selectedId
    }
}

struct TabBarReplicaItem: View {
    let item: UITabBarItem
    let theme: PresentationTheme
    let isSelected: Bool
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            if let image = (isSelected ? (item.selectedImage ?? item.image) : item.image) {
                Image(uiImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .foregroundColor(Color(isSelected ? theme.rootController.tabBar.selectedTextColor : theme.rootController.tabBar.textColor))
            }
            Spacer().frame(height: 2)
            if let title = item.title {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(isSelected ? theme.rootController.tabBar.selectedTextColor : theme.rootController.tabBar.textColor))
            }
            Spacer()
        }
        .frame(width: width, height: height)
    }
}

@available(iOS 17.0, *)
public struct LensTabBarView: View {
    @ObservedObject var model: LensTabBarModel
    public let tapAction: (AnyHashable) -> Void
    
    public init(model: LensTabBarModel, tapAction: @escaping (AnyHashable) -> Void) {
        self.model = model
        self.tapAction = tapAction
    }
    
    @State private var dragLocation: CGPoint? = nil
    @State private var isDragging: Bool = false
    @State private var selectionScale: CGFloat = 1.0
    
    @State private var currentDeformation: CGFloat = 0.0
    @State private var lastPeakSpeed: CGFloat = 0.0
    @State private var isBraking: Bool = false
    
    private let lensRadius: CGFloat = 50.0
    private let contentHeight: CGFloat = 56.0
    
    public var body: some View {
        GeometryReader { geo in
            if geo.size.width > 0 && geo.size.height > 0 {
                makeContent(width: geo.size.width, height: geo.size.height)
            } else {
                Color.clear
            }
        }
    }
    
    private func makeContent(width: CGFloat, height: CGFloat) -> some View {
        let count = CGFloat(max(1, model.items.count))
        let itemWidth = width / count
        
        let minLensX = itemWidth / 2.0
        let maxLensX = width - (itemWidth / 2.0)
        
        let selectedIndex = model.items.firstIndex(where: { $0.id == model.selectedId }) ?? 0
        let selectionX = (CGFloat(selectedIndex) * itemWidth) + (itemWidth / 2.0)
        let selectionCenter = CGPoint(x: selectionX, y: contentHeight / 2.0)
        let activeLocation = isDragging ? (dragLocation ?? selectionCenter) : selectionCenter
        
        let baseWidth = lensRadius * 2
        let baseHeight = lensRadius * 1.4
        
        let verticalChange = currentDeformation * 0.5
        let horizontalChange = currentDeformation * 0.5
        
        let finalWidth = baseWidth - horizontalChange
        let finalHeight = baseHeight + verticalChange
        
        let lensRect = CGRect(
            x: activeLocation.x - (finalWidth / 2.0),
            y: activeLocation.y - (finalHeight / 2.0),
            width: finalWidth,
            height: finalHeight
        )
        
        let lensShape = RoundedRectangle(cornerRadius: finalHeight * 0.5, style: .continuous)
        let opaqueBackground = Color(model.theme.rootController.tabBar.backgroundColor.withAlphaComponent(1.0))
        
        return ZStack(alignment: .top) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 100, style: .continuous)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: itemWidth - 6, height: contentHeight - 6)
                    .position(activeLocation)
                    .scaleEffect(selectionScale)
                    .opacity(isDragging ? 0.0 : 1.0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: activeLocation)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectionScale)
                
                HStack(spacing: 0) {
                    ForEach(model.items, id: \.id) { item in
                        TabBarReplicaItem(
                            item: item.componentItem.item,
                            theme: model.theme,
                            isSelected: isDragging ? false : (item.id == model.selectedId),
                            width: itemWidth,
                            height: contentHeight
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleTap(on: item)
                        }
                    }
                }
            }
            .frame(width: width, height: contentHeight)
            .background(opaqueBackground)
            .clipShape(Capsule())
            .compositingGroup()
            .mask {
                Rectangle()
                    .overlay {
                        lensShape
                            .frame(width: lensRect.width, height: lensRect.height)
                            .position(activeLocation)
                            .scaleEffect(
                                isDragging ? 1.0 : 0.5,
                                anchor: UnitPoint(x: activeLocation.x / width, y: 0.5)
                            )
                            .blendMode(.destinationOut)
                            .opacity(isDragging ? 1.0 : 0.0)
                    }
                    .compositingGroup()
            }
            
            ZStack {
                HStack(spacing: 0) {
                    ForEach(model.items) { item in
                        TabBarReplicaItem(
                            item: item.componentItem.item,
                            theme: model.theme,
                            isSelected: true,
                            width: itemWidth,
                            height: contentHeight
                        )
                    }
                }
                .frame(width: width, height: contentHeight)
                .background(opaqueBackground)
                .clipShape(Capsule())
            }
            .drawingGroup()
            .modifier(LiquidGlassAnimatable(lensRect: lensRect))
            .mask(
                lensShape
                    .frame(width: lensRect.width, height: lensRect.height)
                    .position(activeLocation)
            )
            .allowsHitTesting(false)
            .opacity(isDragging ? 1.0 : 0.001)
            .scaleEffect(
                isDragging ? 1.0 : 0.5,
                anchor: UnitPoint(x: activeLocation.x / width, y: 0.5)
            )
        }
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .frame(width: width, height: height, alignment: .top)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let clampedX = min(max(value.location.x, minLensX), maxLensX)
                    
                    self.dragLocation = CGPoint(x: clampedX, y: contentHeight / 2.0)
                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.65)) {
                        isDragging = true
                    }
                    
                    let speed = abs(value.velocity.width)
                    let fastThreshold: CGFloat = 300.0
                    
                    if speed > fastThreshold {
                        isBraking = false
                        lastPeakSpeed = speed
                        withAnimation(.interactiveSpring(response: 0.15)) { currentDeformation = 0 }
                    } else if !isBraking && lastPeakSpeed > fastThreshold {
                        isBraking = true
                        let intensity = min(lastPeakSpeed / 80.0, 15.0)
                        
                        withAnimation(.easeOut(duration: 0.2)) { currentDeformation = -intensity }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.3)) {
                                currentDeformation = intensity * 0.6
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            if isDragging {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                                    currentDeformation = 0
                                }
                            }
                        }
                        lastPeakSpeed = 0
                    }
                }
                .onEnded { value in
                    let index = Int(value.location.x / itemWidth)
                    let clampedIndex = min(max(0, index), model.items.count - 1)
                    let targetX = (CGFloat(clampedIndex) * itemWidth) + (itemWidth / 2.0)
                    let targetPoint = CGPoint(x: targetX, y: contentHeight / 2.0)
                    
                    withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.7)) {
                        dragLocation = targetPoint
                    }
                    
                    if clampedIndex >= 0 {
                        tapAction(model.items[clampedIndex].id)
                    }
                    
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        currentDeformation = 0
                        isBraking = false
                        lastPeakSpeed = 0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.8)) {
                            isDragging = false
                            dragLocation = nil
                        }
                    }
                }
        )
    }
    
    private func handleTap(on item: LiquidTabItem) {
        tapAction(item.id)
        withAnimation(.linear(duration: 0.1)) { selectionScale = 1.05 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { selectionScale = 1.0 }
        }
    }
}
