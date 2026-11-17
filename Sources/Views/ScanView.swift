import SwiftUI
import AppKit

struct ScanView: View {
    @ObservedObject var printerService: PrinterService
    @ObservedObject var scannerService: ScannerService
    @State private var rotationAngle: Double = 0
    @State private var zoomScale: CGFloat = 1.0
    
    var body: some View {
        HSplitView {
            // Left Controls Panel
            VStack(alignment: .leading, spacing: 18) {
                Text("Scan Settings")
                    .font(.headline)
                
                // Source
                VStack(alignment: .leading, spacing: 6) {
                    Text("Input Source")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Image(systemName: "scanner")
                        Text("Flatbed Glass (Platen)")
                            .font(.callout)
                        Spacer()
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                }
                
                // Resolution
                VStack(alignment: .leading, spacing: 6) {
                    Text("Resolution (DPI)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: $scannerService.resolution) {
                        ForEach(ScanResolution.allCases) { res in
                            Text(res.description).tag(res)
                        }
                    }
                    .labelsHidden()
                }
                
                // Color Mode
                VStack(alignment: .leading, spacing: 6) {
                    Text("Color Mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: $scannerService.colorMode) {
                        ForEach(ScanColorMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
                
                // Output Format
                VStack(alignment: .leading, spacing: 6) {
                    Text("Output Format")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: $scannerService.format) {
                        ForEach(ScanOutputFormat.allCases) { fmt in
                            Text(fmt.displayName).tag(fmt)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
                
                Divider()
                
                // Start Scan Button
                Button {
                    rotationAngle = 0
                    zoomScale = 1.0
                    Task {
                        await scannerService.startScan(
                            host: printerService.printerInfo.ipAddress,
                            port: printerService.printerInfo.scannerPort
                        )
                    }
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "scanner.fill")
                        Text(scannerService.scanState == .scanning ? "Scanning..." : "Start Scan")
                            .bold()
                        Spacer()
                    }
                    .frame(height: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(!printerService.printerInfo.isConnected || scannerService.scanState == .scanning || scannerService.scanState == .preparing)
                
                // Progress Bar
                if scannerService.scanState == .preparing || scannerService.scanState == .scanning || scannerService.scanState == .downloading {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: scannerService.progress)
                            .progressViewStyle(.linear)
                        Text(scannerService.progressMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
                
                if case .failed(let errMsg) = scannerService.scanState {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text(errMsg)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.1)))
                }
                
                Spacer()
                
                // System Fallback Button
                Button {
                    printerService.openImageCapture()
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.right.square")
                        Text("Open macOS Image Capture")
                    }
                    .font(.caption)
                }
                .buttonStyle(.link)
            }
            .padding()
            .frame(minWidth: 260, idealWidth: 280, maxWidth: 320)
            
            // Right Preview Panel
            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 12) {
                    if scannerService.scannedImage != nil {
                        Button {
                            rotationAngle = (rotationAngle + 90).truncatingRemainder(dividingBy: 360)
                        } label: {
                            Label("Rotate", systemImage: "rotate.right")
                        }
                        
                        Button {
                            zoomScale = max(0.5, zoomScale - 0.25)
                        } label: {
                            Image(systemName: "minus.magnifyingglass")
                        }
                        
                        Button {
                            zoomScale = min(3.0, zoomScale + 0.25)
                        } label: {
                            Image(systemName: "plus.magnifyingglass")
                        }
                        
                        Button("Fit") {
                            zoomScale = 1.0
                        }
                        
                        Spacer()
                        
                        Button {
                            scannerService.copyToClipboard()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        
                        Button {
                            scannerService.openInPreview()
                        } label: {
                            Label("Open in Preview", systemImage: "arrow.up.forward.app")
                        }
                        
                        Button {
                            scannerService.saveToDisk()
                        } label: {
                            Label("Save As...", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Text("Scan Preview")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(nsColor: .controlBackgroundColor))
                
                Divider()
                
                // Preview Canvas
                GeometryReader { geo in
                    ZStack {
                        Color(nsColor: .underPageBackgroundColor)
                        
                        if let img = scannerService.scannedImage {
                            ScrollView([.horizontal, .vertical]) {
                                Image(nsImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .rotationEffect(.degrees(rotationAngle))
                                    .scaleEffect(zoomScale)
                                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                                    .padding(40)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "doc.viewfinder")
                                    .font(.system(size: 64))
                                    .foregroundColor(.secondary.opacity(0.6))
                                Text("Ready to Scan")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                                Text("Place document on the HP DeskJet glass platen\nand click 'Start Scan' to begin.")
                                    .font(.callout)
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                        }
                    }
                }
            }
            .frame(minWidth: 400)
        }
    }
}
