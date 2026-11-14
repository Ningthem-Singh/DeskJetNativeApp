import SwiftUI

struct QueueView: View {
    @ObservedObject var printerService: PrinterService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Print Queue & Spooler")
                        .font(.title2)
                        .bold()
                    Text("Queue: \(printerService.printerInfo.cupsQueueName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    Task {
                        await printerService.fetchQueue()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                
                if !printerService.printQueue.isEmpty {
                    Button(role: .destructive) {
                        printerService.cancelAllJobs()
                    } label: {
                        Label("Cancel All Jobs", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.bottom, 8)
            
            // Queue Content
            if printerService.printQueue.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green.opacity(0.8))
                    Text("Print Queue is Clear")
                        .font(.headline)
                    Text("No pending or stuck print jobs.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
            } else {
                List {
                    ForEach(printerService.printQueue) { job in
                        HStack(spacing: 16) {
                            Image(systemName: "doc.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(job.id)
                                    .font(.headline)
                                Text("User: \(job.user) • Size: \(job.size)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(role: .destructive) {
                                printerService.cancelJob(id: job.id)
                            } label: {
                                Text("Cancel")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(20)
    }
}
