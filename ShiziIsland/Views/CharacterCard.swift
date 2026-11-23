import SwiftUI

/// 课本式：拼音在汉字正上方，字号明显更大。需要时左边放插图。
struct TextbookCharacter: View {
    var entry: HanziEntry
    var glyphSize: CGFloat = 168
    var pinyinSize: CGFloat = 76
    var artWidth: CGFloat = 220
    var artHeight: CGFloat = 156
    var showsArt: Bool = true
    var showsStrokes: Bool = true

    var body: some View {
        HStack(alignment: .center, spacing: 22) {
            if showsArt {
                CharacterArt(name: IllustrationCatalog.assetName(for: entry))
                    .frame(width: artWidth, height: artHeight)
            }
            VStack(spacing: 4) {
                Text(entry.pinyin)
                    .font(Theme.ui(pinyinSize, .bold))
                    .foregroundStyle(Theme.seaDeep)
                    .minimumScaleFactor(0.45)
                    .lineLimit(1)
                Text(entry.char)
                    .font(Theme.glyph(glyphSize))
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                if showsStrokes {
                    Text("\(entry.strokes) 画")
                        .font(Theme.ui(18, .medium))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.pinyin)，\(entry.char)")
    }
}

struct CharacterArt: View {
    var name: String

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Theme.ink.opacity(0.08), lineWidth: 2)
            )
            .accessibilityHidden(true)
    }
}
