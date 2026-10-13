import SwiftUI
import SwiftData

// MARK: - Environment Keys

private struct AllCollapsedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var allBlocksCollapsed: Bool {
        get { self[AllCollapsedKey.self] }
        set { self[AllCollapsedKey.self] = newValue }
    }
}

// MARK: - Sticky Header Support

/// Data representing a block header for sticky display
private struct BlockHeaderInfo: Equatable {
    let id: UUID
    let name: String
    let depth: Int
    let color: Color
    let repeatCount: Int
}


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

private let maxNestingDepth = 2

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
    @State private var showingShareSheet = false
    @State private var isAcceptingUpdate = false
    @State private var showingMakeCopyConfirmation = false
    @State private var allCollapsed = false
    @State private var headerPositions: [UUID: CGFloat] = [:]  // block id -> header minY
    @State private var contentBottoms: [UUID: CGFloat] = [:]
    @State private var listTopEdge: CGFloat = 0
    @State private var stickyOverlayHeight: CGFloat = 0
    
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
    private func updateBannerSection(for template: WorkoutTemplate) -> some View {
        if template.isDownloaded == true && template.hasAvailableUpdate == true {
            Section {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .foregroundStyle(.orange)
                        Text("An update is available from the creator.")
                            .font(.subheadline)
                        Spacer()
                    }
                    
                    HStack(spacing: 12) {
                        Button {
                            Task { await acceptUpdate(for: template) }
                        } label: {
                            HStack {
                                Spacer()
                                if isAcceptingUpdate {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("Accept Update")
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isAcceptingUpdate)
                        
                        Button {
                            keepCurrentVersion(template)
                        } label: {
                            HStack {
                                Spacer()
                                Text("Keep Current")
                                Spacer()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func editorContent(for template: WorkoutTemplate) -> some View {
        List {
                // Update banner for downloaded routines
                updateBannerSection(for: template)
                
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
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.title2)
                            if template.isDownloaded == true, let creator = template.creatorName {
                                Text("by \(creator)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
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
                
                // Blocks — all in one section so ForEach.onMove works for reordering
                Section {
                    ForEach(template.sortedBlocks) { block in
                        BlockEditorRow(
                            block: block,
                            template: template,
                            depth: 0,
                            isEditing: isEditing,
                            onChanged: markChanged,
                            onHeaderPosition: { id, minY in
                                headerPositions[id] = minY
                            },
                            onContentBottom: { id, maxY in
                                contentBottoms[id] = maxY
                            }
                        )
                    }
                    .onMove { source, destination in
                        var sortedBlocks = template.blocks.sorted { $0.sortOrder < $1.sortOrder }
                        guard source.allSatisfy({ $0 >= 0 && $0 < sortedBlocks.count }),
                              destination >= 0 && destination <= sortedBlocks.count else {
                            return
                        }
                        sortedBlocks.move(fromOffsets: source, toOffset: destination)
                        for (index, block) in sortedBlocks.enumerated() {
                            block.sortOrder = index
                        }
                        markChanged()
                    }
                    .moveDisabled(!isEditing)
                }
                
                // Add Block button (edit mode only)
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
        .onGeometryChange(for: CGFloat.self) { geo in
            geo.safeAreaInsets.top
        } action: { top in
            listTopEdge = top
        }
        .navigationTitle(isEditing ? "Edit Routine" : template.name)
        .navigationBarBackButtonHidden(isEditing)
        .environment(\.editMode, isEditing ? .constant(.active) : .constant(.inactive))
        .environment(\.allBlocksCollapsed, allCollapsed)
        .scrollDismissesKeyboard(.immediately)
        #if os(iOS)
        .toolbar(.hidden, for: .tabBar)
        #endif
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
                        allCollapsed = false
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        setupChildContext()
                        isEditing = false
                        editingTemplateName = false
                        allCollapsed = false
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        allCollapsed.toggle()
                    } label: {
                        Image(systemName: allCollapsed ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                    }
                    .buttonStyle(.bordered)
                    .clipShape(Capsule())
                }
            } else {
                // View mode toolbar
                if template.isDownloaded != true {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isEditing = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingShareSheet = true
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                } else {
                    // Downloaded routine: Make a Copy button
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingMakeCopyConfirmation = true
                        } label: {
                            Label("Make a Copy", systemImage: "doc.on.doc")
                        }
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
        .sheet(isPresented: $showingShareSheet) {
            ShareRoutineView(template: template)
        }
        .alert(
            "Make a Copy",
            isPresented: $showingMakeCopyConfirmation
        ) {
            Button("Copy") {
                makeCopy(of: template)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will create an editable copy in your My Routines tab.")
        }
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                stickyHeaderOverlay
            }
        }
    }
    
    /// Computes which headers should be pinned based on current scroll positions
    @ViewBuilder
    private var stickyHeaderOverlay: some View {
        let pinned = pinnedHeaders
        if !pinned.isEmpty {
            VStack(spacing: 0) {
                ForEach(pinned, id: \.id) { info in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(info.color)
                            .frame(width: 4, height: 20)
                        
                        Text(info.name)
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        if info.repeatCount > 1 {
                            Text("×\(info.repeatCount)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.leading, CGFloat(info.depth) * 4 + 20)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial)
                }
                Divider()
            }
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear {
                        stickyOverlayHeight = geo.size.height
                    }
                    .onChange(of: geo.size.height) { _, newHeight in
                        stickyOverlayHeight = newHeight
                    }
                }
            )
        } else {
            Color.clear.frame(height: 0)
                .onAppear { stickyOverlayHeight = 0 }
        }
    }
    
    /// Recursively collects all blocks with their depth for display info
    private func allBlocks(from blocks: [IntervalBlock], depth: Int = 0) -> [(block: IntervalBlock, depth: Int)] {
        var result: [(IntervalBlock, Int)] = []
        for block in blocks.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            result.append((block, depth))
            result.append(contentsOf: allBlocks(from: block.childBlocks, depth: depth + 1))
        }
        return result
    }
    
    /// Determines which block headers should be pinned at the top
    private var pinnedHeaders: [BlockHeaderInfo] {
        let pinThreshold = listTopEdge + stickyOverlayHeight
        var pinned: [BlockHeaderInfo] = []
        
        let activeTemplate = editableTemplate ?? template
        
        for (block, depth) in allBlocks(from: activeTemplate.blocks) {
            guard let minY = headerPositions[block.id] else { continue }
            let contentBottom = contentBottoms[block.id] ?? minY
            if minY < pinThreshold && contentBottom > pinThreshold {
                pinned.append(BlockHeaderInfo(
                    id: block.id,
                    name: block.name ?? "Unnamed Block",
                    depth: depth,
                    color: depthColor(depth),
                    repeatCount: block.repeatCount
                ))
            }
        }
        
        pinned.sort { $0.depth < $1.depth }
        return pinned
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
    
    private func makeCopy(of template: WorkoutTemplate) {
        let newBlocks = template.blocks.map { $0.duplicate() }
        let copy = WorkoutTemplate(
            name: "\(template.name) Copy",
            blocks: newBlocks,
            originalTemplateID: template.originalTemplateID
        )
        parentContext.insert(copy)
        try? parentContext.save()
    }
    
    private func acceptUpdate(for template: WorkoutTemplate) async {
        isAcceptingUpdate = true
        do {
            try await RoutineUpdateChecker.acceptUpdate(for: template, context: parentContext)
            setupChildContext()
        } catch {
            // Error handling — could show an alert here
        }
        isAcceptingUpdate = false
    }
    
    private func keepCurrentVersion(_ template: WorkoutTemplate) {
        try? RoutineUpdateChecker.unlinkRoutine(template, context: parentContext)
        dismiss()
    }
}

// MARK: - Block Editor Row (flat row with expandable content)

struct BlockEditorRow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.allBlocksCollapsed) private var allCollapsed
    @Bindable var block: IntervalBlock
    let template: WorkoutTemplate
    let depth: Int
    let isEditing: Bool
    var onChanged: () -> Void
    var onHeaderPosition: (UUID, CGFloat) -> Void = { _, _ in }
    var onContentBottom: (UUID, CGFloat) -> Void = { _, _ in }
    @State private var isExpanded = true
    @State private var editingBlockName = false
    
    private var blockColor: Color {
        depthColor(depth)
    }
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            // Block settings row (edit mode only) — pinned, not movable
            if isEditing {
                HStack {
                    HStack(spacing: 2) {
                        Text("Repeat:")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        
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
                        Label("Duplicate", systemImage: "doc.on.doc")
                            .labelStyle(.iconOnly)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    
                    Button(role: .destructive, action: deleteBlock) {
                        Label("Delete", systemImage: "trash")
                            .labelStyle(.iconOnly)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                }
                .moveDisabled(true)
                .deleteDisabled(true)
            }
            
            // Intervals and child blocks intermingled by sortOrder
            ForEach(block.sortedChildren) { child in
                switch child {
                case .interval(let interval):
                    IntervalRowView(
                        interval: interval,
                        block: block,
                        template: template,
                        depth: depth,
                        isEditing: isEditing,
                        onChanged: onChanged
                    )
                case .childBlock(let childBlock):
                    BlockEditorRow(
                        block: childBlock,
                        template: template,
                        depth: depth + 1,
                        isEditing: isEditing,
                        onChanged: onChanged,
                        onHeaderPosition: onHeaderPosition,
                        onContentBottom: onContentBottom
                    )
                }
            }
            .onMove { source, destination in
                var children = block.sortedChildren
                guard source.allSatisfy({ $0 >= 0 && $0 < children.count }),
                      destination >= 0 && destination <= children.count else {
                    return
                }
                children.move(fromOffsets: source, toOffset: destination)
                for (index, child) in children.enumerated() {
                    switch child {
                    case .interval(let interval):
                        interval.sortOrder = index
                    case .childBlock(let childBlock):
                        childBlock.sortOrder = index
                    }
                }
                onChanged()
            }
            .moveDisabled(!isEditing)
            
            // Add buttons (edit mode only) — pinned, not movable
            if isEditing {
                Button(action: addInterval) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(blockColor)
                            .frame(width: 4, height: 16)
                        Label("Add Interval", systemImage: "plus.circle")
                            .font(.subheadline)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .moveDisabled(true)
                .deleteDisabled(true)
                
                if depth < maxNestingDepth {
                    Button(action: addChildBlock) {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(blockColor)
                                .frame(width: 4, height: 16)
                            Label("Add Sub-Block", systemImage: "folder.badge.plus")
                                .font(.subheadline)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .moveDisabled(true)
                    .deleteDisabled(true)
                }
            }
            
            // Sentinel to track the bottom of this block's content
            Rectangle()
                .fill(.clear)
                .frame(height: 1)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .onGeometryChange(for: CGFloat.self) { geo in
                    geo.frame(in: .global).maxY
                } action: { maxY in
                    onContentBottom(block.id, maxY)
                }
                .moveDisabled(true)
                .deleteDisabled(true)
        } label: {
            // Block title — this is what the drag handle aligns with
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(blockColor)
                    .frame(width: 4, height: 20)
                
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
                }
                
                if isEditing {
                    Spacer()
                    Button {
                        editingBlockName.toggle()
                    } label: {
                        Label("Rename", systemImage: "pencil")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .onGeometryChange(for: CGFloat.self) { geo in
                geo.frame(in: .global).minY
            } action: { minY in
                onHeaderPosition(block.id, minY)
            }
        }
        .padding(.leading, CGFloat(depth) * 4)
        .onChange(of: allCollapsed) { _, collapsed in
            isExpanded = !collapsed
        }
    }
    
    // MARK: - Actions
    
    private func addInterval() {
        let newInterval = IntervalItem(
            name: "Interval \(block.intervals.count + 1)",
            duration: 60,
            sortOrder: block.nextChildSortOrder
        )
        block.intervals.append(newInterval)
        onChanged()
    }
    
    private func addChildBlock() {
        let newBlock = IntervalBlock(
            name: "Sub-Block \(block.childBlocks.count + 1)",
            repeatCount: 1,
            sortOrder: block.nextChildSortOrder,
            intervals: [],
            parentBlock: block
        )
        block.childBlocks.append(newBlock)
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
    
    private var isUntimed: Bool {
        duration <= 0
    }
    
    private var minutes: Int {
        Int(duration) / 60
    }
    private var seconds: Int {
        Int(duration) % 60
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Toggle("No Timer (manual advance)", isOn: Binding(
                get: { isUntimed },
                set: { noTimer in
                    if noTimer {
                        duration = 0
                    } else {
                        duration = 60  // default to 1 minute when re-enabling
                    }
                }
            ))
            .font(.subheadline)
            
            if !isUntimed {
                #if os(iOS)
                iOSPicker
                #else
                macOSPicker
                #endif
            }
        }
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
                    duration = TimeInterval(minutes * 60 + newSec)
                }
            )) {
                ForEach(0...59, id: \.self) { s in
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
        .frame(height: 150)
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
                #if os(iOS)
                .sheet(isPresented: $showingDurationPicker) {
                    DurationPickerView(duration: Binding(
                        get: { interval.duration },
                        set: { interval.duration = $0; onChanged() }
                    ))
                    .padding()
                    .presentationDetents([.fraction(0.35)])
                    .presentationDragIndicator(.visible)
                }
                #else
                .popover(isPresented: $showingDurationPicker) {
                    DurationPickerView(duration: Binding(
                        get: { interval.duration },
                        set: { interval.duration = $0; onChanged() }
                    ))
                    .padding()
                    .frame(width: 320, height: 50)
                }
                #endif
                
                Button(action: duplicateInterval) {
                    Label("Duplicate", systemImage: "doc.on.doc")
                        .labelStyle(.iconOnly)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                
                Button(role: .destructive, action: deleteInterval) {
                    Label("Delete", systemImage: "trash")
                        .labelStyle(.iconOnly)
                        .contentShape(Rectangle())
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
        if seconds <= 0 { return "Manual" }
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
