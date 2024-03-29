//
//  WallpaperView.swift
//  WallHavenClient
//
//  Created by Venti on 15/04/2023.
//

import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import QuickLook

struct WallpaperImage: Identifiable {
    let id = UUID()
    let properties: WallHavenImage
    let image: Image
}

class WallpaperObservable: ObservableObject {
    @Published var wallhavenImages: [WallHavenImage] = []
    @Published var imagesToDisplay: [WallpaperImage] = []

    func downloadImage(from whproperty: WallHavenImage) {
        let url = URL(string: whproperty.thumbs.small)!
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                print("Error downloading image")
                return
            }
#if os(macOS)
            let image = Image(nsImage: NSImage(data: data) ?? NSImage())
#elseif os(iOS)
            let image = Image(uiImage: UIImage(data: data) ?? UIImage())
#endif
            let wallpaperImage = WallpaperImage(properties: whproperty, image: image)
            Task { @MainActor in
                self.imagesToDisplay.append(wallpaperImage)
            }
        }
        task.resume()
    }
}

struct WallpaperView: View {
    @Binding var maxWidth: CGFloat
    @ObservedObject var wallpaperObservable: WallpaperObservable
    @State var downloadingCount = 0
    @State var selectedImage: URL?

    let temporaryDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

    var body: some View {
        VStack {
            ScrollView {
                LazyVGrid(columns: [.init(.adaptive(minimum: maxWidth, maximum: maxWidth))]) {
                    ForEach(wallpaperObservable.imagesToDisplay, id: \.properties.id) { wallpaperImage in
                        Group {
                            VStack {
                                wallpaperImage.image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: maxWidth, maxHeight: maxWidth)
                                    .padding()
                            }
                            .onTapGesture {
                                if let url = URL(string: wallpaperImage.properties.path) {
                                    let task = URLSession.shared.dataTask(with: url) { data, _, error in
                                        guard let data = data, error == nil else {
                                            print("Error downloading image")
                                            return
                                        }
                                        if let file = wallpaperImage.properties.path.components(separatedBy: "/").last {
                                            do {
                                                try data.write(to: temporaryDir.appendingPathComponent(file))
                                                selectedImage = temporaryDir.appendingPathComponent(file)
                                            } catch {
                                                print("Failed to fetch temp files")
                                            }
                                        }
                                    }
                                    task.resume()
                                }
                            }
                            .contextMenu {
                                VStack {
                                    Button(action: {
                                        downloadingCount += 1
                                        let url = URL(string: wallpaperImage.properties.path)!
                                        let task = URLSession.shared.dataTask(with: url) { data, _, error in
                                            guard let data = data, error == nil else {
                                                print("Error downloading image")
                                                return
                                            }
#if os(macOS)
                                            let image = NSImage(data: data) ?? NSImage()
                                            // Prompt user to save image
                                            Task { @MainActor in
                                                let savePanel = NSSavePanel()
                                                savePanel.allowedContentTypes = [.png]
                                                savePanel.nameFieldStringValue = wallpaperImage.properties.id
                                                savePanel.begin { result in
                                                    if result == .OK {
                                                        if let url = savePanel.url {
                                                            do {
                                                                try image.tiffRepresentation?.write(to: url)
                                                            } catch {
                                                                print("Error saving image")
                                                            }
                                                        }
                                                    }
                                                }
                                            }
#elseif os(iOS)
                                            let image = UIImage(data: data) ?? UIImage()
                                            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
#endif
                                            downloadingCount -= 1
                                        }
                                        task.resume()
                                    }, label: {
                                        Label("Save Image", systemImage: "square.and.arrow.down")
                                    })
#if os(macOS)
                                    Button(action: {
                                        downloadingCount += 1
                                        let url = URL(string: wallpaperImage.properties.path)!
                                        let task = URLSession.shared.dataTask(with: url) { data, _, error in
                                            guard let data = data, error == nil else {
                                                print("Error downloading image")
                                                downloadingCount -= 1
                                                return
                                            }
                                            let image = NSImage(data: data) ?? NSImage()
                                            // Prompt user to save image
                                            Task { @MainActor in
                                                let tmpDir = NSTemporaryDirectory()
                                                let tmpFile = tmpDir + wallpaperImage.properties.id + ".png"
                                                let url = URL(fileURLWithPath: tmpFile)
                                                do {
                                                    try image.tiffRepresentation?.write(to: url)
                                                    if let screen = NSScreen.main {
                                                        try NSWorkspace.shared
                                                            .setDesktopImageURL(url, for: screen, options: [:])
                                                    }
                                                } catch {
                                                    print("Error setting wallpaper image: \(error)")
                                                }
                                            }
                                            downloadingCount -= 1
                                        }
                                        task.resume()
                                    }, label: {
                                        Label("Set As Desktop Wallpaper", systemImage: "display.and.arrow.down")
                                    })
#endif
                                }
                            }
                        }
                    }
                }
            }
            if downloadingCount > 0 {
                HStack {
                    ProgressView()
                        .progressViewStyle(.linear)
                    Spacer()
                    Text("Downloading \(downloadingCount) \(downloadingCount == 1 ? "images" : "image")")
                }
                .padding()
            }
        }
        .quickLookPreview($selectedImage)
    }
}
