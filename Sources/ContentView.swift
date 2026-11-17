import SwiftUI

enum NavigationItem: String, CaseIterable, Identifiable {
    case status = "Dashboard"
    case scan = "Scanner"
    case print = "Print Studio"
    case queue = "Queue"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .status: return "gauge.with.dots.needle.bottom.50percent"
        case .scan: return "scanner.fill"
        case .print: return "printer.fill"
        case .queue: return "list.bullet.rectangle.portrait"
        }
    }
}

struct ContentView: View {
    @StateObject private var printerService = PrinterService()
    @StateObject private var scannerService = ScannerService()
    @State private var selectedTab: NavigationItem = .status
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(NavigationItem.allCases, selection: $selectedTab) { item in
                NavigationLink(value: item) {
                    Label(item.rawValue, systemImage: item.icon)
                        .font(.headline)
                        .padding(.vertical, 4)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 240)
            
            // Sidebar Footer
            VStack(alignment: .leading, spacing: 6) {
                Divider()
                HStack(spacing: 8) {
                    Circle()
                        .fill(printerService.printerInfo.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(printerService.printerInfo.connectionLabel)
                        .font(.caption)
                        .bold()
                    Spacer()
                }
                Text("Apple Silicon ARM64")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            
        } detail: {
            Group {
                switch selectedTab {
                case .status:
                    StatusView(printerService: printerService)
                case .scan:
                    ScanView(printerService: printerService, scannerService: scannerService)
                case .print:
                    PrintView(printerService: printerService)
                case .queue:
                    QueueView(printerService: printerService)
                }
            }
            .frame(minWidth: 720, minHeight: 520)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 960, minHeight: 580)
        .navigationTitle("HP DeskJet Studio Pro")
    }
}
