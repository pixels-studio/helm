import PDFKit
import SwiftUI

struct FilePaneView: View {
    @Environment(AppModel.self) private var model
    let pane: Pane
    let session: Session
    @State private var directory = ""
    @State private var entries: [FileEntry] = []
    @State private var selectedPath: String?
    @State private var text = ""

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                Button { directory = URL(fileURLWithPath: directory).deletingLastPathComponent().relativePath; Task { await loadDirectory() } } label: { HStack { Image(systemName: "chevron.up"); Text(directory.isEmpty ? "/" : directory); Spacer() }.padding(8) }.buttonStyle(.plain).disabled(directory.isEmpty)
                List(entries) { entry in Button { select(entry) } label: { Label(entry.name, systemImage: entry.isDirectory ? "folder" : "doc") } }.listStyle(.plain)
            }.frame(minWidth: 180, idealWidth: 220)
            preview.frame(minWidth: 260)
        }.task { await loadDirectory(); if let path = pane.filePath { await loadFile(path) } }
    }

    @ViewBuilder private var preview: some View {
        if let selectedPath {
            let url = session.worktreeURL.appending(path: selectedPath)
            if ["png", "jpg", "jpeg", "gif", "heic"].contains(url.pathExtension.lowercased()), let image = NSImage(contentsOf: url) {
                ScrollView([.horizontal, .vertical]) { Image(nsImage: image).resizable().scaledToFit().padding() }
            } else if url.pathExtension.lowercased() == "pdf" { PDFRepresentable(url: url) }
            else { ScrollView([.horizontal, .vertical]) { Text(text).font(HelmFont.mono).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .topLeading).padding(16) } }
        } else { ContentUnavailableView("Select a File", systemImage: "doc.text") }
    }

    private func select(_ entry: FileEntry) {
        let relative = String(entry.url.path.dropFirst(session.worktreeURL.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if entry.isDirectory { directory = relative; Task { await loadDirectory() } } else { Task { await loadFile(relative) } }
    }
    private func loadDirectory() async { do { entries = try await model.files.list(directory, under: session.worktreeURL) } catch { model.report(error) } }
    private func loadFile(_ path: String) async { selectedPath = path; do { text = try await model.files.readText(path, under: session.worktreeURL) } catch FileSystemError.binary { text = "Binary file" } catch { model.report(error) }; var updated = pane; updated.filePath = path; model.updatePane(updated) }
}

private struct PDFRepresentable: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> PDFView { let view = PDFView(); view.autoScales = true; view.document = PDFDocument(url: url); return view }
    func updateNSView(_ nsView: PDFView, context: Context) { if nsView.document?.documentURL != url { nsView.document = PDFDocument(url: url) } }
}
