//
//  ImagePreviewerView.swift
//  Nally
//
//  Created by Antigravity on 2026/7/26.
//

import SwiftUI
import Cocoa

struct ImagePreviewerView: View {
    var previewer: YLImagePreviewer
    @FocusState private var isFocused: Bool
    @State private var currentMagnification: CGFloat = 1.0
    @State private var currentOffset: CGSize = .zero
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Glassmorphic translucent background
            Color(NSColor.windowBackgroundColor)
                .opacity(0.85)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
            
            if previewer.isDownloading {
                VStack(spacing: 16) {
                    ProgressView(value: previewer.downloadProgress) {
                        Text(previewer.title)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    .progressViewStyle(.linear)
                    .frame(width: 260)
                    
                    Text("\(Int(previewer.downloadProgress * 100))%")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(32)
            } else if let image = previewer.image {
                ZStack(alignment: .topTrailing) {
                    // Image container with pinch & drag gestures
                    GeometryReader { geometry in
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(previewer.zoomScale * currentMagnification)
                            .offset(x: previewer.panOffset.width + currentOffset.width,
                                    y: previewer.panOffset.height + currentOffset.height)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        currentMagnification = value
                                    }
                                    .onEnded { value in
                                        previewer.zoomScale = max(0.5, min(5.0, previewer.zoomScale * value))
                                        currentMagnification = 1.0
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { value in
                                        currentOffset = value.translation
                                    }
                                    .onEnded { value in
                                        previewer.panOffset.width += value.translation.width
                                        previewer.panOffset.height += value.translation.height
                                        currentOffset = .zero
                                    }
                            )
                            .onTapGesture(count: 2) {
                                previewer.resetZoom()
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    
                    // Format & Info Badges (Top Right)
                    HStack(spacing: 6) {
                        if !previewer.formatName.isEmpty {
                            Text(previewer.formatName)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.accentColor.opacity(0.8)))
                                .foregroundColor(.white)
                        }
                        if !previewer.imageSizeText.isEmpty {
                            Text(previewer.imageSizeText)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.black.opacity(0.5)))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(12)
                }
                
                // Bottom floating action controls bar
                HStack(spacing: 12) {
                    Button(action: { previewer.showQuickLook() }) {
                        Label("Quick Look", systemImage: "eye")
                    }
                    .help("Quick Look (Space)")
                    
                    Button(action: { previewer.copyImageToClipboard() }) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .keyboardShortcut("c", modifiers: .command)
                    .help("Copy Image (Cmd+C)")
                    
                    Button(action: { previewer.saveImage() }) {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .help("Save Image")
                    
                    Button(action: { previewer.showExifData() }) {
                        Label("EXIF", systemImage: "info.circle")
                    }
                    .help("View EXIF Data (I)")
                    
                    Spacer()
                    
                    Button(action: { NSWorkspace.shared.open(previewer.originalUrl) }) {
                        Image(systemName: "safari")
                    }
                    .help("Open in Browser")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderedProminent)
                .tint(Color.primary.opacity(0.15))
                .controlSize(.regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.thinMaterial)
                .cornerRadius(12)
                .padding(12)
                .shadow(radius: 4)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.yellow)
                    Text("Failed to display image")
                        .foregroundColor(.primary)
                }
                .padding(32)
            }
        }
        .frame(minWidth: 540, minHeight: 400)
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onAppear {
            isFocused = true
        }
        .onKeyPress(.space) {
            previewer.showQuickLook()
            return .handled
        }
        .onKeyPress(.escape) {
            previewer.closePreview()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "iI")) { _ in
            previewer.showExifData()
            return .handled
        }
    }
}
