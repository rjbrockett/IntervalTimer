import SwiftUI
import SwiftData

/// Sheet for publishing a routine and sharing its link
struct ShareRoutineView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let template: WorkoutTemplate
    
    @State private var creatorName: String = ""
    @State private var isPublishing = false
    @State private var shareURL: URL?
    @State private var errorMessage: String?
    @State private var showingUnpublishConfirm = false
    @State private var isUnpublishing = false
    @State private var showCopiedFeedback = false
    
    var body: some View {
        NavigationStack {
            Form {
                if template.isPublished == true {
                    publishedSection
                } else {
                    publishSection
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Share Routine")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if template.isPublished == true, let recordName = template.publishedRecordName {
                shareURL = CloudKitSharingService.shareURL(for: recordName)
            }
            #if os(iOS)
            creatorName = UIDevice.current.name
            #else
            creatorName = Host.current().localizedName ?? "Unknown"
            #endif
        }
    }
    
    // MARK: - Not Yet Published
    
    private var publishSection: some View {
        Section {
            TextField("Your Name", text: $creatorName)
            
            Button {
                Task { await publish() }
            } label: {
                HStack {
                    Spacer()
                    if isPublishing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Share This Routine", systemImage: "square.and.arrow.up")
                    }
                    Spacer()
                }
            }
            .disabled(isPublishing || creatorName.trimmingCharacters(in: .whitespaces).isEmpty)
        } header: {
            Text("Publish")
        } footer: {
            Text("This will upload your routine to iCloud so others can download it via a link.")
        }
    }
    
    // MARK: - Already Published
    
    private var publishedSection: some View {
        Group {
            Section("Share Link") {
                if let url = shareURL {
                    HStack {
                        Text(url.absoluteString)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        Button {
                            #if os(iOS)
                            UIPasteboard.general.url = url
                            #else
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(url.absoluteString, forType: .string)
                            #endif
                            showCopiedFeedback = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showCopiedFeedback = false
                            }
                        } label: {
                            Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                        }
                    }
                    
                    #if os(iOS)
                    ShareLink(item: url) {
                        Label("Share Link", systemImage: "square.and.arrow.up")
                    }
                    #endif
                }
            }
            
            Section {
                Button {
                    Task { await publish() }
                } label: {
                    HStack {
                        Spacer()
                        if isPublishing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Push Update")
                        }
                        Spacer()
                    }
                }
                .disabled(isPublishing)
            } footer: {
                Text("Push the latest version so people who downloaded this routine can update.")
            }
            
            Section {
                Button(role: .destructive) {
                    showingUnpublishConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        if isUnpublishing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Unpublish")
                        }
                        Spacer()
                    }
                }
                .disabled(isUnpublishing)
                .confirmationDialog("Unpublish Routine?", isPresented: $showingUnpublishConfirm) {
                    Button("Unpublish", role: .destructive) {
                        Task { await unpublish() }
                    }
                } message: {
                    Text("This will remove the shared routine. People who already downloaded it will keep their copy but won't receive updates.")
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func publish() async {
        isPublishing = true
        errorMessage = nil
        
        let service = CloudKitSharingService()
        do {
            let recordName = try await service.publishRoutine(template, creatorName: creatorName)
            shareURL = CloudKitSharingService.shareURL(for: recordName)
            try? modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isPublishing = false
    }
    
    private func unpublish() async {
        isUnpublishing = true
        errorMessage = nil
        
        let service = CloudKitSharingService()
        do {
            try await service.unpublishRoutine(template)
            shareURL = nil
            try? modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isUnpublishing = false
    }
}
