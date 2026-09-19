import SwiftUI

struct HelmIcon: View {
    let name: String
    var size: CGFloat = HelmDimension.icon
    var body: some View {
        if let url = Bundle.main.url(forResource: name, withExtension: "svg", subdirectory: "Icons"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image).resizable().frame(width: size, height: size)
        } else {
            Image(systemName: fallback).frame(width: size, height: size)
        }
    }
    private var fallback: String {
        switch name {
        case "search": "magnifyingglass"
        case "add": "plus"
        case "settings": "square.grid.2x2"
        case "help": "questionmark.circle"
        case "diff": "plus.forwardslash.minus"
        case "file": "doc.text"
        default: "circle"
        }
    }
}

enum HelmColor {
    static let canvas = Color(red: 17/255, green: 17/255, blue: 17/255)
    static let panel = Color(red: 26/255, green: 26/255, blue: 26/255)
    static let selected = Color.white.opacity(0.08)
    static let primary = Color.white
    static let secondary = Color.white.opacity(0.6)
    static let tertiary = Color.white.opacity(0.4)
    static let green = Color(red: 72/255, green: 176/255, blue: 5/255)
    static let orange = Color(red: 250/255, green: 100/255, blue: 31/255)
    static let diffBackground = green.opacity(0.06)
    static let diffBorder = green.opacity(0.12)
}

enum HelmSpacing {
    static let outer: CGFloat = 8
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let section: CGFloat = 40
}

enum HelmRadius {
    static let row: CGFloat = 6
    static let pane: CGFloat = 8
    static let chip: CGFloat = 48
}

enum HelmDimension {
    static let sidebarWidth: CGFloat = 264
    static let sidebarContentWidth: CGFloat = 248
    static let headerHeight: CGFloat = 48
    static let rowHeight: CGFloat = 36
    static let icon: CGFloat = 20
    static let fileIcon: CGFloat = 24
    static let minimumPaneWidth: CGFloat = 320
    static let minimumPaneHeight: CGFloat = 220
    static let minimumWindowWidth: CGFloat = 920
    static let minimumWindowHeight: CGFloat = 600
}

enum HelmFont {
    static let ui = Font.system(size: 14, weight: .regular)
    static let label = Font.system(size: 14, weight: .medium)
    static let chip = Font.system(size: 12, weight: .regular)
    static let mono = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let file = Font.system(size: 16, weight: .regular)
}

struct HelmHoverButtonStyle: ButtonStyle {
    var selected = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(selected || configuration.isPressed ? HelmColor.selected : .clear)
            .clipShape(RoundedRectangle(cornerRadius: HelmRadius.row))
            .contentShape(Rectangle())
    }
}

struct BranchChip: View {
    let branch: String
    var body: some View {
        Text(branch).font(HelmFont.chip).lineLimit(1)
            .padding(.horizontal, 8).frame(height: 20)
            .background(Color.white.opacity(0.1))
            .clipShape(Capsule())
    }
}
