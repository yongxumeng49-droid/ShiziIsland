import SwiftUI
import UIKit

enum Theme {
    static let paper = Color(red: 0.973, green: 0.925, blue: 0.855)
    static let paperDeep = Color(red: 0.925, green: 0.843, blue: 0.725)
    static let card = Color(red: 1.0, green: 0.976, blue: 0.941)
    static let ink = Color(red: 0.173, green: 0.141, blue: 0.086)
    static let inkSoft = Color(red: 0.42, green: 0.345, blue: 0.267)
    static let sea = Color(red: 0.122, green: 0.435, blue: 0.416)
    static let seaDeep = Color(red: 0.071, green: 0.275, blue: 0.282)
    static let coral = Color(red: 0.878, green: 0.478, blue: 0.298)
    static let gold = Color(red: 0.902, green: 0.635, blue: 0.220)
    static let good = Color(red: 0.227, green: 0.541, blue: 0.412)
    static let miss = Color(red: 0.753, green: 0.345, blue: 0.275)
    static let locked = Color(red: 0.62, green: 0.55, blue: 0.47)

    static func stageColor(_ stage: Int) -> Color {
        switch stage {
        case 1: return coral
        case 2: return sea
        case 3: return Color(red: 0.286, green: 0.384, blue: 0.612)
        default: return Color(red: 0.545, green: 0.345, blue: 0.420)
        }
    }

    static func glyph(_ size: CGFloat) -> Font {
        let names = ["KaitiSC-Regular", "Kaiti SC", "STKaiti", "SongtiSC-Regular", "Songti SC", "STSongti-SC-Regular"]
        for name in names where UIFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: .regular, design: .serif)
    }

    static func ui(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

enum StageArt {
    static func imageName(_ stage: Int) -> String {
        switch stage {
        case 1: return "StageQimeng"
        case 2: return "StageJichu"
        case 3: return "StageJinjie"
        default: return "StageTuozhan"
        }
    }
}

/// Fills the given frame without stretching. Overflow is clipped, so a square
/// picture in a wide card stays in proportion and cannot spill into the next card.
struct ArtworkFill: View {
    var name: String
    var saturation: Double = 1
    var brightness: Double = 0

    var body: some View {
        GeometryReader { geo in
            Image(name)
                .resizable()
                .scaledToFill()
                .saturation(saturation)
                .brightness(brightness)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .allowsHitTesting(false)
    }
}

/// Full-screen picture. The geometry reader ignores the safe area so the image
/// covers the status bar and home indicator instead of leaving empty strips.
struct SceneBackground: View {
    var imageName: String
    var dim: Double = 0.12

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                LinearGradient(
                    colors: [Color.white.opacity(0.05), Color.black.opacity(dim)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
    }
}

/// Lays out a full-screen picture, including under the status bar and home indicator,
/// and insets the controls so they stay in the safe area.
struct AdaptiveScreen<Content: View>: View {
    var imageName: String
    var dim: Double = 0.12
    /// When true, use the 3:4 seaside picture if the screen is taller than it is wide.
    var usesHomePair: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let tall = geo.size.height > geo.size.width
            let name = usesHomePair
                ? (tall ? "HomeBackgroundPortrait" : "HomeBackground")
                : imageName
            ZStack {
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                LinearGradient(
                    colors: [Color.white.opacity(0.04), Color.black.opacity(dim)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geo.size.width, height: geo.size.height)
                .allowsHitTesting(false)
                content()
                    .padding(.top, geo.safeAreaInsets.top)
                    .padding(.bottom, geo.safeAreaInsets.bottom)
                    .padding(.leading, geo.safeAreaInsets.leading)
                    .padding(.trailing, geo.safeAreaInsets.trailing)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
    }
}

/// Landscape art is 4:3. Portrait art is 3:4. Pick by the screen, never stretch.
struct HomeBackdrop: View {
    var dim: Double = 0.08

    var body: some View {
        GeometryReader { geo in
            let tall = geo.size.height > geo.size.width
            let name = tall ? "HomeBackgroundPortrait" : "HomeBackground"
            ZStack {
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                LinearGradient(
                    colors: [Color.white.opacity(0.05), Color.black.opacity(dim)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
    }
}

struct MemoryDots: View {
    var box: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { index in
                Circle()
                    .fill(index <= box ? Theme.good : Color.white.opacity(0.45))
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
            }
        }
        .accessibilityLabel("记得 \(min(max(box, 0), 7)) 成")
    }
}

struct PaperBackground: View {
    var body: some View {
        LinearGradient(colors: [Theme.paper, Theme.paperDeep], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

struct StarRow: View {
    var filled: Int
    var total: Int = 3
    var size: CGFloat = 18

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { index in
                Image(systemName: index < filled ? "star.fill" : "star")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(index < filled ? Theme.gold : Theme.ink.opacity(0.18))
            }
        }
        .accessibilityLabel("\(filled) 颗星")
    }
}

struct PrimaryButton: View {
    var title: String
    var fill: Color = Theme.sea
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.ui(24, .bold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(maxWidth: 460, minHeight: 68)
                .background(fill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct FractionBar: View {
    var fraction: CGFloat
    var tint: Color = Theme.sea
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let width = max(0, min(1, fraction)) * geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.ink.opacity(0.08))
                Capsule().fill(tint).frame(width: width)
            }
        }
        .frame(height: height)
    }
}

struct HintBanner: View {
    var text: String

    var body: some View {
        Text(text)
            .font(Theme.ui(18, .semibold))
            .foregroundStyle(Theme.card)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Theme.ink.opacity(0.88), in: Capsule())
    }
}

enum AnswerMark {
    case idle
    case selected
    case correct
    case wrong
    case dimmed
}

struct AnswerTile: View {
    var title: String
    var glyph: Bool
    var mark: AnswerMark
    var action: () -> Void

    private var fill: Color {
        switch mark {
        case .idle: return Theme.card
        case .selected: return Theme.sea.opacity(0.14)
        case .correct: return Theme.good.opacity(0.2)
        case .wrong: return Theme.miss.opacity(0.18)
        case .dimmed: return Theme.card.opacity(0.55)
        }
    }

    private var border: Color {
        switch mark {
        case .idle: return Theme.ink.opacity(0.08)
        case .selected: return Theme.sea
        case .correct: return Theme.good
        case .wrong: return Theme.miss
        case .dimmed: return Theme.ink.opacity(0.05)
        }
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(glyph ? Theme.glyph(glyphSize) : Theme.ui(34, .semibold))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: glyph ? 108 : 84)
                .padding(.horizontal, 12)
                .background(fill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(border, lineWidth: 3)
                )
        }
        .buttonStyle(.plain)
        .disabled(mark == .correct || mark == .wrong || mark == .dimmed)
    }

    private var glyphSize: CGFloat {
        title.count > 1 ? 48 : 64
    }
}
