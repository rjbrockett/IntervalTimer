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

/// Identifies the item being dragged and its context
private struct DragItem {
    enum Kind {
        case block
        case interval
    }
    let kind: Kind
    let itemID: UUID
    let itemName: String
    let itemColor: Color
    let repeatCount: Int
    let depth: Int
    /// For top-level blocks: nil. For children: the parent block's ID.
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

/// Non-reactive storage for geometry positions to avoid layout feedback loops in LazyVStack.
/// Updates to @State from onGeometryChange cause re-renders → more geometry changes → crash.
private class PositionStorage {
    var headerPositions: [UUID: CGFloat] = [:]
    var contentBottoms: [UUID: CGFloat] = [:]
    var autoScrollSpeed: CGFloat = 0
    var isDragging: Bool = false
}

#if os(iOS)
private class DisplayLinkTarget: NSObject {
    let action: () -> Void
    init(action: @escaping () -> Void) { self.action = action }
    @objc func tick() { action() }
}
#endif



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
    #if os(iOS)
    @State private var displayLink: CADisplayLink?
    #endif
    @State private var dragStartTime: Date?
    @State private var listGlobalFrame: CGRect = .zero
    /// Current pinned headers, updated by scroll geometry change
    @State private var currentPinnedHeaders: [BlockHeaderInfo] = []

    #if os(iOS)

    #endif
    private let positionStorage = PositionStorage()
    /// Convenience accessors — non-reactive to avoid layout feedback loops in LazyVStack
    private var headerPositions: [UUID: CGFloat] {
        get { positionStorage.headerPositions }
        nonmutating set { positionStorage.headerPositions = newValue }
    }
    private var contentBottoms: [UUID: CGFloat] {
        get { positionStorage.contentBottoms }
        nonmutating set { positionStorage.contentBottoms = newValue }
    }
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
            sectionCard {
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
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        #if os(iOS)
        .background(Color(.secondarySystemGroupedBackground))
        #else
        .background(Color(.controlBackgroundColor))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func editorContent(for template: WorkoutTemplate) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Update banner for downloaded routines
                    updateBannerSection(for: template)
                    
                    // Template name section
                    sectionCard {
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
                    sectionCard {
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
                    
                    // Blocks section
                    sectionCard {
                        ForEach(template.sortedBlocks) { block in
                            if block.sortOrder > 0 {
                                Divider()
                            }
                            BlockEditorRow(
                                block: block,
                                template: template,
                                depth: 0,
                                isEditing: isEditing,
                                onChanged: markChanged,
                                onHeaderPosition: { id, minY in
                                    if headerPositions[id] != minY {
                                        headerPositions[id] = minY
                                    }
                                },
                                onContentBottom: { id, maxY in
                                    if contentBottoms[id] != maxY {
                                        contentBottoms[id] = maxY
                                    }
                                },
                                onDragStarted: { draggedID in
                                    guard activeDrag == nil else { return }
                                    
                                    // Capture item's viewport-relative Y before collapse shifts layout
                                    let anchorY: CGFloat
                                    if let itemY = headerPositions[draggedID] {
                                        let relativeY = (itemY - listGlobalFrame.minY) / listGlobalFrame.height
                                        anchorY = min(max(relativeY - 0.015, 0), 1)
                                    } else {
                                        anchorY = 0.5
                                    }
                                    
                                    startDrag(itemID: draggedID, in: template)
                                    
                                    // After collapse, scroll to pin item at its original screen position
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        var transaction = Transaction()
                                        transaction.animation = nil
                                        withTransaction(transaction) {
                                            scrollProxy.scrollTo(draggedID, anchor: UnitPoint(x: 0.5, y: anchorY))
                                        }
                                    }
                                },
                                onDragMoved: { location in
                                    guard activeDrag != nil else { return }
                                    dragLocation = location
                                    dropTarget = computeDropTarget(at: location)
                                    updateAutoScroll(at: location, scrollProxy: scrollProxy)
                                },
                                onDragEnded: {
                                    commitDrag(in: template, scrollProxy: scrollProxy)
                                },
                                onScrollTo: { targetID in
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation {
                                            scrollProxy.scrollTo(targetID)
                                        }
                                    }
                                },
                                hiddenBlockIDs: $hiddenBlockIDs,
                                activeDragItemID: activeDrag?.itemID
                            )
                        }
                    }
                    
                    // Add Block button (edit mode only)
                    if isEditing {
                        sectionCard {
                            Button(action: {
                                let newBlock = IntervalBlock(
                                    name: "Block \(template.blocks.count + 1)",
                                    repeatCount: 1,
                                    sortOrder: template.blocks.count,
                                    intervals: []
                                )
                                template.blocks.append(newBlock)
                                markChanged()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation {
                                        scrollProxy.scrollTo("addBlockButton", anchor: .bottom)
                                    }
                                }
                            }) {
                                Label("Add Block", systemImage: "plus.circle.fill")
                            }
                        }
                        .id("addBlockButton")
                        
                        // Delete routine button
                        sectionCard {
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
            }
            .scrollDismissesKeyboard(.immediately)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { _, _ in
                let newPinned = computePinnedHeaders()
                if newPinned != currentPinnedHeaders {
                    currentPinnedHeaders = newPinned
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
        #if os(iOS)
        .background(Color(.systemGroupedBackground))
        #else
        .background(Color(.windowBackgroundColor))
        #endif
        .navigationTitle(isEditing ? "Edit Routine" : template.name)
        .navigationBarBackButtonHidden(isEditing)
        .environment(\.allBlocksCollapsed, allCollapsed)
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
                if activeDrag == nil {
                    stickyHeaderOverlay
                }
            }
        }
        .overlay {
            // Floating drag preview anchored to finger
            if let drag = activeDrag, dragLocation != .zero {
                DragPreviewView(
                    name: drag.itemName,
                    color: drag.itemColor,
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
        let pinned = currentPinnedHeaders
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
                    .padding(.leading, CGFloat(info.depth) * 16 + 32)
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
    
    /// Computes which block headers should be pinned at the top
    private func computePinnedHeaders() -> [BlockHeaderInfo] {
        let pinThreshold = listMetrics.top + stickyOverlayHeight
        var pinned: [BlockHeaderInfo] = []
        
        let activeTemplate = editableTemplate ?? template
        
        for (block, depth) in allBlocks(from: activeTemplate.blocks) {
            // Skip blocks that are collapsed during drag
            guard !hiddenBlockIDs.contains(block.id) else { continue }
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
    
    /// Unified drag start: detects whether the item is a block or interval
    private func startDrag(itemID: UUID, in template: WorkoutTemplate) {
        guard activeDrag == nil else { return }
        
        // Check if it's a block
        if findBlockContext(id: itemID, in: template) != nil {
            startBlockDrag(blockID: itemID, in: template)
            return
        }
        
        // Check if it's an interval — find its parent block
        for (block, depth) in allBlocks(from: template.blocks) {
            if let interval = block.intervals.first(where: { $0.id == itemID }) {
                startChildDrag(
                    childID: interval.id,
                    childName: interval.name,
                    kind: .interval,
                    parentBlock: block,
                    depth: depth
                )
                return
            }
        }
    }
    
    /// Begin a custom drag for a top-level or nested block
    private func startBlockDrag(blockID: UUID, in template: WorkoutTemplate) {
        guard activeDrag == nil else { return }
        guard let ctx = findBlockContext(id: blockID, in: template) else { return }
        
        dragStartTime = Date()
        positionStorage.isDragging = true
        
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
        
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            activeDrag = DragItem(
                kind: .block,
                itemID: blockID,
                itemName: ctx.block.name ?? "Unnamed Block",
                itemColor: depthColor(ctx.depth),
                repeatCount: ctx.block.repeatCount,
                depth: ctx.depth,
                parentBlockID: ctx.parentBlockID
            )
            if let headerY = headerPositions[blockID] {
                dragLocation = CGPoint(x: listGlobalFrame.midX, y: headerY + 20)
            }
        }
        
        // Collapse all sibling blocks (including the dragged one) — no animation
        // to prevent the dragged item from visually shifting position
        var idsToHide = Set<UUID>()
        for siblingID in ctx.siblingIDs {
            idsToHide.insert(siblingID)
            if let block = findBlock(id: siblingID, in: template) {
                collectAllDescendantIDs(of: block, into: &idsToHide)
            }
        }
        hiddenBlockIDs = idsToHide
    }
    
    /// Begin a custom drag for a child item (interval or sub-block) within a parent block
    private func startChildDrag(childID: UUID, childName: String, kind: DragItem.Kind, parentBlock: IntervalBlock, depth: Int) {
        guard activeDrag == nil else { return }
        
        dragStartTime = Date()
        positionStorage.isDragging = true
        
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
        
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            activeDrag = DragItem(
                kind: kind,
                itemID: childID,
                itemName: childName,
                itemColor: depthColor(depth),
                repeatCount: kind == .block ? (findBlock(id: childID, in: editableTemplate ?? template)?.repeatCount ?? 1) : 0,
                depth: depth,
                parentBlockID: parentBlock.id
            )
            if let headerY = headerPositions[childID] {
                dragLocation = CGPoint(x: listGlobalFrame.midX, y: headerY + 20)
            }
        }
        
        // Collapse child sub-blocks within the parent (not the parent itself)
        // No animation to prevent the dragged item from visually shifting position
        var idsToHide = Set<UUID>()
        for child in parentBlock.childBlocks {
            idsToHide.insert(child.id)
            collectAllDescendantIDs(of: child, into: &idsToHide)
        }
        hiddenBlockIDs = idsToHide
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
    
    /// Get the list of sibling IDs for the current drag context
    private func siblingIDs(for drag: DragItem, in template: WorkoutTemplate) -> [UUID] {
        if let pid = drag.parentBlockID,
           let parent = findBlock(id: pid, in: template) {
            if drag.kind == .block && drag.parentBlockID == nil {
                return template.blocks.sorted { $0.sortOrder < $1.sortOrder }.map(\.id)
            }
            // Children within a parent block (intervals + sub-blocks)
            return parent.sortedChildren.map(\.id)
        } else {
            // Top-level blocks
            return template.blocks.sorted { $0.sortOrder < $1.sortOrder }.map(\.id)
        }
    }
    
    /// Compute which gap the user is hovering over
    private func computeDropTarget(at location: CGPoint) -> DropTarget? {
        guard let drag = activeDrag else { return nil }
        let activeTemplate = editableTemplate ?? template
        let ids = siblingIDs(for: drag, in: activeTemplate)
        
        var bestIndex = 0
        var bestDistance: CGFloat = .infinity
        
        for (i, id) in ids.enumerated() {
            guard let headerY = headerPositions[id] else { continue }
            let distance = abs(location.y - headerY)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = location.y < headerY ? i : i + 1
            }
        }
        
        if let lastID = ids.last,
           let lastY = headerPositions[lastID] {
            if location.y > lastY + 20 {
                bestIndex = ids.count
            }
        }
        
        return DropTarget(parentBlockID: drag.parentBlockID, insertionIndex: bestIndex)
    }
    
    /// Y position for the drop indicator line
    private func computeIndicatorY(for target: DropTarget, in template: WorkoutTemplate) -> CGFloat {
        guard let drag = activeDrag else { return 0 }
        let ids = siblingIDs(for: drag, in: template)
        
        if target.insertionIndex == 0 {
            if let first = ids.first, let y = headerPositions[first] {
                return y - 2
            }
        } else if target.insertionIndex >= ids.count {
            if let last = ids.last, let y = headerPositions[last] {
                return y + 40
            }
        } else {
            let aboveID = ids[target.insertionIndex - 1]
            let belowID = ids[target.insertionIndex]
            if let yA = headerPositions[aboveID], let yB = headerPositions[belowID] {
                return (yA + yB) / 2 + 15
            }
        }
        return 0
    }
    
    /// Commit the drag: reorder items, then cleanup
    private func commitDrag(in template: WorkoutTemplate, scrollProxy: ScrollViewProxy) {
        guard let drag = activeDrag, let target = dropTarget else {
            cancelDrag(scrollProxy: scrollProxy)
            return
        }
        
        if let pid = drag.parentBlockID,
           let parentBlock = findBlock(id: pid, in: template) {
            // Dragging a child (interval or sub-block) within a parent block
            var children = parentBlock.sortedChildren
            guard let currentIndex = children.firstIndex(where: { $0.id == drag.itemID }) else {
                cancelDrag(scrollProxy: scrollProxy)
                return
            }
            
            let isNoOp = target.insertionIndex == currentIndex || target.insertionIndex == currentIndex + 1
            
            if !isNoOp {
                let item = children.remove(at: currentIndex)
                let adjusted = target.insertionIndex > currentIndex
                    ? target.insertionIndex - 1
                    : target.insertionIndex
                let clamped = min(adjusted, children.count)
                children.insert(item, at: clamped)
                
                for (i, child) in children.enumerated() {
                    switch child {
                    case .interval(let interval): interval.sortOrder = i
                    case .childBlock(let block): block.sortOrder = i
                    }
                }
                
                markChanged()
                #if os(iOS)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
            } else {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
            }
        } else {
            // Dragging a top-level block
            guard let ctx = findBlockContext(id: drag.itemID, in: template) else {
                cancelDrag(scrollProxy: scrollProxy)
                return
            }
            
            let isNoOp = target.insertionIndex == ctx.indexInSiblings ||
                target.insertionIndex == ctx.indexInSiblings + 1
            
            if !isNoOp {
                var siblings = template.blocks.sorted { $0.sortOrder < $1.sortOrder }
                guard ctx.indexInSiblings < siblings.count else {
                    cancelDrag(scrollProxy: scrollProxy)
                    return
                }
                
                siblings.remove(at: ctx.indexInSiblings)
                let adjusted = target.insertionIndex > ctx.indexInSiblings
                    ? target.insertionIndex - 1
                    : target.insertionIndex
                let clamped = min(adjusted, siblings.count)
                siblings.insert(ctx.block, at: clamped)
                
                for (i, block) in siblings.enumerated() {
                    block.sortOrder = i
                }
                
                markChanged()
                #if os(iOS)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
            } else {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
            }
        }
        
        cleanupDrag(scrollProxy: scrollProxy)
    }
    
    /// Cancel drag without reordering
    private func cancelDrag(scrollProxy: ScrollViewProxy) {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
        cleanupDrag(scrollProxy: scrollProxy)
    }
    
    /// Clear drag state without scroll anchoring
    private func cleanupDrag() {
        cleanupDrag(scrollProxy: nil)
    }
    
    /// Clear all drag state, optionally anchoring scroll position
    private func cleanupDrag(scrollProxy: ScrollViewProxy?) {
        let draggedID = activeDrag?.itemID
        
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            activeDrag = nil
            dropTarget = nil
            dragLocation = .zero
            dragStartTime = nil
            positionStorage.isDragging = false
            stopAutoScroll()
        }
        
        // Wait a frame for layout to settle at the new position, then read anchor and expand
        if let draggedID, let scrollProxy {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                // Read the item's NEW position after reorder layout
                let anchorY: CGFloat
                if let itemY = headerPositions[draggedID] {
                    let relativeY = (itemY - listGlobalFrame.minY) / listGlobalFrame.height
                    anchorY = min(max(relativeY - 0.015, 0), 1)
                } else {
                    anchorY = 0.5
                }
                
                withAnimation(.easeInOut(duration: 0.25)) {
                    hiddenBlockIDs.removeAll()
                }
                
                // After expand animation, scroll to pin item at its post-drop position
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    var t = Transaction()
                    t.animation = nil
                    withTransaction(t) {
                        scrollProxy.scrollTo(draggedID, anchor: UnitPoint(x: 0.5, y: anchorY))
                    }
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                hiddenBlockIDs.removeAll()
            }
        }
    }
    
    /// Builds an ordered list of all block IDs in template order (depth-first)
    private func orderedBlockIDs(in template: WorkoutTemplate) -> [UUID] {
        var ids: [UUID] = []
        for (block, _) in allBlocks(from: template.blocks) {
            ids.append(block.id)
        }
        return ids
    }
    
    /// Auto-scroll when finger is near list edges
    private func updateAutoScroll(at location: CGPoint, scrollProxy: ScrollViewProxy) {
        // Skip auto-scroll for 0.4s after drag starts (collapse + anchor settle)
        if let startTime = dragStartTime, Date().timeIntervalSince(startTime) < 0.4 {
            stopAutoScroll()
            return
        }
        
        let zoneSize = listGlobalFrame.height * 0.1
        let topEdge = listGlobalFrame.minY + zoneSize
        let bottomEdge = listGlobalFrame.maxY - zoneSize
        
        if location.y < topEdge {
            let depth = (topEdge - location.y) / zoneSize
            positionStorage.autoScrollSpeed = -2.4 * min(depth, 1.0)
            startDisplayLinkIfNeeded()
        } else if location.y > bottomEdge {
            let depth = (location.y - bottomEdge) / zoneSize
            positionStorage.autoScrollSpeed = 2.4 * min(depth, 1.0)
            startDisplayLinkIfNeeded()
        } else {
            stopAutoScroll()
        }
    }
    
    #if os(iOS)
    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }
        let storage = positionStorage
        guard let scrollView = findUIScrollView() else { return }
        let link = CADisplayLink(target: DisplayLinkTarget { [storage, weak scrollView] in
            guard let scrollView, storage.isDragging, storage.autoScrollSpeed != 0 else { return }
            
            var offset = scrollView.contentOffset
            offset.y += storage.autoScrollSpeed
            let maxY = max(scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom, 0)
            let minY = -scrollView.contentInset.top
            offset.y = min(max(offset.y, minY), maxY)
            scrollView.contentOffset = offset
        }, selector: #selector(DisplayLinkTarget.tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }
    
    private func stopAutoScroll() {
        displayLink?.invalidate()
        displayLink = nil
        positionStorage.autoScrollSpeed = 0
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }
    
    private func findUIScrollView() -> UIScrollView? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return nil }
        return findScrollView(in: window)
    }
    
    private func findScrollView(in view: UIView) -> UIScrollView? {
        if let sv = view as? UIScrollView {
            let frame = sv.convert(sv.bounds, to: nil)
            // Match on width and that the scroll view contains our visible area
            if abs(frame.width - listGlobalFrame.width) < 5 && frame.minY <= listGlobalFrame.minY && frame.maxY >= listGlobalFrame.maxY {
                return sv
            }
        }
        for sub in view.subviews {
            if let found = findScrollView(in: sub) { return found }
        }
        return nil
    }
    #else
    private func startDisplayLinkIfNeeded() {
        guard autoScrollTimer == nil else { return }
        let storage = positionStorage
        guard let scrollView = findNSScrollView() else { return }
        // Use a fast timer to approximate display link on macOS
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            guard storage.isDragging, storage.autoScrollSpeed != 0 else { return }
            let clipView = scrollView.contentView
            var point = clipView.bounds.origin
            // SwiftUI's hosting scroll view is flipped, so positive Y = scroll down
            point.y += storage.autoScrollSpeed
            let documentHeight = scrollView.documentView?.frame.height ?? 0
            let maxY = max(documentHeight - clipView.bounds.height, 0)
            point.y = min(max(point.y, 0), maxY)
            clipView.scroll(to: point)
            scrollView.reflectScrolledClipView(clipView)
        }
    }
    
    private func stopAutoScroll() {
        positionStorage.autoScrollSpeed = 0
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }
    
    private func findNSScrollView() -> NSScrollView? {
        guard let window = NSApplication.shared.windows.first else { return nil }
        return findScrollView(in: window.contentView)
    }
    
    private func findScrollView(in view: NSView?) -> NSScrollView? {
        guard let view else { return nil }
        if let sv = view as? NSScrollView {
            let frame = sv.convert(sv.bounds, to: nil)
            if abs(frame.width - listGlobalFrame.width) < 5 && frame.minY <= listGlobalFrame.minY && frame.maxY >= listGlobalFrame.maxY {
                return sv
            }
        }
        for sub in view.subviews {
            if let found = findScrollView(in: sub) { return found }
        }
        return nil
    }
    #endif
    
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
    var onScrollTo: (AnyHashable) -> Void = { _ in }
    @Binding var hiddenBlockIDs: Set<UUID>
    var activeDragItemID: UUID? = nil
    @State private var isExpanded = true
    @State private var editingBlockName = false
    
    private var blockColor: Color {
        depthColor(depth)
    }
    
    /// Tracks what the user set before a drag collapse, so we can restore it
    @State private var expandedBeforeDrag: Bool? = nil
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Group {
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
                
            }
            
            // Intervals and child blocks intermingled by sortOrder
            ForEach(block.sortedChildren) { child in
                Divider()
                switch child {
                case .interval(let interval):
                    IntervalRowView(
                        interval: interval,
                        block: block,
                        template: template,
                        depth: depth,
                        isEditing: isEditing,
                        onChanged: onChanged,
                        onDragStarted: onDragStarted,
                        onDragMoved: onDragMoved,
                        onDragEnded: onDragEnded,
                        onHeaderPosition: onHeaderPosition,
                        activeDragItemID: activeDragItemID
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
                        onScrollTo: onScrollTo,
                        hiddenBlockIDs: $hiddenBlockIDs,
                        activeDragItemID: activeDragItemID
                    )
                    
                }
            }
            
            // Add buttons (edit mode only)
            if isEditing {
                Divider()
                Button(action: addInterval) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(blockColor)
                            .frame(width: 4, height: 16)
                        Label("Add Interval", systemImage: "plus.circle")
                            .font(.subheadline)
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderless)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id("addInterval-\(block.id)")
                
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
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderless)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id("addSubBlock-\(block.id)")
                }
            }
            
            // Sentinel to track the bottom of this block's content
            Rectangle()
                .fill(.clear)
                .frame(height: 1)
                .onGeometryChange(for: CGFloat.self) { geo in
                    geo.frame(in: .global).maxY
                } action: { maxY in
                    onContentBottom(block.id, maxY)
                }
            }
            .padding(.leading, 16)
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
        .padding(.leading, 0)
        .opacity(activeDragItemID == block.id ? 0 : 1)
        .onChange(of: allCollapsed) { _, collapsed in
            isExpanded = !collapsed
        }
        .onChange(of: hiddenBlockIDs) { oldIDs, newIDs in
            let wasHidden = oldIDs.contains(block.id)
            let isNowHidden = newIDs.contains(block.id)
            if !wasHidden && isNowHidden {
                expandedBeforeDrag = isExpanded
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded = false
                }
            } else if wasHidden && !isNowHidden {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded = expandedBeforeDrag ?? true
                }
                expandedBeforeDrag = nil
            }
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
        // Scroll to the add button so it stays visible after the new item appears above it
        onScrollTo("addInterval-\(block.id)")
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
        // Scroll to the add button so it stays visible after the new item appears above it
        onScrollTo("addSubBlock-\(block.id)")
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
    var onDragStarted: (UUID) -> Void = { _ in }
    var onDragMoved: (CGPoint) -> Void = { _ in }
    var onDragEnded: () -> Void = {}
    var onHeaderPosition: (UUID, CGFloat) -> Void = { _, _ in }
    var activeDragItemID: UUID? = nil
    
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
            RoundedRectangle(cornerRadius: 2)
                .fill(rowColor.opacity(0.3))
                .frame(width: 3)
            
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
        .padding(.vertical, 8)
    }
    
    // MARK: - Edit Mode
    
    private var editingBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(rowColor.opacity(0.3))
                    .frame(width: 3)
                
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
                
                // Custom drag handle
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
                                    onDragStarted(interval.id)
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
            .onGeometryChange(for: CGFloat.self) { geo in
                geo.frame(in: .global).minY
            } action: { minY in
                onHeaderPosition(interval.id, minY)
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
        .padding(.vertical, 4)
        .opacity(activeDragItemID == interval.id ? 0 : 1)
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
