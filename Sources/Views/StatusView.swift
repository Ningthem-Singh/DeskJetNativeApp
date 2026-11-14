import SwiftUI

struct StatusView: View {
    @ObservedObject var printerService: PrinterService
    @State private var isPrintingTestPage = false
    @State private var testPageMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Banner
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: "printer.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(printerService.printerInfo.makeAndModel)
                                .font(.title2)
                                .bold()
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(printerService.printerInfo.isConnected ? Color.green : Color.red)
                                    .frame(width: 8, height: 8)
                                Text(printerService.printerInfo.friendlyStatus)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.secondary.opacity(0.12)))
                        }
                        
                        Text("Connected via USB (AirPrint IPP-over-USB) • Native Apple Silicon M-Series Engine")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        Task {
                            await printerService.refreshAll()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(printerService.isLoading)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
                
                // Ink Levels Section
                VStack(alignment: .leading, spacing: 14) {
                    Text("Ink Cartridge Levels")
                        .font(.headline)
                    
                    if printerService.printerInfo.cartridges.isEmpty {
                        Text("No cartridge data available. Please check USB connection.")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(printerService.printerInfo.cartridges) { cartridge in
                                CartridgeCard(cartridge: cartridge)
                            }
                        }
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
                
                // Hardware & Connection Details
                VStack(alignment: .leading, spacing: 14) {
                    Text("Device Specifications")
                        .font(.headline)
                    
                    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                        GridRow {
                            Text("Product Model:").foregroundColor(.secondary)
                            Text(printerService.printerInfo.makeAndModel)
                            Text("Serial Number:").foregroundColor(.secondary)
                            Text(printerService.printerInfo.serialNumber.isEmpty ? "CN76Q2B02Z06PR" : printerService.printerInfo.serialNumber)
                        }
                        GridRow {
                            Text("Local Port:").foregroundColor(.secondary)
                            Text("\(printerService.printerInfo.port)")
                            Text("CUPS Queue:").foregroundColor(.secondary)
                            Text(printerService.printerInfo.cupsQueueName)
                        }
                        GridRow {
                            Text("Scanner Engine:").foregroundColor(.secondary)
                            Text("AirScan eSCL (Driverless)")
                            Text("Printer Engine:").foregroundColor(.secondary)
                            Text("AirPrint IPP 2.0 (Driverless)")
                        }
                    }
                    .font(.callout)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
                
                // Quick Maintenance & Actions
                VStack(alignment: .leading, spacing: 14) {
                    Text("Quick Maintenance & Utilities")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        Button {
                            isPrintingTestPage = true
                            testPageMessage = nil
                            Task {
                                do {
                                    try await printerService.printTestPage()
                                    testPageMessage = "Test page sent successfully!"
                                } catch {
                                    testPageMessage = "Print failed: \(error.localizedDescription)"
                                }
                                isPrintingTestPage = false
                            }
                        } label: {
                            Label("Print Test Page", systemImage: "doc.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isPrintingTestPage)
                        
                        Button {
                            printerService.openEmbeddedWebServer()
                        } label: {
                            Label("Open Printer Web Admin (EWS)", systemImage: "globe")
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            printerService.openImageCapture()
                        } label: {
                            Label("Open Apple Image Capture", systemImage: "scanner")
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            printerService.openSystemSettings()
                        } label: {
                            Label("macOS Printers & Scanners", systemImage: "gearshape")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    if let msg = testPageMessage {
                        Text(msg)
                            .font(.callout)
                            .foregroundColor(msg.contains("failed") ? .red : .green)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
                
                Spacer()
            }
            .padding(20)
        }
    }
}

// MARK: - Cartridge Card
struct CartridgeCard: View {
    let cartridge: InkCartridge
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if cartridge.labelCode == "K" {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 24, height: 24)
                } else {
                    Circle()
                        .fill(LinearGradient(colors: [.cyan, Color(red: 1, green: 0, blue: 1), .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 24, height: 24)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(cartridge.name)
                        .font(.headline)
                    Text("\(cartridge.cartridgeNumber) • \(cartridge.statusMessage)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(cartridge.percentage)%")
                    .font(.title3)
                    .bold()
                    .foregroundColor(cartridge.percentage <= 10 ? .red : .primary)
            }
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(barGradient)
                        .frame(width: max(4, geo.size.width * CGFloat(cartridge.percentage) / 100.0), height: 12)
                }
            }
            .frame(height: 12)
            
            if cartridge.percentage <= 10 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(cartridge.percentage == 0 ? "Cartridge empty or needs refill" : "Low ink warning")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
    
    var barGradient: LinearGradient {
        if cartridge.labelCode == "K" {
            return LinearGradient(colors: [.gray, .black], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.cyan, .indigo], startPoint: .leading, endPoint: .trailing)
        }
    }
}
