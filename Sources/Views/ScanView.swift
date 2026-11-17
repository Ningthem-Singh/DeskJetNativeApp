import SwiftUI
import AppKit

struct ScanView: View {
    @ObservedObject var printerService: PrinterService
    @ObservedObject var scannerService: ScannerService
    @State private var rotationAngle: Double = 0
    @State private var zoomScale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Controls Panel (Clean, Fixed-Width Inspector)
            ScrollView(.vertical, showsIndicators: false) {
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
                    
                    // Color Mode (Compact short titles prevent overflow)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Color Mode")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $scannerService.colorMode) {
                            ForEach(ScanColorMode.allCases) { mode in
                                Text(mode.shortTitle).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }
                    
                    // Output Format (Compact short titles prevent overflow)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Output Format")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $scannerService.format) {
                            ForEach(ScanOutputFormat.allCases) { fmt in
                                Text(fmt.shortName).tag(fmt)
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
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.body)
                            Text(errMsg)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.1)))
                    }
                    
                    Spacer(minLength: 20)
                    
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
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 290)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
            
            Divider()
            
            // Right Preview Panel
            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 12) {
                    if scannerService.scannedImage != nil {
                        // Transform & Zoom Group
                        HStack(spacing: 6) {
                            Button {
                                rotationAngle = (rotationAngle + 90).truncatingRemainder(dividingBy: 360)
                            } label: {
                                Image(systemName: "rotate.right")
                            }
                            .buttonStyle(.bordered)
                            .help("Rotate 90° clockwise")
                            
                            Divider()
                                .frame(height: 16)
                            
                            Button {
                                zoomScale = max(0.5, zoomScale - 0.25)
                            } label: {
                                Image(systemName: "minus.magnifyingglass")
                            }
                            .buttonStyle(.bordered)
                            .help("Zoom out")
                            
                            Text("\(Int(zoomScale * 100))%")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                                .frame(minWidth: 42)
                            
                            Button {
                                zoomScale = min(3.0, zoomScale + 0.25)
                            } label: {
                                Image(systemName: "plus.magnifyingglass")
                            }
                            .buttonStyle(.bordered)
                            .help("Zoom in")
                            
                            Button("Fit") {
                                zoomScale = 1.0
                            }
                            .buttonStyle(.bordered)
                            .help("Reset Zoom to 100%")
                        }
                        
                        Spacer(minLength: 12)
                        
                        // Actions Group (fixed-size, never truncates into single letters)
                        HStack(spacing: 8) {
                            Button {
                                scannerService.copyToClipboard()
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                            .help("Copy scanned image to clipboard")
                            
                            Button {
                                scannerService.openInPreview()
                            } label: {
                                Label("Preview", systemImage: "arrow.up.forward.app")
                            }
                            .buttonStyle(.bordered)
                            .help("Open in Apple Preview")
                            
                            Button {
                                scannerService.saveToDisk()
                            } label: {
                                Label("Save...", systemImage: "square.and.arrow.down")
                            }
                            .buttonStyle(.borderedProminent)
                            .help("Save scanned document to disk (JPEG or PDF)")
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    } else {
                        Text("Scan Preview")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
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
            .frame(minWidth: 420)
        }
    }
}
