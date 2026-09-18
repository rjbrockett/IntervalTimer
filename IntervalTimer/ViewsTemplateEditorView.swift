import SwiftUI
import SwiftData

// MARK: - Numeric TextField with Done Button

#if os(iOS)
/// A text field for numeric input that shows a "Done" button above the keyboard.
/// Uses UIKit's inputAccessoryView for a native look.
struct NumericTextField: UIViewRepresentable {
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...99
    var keyboardType: UIKeyboardType = .numberPad
    var onChanged: (() -> Void)?
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.textAlignment = .center
        textField.borderStyle = .roundedRect
        textField.keyboardType = keyboardType
        textField.delegate = context.coordinator
        textField.font = .systemFont(ofSize: 17)
        
        // Add Done button using UIToolbar as inputAccessoryView
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flexSpace = UIBarButtonItem(
            barButtonSystemItem: .flexibleSpace, target: nil, action: nil
        )
        let doneButton = UIBarButtonItem(
            title: "Done",
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.donePressed)
        )
        doneButton.setTitleTextAttributes(
            [.font: UIFont.boldSystemFont(ofSize: 17)], for: .normal
        )
        toolbar.setItems([flexSpace, doneButton], animated: false)
        textField.inputAccessoryView = toolbar
        
        return textField
    }
    
    func updateUIView(_ textField: UITextField, context: Context) {
        let newText = "\(value)"
        if textField.text != newText {
            textField.text = newText
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        let parent: NumericTextField
        
        init(_ parent: NumericTextField) {
            self.parent = parent
        }
        
        @objc func donePressed() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            if let text = textField.text, let num = Int(text) {
                let clamped = max(parent.range.lowerBound, min(parent.range.upperBound, num))
                if parent.value != clamped {
                    parent.value = clamped
                    parent.onChanged?()
                }
            } else {
                textField.text = "\(parent.value)"
            }
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let allowed = CharacterSet.decimalDigits
            return string.unicodeScalars.allSatisfy { allowed.contains($0) } || string.isEmpty
        }
    }
}

/// A text field for decimal input (e.g. distance in miles) with a "Done" button.
struct DecimalTextField: UIViewRepresentable {
    @Binding var value: Double?
    var placeholder: String = ""
    var onChanged: (() -> Void)?
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.textAlignment = .right
        textField.borderStyle = .roundedRect
        textField.keyboardType = .decimalPad
        textField.placeholder = placeholder
        textField.delegate = context.coordinator
        textField.font = .systemFont(ofSize: 17)
        
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flexSpace = UIBarButtonItem(
            barButtonSystemItem: .flexibleSpace, target: nil, action: nil
        )
        let doneButton = UIBarButtonItem(
            title: "Done",
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.donePressed)
        )
        doneButton.setTitleTextAttributes(
            [.font: UIFont.boldSystemFont(ofSize: 17)], for: .normal
        )
        toolbar.setItems([flexSpace, doneButton], animated: false)
        textField.inputAccessoryView = toolbar
        
        return textField
    }
    
    func updateUIView(_ textField: UITextField, context: Context) {
        if !textField.isFirstResponder {
            if let val = value {
                textField.text = String(format: "%.2f", val)
            } else {
                textField.text = nil
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        let parent: DecimalTextField
        
        init(_ parent: DecimalTextField) {
            self.parent = parent
        }
        
        @objc func donePressed() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            if let text = textField.text, let num = Double(text), num > 0 {
                parent.value = num
            } else {
                parent.value = nil
            }
            parent.onChanged?()
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let allowed = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))
            return string.unicodeScalars.allSatisfy { allowed.contains($0) } || string.isEmpty
        }
    }
}
#endif

private let maxNestingDepth = 4

// Depth-based color for visual nesting
private func depthColor(_ depth: Int) -> Color {
    let colors: [Color] = [.blue, .purple, .orange, .green, .pink]
    return colors[depth % colors.count]
}

// MARK: - Template Editor (with save/cancel via child context)

struct TemplateEditorView: View {
    @Environment(\.modelContext) private var parentContext
    @Environment(\.dismiss) private var dismiss
    let template: WorkoutTemplate
    
    @State private var editingTemplateName = false
    @State private var hasUnsavedChanges = false
    @State private var showingDiscardAlert = false
    @State private var showingWorkoutSession = false
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    
    // Child context for transactional editing
    @State private var childContext: ModelContext?
    @State private var editableTemplate: WorkoutTemplate?
    
    var body: some View {
        Group {
            if let editableTemplate {
                editorContent(for: editableTemplate)
            } else {
                // Fallback: edit directly (used in previews or before context is ready)
                editorContent(for: template)
            }
        }
        .onAppear {
            setupChildContext()
        }
        .onChange(of: template.id) {
            setupChildContext()
        }
    }
    
    private func setupChildContext() {
        let container = parentContext.container
        let child = ModelContext(container)
        child.autosaveEnabled = false
        self.childContext = child
        
        // Fetch the same template in the child context
        let templateID = template.id
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate { $0.id == templateID }
        )
        if let fetched = try? child.fetch(descriptor).first {
            self.editableTemplate = fetched
        } else {
            // Template not persisted yet (e.g., preview) — edit directly
            self.editableTemplate = nil
        }
        hasUnsavedChanges = false
    }
    
    @ViewBuilder
    private func editorContent(for template: WorkoutTemplate) -> some View {
        List {
            // Template name section
            Section {
                if isEditing {
                    HStack {
                        if editingTemplateName {
                            TextField("Routine Name", text: Binding(
                                get: { template.name },
                                set: { template.name = $0; markChanged() }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                editingTemplateName = false
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
                } else {
                    Text(template.name)
                        .font(.title2)
                }
            }
            
            // Heart Rate Zones toggle
            Section {
                if isEditing {
                    Toggle("Show Heart Rate Zones", isOn: Binding(
                        get: { template.showHeartRateZones },
                        set: { template.showHeartRateZones = $0; markChanged() }
                    ))
                    .font(.subheadline)
                } else if template.showHeartRateZones {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                        Text("Heart Rate Zones Enabled")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Blocks
            ForEach(template.sortedBlocks) { block in
                BlockEditorSection(
                    block: block,
                    template: template,
                    depth: 0,
                    isEditing: isEditing,
                    onChanged: markChanged
                )
            }
            .onMove { source, destination in
                var sortedBlocks = template.blocks.sorted { $0.sortOrder < $1.sortOrder }
                sortedBlocks.move(fromOffsets: source, toOffset: destination)
                for (index, block) in sortedBlocks.enumerated() {
                    block.sortOrder = index
                }
                markChanged()
            }
            .moveDisabled(!isEditing)
            
            // Add Block button (only in edit mode)
            if isEditing {
                Section {
                    Button(action: {
                        let newBlock = IntervalBlock(
                            name: "Block \(template.blocks.count + 1)",
                            repeatCount: 1,
                            sortOrder: template.blocks.count,
                            intervals: []
                        )
                        template.blocks.append(newBlock)
                        markChanged()
                    }) {
                        Label("Add Block", systemImage: "plus.circle.fill")
                    }
                }
                
                // Delete routine button
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Routine")
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Routine" : template.name)
        .navigationBarBackButtonHidden(isEditing)
        .environment(\.editMode, isEditing ? .constant(.active) : .constant(.inactive))
        .scrollDismissesKeyboard(.immediately)
        .toolbar {
            if isEditing {
                // Editing toolbar
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if hasUnsavedChanges {
                            saveChanges()
                        }
                        isEditing = false
                        editingTemplateName = false
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        setupChildContext()
                        isEditing = false
                        editingTemplateName = false
                    }
                }
            } else {
                // View mode toolbar
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isEditing = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingWorkoutSession = true
                    } label: {
                        Label("Start Workout", systemImage: "play.fill")
                    }
                    .disabled(template.blocks.isEmpty)
                }
            }
        }
        .fullScreenCover(isPresented: $showingWorkoutSession) {
            WorkoutSessionView(template: template)
        }
        .alert(
            "Delete Routine",
            isPresented: $showingDeleteConfirmation
        ) {
            Button("Delete", role: .destructive) {
                deleteRoutine(template)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this routine? This cannot be undone.")
        }
    }
    
    private func markChanged() {
        hasUnsavedChanges = true
    }
    
    private func saveChanges() {
        guard let childContext else { return }
        editableTemplate?.updatedAt = Date()
        try? childContext.save()
        hasUnsavedChanges = false
    }
    
    private func deleteRoutine(_ template: WorkoutTemplate) {
        parentContext.delete(template)
        try? parentContext.save()
        dismiss()
    }
}

// MARK: - Block Editor Section (recursive)

struct BlockEditorSection: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var block: IntervalBlock
    let template: WorkoutTemplate
    let depth: Int
    let isEditing: Bool
    var onChanged: () -> Void
    
    @State private var isExpanded = true
    @State private var editingBlockName = false
    
    private var blockColor: Color {
        depthColor(depth)
    }
    
    var body: some View {
        Section {
            if isEditing {
                // Edit mode: full controls
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        HStack(spacing: 2) {
                            Text("Repeat:")
                                .foregroundStyle(.secondary)
                            
                            #if os(iOS)
                            NumericTextField(
                                value: Binding(
                                    get: { block.repeatCount },
                                    set: { block.repeatCount = $0 }
                                ),
                                range: 1...99,
                                onChanged: onChanged
                            )
                            .frame(width: 45, height: 34)
                            #else
                            TextField("", value: Binding(
                                get: { block.repeatCount },
                                set: { newVal in
                                    block.repeatCount = max(1, min(99, newVal))
                                    onChanged()
                                }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 45)
                            .multilineTextAlignment(.center)
                            #endif
                            
                            Stepper("", value: Binding(
                                get: { block.repeatCount },
                                set: { newVal in
                                    block.repeatCount = max(1, min(99, newVal))
                                    onChanged()
                                }
                            ), in: 1...99)
                            .labelsHidden()
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
            }
            
            // Content: intervals and/or child blocks
            if isExpanded {
                // Intervals
                ForEach(block.sortedIntervals) { interval in
                    IntervalRowView(
                        interval: interval,
                        block: block,
                        template: template,
                        depth: depth,
                        isEditing: isEditing,
                        onChanged: onChanged
                    )
                }
                .onMove { source, destination in
                    moveIntervals(from: source, to: destination)
                }
                .moveDisabled(!isEditing)
                
                // Child blocks
                ForEach(block.sortedChildBlocks) { childBlock in
                    BlockEditorSection(
                        block: childBlock,
                        template: template,
                        depth: depth + 1,
                        isEditing: isEditing,
                        onChanged: onChanged
                    )
                }
                .onMove { source, destination in
                    moveChildBlocks(from: source, to: destination)
                }
                .moveDisabled(!isEditing)
                
                // Add buttons (edit mode only)
                if isEditing {
                    HStack {
                        Button(action: addInterval) {
                            Label("Add Interval", systemImage: "plus.circle")
                        }
                        
                        if depth < maxNestingDepth {
                            Button(action: addChildBlock) {
                                Label("Add Sub-Block", systemImage: "folder.badge.plus")
                            }
                        }
                    }
                }
            }
        } header: {
            HStack {
                if editingBlockName && isEditing {
                    TextField("Block Name", text: Binding(
                        get: { block.name ?? "" },
                        set: { block.name = $0.isEmpty ? nil : $0 }
                    ))
                    .font(.headline)
                    .fontWeight(.bold)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        editingBlockName = false
                        onChanged()
                    }
                } else {
                    Button(action: { isExpanded.toggle() }) {
                        HStack {
                            Text(block.name ?? "Unnamed Block")
                                .font(.headline)
                                .fontWeight(.bold)
                            if block.repeatCount > 1 {
                                Text("×\(block.repeatCount)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if block.isGroup {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                if isEditing {
                    Button {
                        editingBlockName.toggle()
                    } label: {
                        Label("Rename", systemImage: "pencil")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        // Visual distinction for sub-blocks: indentation + colored left border
        .padding(.leading, CGFloat(depth) * 16)
        .listRowBackground(
            depth > 0
            ? AnyView(
                HStack(spacing: 0) {
                    Spacer().frame(width: CGFloat(depth) * 16 - 4)
                    blockColor.frame(width: 4)
                    Color.clear
                }
            )
            : AnyView(Color.clear)
        )
    }
    
    // MARK: - Actions
    
    private func addInterval() {
        let newInterval = IntervalItem(
            name: "Interval \(block.intervals.count + 1)",
            duration: 60,
            sortOrder: block.intervals.count
        )
        block.intervals.append(newInterval)
        onChanged()
    }
    
    private func addChildBlock() {
        let newBlock = IntervalBlock(
            name: "Sub-Block \(block.childBlocks.count + 1)",
            repeatCount: 1,
            sortOrder: block.childBlocks.count,
            intervals: [],
            parentBlock: block
        )
        block.childBlocks.append(newBlock)
        onChanged()
    }
    
    private func moveIntervals(from source: IndexSet, to destination: Int) {
        var sortedIntervals = block.intervals.sorted { $0.sortOrder < $1.sortOrder }
        sortedIntervals.move(fromOffsets: source, toOffset: destination)
        for (index, interval) in sortedIntervals.enumerated() {
            interval.sortOrder = index
        }
        onChanged()
    }
    
    private func moveChildBlocks(from source: IndexSet, to destination: Int) {
        var sorted = block.childBlocks.sorted { $0.sortOrder < $1.sortOrder }
        sorted.move(fromOffsets: source, toOffset: destination)
        for (index, child) in sorted.enumerated() {
            child.sortOrder = index
        }
        onChanged()
    }
    
    private func deleteBlock() {
        if let parent = block.parentBlock {
            parent.childBlocks.removeAll { $0.id == block.id }
        } else {
            template.blocks.removeAll { $0.id == block.id }
        }
        modelContext.delete(block)
        onChanged()
    }
    
    private func duplicateBlock() {
        let duplicatedBlock = block.duplicate()
        duplicatedBlock.sortOrder = block.sortOrder + 1
        
        if let parent = block.parentBlock {
            for existing in parent.childBlocks where existing.sortOrder > block.sortOrder {
                existing.sortOrder += 1
            }
            parent.childBlocks.append(duplicatedBlock)
        } else {
            for existing in template.blocks where existing.sortOrder > block.sortOrder {
                existing.sortOrder += 1
            }
            template.blocks.append(duplicatedBlock)
        }
        onChanged()
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
        HStack(spacing: 12) {
            // Minutes group
            HStack(spacing: 4) {
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
                
                Stepper("", value: Binding(
                    get: { minutes },
                    set: { newMin in
                        duration = TimeInterval(max(0, newMin) * 60 + seconds)
                        if duration < 5 { duration = 5 }
                        if duration > 3600 { duration = TimeInterval(59 * 60 + seconds) }
                    }
                ), in: 0...59)
                .labelsHidden()
            }
            
            // Seconds group
            HStack(spacing: 4) {
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
                
                Stepper("", value: Binding(
                    get: { seconds },
                    set: { newSec in
                        let clamped = max(0, min(55, newSec))
                        duration = TimeInterval(minutes * 60 + clamped)
                        if duration < 5 { duration = 5 }
                    }
                ), in: 0...55, step: 5)
                .labelsHidden()
            }
        }
    }
    #endif
}

// MARK: - Interval Row

struct IntervalRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var interval: IntervalItem
    let block: IntervalBlock
    let template: WorkoutTemplate
    let depth: Int
    let isEditing: Bool
    var onChanged: () -> Void
    
    @State private var editingName = false
    @State private var showingDurationPicker = false
    
    private var rowColor: Color {
        depthColor(depth)
    }
    
    var body: some View {
        if isEditing {
            editingBody
        } else {
            viewBody
        }
    }
    
    // MARK: - View Mode (read-only)
    
    private var viewBody: some View {
        HStack {
            if depth > 0 {
                RoundedRectangle(cornerRadius: 2)
                    .fill(rowColor.opacity(0.3))
                    .frame(width: 3)
            }
            
            Text(interval.name)
                .lineLimit(1)
            
            Spacer()
            
            Text(formatDuration(interval.duration))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            
            if interval.trackDistance {
                Image(systemName: "figure.run")
                    .font(.caption)
                    .foregroundStyle(.green)
                if let goal = interval.distanceGoal, goal > 0 {
                    Text(String(format: "%.1f mi", goal / 1609.34))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Edit Mode
    
    private var editingBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if depth > 0 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(rowColor.opacity(0.3))
                        .frame(width: 3)
                }
                
                if editingName {
                    TextField("Name", text: Binding(
                        get: { interval.name },
                        set: { interval.name = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        editingName = false
                        onChanged()
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
                    DurationPickerView(duration: Binding(
                        get: { interval.duration },
                        set: { interval.duration = $0; onChanged() }
                    ))
                    .padding()
                    #if os(macOS)
                    .frame(width: 320, height: 50)
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
            
            // Distance tracking
            HStack {
                Toggle("Track Distance", isOn: Binding(
                    get: { interval.trackDistance },
                    set: { interval.trackDistance = $0; onChanged() }
                ))
                .font(.subheadline)
                .toggleStyle(.switch)
            }
            
            if interval.trackDistance {
                HStack {
                    Text("Distance Goal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    #if os(iOS)
                    DecimalTextField(
                        value: Binding(
                            get: { interval.distanceGoal.map { $0 / 1609.34 } },
                            set: { interval.distanceGoal = $0.map { $0 * 1609.34 } }
                        ),
                        placeholder: "None",
                        onChanged: onChanged
                    )
                    .frame(width: 80, height: 34)
                    #else
                    TextField("None", value: Binding(
                        get: { interval.distanceGoal.map { $0 / 1609.34 } },
                        set: {
                            interval.distanceGoal = $0.map { $0 * 1609.34 }
                            onChanged()
                        }
                    ), format: .number.precision(.fractionLength(1...2)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    #endif
                    Text("mi")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private func duplicateInterval() {
        let duplicated = interval.duplicate()
        duplicated.sortOrder = interval.sortOrder + 1
        
        for existingInterval in block.intervals where existingInterval.sortOrder > interval.sortOrder {
            existingInterval.sortOrder += 1
        }
        
        block.intervals.append(duplicated)
        onChanged()
    }
    
    private func deleteInterval() {
        block.intervals.removeAll { $0.id == interval.id }
        modelContext.delete(interval)
        onChanged()
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

// MARK: - Preview

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
