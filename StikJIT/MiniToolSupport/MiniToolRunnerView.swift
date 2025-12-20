import SwiftUI
import WebKit

struct MiniToolRunnerView: View {
    let tool: MiniToolBundle
    let toolInfo: ToolInfo
    @StateObject private var runtime: MiniToolRuntime
    @State private var showLogs = false
    @State private var initiated = false

    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @Environment(\.themeExpansionManager) private var themeExpansion

    private var backgroundStyle: BackgroundStyle { themeExpansion?.backgroundStyle(for: appThemeRaw) ?? AppTheme.system.backgroundStyle }
    private var preferredScheme: ColorScheme? { themeExpansion?.preferredColorScheme(for: appThemeRaw) }

    init(tool: MiniToolBundle, toolInfo: ToolInfo) {
        self.tool = tool
        self.toolInfo = toolInfo
        _runtime = StateObject(wrappedValue: MiniToolRuntime(tool: tool, toolInfo: toolInfo))
    }

    var body: some View {
        ZStack {
            ThemedBackground(style: backgroundStyle)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                MiniToolWebContainer(runtime: runtime)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                if !runtime.logs.isEmpty && showLogs {
                    logList
                }
            }
            .padding(16)
        }
        .navigationTitle(tool.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !initiated {
                runtime.start()
                initiated = true
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showLogs.toggle()
                } label: {
                    Label("Toggle Log", systemImage: "bubble.left")
                }
                Button {
                    runtime.reload()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
            }
        }
        .preferredColorScheme(preferredScheme)
    }

    private var logList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Messages", systemImage: "bubble.left")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(runtime.logs.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.caption.monospaced())
                                .id(index)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .onChange(of: runtime.logs.count) { _, newCount in
                    guard newCount > 0 else { return }
                    withAnimation { proxy.scrollTo(newCount - 1, anchor: .bottom) }
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct MiniToolWebContainer: UIViewRepresentable {
    @ObservedObject var runtime: MiniToolRuntime

    func makeUIView(context: Context) -> WKWebView {
        runtime.webView!
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
    }
}
