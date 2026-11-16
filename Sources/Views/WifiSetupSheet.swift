import SwiftUI

struct WifiSetupSheet: View {
    @ObservedObject var printerService: PrinterService
    @Environment(\.dismiss) private var dismiss
    
    @State private var networks: [WifiAP] = []
    @State private var selectedAP: WifiAP?
    @State private var password: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var isScanning: Bool = false
    @State private var isConnecting: Bool = false
    @State private var connectionSuccess: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Wireless Setup Wizard")
                        .font(.headline)
                    Text("Connect your HP DeskJet to your local Wi-Fi network without using a browser.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            if connectionSuccess {
                // Success View
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Wi-Fi Settings Applied!")
                        .font(.title2)
                        .bold()
                    
                    Text("The printer has received the Wi-Fi credentials for:\n**\(selectedAP?.ssid ?? "your Wi-Fi")**")
                        .multilineTextAlignment(.center)
                        .font(.callout)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "1.circle.fill").foregroundColor(.blue)
                            Text("Watch the blue **Wireless** light on the printer: it will stop blinking and turn solid blue.")
                        }
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "2.circle.fill").foregroundColor(.blue)
                            Text("Once solid blue, you can **unplug the USB cable completely**.")
                        }
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "3.circle.fill").foregroundColor(.blue)
                            Text("This app and macOS will automatically stay connected to your printer wire-free.")
                        }
                    }
                    .font(.caption)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.1)))
                    .frame(maxWidth: 440)
                    
                    Spacer()
                    
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            } else {
                // Setup Form View
                VStack(alignment: .leading, spacing: 16) {
                    // Networks List Header
                    HStack {
                        Text("Select Wi-Fi Network")
                            .font(.subheadline)
                            .bold()
                        Spacer()
                        if isScanning {
                            ProgressView()
                                .controlSize(.small)
                            Text("Scanning...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Button {
                                scanNetworks()
                            } label: {
                                Label("Rescan", systemImage: "arrow.clockwise")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    
                    // Networks Scroll Area
                    ScrollView {
                        VStack(spacing: 6) {
                            if networks.isEmpty && !isScanning {
                                Text("No Wi-Fi networks found. Make sure printer is powered on and click Rescan.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                ForEach(networks) { ap in
                                    NetworkRow(
                                        ap: ap,
                                        isSelected: selectedAP?.id == ap.id
                                    )
                                    .onTapGesture {
                                        selectedAP = ap
                                        errorMessage = nil
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: 180)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    
                    // Password Section
                    if let ap = selectedAP {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Password for \(ap.ssid)")
                                    .font(.subheadline)
                                    .bold()
                                Spacer()
                                if !ap.isSecure {
                                    Text("Open Network (No password required)")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                            
                            if ap.isSecure {
                                HStack {
                                    if isPasswordVisible {
                                        TextField("Enter Wi-Fi Password", text: $password)
                                            .textFieldStyle(.plain)
                                    } else {
                                        SecureField("Enter Wi-Fi Password", text: $password)
                                            .textFieldStyle(.plain)
                                    }
                                    
                                    Button {
                                        isPasswordVisible.toggle()
                                    } label: {
                                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                            }
                        }
                    }
                    
                    // Error Message
                    if let err = errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.1)))
                    }
                    
                    Spacer()
                    
                    // Action Footer
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isConnecting)
                        
                        Spacer()
                        
                        Button {
                            connect()
                        } label: {
                            HStack {
                                if isConnecting {
                                    ProgressView().controlSize(.small)
                                    Text("Connecting...")
                                } else {
                                    Image(systemName: "wifi")
                                    Text("Connect Printer to Wi-Fi")
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedAP == nil || isConnecting || (selectedAP?.isSecure == true && password.isEmpty))
                    }
                }
                .padding()
            }
        }
        .frame(width: 480, height: 440)
        .onAppear {
            scanNetworks()
        }
    }
    
    private func scanNetworks() {
        isScanning = true
        errorMessage = nil
        Task {
            do {
                let nets = try await printerService.fetchWifiNetworks()
                self.networks = nets
                // Pre-select home Wi-Fi if found
                if let home = nets.first(where: { $0.ssid.contains("Airtel") }) {
                    self.selectedAP = home
                } else if self.selectedAP == nil {
                    self.selectedAP = nets.first
                }
            } catch {
                self.errorMessage = "Could not scan Wi-Fi: \(error.localizedDescription)"
            }
            self.isScanning = false
        }
    }
    
    private func connect() {
        guard let ap = selectedAP else { return }
        isConnecting = true
        errorMessage = nil
        
        Task {
            do {
                try await printerService.connectToWifi(ap: ap, password: password)
                self.connectionSuccess = true
            } catch {
                self.errorMessage = "Connection error: \(error.localizedDescription)"
            }
            self.isConnecting = false
        }
    }
}

// MARK: - Network Row
struct NetworkRow: View {
    let ap: WifiAP
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: signalIcon(ap.signalStrength))
                .foregroundColor(isSelected ? .white : .blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(ap.ssid)
                    .font(.callout)
                    .bold(isSelected)
                Text("\(ap.encryptionType) • Channel \(ap.signalStrength > 0 ? "Good" : "Weak")")
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            
            Spacer()
            
            if ap.isSecure {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.blue : Color.clear)
        )
        .contentShape(Rectangle())
    }
    
    private func signalIcon(_ strength: Int) -> String {
        switch strength {
        case 3...: return "wifi"
        case 2: return "wifi"
        case 1: return "wifi"
        default: return "wifi.exclamationmark"
        }
    }
}
