import SwiftUI
import UIKit

/// 全局轻提示（撤销删除等）—— 底部胶囊, 5 秒自动消失
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()
    @Published var message: String?
    @Published var undoLabel: String = "撤销"
    private var undoAction: (() -> Void)?
    private var hideTask: DispatchWorkItem?

    func show(_ message: String, undoLabel: String = "撤销", undo: (() -> Void)? = nil) {
        self.message = message
        self.undoAction = undo
        self.undoLabel = undoLabel
        hideTask?.cancel()
        let t = DispatchWorkItem { [weak self] in withAnimation(.easeIn(duration: 0.2)) { self?.message = nil } }
        hideTask = t
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: t)
    }

    func performUndo() {
        undoAction?()
        withAnimation(.easeIn(duration: 0.18)) { message = nil }
    }
}

struct ToastOverlay: View {
    @ObservedObject private var center = ToastCenter.shared

    var body: some View {
        VStack {
            Spacer()
            if let msg = center.message {
                HStack(spacing: 14) {
                    Text(msg)
                        .font(DS.F.subhead)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if center.undoAction != nil {
                        Button {
                            Haptic.tick()
                            center.performUndo()
                        } label: {
                            Text(center.undoLabel)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(hex: "#8FA0FF"))
                        }
                    }
                }
                .padding(.leading, 18)
                .padding(.trailing, 12)
                .padding(.vertical, 13)
                .background(
                    Capsule()
                        .fill(Color(hex: "#26262E"))
                        .shadow(color: .black.opacity(0.28), radius: 14, y: 5)
                )
                .padding(.bottom, 86)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: center.message)
        .allowsHitTesting(center.message != nil)
    }
}
