import SwiftUI
import Cocoa

struct ImagePreviewerView: View {
    @ObservedObject var previewer: YLImagePreviewer
    @State private var isHovering = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()
            
            if previewer.isDownloading {
                VStack(spacing: 12) {
                    ProgressView(value: previewer.downloadProgress) {
                        Text(previewer.title)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .progressViewStyle(.linear)
                    .frame(width: 300)
                    
                    Text("\(Int(previewer.downloadProgress * 100))%")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            } else if let image = previewer.image {
                ZStack(alignment: .bottomTrailing) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    if isHovering {
                        Button(action: {
                            previewer.saveImage()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(width: 44, height: 44)
                                    .shadow(radius: 4)
                                
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(16)
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHovering = hovering
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.yellow)
                    Text("Failed to display image")
                        .foregroundColor(.white)
                }
            }
            
            // Key event listener helper
            KeyEventHelper { event in
                if event.characters == "i" || event.characters == "I" {
                    previewer.showExifData()
                } else if event.keyCode == 53 { // Escape key
                    previewer.closeWindow()
                }
            }
            .frame(width: 0, height: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// NSViewRepresentable to intercept key events in SwiftUI
struct KeyEventHelper: NSViewRepresentable {
    let onKeyPress: (NSEvent) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyView()
        view.onKeyPress = onKeyPress
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
    
    class KeyView: NSView {
        var onKeyPress: ((NSEvent) -> Void)?
        
        override var acceptsFirstResponder: Bool { true }
        
        override func keyDown(with event: NSEvent) {
            onKeyPress?(event)
        }
    }
}
