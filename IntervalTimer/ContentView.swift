import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse) 
    private var templates: [WorkoutTemplate]
    
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var showingAddTemplate = false
    @State private var newTemplateName = ""
    
    var body: some View {
        NavigationSplitView {
            templateList
        } detail: {
            if let template = selectedTemplate {
                TemplateEditorView(template: template)
            } else {
                Text("Select a template")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var templateList: some View {
        List(selection: $selectedTemplate) {
            ForEach(templates) { template in
                NavigationLink(value: template) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.name)
                            .font(.headline)
                        Text("\(template.blocks.count) block\(template.blocks.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        if selectedTemplate?.id == template.id {
                            selectedTemplate = nil
                        }
                        modelContext.delete(template)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                #if os(macOS)
                .contextMenu {
                    Button {
                        duplicateTemplate(template)
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        if selectedTemplate?.id == template.id {
                            selectedTemplate = nil
                        }
                        modelContext.delete(template)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                #endif
            }
        }
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddTemplate = true }) {
                    Label("Add Template", systemImage: "plus")
                }
            }
            
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            #endif
        }
        .sheet(isPresented: $showingAddTemplate) {
            addTemplateSheet
        }
        .onAppear {
            if templates.isEmpty {
                seedSampleData()
            }
        }
    }
    
    private var addTemplateSheet: some View {
        NavigationStack {
            Form {
                TextField("Template Name", text: $newTemplateName)
            }
            .navigationTitle("New Template")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddTemplate = false
                        newTemplateName = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addTemplate()
                    }
                    .disabled(newTemplateName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 200)
        #endif
    }
    
    private func addTemplate() {
        let template = WorkoutTemplate(name: newTemplateName)
        modelContext.insert(template)
        
        showingAddTemplate = false
        newTemplateName = ""
        selectedTemplate = template
    }
    
    private func duplicateTemplate(_ original: WorkoutTemplate) {
        let newBlocks = original.blocks.map { $0.duplicate() }
        let copy = WorkoutTemplate(
            name: "\(original.name) Copy",
            blocks: newBlocks
        )
        modelContext.insert(copy)
        selectedTemplate = copy
    }
    
    private func seedSampleData() {
        // Sample 1: Basic Interval Run
        let warmup = IntervalBlock(
            name: "Warmup",
            repeatCount: 1,
            sortOrder: 0,
            intervals: [
                IntervalItem(name: "Easy Jog", duration: 300, sortOrder: 0)
            ]
        )
        
        let mainSet = IntervalBlock(
            name: "Main Set",
            repeatCount: 5,
            sortOrder: 1,
            intervals: [
                IntervalItem(name: "Sprint", duration: 60, sortOrder: 0),
                IntervalItem(name: "Recovery", duration: 90, sortOrder: 1)
            ]
        )
        
        let cooldown = IntervalBlock(
            name: "Cooldown",
            repeatCount: 1,
            sortOrder: 2,
            intervals: [
                IntervalItem(name: "Walk", duration: 300, sortOrder: 0)
            ]
        )
        
        let template1 = WorkoutTemplate(
            name: "5x Sprint Intervals",
            blocks: [warmup, mainSet, cooldown]
        )
        
        // Sample 2: Tabata
        let tabata = IntervalBlock(
            name: "Tabata",
            repeatCount: 8,
            sortOrder: 0,
            intervals: [
                IntervalItem(name: "Work", duration: 20, sortOrder: 0),
                IntervalItem(name: "Rest", duration: 10, sortOrder: 1)
            ]
        )
        
        let template2 = WorkoutTemplate(
            name: "Tabata 4 Minutes",
            blocks: [tabata]
        )
        
        // Sample 3: Nested HIIT Circuit
        let upperBody = IntervalBlock(
            name: "Upper Body",
            repeatCount: 2,
            sortOrder: 0,
            intervals: [
                IntervalItem(name: "Pushups", duration: 30, sortOrder: 0),
                IntervalItem(name: "Rest", duration: 15, sortOrder: 1)
            ]
        )
        let lowerBody = IntervalBlock(
            name: "Lower Body",
            repeatCount: 2,
            sortOrder: 1,
            intervals: [
                IntervalItem(name: "Squats", duration: 30, sortOrder: 0),
                IntervalItem(name: "Rest", duration: 15, sortOrder: 1)
            ]
        )
        let circuit = IntervalBlock(
            name: "Circuit",
            repeatCount: 3,
            sortOrder: 0,
            childBlocks: [upperBody, lowerBody]
        )
        let template3 = WorkoutTemplate(
            name: "3x HIIT Circuit",
            blocks: [circuit]
        )
        
        modelContext.insert(template1)
        modelContext.insert(template2)
        modelContext.insert(template3)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WorkoutTemplate.self, IntervalBlock.self, IntervalItem.self])
}
