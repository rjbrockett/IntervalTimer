import SwiftUI
import SwiftData

struct TemplateEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var template: WorkoutTemplate
    
    @State private var editingTemplateName = false
    
    var body: some View {
        List {
            Section {
                HStack {
                    if editingTemplateName {
                        TextField("Template Name", text: $template.name)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                editingTemplateName = false
                                template.updatedAt = Date()
                            }
                    } else {
                        Text(template.name)
                            .font(.title2)
                            .onTapGesture {
                                editingTemplateName = true
                            }
                    }
                    Spacer()
                    if !editingTemplateName {
                        Button {
                            editingTemplateName = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            
            ForEach(template.sortedBlocks) { block in
                BlockEditorSection(block: block, template: template)
            }
            
            Section {
                Button(action: addBlock) {
                    Label("Add Block", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("Edit Template")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            #endif
        }
    }
    
    private func addBlock() {
        let newBlock = IntervalBlock(
            name: "Block \(template.blocks.count + 1)",
            repeatCount: 1,
            sortOrder: template.blocks.count,
            intervals: []
        )
        template.blocks.append(newBlock)
        template.updatedAt = Date()
    }
}

struct BlockEditorSection: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var block: IntervalBlock
    let template: WorkoutTemplate
    
    @State private var isExpanded = true
    @State private var editingBlockName = false
    
    var body: some View {
        Section {
            // Block header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if editingBlockName {
                        TextField("Block Name (optional)", text: Binding(
                            get: { block.name ?? "" },
                            set: { block.name = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            editingBlockName = false
                            template.updatedAt = Date()
                        }
                    } else {
                        Text(block.name ?? "Unnamed Block")
                            .font(.headline)
                            .onTapGesture {
                                editingBlockName = true
                            }
                    }
                    Spacer()
                    if !editingBlockName {
                        Button {
                            editingBlockName = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                
                HStack {
                    Stepper("Repeat: \(block.repeatCount)x", value: $block.repeatCount, in: 1...99)
                        .onChange(of: block.repeatCount) {
                            template.updatedAt = Date()
                        }
                    
                    Spacer()
                    
                    Button(action: duplicateBlock) {
                        Label("Duplicate Block", systemImage: "doc.on.doc")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    
                    Button(role: .destructive, action: deleteBlock) {
                        Label("Delete Block", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.vertical, 4)
            
            // Intervals in this block
            if isExpanded {
                ForEach(block.intervals.sorted(by: { $0.sortOrder < $1.sortOrder })) { interval in
                    IntervalRowView(interval: interval, block: block, template: template)
                }
                .onMove { source, destination in
                    moveIntervals(from: source, to: destination)
                }
                
                Button(action: addInterval) {
                    Label("Add Interval", systemImage: "plus.circle")
                }
            }
        } header: {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Text(block.name ?? "Unnamed Block")
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    private func addInterval() {
        let newInterval = IntervalItem(
            name: "Interval \(block.intervals.count + 1)",
            duration: 60,
            sortOrder: block.intervals.count
        )
        block.intervals.append(newInterval)
        template.updatedAt = Date()
    }
    
    private func moveIntervals(from source: IndexSet, to destination: Int) {
        var sortedIntervals = block.intervals.sorted { $0.sortOrder < $1.sortOrder }
        sortedIntervals.move(fromOffsets: source, toOffset: destination)
        
        for (index, interval) in sortedIntervals.enumerated() {
            interval.sortOrder = index
        }
        template.updatedAt = Date()
    }
    
    private func deleteBlock() {
        modelContext.delete(block)
        template.updatedAt = Date()
    }
    
    private func duplicateBlock() {
        let duplicatedBlock = block.duplicate()
        duplicatedBlock.sortOrder = block.sortOrder + 1
        
        // Shift sort orders of blocks after this one
        for existingBlock in template.blocks where existingBlock.sortOrder > block.sortOrder {
            existingBlock.sortOrder += 1
        }
        
        template.blocks.append(duplicatedBlock)
        template.updatedAt = Date()
    }
}

// MARK: - Duration Picker

struct DurationPickerView: View {
    @Binding var duration: TimeInterval
    
    private var minutes: Int {
        Int(duration) / 60
    }
    private var seconds: Int {
        Int(duration) % 60
    }
    
    var body: some View {
        #if os(iOS)
        iOSPicker
        #else
        macOSPicker
        #endif
    }
    
    #if os(iOS)
    private var iOSPicker: some View {
        HStack(spacing: 0) {
            Picker("Minutes", selection: Binding(
                get: { minutes },
                set: { newMin in
                    duration = TimeInterval(newMin * 60 + seconds)
                }
            )) {
                ForEach(0...59, id: \.self) { m in
                    Text("\(m)").tag(m)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 60)
            .clipped()
            
            Text("m")
                .font(.body)
                .foregroundStyle(.secondary)
            
            Picker("Seconds", selection: Binding(
                get: { seconds },
                set: { newSec in
                    let total = TimeInterval(minutes * 60 + newSec)
                    duration = max(5, total)
                }
            )) {
                ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { s in
                    Text("\(s)").tag(s)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 60)
            .clipped()
            
            Text("s")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(height: 100)
    }
    #endif
    
    #if os(macOS)
    private var macOSPicker: some View {
        HStack(spacing: 4) {
            Button {
                if duration > 5 { duration -= 5 }
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.borderless)
            
            HStack(spacing: 2) {
                TextField("", value: Binding(
                    get: { minutes },
                    set: { newMin in
                        duration = TimeInterval(max(0, newMin) * 60 + seconds)
                        if duration < 5 { duration = 5 }
                    }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 40)
                .multilineTextAlignment(.trailing)
                
                Text("m")
                    .foregroundStyle(.secondary)
                
                TextField("", value: Binding(
                    get: { seconds },
                    set: { newSec in
                        let clamped = min(55, max(0, newSec))
                        duration = TimeInterval(minutes * 60 + clamped)
                        if duration < 5 { duration = 5 }
                    }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 40)
                .multilineTextAlignment(.trailing)
                
                Text("s")
                    .foregroundStyle(.secondary)
            }
            
            Button {
                if duration < 3600 { duration += 5 }
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
        }
    }
    #endif
}

struct IntervalRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var interval: IntervalItem
    let block: IntervalBlock
    let template: WorkoutTemplate
    
    @State private var editingName = false
    @State private var showingDurationPicker = false
    
    var body: some View {
        HStack {
            if editingName {
                TextField("Name", text: $interval.name)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        editingName = false
                        template.updatedAt = Date()
                    }
                    .frame(maxWidth: 150)
            } else {
                Text(interval.name)
                    .lineLimit(1)
                    .onTapGesture {
                        editingName = true
                    }
            }
            
            Spacer()
            
            Button {
                showingDurationPicker.toggle()
            } label: {
                Text(formatDuration(interval.duration))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.bordered)
            .popover(isPresented: $showingDurationPicker) {
                DurationPickerView(duration: $interval.duration)
                    .padding()
                    .onChange(of: interval.duration) {
                        template.updatedAt = Date()
                    }
                    #if os(macOS)
                    .frame(width: 220, height: 50)
                    #endif
            }
            
            Button(action: duplicateInterval) {
                Label("Duplicate", systemImage: "doc.on.doc")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            
            Button(role: .destructive, action: deleteInterval) {
                Label("Delete", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
        }
    }
    
    private func duplicateInterval() {
        let duplicated = interval.duplicate()
        duplicated.sortOrder = interval.sortOrder + 1
        
        // Shift sort orders of intervals after this one
        for existingInterval in block.intervals where existingInterval.sortOrder > interval.sortOrder {
            existingInterval.sortOrder += 1
        }
        
        block.intervals.append(duplicated)
        template.updatedAt = Date()
    }
    
    private func deleteInterval() {
        modelContext.delete(interval)
        template.updatedAt = Date()
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if minutes > 0 {
            if secs > 0 {
                return "\(minutes)m \(secs)s"
            } else {
                return "\(minutes)m"
            }
        } else {
            return "\(secs)s"
        }
    }
}

#Preview {
    NavigationStack {
        TemplateEditorView(template: WorkoutTemplate(
            name: "Test Template",
            blocks: [
                IntervalBlock(
                    name: "Warmup",
                    repeatCount: 1,
                    sortOrder: 0,
                    intervals: [
                        IntervalItem(name: "Jog", duration: 300, sortOrder: 0),
                        IntervalItem(name: "Stretch", duration: 60, sortOrder: 1)
                    ]
                ),
                IntervalBlock(
                    name: "Main Set",
                    repeatCount: 3,
                    sortOrder: 1,
                    intervals: [
                        IntervalItem(name: "Sprint", duration: 60, sortOrder: 0),
                        IntervalItem(name: "Recovery", duration: 90, sortOrder: 1)
                    ]
                )
            ]
        ))
    }
    .modelContainer(for: [WorkoutTemplate.self, IntervalBlock.self, IntervalItem.self])
}
