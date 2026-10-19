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


// MARK: - Custom Drag System

/// Identifies the block being dragged and its context
private struct DragItem {
    let blockID: UUID
    let blockName: String
    let blockColor: Color
    let repeatCount: Int
    let depth: Int
    let parentBlockID: UUID?
}

/// Where the dragged item would be inserted
private struct DropTarget: Equatable {
    let parentBlockID: UUID?
    let insertionIndex: Int
}

/// Lightweight floating preview shown during drag
private struct DragPreviewView: View {
    let name: String
    let color: Color
    let repeatCount: Int
    
    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 20)
            Text(name)
                .font(.headline)
                .fontWeight(.bold)
            if repeatCount > 1 {
                Text("×\(repeatCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
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
    /// Block IDs whose content is visually hidden during drag (rows still exist).
    @State private var hiddenBlockIDs: Set<UUID> = []
    /// Custom drag state
    @State private var activeDrag: DragItem?
    @State private var dragLocation: CGPoint = .zero
    @State private var dropTarget: DropTarget?
    @State private var autoScrollTimer: Timer?
    @State private var listGlobalFrame: CGRect = .zero
    #if os(iOS)
    @State private var editMode: EditMode = .inactive
    #endif
    @State private var headerPositions: [UUID: CGFloat] = [:]  // block id -> header minY
    @State private var contentBottoms: [UUID: CGFloat] = [:]
    @State private var listMetrics: (top: CGFloat, height: CGFloat) = (0, 0)
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
        .onChange(of: isEditing) { _, editing in
            #if os(iOS)
            editMode = editing ? .active : .inactive
            #endif
            if !editing {
                cleanupDrag()
            }
        }
        .onChange(of: allCollapsed) {
            cleanupDrag()
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
        ScrollViewReader { scrollProxy in
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
                            },
                            onDragStarted: { draggedID in
                                startDrag(blockID: draggedID, in: template)
                            },
                            onDragMoved: { location in
                                guard activeDrag != nil else { return }
                                dragLocation = location
                                dropTarget = computeDropTarget(at: location)
                                updateAutoScroll(at: location, scrollProxy: scrollProxy)
                            },
                            onDragEnded: {
                                commitDrag(in: template)
                            },
                            hiddenBlockIDs: $hiddenBlockIDs,
                            activeDragBlockID: activeDrag?.blockID
                        )
                    }
                    .moveDisabled(true)
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
        .onGeometryChange(for: [CGFloat].self) { geo in
            [geo.safeAreaInsets.top, geo.size.height]
        } action: { values in
            listMetrics = (values[0], values[1])
        }
        .onGeometryChange(for: CGRect.self) { geo in
            geo.frame(in: .global)
        } action: { frame in
            listGlobalFrame = frame
        }
        } // ScrollViewReader
        .navigationTitle(isEditing ? "Edit Routine" : template.name)
        .navigationBarBackButtonHidden(isEditing)
        #if os(iOS)
        .environment(\.editMode, $editMode)
        #endif
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
        #if os(iOS)
        .fullScreenCover(isPresented: $showingWorkoutSession) {
            WorkoutSessionView(template: template)
        }
        #else
        .sheet(isPresented: $showingWorkoutSession) {
            WorkoutSessionView(template: template)
        }
        #endif
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
        .overlay {
            // Floating drag preview anchored to finger
            if let drag = activeDrag, dragLocation != .zero {
                DragPreviewView(
                    name: drag.blockName,
                    color: drag.blockColor,
                    repeatCount: drag.repeatCount
                )
                .frame(width: listGlobalFrame.width * 0.9)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                .position(
                    x: listGlobalFrame.width / 2,
                    y: dragLocation.y - listGlobalFrame.minY
                )
                .allowsHitTesting(false)
                .animation(.interactiveSpring, value: dragLocation)
            }
        }
        .overlay {
            // Drop indicator line
            if let target = dropTarget, activeDrag != nil {
                let indicatorY = computeIndicatorY(for: target, in: editableTemplate ?? template)
                if indicatorY > 0 {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.blue)
                        .frame(width: listGlobalFrame.width - 40, height: 3)
                        .position(
                            x: listGlobalFrame.width / 2,
                            y: indicatorY - listGlobalFrame.minY
                        )
                        .allowsHitTesting(false)
                }
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
        let pinThreshold = listMetrics.top + stickyOverlayHeight
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
    
    // MARK: - Custom Drag Helpers
    
    /// Context info for a block found in the hierarchy
    private struct BlockContext {
        let block: IntervalBlock
        let depth: Int
        let parentBlockID: UUID?
        let siblingIDs: [UUID]
        let indexInSiblings: Int
    }
    
    /// Recursively find a block and its context in the template hierarchy
    private func findBlockContext(id: UUID, in template: WorkoutTemplate) -> BlockContext? {
        // Check top-level blocks
        let topBlocks = template.blocks.sorted { $0.sortOrder < $1.sortOrder }
        if let index = topBlocks.firstIndex(where: { $0.id == id }) {
            return BlockContext(
                block: topBlocks[index],
                depth: 0,
                parentBlockID: nil,
                siblingIDs: topBlocks.map(\.id),
                indexInSiblings: index
            )
        }
        // Recurse into children
        return findBlockContextRecursive(id: id, blocks: topBlocks, depth: 1)
    }
    
    private func findBlockContextRecursive(id: UUID, blocks: [IntervalBlock], depth: Int) -> BlockContext? {
        for parent in blocks {
            let children = parent.childBlocks.sorted { $0.sortOrder < $1.sortOrder }
            if let index = children.firstIndex(where: { $0.id == id }) {
                return BlockContext(
                    block: children[index],
                    depth: depth,
                    parentBlockID: parent.id,
                    siblingIDs: children.map(\.id),
                    indexInSiblings: index
                )
            }
            if let found = findBlockContextRecursive(id: id, blocks: children, depth: depth + 1) {
                return found
            }
        }
        return nil
    }
    
    /// Begin a custom drag: populate activeDrag, collapse sibling blocks
    private func startDrag(blockID: UUID, in template: WorkoutTemplate) {
        guard activeDrag == nil else { return }
        guard let ctx = findBlockContext(id: blockID, in: template) else { return }
        
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
        
        // Set drag state without animation
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            activeDrag = DragItem(
                blockID: blockID,
                blockName: ctx.block.name ?? "Unnamed Block",
                blockColor: depthColor(ctx.depth),
                repeatCount: ctx.block.repeatCount,
                depth: ctx.depth,
                parentBlockID: ctx.parentBlockID
            )
            if let headerY = headerPositions[blockID] {
                dragLocation = CGPoint(x: listGlobalFrame.midX, y: headerY + 20)
            }
        }
        
        // Collapse all sibling blocks (including the dragged one) — animated
        var idsToHide = Set<UUID>()
        for siblingID in ctx.siblingIDs {
            idsToHide.insert(siblingID)
            if let block = findBlock(id: siblingID, in: template) {
                collectAllDescendantIDs(of: block, into: &idsToHide)
            }
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            hiddenBlockIDs = idsToHide
        }
    }
    
    /// Find a block by ID anywhere in the template
    private func findBlock(id: UUID, in template: WorkoutTemplate) -> IntervalBlock? {
        for block in template.blocks {
            if block.id == id { return block }
            if let found = findBlockRecursive(id: id, in: block) { return found }
        }
        return nil
    }
    
    private func findBlockRecursive(id: UUID, in parent: IntervalBlock) -> IntervalBlock? {
        for child in parent.childBlocks {
            if child.id == id { return child }
            if let found = findBlockRecursive(id: id, in: child) { return found }
        }
        return nil
    }
    
    /// Collect all descendant block IDs (children, grandchildren, etc.)
    private func collectAllDescendantIDs(of block: IntervalBlock, into set: inout Set<UUID>) {
        for child in block.childBlocks {
            set.insert(child.id)
            collectAllDescendantIDs(of: child, into: &set)
        }
    }
    
    /// Compute which gap the user is hovering over
    private func computeDropTarget(at location: CGPoint) -> DropTarget? {
        guard let drag = activeDrag else { return nil }
        
        // Get sibling blocks based on drag context
        let activeTemplate = editableTemplate ?? template
        let siblings: [IntervalBlock]
        let parentID: UUID?
        
        if let pid = drag.parentBlockID,
           let parent = findBlock(id: pid, in: activeTemplate) {
            siblings = parent.childBlocks.sorted { $0.sortOrder < $1.sortOrder }
            parentID = pid
        } else {
            siblings = activeTemplate.blocks.sorted { $0.sortOrder < $1.sortOrder }
            parentID = nil
        }
        
        // Find closest gap between headers
        var bestIndex = 0
        var bestDistance: CGFloat = .infinity
        
        for (i, block) in siblings.enumerated() {
            guard let headerY = headerPositions[block.id] else { continue }
            let distance = abs(location.y - headerY)
            if distance < bestDistance {
                bestDistance = distance
                // If above the midpoint of this header, insert before; otherwise after
                bestIndex = location.y < headerY ? i : i + 1
            }
        }
        
        // Also check "after the last block"
        if let lastBlock = siblings.last,
           let lastY = headerPositions[lastBlock.id] {
            if location.y > lastY + 20 {
                bestIndex = siblings.count
            }
        }
        
        return DropTarget(parentBlockID: parentID, insertionIndex: bestIndex)
    }
    
    /// Y position for the drop indicator line
    private func computeIndicatorY(for target: DropTarget, in template: WorkoutTemplate) -> CGFloat {
        let siblings: [IntervalBlock]
        
        if let pid = target.parentBlockID,
           let parent = findBlock(id: pid, in: template) {
            siblings = parent.childBlocks.sorted { $0.sortOrder < $1.sortOrder }
        } else {
            siblings = template.blocks.sorted { $0.sortOrder < $1.sortOrder }
        }
        
        if target.insertionIndex == 0 {
            // Before the first block
            if let first = siblings.first, let y = headerPositions[first.id] {
                return y - 2
            }
        } else if target.insertionIndex >= siblings.count {
            // After the last block
            if let last = siblings.last, let y = headerPositions[last.id] {
                return y + 40
            }
        } else {
            // Between two blocks
            let above = siblings[target.insertionIndex - 1]
            let below = siblings[target.insertionIndex]
            if let yA = headerPositions[above.id], let yB = headerPositions[below.id] {
                return (yA + yB) / 2 + 15
            }
        }
        return 0
    }
    
    /// Commit the drag: reorder blocks, then cleanup
    private func commitDrag(in template: WorkoutTemplate) {
        guard let drag = activeDrag, let target = dropTarget else {
            cancelDrag()
            return
        }
        
        guard let ctx = findBlockContext(id: drag.blockID, in: template) else {
            cancelDrag()
            return
        }
        
        // Skip no-op: same parent, same position or adjacent
        let isNoOp = target.parentBlockID == ctx.parentBlockID &&
            (target.insertionIndex == ctx.indexInSiblings ||
             target.insertionIndex == ctx.indexInSiblings + 1)
        
        if !isNoOp {
            // Get siblings list
            var siblings: [IntervalBlock]
            if let pid = ctx.parentBlockID,
               let parent = findBlock(id: pid, in: template) {
                siblings = parent.childBlocks.sorted { $0.sortOrder < $1.sortOrder }
            } else {
                siblings = template.blocks.sorted { $0.sortOrder < $1.sortOrder }
            }
            
            // Move the block
            guard ctx.indexInSiblings < siblings.count else {
                cancelDrag()
                return
            }
            
            siblings.remove(at: ctx.indexInSiblings)
            let adjustedIndex = target.insertionIndex > ctx.indexInSiblings
                ? target.insertionIndex - 1
                : target.insertionIndex
            let clampedIndex = min(adjustedIndex, siblings.count)
            siblings.insert(ctx.block, at: clampedIndex)
            
            // Update sortOrders
            for (i, block) in siblings.enumerated() {
                block.sortOrder = i
            }
            
            markChanged()
            
            #if os(iOS)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            #endif
        } else {
            #if os(iOS)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            #endif
        }
        
        cleanupDrag()
    }
    
    /// Cancel drag without reordering
    private func cancelDrag() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
        cleanupDrag()
    }
    
    /// Clear all drag state
    private func cleanupDrag() {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            activeDrag = nil
            dropTarget = nil
            dragLocation = .zero
            autoScrollTimer?.invalidate()
            autoScrollTimer = nil
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            hiddenBlockIDs.removeAll()
        }
    }
    
    /// Auto-scroll when finger is near list edges
    private func updateAutoScroll(at location: CGPoint, scrollProxy: ScrollViewProxy) {
        let edgeZone: CGFloat = 60
        let topEdge = listGlobalFrame.minY + edgeZone
        let bottomEdge = listGlobalFrame.maxY - edgeZone
        
        if location.y < topEdge || location.y > bottomEdge {
            // Start auto-scroll if not already running
            guard autoScrollTimer == nil else { return }
            autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                guard activeDrag != nil else { return }
                // Find the block closest to top/bottom edge and scroll toward it
                let activeTemplate = editableTemplate ?? template
                let allBlockList = allBlocks(from: activeTemplate.blocks)
                
                if dragLocation.y < topEdge {
                    // Scroll up — find block above current position
                    if let target = allBlockList.last(where: {
                        (headerPositions[$0.block.id] ?? .infinity) < dragLocation.y
                    }) {
                        scrollProxy.scrollTo(target.block.id, anchor: .top)
                    }
                } else if dragLocation.y > bottomEdge {
                    // Scroll down — find block below current position
                    if let target = allBlockList.first(where: {
                        (headerPositions[$0.block.id] ?? -.infinity) > dragLocation.y
                    }) {
                        scrollProxy.scrollTo(target.block.id, anchor: .bottom)
                    }
                }
            }
        } else {
            // Outside edge zones, stop auto-scroll
            autoScrollTimer?.invalidate()
            autoScrollTimer = nil
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
    var onDragStarted: (UUID) -> Void = { _ in }
    var onDragMoved: (CGPoint) -> Void = { _ in }
    var onDragEnded: () -> Void = {}
    @Binding var hiddenBlockIDs: Set<UUID>
    var activeDragBlockID: UUID? = nil
    @State private var isExpanded = true
    @State private var editingBlockName = false
    
    private var blockColor: Color {
        depthColor(depth)
    }
    
    /// Whether this block should be collapsed due to an active drag
    private var isDragCollapsed: Bool {
        hiddenBlockIDs.contains(block.id)
    }
    
    var body: some View {
        DisclosureGroup(isExpanded: Binding(
            get: { isDragCollapsed ? false : isExpanded },
            set: { newValue in
                if !isDragCollapsed {
                    isExpanded = newValue
                }
            }
        )) {
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
                        onContentBottom: onContentBottom,
                        onDragStarted: onDragStarted,
                        onDragMoved: onDragMoved,
                        onDragEnded: onDragEnded,
                        hiddenBlockIDs: $hiddenBlockIDs,
                        activeDragBlockID: activeDragBlockID
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
                    
                    // Custom drag handle with long-press → drag gesture
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .gesture(
                            LongPressGesture(minimumDuration: 0.1)
                                .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
                                .onChanged { value in
                                    switch value {
                                    case .second(true, let drag):
                                        // Long press succeeded + drag started
                                        onDragStarted(block.id)
                                        if let drag {
                                            onDragMoved(drag.location)
                                        }
                                    default:
                                        break
                                    }
                                }
                                .onEnded { _ in
                                    onDragEnded()
                                }
                        )
                }
            }
            .onGeometryChange(for: CGFloat.self) { geo in
                geo.frame(in: .global).minY
            } action: { minY in
                onHeaderPosition(block.id, minY)
            }
        }
        .padding(.leading, CGFloat(depth) * 4)
        .opacity(activeDragBlockID == block.id ? 0 : 1)
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
