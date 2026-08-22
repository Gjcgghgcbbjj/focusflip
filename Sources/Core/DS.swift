import SwiftUI

/// 设计令牌 —— 全 App 唯一来源（v1.9 规范化）
struct DS {

    // MARK: 字号阶梯（唯一允许的字号集合）
    struct F {
        static let display = Font.system(size: 56, weight: .light, design: .rounded)
        static let timerLg = Font.system(size: 62, weight: .light, design: .rounded)
        static let title1  = Font.system(size: 30, weight: .bold, design: .rounded)
        static let title2  = Font.system(size: 22, weight: .bold, design: .rounded)
        static let numberM = Font.system(size: 17, weight: .bold, design: .rounded)
        static let headline = Font.system(size: 16, weight: .semibold)
        static let body     = Font.system(size: 15)
        static let bodyMd   = Font.system(size: 15, weight: .medium)
        static let bodySb   = Font.system(size: 15, weight: .semibold)
        static let subhead  = Font.system(size: 13, weight: .medium)
        static let subheadSb = Font.system(size: 13, weight: .semibold)
        static let caption  = Font.system(size: 11)
        static let microCaps = Font.system(size: 10, weight: .semibold)
    }

    // MARK: 间距
    struct S {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 32
    }

    // MARK: 圆角
    struct R {
        static let card: CGFloat = 20      // 所有卡片统一
        static let tile: CGFloat = 7       // 设置图标块
        static let composer: CGFloat = 14  // 输入条等小型容器
    }

    // MARK: 组件高度
    struct H {
        static let primaryButton: CGFloat = 54   // 主 CTA 胶囊
        static let circleMain: CGFloat = 76      // 运行中大圆钮
        static let ghostPill: CGFloat = 40       // 次级幽灵胶囊
        static let chip: CGFloat = 38            // 时长快选
        static let segInner: CGFloat = 34        // 自绘分段内高
        static let touchMin: CGFloat = 44        // 热区下限
    }

    // MARK: 品牌色
    static let accent = Color(hex: "#5865F2")
    static let accentDeep = Color(hex: "#4C50E0")
}
