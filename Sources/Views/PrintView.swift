import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct PrintView: View {
    @ObservedObject var printerService: PrinterService
    
    @State private var selectedFileURL: URL?
    @State private var copies: Int = 1
    @State private var colorMode: String = "RGB"
    @State private var quality: String = "Normal"
    @State private var pageSize: String = "A4"
    @State private var isPrinting: Bool = false
    @State private var printStatusMessage: String?
    @State private var isTargeted: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Direct Print Studio")
                        .font(.title2)
                        .bold()
                    Text("Print documents and photos directly to your HP DeskJet with native Apple Silicon speed.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Drop Target Area
                VStack(spacing: 16) {
                    if let url = selectedFileURL {
                        HStack(spacing: 16) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(url.lastPathComponent)
                                    .font(.headline)
                                Text(url.path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Button("Change File") {
                                pickFile()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.08)))
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 44))
                                .foregroundColor(isTargeted ? .blue : .secondary)
                            
                            Text("Drag & Drop any PDF, Image, or Document here")
                                .font(.headline)
                            
                            Text("or click below to choose a file")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Select File...") {
                                pickFile()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(isTargeted ? Color.blue : Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
                                .background(Color(nsColor: .controlBackgroundColor))
                        )
                        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                            guard let provider = providers.first else { return false }
                            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                                if let url = url {
                                    DispatchQueue.main.async {
                                        self.selectedFileURL = url
                                    }
                                }
                            }
                            return true
                        }
                    }
                }
                
                // Print Settings
                VStack(alignment: .leading, spacing: 16) {
                    Text("Print Options")
                        .font(.headline)
                    
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 14) {
                        GridRow {
                            Text("Copies:").foregroundColor(.secondary)
                            Stepper("\(copies) \(copies == 1 ? "copy" : "copies")", value: $copies, in: 1...99)
                                .frame(width: 180)
                        }
                        
                        GridRow {
                            Text("Color Mode:").foregroundColor(.secondary)
                            Picker("", selection: $colorMode) {
                                Text("Full Color (RGB)").tag("RGB")
                                Text("Black & White (Monochrome)").tag("Gray")
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 280)
                        }
                        
                        GridRow {
                            Text("Paper Size:").foregroundColor(.secondary)
                            Picker("", selection: $pageSize) {
                                Text("A4 (Standard)").tag("A4")
                                Text("US Letter").tag("Letter")
                                Text("4 x 6 in (Photo)").tag("4x6")
                                Text("Legal").tag("Legal")
                            }
                            .labelsHidden()
                            .frame(width: 220)
                        }
                        
                        GridRow {
                            Text("Print Quality:").foregroundColor(.secondary)
                            Picker("", selection: $quality) {
                                Text("Draft (Fast)").tag("Draft")
                                Text("Normal (Standard)").tag("Normal")
                                Text("High (Photo Quality)").tag("High")
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 280)
                        }
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
                
                // Print Action Button
                HStack {
                    Button {
                        guard let url = selectedFileURL else { return }
                        isPrinting = true
                        printStatusMessage = nil
                        Task {
                            do {
                                try await printerService.printFile(
                                    url: url,
                                    copies: copies,
                                    colorMode: colorMode,
                                    quality: quality,
                                    pageSize: pageSize
                                )
                                printStatusMessage = "Document sent to printer successfully!"
                            } catch {
                                printStatusMessage = "Print failed: \(error.localizedDescription)"
                            }
                            isPrinting = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: "printer.fill")
                            Text(isPrinting ? "Sending to Printer..." : "Print Document Now")
                                .bold()
                        }
                        .frame(minWidth: 200, minHeight: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(selectedFileURL == nil || isPrinting || !printerService.printerInfo.isConnected)
                    
                    if let msg = printStatusMessage {
                        Text(msg)
                            .font(.callout)
                            .foregroundColor(msg.contains("failed") ? .red : .green)
                            .padding(.leading, 12)
                    }
                    
                    Spacer()
                }
                
                Spacer()
            }
            .padding(20)
        }
    }
    
    private func pickFile() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.pdf, .image, .plainText]
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            self.selectedFileURL = url
        }
    }
}
