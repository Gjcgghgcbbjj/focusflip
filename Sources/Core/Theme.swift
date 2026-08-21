import SwiftUI

// MARK: - 基础色工具

extension Color {
    init(hex: String) {
        var c = hex.replacingOccurrences(of: "#", with: "")
        if c.count == 6 { c = "FF" + c }
        var v: UInt64 = 0
        Scanner(string: c).scanHexInt64(&v)
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255,
                  opacity: Double(v & 0xFF) / 255)
    }
}

// MARK: - 场景色板（Flow 核心：任务色即界面色）

enum Palette {

    static let defaultBase = Color(hex: "#5865F2")     // 未选任务的靛蓝
    static let shortBreakBase = Color(hex: "#2FA84F")  // 小憩绿
    static let longBreakBase = Color(hex: "#1E88C7")   // 长歇蓝

    /// 新任务自动轮换的色板
    static let taskPalette = ["#5865F2", "#E5573F", "#2FA84F", "#1E88C7",
                              "#9C27B0", "#E8912D", "#2AA198", "#D81B60"]

    /// 上浅下深的整屏场景渐变
    static func sceneGradient(_ base: Color) -> LinearGradient {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(base).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let top = Color(hue: h, saturation: min(0.72, s * 0.90),
                        brightness: min(1, b * 1.04 + 0.02))
        let bottom = Color(hue: h, saturation: min(1, s * 1.04),
                           brightness: max(0.18, b * 0.56))
        return LinearGradient(colors: [top, bottom],
                              startPoint: .top, endPoint: .bottom)
    }

    /// 渐变底端的深色（用作白底按钮上的文字色）
    static func deepVariant(_ base: Color) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(base).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: h, saturation: min(1, s * 1.05),
                     brightness: max(0.16, b * 0.48))
    }
}

// MARK: - 版式常量

enum Layout {
    static let ringSize: CGFloat = 280
    static let ringWidth: CGFloat = 12
}
