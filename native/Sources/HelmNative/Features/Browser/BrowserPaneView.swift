import SwiftUI
import WebKit

@MainActor
final class BrowserRegistry {
    private var views: [UUID: (sessionID: UUID, view: WKWebView)] = [:]
    func view(for pane: Pane) -> WKWebView {
        if let existing = views[pane.id]?.view { return existing }
        let configuration = WKWebViewConfiguration(); configuration.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: configuration)
        if let url = pane.browserURL { view.load(URLRequest(url: url)) }
        views[pane.id] = (pane.sessionID, view); return view
    }
    func remove(paneID: UUID) { views.removeValue(forKey: paneID)?.view.stopLoading() }
    func remove(sessionID: UUID) { views.filter { $0.value.sessionID == sessionID }.map(\.key).forEach(remove(paneID:)) }
}

struct BrowserPaneView: View {
    @Environment(AppModel.self) private var model
    let pane: Pane
    @State private var address: String

    init(pane: Pane) { self.pane = pane; _address = State(initialValue: pane.browserURL?.absoluteString ?? "http://localhost:5173") }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button { webView.goBack() } label: { Image(systemName: "chevron.left") }
                Button { webView.goForward() } label: { Image(systemName: "chevron.right") }
                Button { webView.reload() } label: { Image(systemName: "arrow.clockwise") }
                TextField("URL", text: $address).textFieldStyle(.plain).onSubmit { navigate() }
                    .padding(.horizontal, 10).frame(height: 28).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 5))
                Button { if let url = URL(string: address) { NSWorkspace.shared.open(url) } } label: { Image(systemName: "safari") }
            }.buttonStyle(.plain).padding(.horizontal, 12).frame(height: 40)
            BrowserRepresentable(view: webView)
        }
    }
    private var webView: WKWebView { model.browserRegistry.view(for: pane) }
    private func navigate() {
        let normalized = address.contains("://") ? address : "http://\(address)"
        guard let url = URL(string: normalized) else { return }
        webView.load(URLRequest(url: url)); address = normalized
        var updated = pane; updated.browserURL = url; model.updatePane(updated)
    }
}

private struct BrowserRepresentable: NSViewRepresentable {
    let view: WKWebView
    func makeNSView(context: Context) -> WKWebView { view }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
