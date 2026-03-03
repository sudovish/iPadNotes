import SwiftUI
import PencilKit
import PDFKit
import PhotosUI
import UniformTypeIdentifiers
import UIKit
import VisionKit
import ImageIO

struct ContentView: View {
    @StateObject private var store = NotesStore()
    @State private var navigationPath: [UUID] = []
    @State private var isPresentingNewNotebookSheet = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            NotebookLibraryHomeView(
                store: store,
                onOpenNotebook: { notebookID in
                    store.selectNotebook(notebookID)
                    navigationPath = [notebookID]
                },
                onCreateNotebook: {
                    isPresentingNewNotebookSheet = true
                }
            )
            .navigationDestination(for: UUID.self) { notebookID in
                NotebookPagesWorkspaceView(store: store, notebookID: notebookID)
            }
        }
        .tint(Color.accentInk)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.95, blue: 0.92),
                    Color(red: 0.91, green: 0.94, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
        )
        .sheet(isPresented: $isPresentingNewNotebookSheet) {
            NewNotebookSheet { name, theme, paperStyle in
                let notebookID = store.createNotebook(named: name, theme: theme, paperStyle: paperStyle)
                navigationPath = [notebookID]
            }
        }
    }
}

private struct NotebookLibraryHomeView: View {
    @ObservedObject var store: NotesStore
    let onOpenNotebook: (UUID) -> Void
    let onCreateNotebook: () -> Void

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170, maximum: 210), spacing: 14)], spacing: 14) {
                ForEach(store.notebooks) { notebook in
                    Button {
                        onOpenNotebook(notebook.id)
                    } label: {
                        NotebookLibraryCard(
                            notebook: notebook,
                            pageCount: store.pageCount(in: notebook.id),
                            onDelete: {
                                store.deleteNotebook(notebook.id)
                            },
                            onSetPaperStyle: { style in
                                store.updateNotebookPaperStyle(style, for: notebook.id)
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    onCreateNotebook()
                } label: {
                    AddNotebookCard()
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(Color.clear)
        .navigationTitle("Notebooks")
    }
}

private struct NotebookLibraryCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let notebook: Notebook
    let pageCount: Int
    let onDelete: () -> Void
    let onSetPaperStyle: (NotebookPaperStyle) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NotebookCoverPill(theme: notebook.theme)
                .frame(width: 46, height: 68)

            Text(notebook.displayName)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            HStack(spacing: 10) {
                Label(pageCount == 1 ? "1 page" : "\(pageCount) pages", systemImage: "doc.on.doc")
                    .lineLimit(1)
                Label(notebook.paperStyle.displayName, systemImage: "square.split.2x1")
                    .lineLimit(1)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Color.clear
                .frame(height: 10)

            HStack {
                Text("Open notebook")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentInk)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(height: 208)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(cardStroke, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            Menu {
                Picker("Paper", selection: .init(
                    get: { notebook.paperStyle },
                    set: { onSetPaperStyle($0) }
                )) {
                    ForEach(NotebookPaperStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Notebook", systemImage: "trash")
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17.5, weight: .semibold))
                    .foregroundStyle(gearForeground)
                    .frame(width: 35, height: 35)
                    .background(gearBackground, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(gearStroke, lineWidth: 1)
                    )
            }
            .padding(10)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 5)
    }

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.14, green: 0.14, blue: 0.16)
            : Color.white.opacity(0.82)
    }

    private var cardStroke: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.14)
            : Color.black.opacity(0.06)
    }

    private var gearBackground: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.34)
            : Color.white.opacity(0.92)
    }

    private var gearForeground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.96)
            : Color.black.opacity(0.55)
    }

    private var gearStroke: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.30)
            : Color.black.opacity(0.08)
    }
}

private struct AddNotebookCard: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color.accentInk)

            Text("New Notebook")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)

            Text("Configure name, paper, and cover")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: 208)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [8, 6]))
                .foregroundStyle(Color.accentInk.opacity(0.55))
        )
    }

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.14, green: 0.14, blue: 0.16)
            : Color.white.opacity(0.75)
    }
}

private struct NotebookCoverPill: View {
    let theme: NotebookTheme

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(theme.coverGradient)
            .overlay(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.5))
                    .frame(width: 4)
                    .padding(.vertical, 6)
                    .padding(.leading, 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: theme.accentColor.opacity(0.16), radius: 8, y: 4)
    }
}

private struct NewNotebookSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedTheme: NotebookTheme = .ocean
    @State private var selectedPaperStyle: NotebookPaperStyle = .lined

    let onCreate: (String, NotebookTheme, NotebookPaperStyle) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Notebook Name")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                        TextField("Physics", text: $name)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
                            )
                    }
                    .editorCardStyle()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Paper Template")
                            .font(.system(.headline, design: .rounded).weight(.semibold))

                        Picker("Paper Template", selection: $selectedPaperStyle) {
                            ForEach(NotebookPaperStyle.allCases) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)

                        HStack(spacing: 12) {
                            PaperTemplatePreviewTile(style: .lined, isSelected: selectedPaperStyle == .lined) {
                                selectedPaperStyle = .lined
                            }
                            PaperTemplatePreviewTile(style: .blank, isSelected: selectedPaperStyle == .blank) {
                                selectedPaperStyle = .blank
                            }
                        }
                    }
                    .editorCardStyle()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Cover Color")
                            .font(.system(.headline, design: .rounded).weight(.semibold))

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                            ForEach(NotebookTheme.allCases) { theme in
                                Button {
                                    selectedTheme = theme
                                } label: {
                                    HStack(spacing: 8) {
                                        NotebookCoverPill(theme: theme)
                                            .frame(width: 24, height: 36)
                                        Text(theme.displayName)
                                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Spacer(minLength: 0)
                                        if selectedTheme == theme {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(theme.accentColor)
                                        }
                                    }
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.white.opacity(0.75))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(selectedTheme == theme ? theme.accentColor.opacity(0.35) : Color.black.opacity(0.05), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .editorCardStyle()
                }
                .padding(16)
            }
            .background(Color(red: 0.96, green: 0.95, blue: 0.92).ignoresSafeArea())
            .navigationTitle("New Notebook")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(name, selectedTheme, selectedPaperStyle)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct PaperTemplatePreviewTile: View {
    let style: NotebookPaperStyle
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    PaperTemplateBackground(style: style)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                }
                .frame(height: 90)

                HStack {
                    Text(style.displayName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentInk)
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.accentInk.opacity(0.35) : Color.black.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private enum WorkspaceInteractionMode: String, Equatable {
    case draw
    case text
}

private struct ScopedBoxSelection: Equatable {
    var noteID: UUID
    var boxID: UUID
}

private struct NotebookPagesWorkspaceView: View {
    @ObservedObject var store: NotesStore
    let notebookID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var exportedDocument: NotePDFDocument?
    @State private var isShowingExporter = false
    @State private var exportErrorMessage: String?
    @State private var isShowingPDFImporter = false
    @State private var importErrorMessage: String?
    @State private var isShowingShareSheet = false
    @State private var sharedExportURL: URL?
    @State private var isShowingDiagnosticsShareSheet = false
    @State private var diagnosticsShareURL: URL?
    @State private var interactionMode: WorkspaceInteractionMode = .draw
    @State private var selectedInlineSelection: ScopedBoxSelection?
    @State private var selectedMediaSelection: ScopedBoxSelection?
    @State private var isShowingDocumentScanner = false
    @State private var isShowingTextFormatPopover = false
    @State private var isShowingTextBoxImagePicker = false
    @State private var isShowingPageImagePicker = false
    @State private var isShowingPageOverview = false
    @State private var pendingScannedImages: [UIImage] = []
    @State private var isShowingScanDestinationDialog = false
    @State private var shouldShowScanDestinationAfterScannerDismiss = false
    @State private var zoomCommandNonce = 0
    @State private var canvasZoomFactorTarget: CGFloat?
    @State private var pageLayoutScale: CGFloat = 1
    @State private var sharedPageZoomFactor: CGFloat = 1
    @State private var pinchGestureStartZoomFactor: CGFloat?
    @State private var pinchLastMagnificationValue: CGFloat = 1
    @State private var pinchLastSampleTimestamp: CFTimeInterval = 0
    @State private var pinchZoomVelocity: CGFloat = 0
    @State private var isOuterBelowFitGestureActive = false
    @State private var viewportSize: CGSize = .zero
    @State private var autoScrollTimer: Timer?
    @State private var dragEdgeY: CGFloat? = nil
    @State private var pageViewportStates: [UUID: CanvasViewportState] = [:]
    @State private var currentViewedNoteID: UUID?
    @State private var pageSearchMatches: [PageSearchMatch] = []
    @State private var activePageSearchMatchIndex: Int?
    @State private var ignoreTextModePageTapUntil: CFTimeInterval = 0
    @State private var ignoreDrawModePageTapUntil: CFTimeInterval = 0
    @State private var suppressNextSelectionAutoScroll = false
    @State private var pendingSelectionAutoScroll = false
    @State private var activeMediaDragNoteIDs: Set<UUID> = []
    @FocusState private var textBoxFocusedID: UUID?
    private let lockedMinimumPageLayoutScale: CGFloat = 0.5
    private let nextPagePeekFraction: CGFloat = 0.14
    private let pinchInertiaProjectionDuration: CGFloat = 0.18
    private let zoomBoundaryHysteresis: CGFloat = 0.02

    private var diagnostics: TextBoxDiagnosticsLogger {
        TextBoxDiagnosticsLogger.shared
    }

    private var notebook: Notebook? {
        store.notebook(withID: notebookID)
    }

    private var isTextMode: Bool {
        interactionMode == .text
    }

    private var selectedInlineTextBoxID: UUID? {
        guard let selectedInlineSelection,
              selectedInlineSelection.noteID == store.selectedNoteID else {
            return nil
        }
        return selectedInlineSelection.boxID
    }

    private var selectedMediaBoxID: UUID? {
        guard let selectedMediaSelection,
              selectedMediaSelection.noteID == store.selectedNoteID else {
            return nil
        }
        return selectedMediaSelection.boxID
    }

    private var isMediaDragInFlight: Bool {
        !activeMediaDragNoteIDs.isEmpty
    }

    private var hasSelectedBoxOnActivePage: Bool {
        selectedInlineTextBoxID != nil || selectedMediaBoxID != nil
    }

    private func selectedInlineTextBoxID(for noteID: UUID) -> UUID? {
        guard let selectedInlineSelection,
              selectedInlineSelection.noteID == noteID else {
            return nil
        }
        return selectedInlineSelection.boxID
    }

    private func selectedMediaBoxID(for noteID: UUID) -> UUID? {
        guard let selectedMediaSelection,
              selectedMediaSelection.noteID == noteID else {
            return nil
        }
        return selectedMediaSelection.boxID
    }

    var body: some View {
        Group {
            if let notebook {
                notebookPagesView(notebook)
            } else {
                ContentUnavailableView(
                    "Notebook Missing",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This notebook was deleted.")
                )
            }
        }
        .onAppear {
            store.selectNotebook(notebookID)
        }
        .onChange(of: notebook?.id) { _, newValue in
            if newValue == nil {
                dismiss()
            }
        }
        .fileExporter(
            isPresented: $isShowingExporter,
            document: exportedDocument,
            contentType: .pdf,
            defaultFilename: exportedFilename
        ) { result in
            exportedDocument = nil
            if case .failure(let error) = result {
                exportErrorMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $isShowingPDFImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handlePDFImport(result)
        }
        .sheet(isPresented: $isShowingShareSheet, onDismiss: cleanupSharedExportURL) {
            if let sharedExportURL {
                ShareSheet(items: [sharedExportURL])
            }
        }
        .sheet(isPresented: $isShowingDiagnosticsShareSheet, onDismiss: cleanupDiagnosticsShareURL) {
            if let diagnosticsShareURL {
                ShareSheet(items: [diagnosticsShareURL])
            }
        }
        .sheet(isPresented: $isShowingDocumentScanner, onDismiss: {
            if shouldShowScanDestinationAfterScannerDismiss, !pendingScannedImages.isEmpty {
                shouldShowScanDestinationAfterScannerDismiss = false
                isShowingScanDestinationDialog = true
            }
        }) {
            DocumentScannerSheet(
                onCancel: {
                    isShowingDocumentScanner = false
                    shouldShowScanDestinationAfterScannerDismiss = false
                    pendingScannedImages = []
                },
                onCompletion: { images in
                    handleScannedImages(images)
                    isShowingDocumentScanner = false
                },
                onError: { error in
                    isShowingDocumentScanner = false
                    shouldShowScanDestinationAfterScannerDismiss = false
                    pendingScannedImages = []
                    importErrorMessage = error.localizedDescription
                }
            )
        }
        .alert("Use Scanned Document", isPresented: $isShowingScanDestinationDialog) {
            Button(pendingScannedImages.count > 1 ? "Add as New Pages" : "Add as New Page") {
                importScannedImagesAsPages(pendingScannedImages)
                clearPendingScans()
            }
            Button("Place on Current Page") {
                placeScannedImagesOnCurrentPage(pendingScannedImages)
                clearPendingScans()
            }
            Button("Cancel", role: .cancel) {
                clearPendingScans()
            }
        } message: {
            Text(scanDestinationSummary)
        }
        .alert("Export Failed", isPresented: exportErrorPresented) {
            Button("OK") { exportErrorMessage = nil }
        } message: {
            Text(exportErrorMessage ?? "Unknown error")
        }
        .alert("Import Failed", isPresented: importErrorPresented) {
            Button("OK") { importErrorMessage = nil }
        } message: {
            Text(importErrorMessage ?? "Unknown error")
        }
    }

    private var exportErrorPresented: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { newValue in if !newValue { exportErrorMessage = nil } }
        )
    }

    private var importErrorPresented: Binding<Bool> {
        Binding(
            get: { importErrorMessage != nil },
            set: { newValue in if !newValue { importErrorMessage = nil } }
        )
    }

    private var exportedFilename: String {
        guard let notebook,
              let note = store.selectedNote else {
            return "Page.pdf"
        }
        let notebookPart = sanitizeFilename(notebook.displayName)
        let pagePart = sanitizeFilename(note.displayTitle)
        return "\(notebookPart)-\(pagePart).pdf"
    }

    @ViewBuilder
    private func pageCard(for note: Note, notebook: Notebook, pageWidth: CGFloat) -> some View {
        let notes = store.visibleNotes
        let noteIndex = notes.firstIndex(where: { $0.id == note.id })
        let edgeScrollHandler: ((CGFloat?) -> Void)? = { [self] y in
            startAutoScrollIfNeeded(globalY: y)
        }
        NotebookScrollPageCard(
            store: store,
            notebook: notebook,
            note: note,
            isActive: note.id == store.selectedNoteID,
            isFirstPage: noteIndex == 0,
            isLastPage: noteIndex == notes.indices.last,
            inlineTextBoxes: note.inlineTextBoxes,
            mediaBoxes: note.mediaBoxes,
            selectedInlineTextBoxID: selectedInlineTextBoxID(for: note.id),
            selectedMediaBoxID: selectedMediaBoxID(for: note.id),
            isTextMode: isTextMode && note.id == store.selectedNoteID,
            zoomCommandNonce: zoomCommandNonce,
            canvasZoomFactorTarget: effectiveCanvasZoomTarget,
            sharedZoomFactor: effectiveSharedCanvasZoomFactor,
            pageLayoutScale: pageLayoutScale,
            pageWidth: pageWidth,
            searchQuery: normalizedSearchQuery,
            searchMatches: pageSearchMatches,
            activeSearchMatchID: activeSearchMatch?.id,
            ignorePageTapUntil: ignoreTextModePageTapUntil,
            ignoreDrawModePageTapUntil: ignoreDrawModePageTapUntil,
            onInlineTextBoxTextChange: { [self] id, text in
                store.updateInlineTextBoxText(for: note.id, boxID: id, to: text)
            },
            onInlineTextBoxStyleChange: { [self] id, style in
                store.updateInlineTextBoxStyle(for: note.id, boxID: id, to: style)
            },
            onInlineTextBoxFrameChange: { [self] id, cx, cy, w, h, r in
                store.updateInlineTextBoxFrame(for: note.id, boxID: id, centerX: cx, centerY: cy, width: w, height: h, rotationDegrees: r)
            },
            onMediaBoxFrameChange: { [self] id, cx, cy, w, h, r in
                handleMediaBoxFrameChange(noteID: note.id, boxID: id, cx: cx, cy: cy, w: w, h: h, r: r)
            },
            onBeginEditingInlineTextBox: { [self] id in
                handleBeginEditingInlineTextBox(noteID: note.id, boxID: id)
            },
            onBeginEditingMediaBox: { [self] id in
                handleBeginEditingMediaBox(noteID: note.id, boxID: id)
            },
            onCreateInlineTextBoxAt: { [self] cx, cy in
                handleCreateInlineTextBox(noteID: note.id, cx: cx, cy: cy)
            },
            onDeleteInlineTextBox: { [self] id in
                handleDeleteInlineTextBox(noteID: note.id, boxID: id)
            },
            onDeleteMediaBox: { [self] id in
                handleDeleteMediaBox(noteID: note.id, boxID: id)
            },
            onCrossPageDrop: { [self] boxID, targetNoteID, cx, cy, w, h in
                let targetIndex = notes.firstIndex(where: { $0.id == targetNoteID })
                moveSelectedMediaBox(
                    boxID: boxID,
                    fromNoteID: note.id,
                    toNoteID: targetNoteID,
                    centerX: cx,
                    centerY: cy,
                    width: w,
                    height: h,
                    rotationDegrees: 0,
                    targetIsFirstPage: targetIndex == 0,
                    targetIsLastPage: targetIndex == notes.indices.last
                )
            },
            onRequestIgnorePageTap: { [self] in
                ignoreTextModePageTapUntil = CACurrentMediaTime() + 0.12
            },
            onRequestIgnoreDrawModePageTap: { [self] in
                ignoreDrawModePageTapUntil = CACurrentMediaTime() + 0.06
            },
            onEdgeScroll: edgeScrollHandler,
            isAnyMediaDragActive: isMediaDragInFlight,
            onMediaDragActiveChanged: { active in
                if active {
                    activeMediaDragNoteIDs.insert(note.id)
                } else {
                    activeMediaDragNoteIDs.remove(note.id)
                }
            },
            onExitInlineTextBox: { [self] in
                diagnostics.log("inline.deselect note=\(note.id.uuidString) selectedBefore=\(selectedInlineSelection?.boxID.uuidString ?? "nil") mode=\(interactionMode.rawValue)")
                clearInlineTextSelection(for: note.id)
            },
            onExitMediaBox: { [self] in
                diagnostics.log("media.deselect note=\(note.id.uuidString) selectedBefore=\(selectedMediaSelection?.boxID.uuidString ?? "nil") mode=\(interactionMode.rawValue)")
                interactionMode = .draw
                if let selected = selectedMediaSelection,
                   selected.noteID == note.id {
                    settleSelectedMediaBoxIfNeeded(noteID: selected.noteID, boxID: selected.boxID)
                }
                clearMediaSelection(for: note.id)
            },
            onViewportStateChange: { [self] state in
                pageViewportStates[note.id] = state
            },
            onZoomFactorChange: { [self] factor in
                handlePageZoomFactorChange(noteID: note.id, factor: factor)
            }
        )
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: VisiblePageFramePreferenceKey.self,
                        value: [note.id: proxy.frame(in: .named("notebookScroll"))]
                    )
            }
        )
    }

    private func handleBeginEditingInlineTextBox(noteID: UUID, boxID: UUID) {
        ignoreTextModePageTapUntil = CACurrentMediaTime() + 0.25
        selectInlineTextBox(noteID: noteID, boxID: boxID)
        diagnostics.log("inline.select note=\(noteID.uuidString) box=\(boxID.uuidString) mode=\(interactionMode.rawValue)")
    }

    private func handleBeginEditingMediaBox(noteID: UUID, boxID: UUID) {
        selectMediaBox(noteID: noteID, boxID: boxID)
        textBoxFocusedID = nil
        diagnostics.log("media.select note=\(noteID.uuidString) box=\(boxID.uuidString) mode=\(interactionMode.rawValue)")
    }

    private func handleCreateInlineTextBox(noteID: UUID, cx: Double, cy: Double) -> UUID? {
        guard let newBoxID = store.addInlineTextBox(for: noteID, centerX: cx, centerY: cy, width: 0.07, height: 0.045) else { return nil }
        selectInlineTextBox(noteID: noteID, boxID: newBoxID)
        diagnostics.log("inline.create note=\(noteID.uuidString) box=\(newBoxID.uuidString) center=(\(String(format: "%.4f", cx)),\(String(format: "%.4f", cy)))")
        return newBoxID
    }

    private func handleDeleteInlineTextBox(noteID: UUID, boxID: UUID) {
        store.deleteInlineTextBox(for: noteID, boxID: boxID)
        diagnostics.log("inline.delete note=\(noteID.uuidString) box=\(boxID.uuidString)")
        if selectedInlineSelection?.noteID == noteID, selectedInlineSelection?.boxID == boxID {
            clearInlineTextSelection(for: noteID)
        }
    }

    private func handleDeleteMediaBox(noteID: UUID, boxID: UUID) {
        store.deleteMediaBox(for: noteID, boxID: boxID)
        diagnostics.log("media.delete note=\(noteID.uuidString) box=\(boxID.uuidString)")
        if selectedMediaSelection?.noteID == noteID, selectedMediaSelection?.boxID == boxID {
            clearMediaSelection(for: noteID)
        }
    }

    private func handlePageZoomFactorChange(noteID: UUID, factor: CGFloat) {
        guard !isOuterBelowFitGestureActive else { return }
        guard noteID == store.selectedNoteID else { return }
        if sharedPageZoomFactor < (1 + zoomBoundaryHysteresis) && factor >= 1 { return }
        applyLinkedZoom(factor)
    }

    private func handleMediaBoxFrameChange(noteID: UUID, boxID: UUID, cx: Double, cy: Double, w: Double, h: Double, r: Double) {
        let notes = store.visibleNotes
        guard let idx = notes.firstIndex(where: { $0.id == noteID }) else { return }
        let extents = rotatedHalfExtents(width: w, height: h, rotationDegrees: r)
        let crossPageSlack = 0.035

        if cy + extents.vertical > 1.0 + crossPageSlack,
           idx + 1 < notes.count {
            moveSelectedMediaBox(
                boxID: boxID,
                fromNoteID: noteID,
                toNoteID: notes[idx + 1].id,
                centerX: cx,
                centerY: cy - 1.0,
                width: w,
                height: h,
                rotationDegrees: r,
                targetIsFirstPage: (idx + 1) == 0,
                targetIsLastPage: (idx + 1) == notes.indices.last
            )
        } else if cy - extents.vertical < -crossPageSlack,
                  idx - 1 >= 0 {
            moveSelectedMediaBox(
                boxID: boxID,
                fromNoteID: noteID,
                toNoteID: notes[idx - 1].id,
                centerX: cx,
                centerY: 1.0 + cy,
                width: w,
                height: h,
                rotationDegrees: r,
                targetIsFirstPage: (idx - 1) == 0,
                targetIsLastPage: (idx - 1) == notes.indices.last
            )
        } else {
            let isFirstPage = idx == 0
            let isLastPage = idx == notes.indices.last
            let minY = isFirstPage ? extents.vertical : -Double.infinity
            let maxY = isLastPage ? (1.0 - extents.vertical) : Double.infinity
            let boundedY = min(max(cy, minY), maxY)
            store.updateMediaBoxFrame(
                for: noteID,
                boxID: boxID,
                centerX: cx,
                centerY: boundedY,
                width: w,
                height: h,
                rotationDegrees: r,
                clampTopEdge: isFirstPage,
                clampBottomEdge: isLastPage
            )
        }
    }

    private func moveSelectedMediaBox(
        boxID: UUID,
        fromNoteID: UUID,
        toNoteID: UUID,
        centerX: Double,
        centerY: Double,
        width: Double,
        height: Double,
        rotationDegrees: Double,
        targetIsFirstPage: Bool,
        targetIsLastPage: Bool
    ) {
        suppressNextSelectionAutoScroll = true
        store.moveMediaBox(
            boxID: boxID,
            fromNoteID: fromNoteID,
            toNoteID: toNoteID,
            centerX: centerX,
            centerY: centerY,
            width: width,
            height: height,
            rotationDegrees: rotationDegrees,
            clampTopEdge: targetIsFirstPage,
            clampBottomEdge: targetIsLastPage
        )
        store.selectPage(toNoteID)
        selectMediaBox(noteID: toNoteID, boxID: boxID)
        ignoreDrawModePageTapUntil = CACurrentMediaTime() + 0.12
    }

    private func settleSelectedMediaBoxIfNeeded(noteID: UUID, boxID: UUID) {
        guard let note = store.note(withID: noteID),
              let box = note.mediaBoxes.first(where: { $0.id == boxID }) else { return }

        let extents = rotatedHalfExtents(width: box.width, height: box.height, rotationDegrees: box.rotationDegrees)
        let notes = store.visibleNotes
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }

        if box.centerY + extents.vertical > 1.0, index + 1 < notes.count {
            store.moveMediaBox(
                boxID: boxID,
                fromNoteID: noteID,
                toNoteID: notes[index + 1].id,
                centerX: box.centerX,
                centerY: box.centerY - 1.0,
                width: box.width,
                height: box.height,
                rotationDegrees: box.rotationDegrees,
                clampTopEdge: true,
                clampBottomEdge: true
            )
            return
        }

        if box.centerY - extents.vertical < 0.0, index - 1 >= 0 {
            store.moveMediaBox(
                boxID: boxID,
                fromNoteID: noteID,
                toNoteID: notes[index - 1].id,
                centerX: box.centerX,
                centerY: 1.0 + box.centerY,
                width: box.width,
                height: box.height,
                rotationDegrees: box.rotationDegrees,
                clampTopEdge: true,
                clampBottomEdge: true
            )
            return
        }

        let isFirstPage = index == 0
        let isLastPage = index == notes.indices.last
        store.updateMediaBoxFrame(
            for: noteID,
            boxID: boxID,
            centerX: box.centerX,
            centerY: box.centerY,
            width: box.width,
            height: box.height,
            rotationDegrees: box.rotationDegrees,
            clampTopEdge: isFirstPage || (!isFirstPage && !isLastPage),
            clampBottomEdge: isLastPage || (!isFirstPage && !isLastPage)
        )
    }

    private func rotatedHalfExtents(width: Double, height: Double, rotationDegrees: Double) -> (horizontal: Double, vertical: Double) {
        let radians = rotationDegrees * .pi / 180
        let halfWidth = width / 2
        let halfHeight = height / 2
        let horizontal = abs(cos(radians)) * halfWidth + abs(sin(radians)) * halfHeight
        let vertical = abs(sin(radians)) * halfWidth + abs(cos(radians)) * halfHeight
        return (horizontal, vertical)
    }

    private func updateCurrentViewedPage(using frames: [UUID: CGRect], viewportHeight: CGFloat) {
        guard !frames.isEmpty else { return }

        let viewportMidY = viewportHeight / 2
        let bestMatch = frames.min { lhs, rhs in
            abs(lhs.value.midY - viewportMidY) < abs(rhs.value.midY - viewportMidY)
        }?.key

        if let bestMatch {
            currentViewedNoteID = bestMatch
        }
    }

    private var shouldLockPageScrollForBoxManipulation: Bool {
        guard interactionMode == .draw,
              let activeNoteID = store.selectedNoteID,
              selectedMediaSelection?.noteID == activeNoteID else {
            return false
        }
        return true
    }

    private func notebookPagesView(_ notebook: Notebook) -> some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .center, spacing: 0) {
                        ForEach(store.visibleNotes) { note in
                            pageCard(for: note, notebook: notebook, pageWidth: max(1, geometry.size.width * pageLayoutScale))
                                .id(note.id)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height, alignment: pageLayoutScale < 1 ? .center : .top)
                }
                .scrollDisabled(shouldLockPageScrollForBoxManipulation)
                .coordinateSpace(name: "notebookScroll")
                .onPreferenceChange(VisiblePageFramePreferenceKey.self) { frames in
                    updateCurrentViewedPage(using: frames, viewportHeight: geometry.size.height)
                }
                .background(Color.clear)
                .navigationTitle(notebook.displayName)
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            if hasSelectedBoxOnActivePage {
                                return
                            }
                            let now = CACurrentMediaTime()
                            if pinchGestureStartZoomFactor == nil {
                                pinchGestureStartZoomFactor = sharedPageZoomFactor
                                pinchLastMagnificationValue = value
                                pinchLastSampleTimestamp = now
                                pinchZoomVelocity = 0
                            }
                            let base = pinchGestureStartZoomFactor ?? sharedPageZoomFactor
                            let proposed = base * value
                            let shouldUseOuterBelowFitPath = isOuterBelowFitGestureActive
                                || proposed < (1 + zoomBoundaryHysteresis)
                                || sharedPageZoomFactor < (1 + zoomBoundaryHysteresis)

                            if shouldUseOuterBelowFitPath {
                                isOuterBelowFitGestureActive = true
                                applyLinkedZoom(proposed)
                            }

                            let deltaTime = now - pinchLastSampleTimestamp
                            if deltaTime > 0.008 && deltaTime < 0.12 {
                                let magnificationRate = (value - pinchLastMagnificationValue) / CGFloat(deltaTime)
                                let instantaneousVelocity = base * magnificationRate
                                pinchZoomVelocity = (pinchZoomVelocity * 0.7) + (instantaneousVelocity * 0.3)
                            }
                            pinchLastMagnificationValue = value
                            pinchLastSampleTimestamp = now
                        }
                        .onEnded { _ in
                            if hasSelectedBoxOnActivePage {
                                pinchGestureStartZoomFactor = nil
                                pinchLastMagnificationValue = 1
                                pinchLastSampleTimestamp = 0
                                pinchZoomVelocity = 0
                                isOuterBelowFitGestureActive = false
                                return
                            }
                            let gestureStartedZoom = pinchGestureStartZoomFactor ?? sharedPageZoomFactor
                            let endingVelocity = pinchZoomVelocity
                            let wasOuterBelowFitGestureActive = isOuterBelowFitGestureActive
                            pinchGestureStartZoomFactor = nil
                            pinchLastMagnificationValue = 1
                            pinchLastSampleTimestamp = 0
                            pinchZoomVelocity = 0
                            isOuterBelowFitGestureActive = false

                            guard wasOuterBelowFitGestureActive || gestureStartedZoom < 1 || sharedPageZoomFactor < 1 else { return }
                            guard abs(endingVelocity) > 0.03 else { return }

                            let cappedVelocity = min(max(endingVelocity, -1.4), 1.4)
                            let projectedDelta = cappedVelocity * pinchInertiaProjectionDuration
                            let limitedDelta = min(max(projectedDelta, -0.22), 0.22)
                            guard abs(limitedDelta) > 0.01 else { return }

                            let projected = sharedPageZoomFactor + limitedDelta
                            withAnimation(.easeOut(duration: 0.2)) {
                                applyLinkedZoom(projected)
                            }
                        },
                    including: hasSelectedBoxOnActivePage ? .none : .gesture
                )
                .toolbar {
                    workspaceToolbar(for: notebook)
                }
                .onChange(of: store.selectedNoteID) { _, selectedID in
                    guard let selectedID else { return }
                    if isMediaDragInFlight {
                        return
                    }
                    diagnostics.log("page.select note=\(selectedID.uuidString)")
                    if suppressNextSelectionAutoScroll {
                        suppressNextSelectionAutoScroll = false
                        pendingSelectionAutoScroll = false
                    } else if pendingSelectionAutoScroll {
                        pendingSelectionAutoScroll = false
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(selectedID, anchor: .top)
                        }
                    }
                    if selectedInlineSelection?.noteID != selectedID {
                        clearInlineTextSelection()
                    }
                    if selectedMediaSelection?.noteID != selectedID {
                        clearMediaSelection()
                        ignoreDrawModePageTapUntil = 0
                    }
                }
                .onChange(of: interactionMode) { _, mode in
                    diagnostics.log(
                        "mode.state mode=\(mode.rawValue) inline=\(selectedInlineSelection?.boxID.uuidString ?? "nil") media=\(selectedMediaSelection?.boxID.uuidString ?? "nil")"
                    )
                    switch mode {
                    case .draw:
                        clearInlineTextSelection()
                        isShowingTextFormatPopover = false
                    case .text:
                        clearMediaSelection()
                    }
                }
                .onAppear {
                    viewportSize = geometry.size
                    store.selectNotebook(notebook.id)
                    store.searchText = ""
                    clearInlineTextSelection()
                    clearMediaSelection()
                    interactionMode = .draw
                    textBoxFocusedID = nil
                    refreshPageSearchMatches(autoSelectFirst: true)
                    currentViewedNoteID = store.selectedNoteID ?? store.visibleNotes.first?.id
                    diagnostics.log("workspace.onAppear notebook=\(notebook.id.uuidString) selectedNote=\(store.selectedNoteID?.uuidString ?? "nil")")
                }
                .onChange(of: geometry.size) { _, newSize in
                    viewportSize = newSize
                }
                .onChange(of: store.searchText) { _, _ in
                    refreshPageSearchMatches(autoSelectFirst: true)
                }
                .onChange(of: store.visibleNotes) { _, _ in
                    refreshPageSearchMatches(autoSelectFirst: false)
                }
                .sheet(isPresented: $isShowingTextBoxImagePicker) {
                    PhotoLibraryPickerSheet(
                        onCancel: {
                            isShowingTextBoxImagePicker = false
                        },
                        onCompletion: { images in
                            isShowingTextBoxImagePicker = false
                            guard !images.isEmpty else { return }
                            insertPickedImagesOnCurrentPage(images)
                        }
                    )
                }
                .sheet(isPresented: $isShowingPageImagePicker) {
                    PhotoLibraryPickerSheet(
                        onCancel: {
                            isShowingPageImagePicker = false
                        },
                        onCompletion: { images in
                            isShowingPageImagePicker = false
                            guard !images.isEmpty else { return }
                            addPickedImagesAsPages(images)
                        }
                    )
                }
                .sheet(isPresented: $isShowingPageOverview) {
                    PageOverviewSheet(
                        store: store,
                        notebook: notebook,
                        currentViewedNoteID: currentViewedNoteID ?? store.selectedNoteID,
                        onSelectPage: { noteID in
                            pendingSelectionAutoScroll = true
                            store.selectPage(noteID)
                        },
                        onAddBlankPage: {
                            addPageFromOverview(style: .blank)
                        },
                        onAddLinedPage: {
                            addPageFromOverview(style: .lined)
                        },
                        onAddImagePage: {
                            isShowingPageOverview = false
                            isShowingPageImagePicker = true
                        },
                        onAddPDFPage: {
                            isShowingPageOverview = false
                            isShowingPDFImporter = true
                        },
                        onDeletePage: { noteID in
                            store.deletePage(id: noteID)
                        },
                        onMovePages: { fromOffsets, toOffset in
                            store.reorderPages(in: notebook.id, fromOffsets: fromOffsets, toOffset: toOffset)
                        }
                    )
                }
            }
        }
    }

    @ToolbarContentBuilder
    private func workspaceToolbar(for notebook: Notebook) -> some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {

            Button {
                enterDrawMode()
            } label: {
                Label("Draw", systemImage: "pencil.tip")
                    .labelStyle(.iconOnly)
                    .symbolVariant(isTextMode ? .none : .fill)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isTextMode ? Color.clear : Color.accentInk.opacity(0.18))
                    )
            }
            .disabled(store.selectedNote == nil)

            Button {
                if isTextMode {
                    if selectedInlineTextBoxID != nil {
                        isShowingTextFormatPopover = true
                    } else {
                        enterDrawMode()
                    }
                } else {
                    enterTextMode()
                }
            } label: {
                Text("Tt")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(isTextMode ? Color.accentInk : Color.primary)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isTextMode ? Color.accentInk.opacity(0.18) : Color.clear)
                    )
            }
            .popover(isPresented: $isShowingTextFormatPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                textFormatPopoverContent
            }
            .disabled(store.selectedNote == nil)

            Button {
                enterDrawMode()
                isShowingTextBoxImagePicker = true
            } label: {
                Label("Insert Image", systemImage: "photo")
            }
            .disabled(store.selectedNote == nil)

            Button {
                enterDrawMode()
                isShowingDocumentScanner = true
            } label: {
                Label("Scan Document", systemImage: "doc.viewfinder")
            }
            .disabled(!DocumentScannerSheet.isSupported)

            Button {
                isShowingPDFImporter = true
            } label: {
                Label("Import PDF as Pages", systemImage: "doc.badge.plus")
            }
            .disabled(store.selectedNotebook == nil)

            Button {
                isShowingPageOverview = true
            } label: {
                Label("Pages Overview", systemImage: "square.grid.2x2")
            }
            .disabled(store.selectedNotebook == nil)

        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Button {
                    store.createPage()
                } label: {
                    Label("New Page", systemImage: "plus")
                }

                Button {
                    store.insertPageBeforeSelected()
                } label: {
                    Label("Insert Page Before Selected", systemImage: "arrow.up.to.line.compact")
                }
                .disabled(store.selectedNote == nil)

                Button {
                    store.insertPageAfterSelected()
                } label: {
                    Label("Insert Page After Selected", systemImage: "arrow.down.to.line.compact")
                }
                .disabled(store.selectedNote == nil)

                Button {
                    store.duplicateSelectedPage()
                } label: {
                    Label("Duplicate Selected Page", systemImage: "plus.square.on.square")
                }
                .disabled(store.selectedNote == nil)

                Button(role: .destructive) {
                    store.deleteSelectedPage()
                } label: {
                    Label("Delete Selected Page", systemImage: "trash")
                }
                .disabled(store.selectedNote == nil)

                Divider()

                Button {
                    shareDiagnosticsLog()
                } label: {
                    Label("Share Text Box Log", systemImage: "doc.text")
                }

                Button {
                    diagnostics.clear()
                    diagnostics.log("session.log.cleared.fromUI")
                } label: {
                    Label("Clear Text Box Log", systemImage: "trash.slash")
                }
            } label: {
                Label("Page Actions", systemImage: "ellipsis.circle")
            }

            Button {
                shareSelectedPage()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .disabled(store.selectedNote == nil || store.selectedNotebook == nil)
        }
    }

    private func exportSelectedPagePDF() {
        guard let notebook,
              let note = store.selectedNote else { return }
        do {
            let data = try NotePDFExporter.makePDF(for: note, in: notebook)
            exportedDocument = NotePDFDocument(data: data)
            isShowingExporter = true
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func shareSelectedPage() {
        guard let notebook,
              let note = store.selectedNote else { return }
        do {
            let data = try NotePDFExporter.makePDF(for: note, in: notebook)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(exportedFilename)
                .appendingPathExtension("pdf")
            try data.write(to: url, options: [.atomic])
            sharedExportURL = url
            isShowingShareSheet = true
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func cleanupSharedExportURL() {
        guard let sharedExportURL else { return }
        try? FileManager.default.removeItem(at: sharedExportURL)
        self.sharedExportURL = nil
    }

    private func shareDiagnosticsLog() {
        guard let snapshotURL = diagnostics.exportSnapshotURL() else {
            importErrorMessage = "No text box diagnostics available yet."
            return
        }
        diagnosticsShareURL = snapshotURL
        isShowingDiagnosticsShareSheet = true
        diagnostics.log("session.log.share snapshot=\(snapshotURL.lastPathComponent)")
    }

    private func cleanupDiagnosticsShareURL() {
        guard let diagnosticsShareURL else { return }
        try? FileManager.default.removeItem(at: diagnosticsShareURL)
        self.diagnosticsShareURL = nil
    }

    private func sendZoomCommand(scale: CGFloat?) {
        guard let scale else {
            applyLinkedZoom(1, isFitCommand: true, broadcastCommand: true)
            return
        }
        applyLinkedZoom(scale, broadcastCommand: true)
    }

    private func applyLinkedZoom(_ factor: CGFloat, isFitCommand: Bool = false, broadcastCommand: Bool = false) {
        let minimumScale = minimumPageLayoutScale(for: viewportSize)
        let snappedToBoundary = abs(factor - 1) < zoomBoundaryHysteresis ? 1 : factor
        let clamped = min(max(snappedToBoundary, minimumScale), 4.0)
        if abs(clamped - sharedPageZoomFactor) < 0.003, !isFitCommand {
            return
        }

        sharedPageZoomFactor = clamped
        if clamped < 1 {
            pageLayoutScale = clamped
            canvasZoomFactorTarget = 1
        } else {
            pageLayoutScale = 1
            canvasZoomFactorTarget = isFitCommand ? nil : clamped
        }

        if broadcastCommand {
            zoomCommandNonce += 1
        }
    }

    private func synchronizePageZoom(_ scale: CGFloat) {
        _ = scale
    }

    private var effectiveSharedCanvasZoomFactor: CGFloat {
        max(1, sharedPageZoomFactor)
    }

    private var effectiveCanvasZoomTarget: CGFloat? {
        guard let canvasZoomFactorTarget else { return nil }
        return max(1, canvasZoomFactorTarget)
    }

    private func minimumPageLayoutScale(for viewport: CGSize) -> CGFloat {
        guard viewport.width > 0, viewport.height > 0 else {
            return lockedMinimumPageLayoutScale
        }

        let a4HeightOverWidth: CGFloat = 1123.0 / 794.0
        let pageHeightAtFit = viewport.width * a4HeightOverWidth
        guard pageHeightAtFit > 0 else {
            return lockedMinimumPageLayoutScale
        }

        let target = viewport.height / (pageHeightAtFit * (1 + nextPagePeekFraction))
        return min(1, max(lockedMinimumPageLayoutScale, target))
    }

    private var normalizedSearchQuery: String {
        store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var activeSearchMatch: PageSearchMatch? {
        guard let activePageSearchMatchIndex,
              pageSearchMatches.indices.contains(activePageSearchMatchIndex) else { return nil }
        return pageSearchMatches[activePageSearchMatchIndex]
    }

    private var pageSearchResultSummary: String {
        guard !normalizedSearchQuery.isEmpty else { return "" }
        guard !pageSearchMatches.isEmpty else { return "0/0" }
        let current = (activePageSearchMatchIndex ?? 0) + 1
        return "\(current)/\(pageSearchMatches.count)"
    }

    private func refreshPageSearchMatches(autoSelectFirst: Bool) {
        let query = normalizedSearchQuery
        guard !query.isEmpty else {
            pageSearchMatches = []
            activePageSearchMatchIndex = nil
            return
        }

        let previousMatchID = activeSearchMatch?.id
        let matches = buildPageSearchMatches(for: query, notes: store.visibleNotes)
        pageSearchMatches = matches

        guard !matches.isEmpty else {
            activePageSearchMatchIndex = nil
            return
        }

        if let previousMatchID,
           let preservedIndex = matches.firstIndex(where: { $0.id == previousMatchID }) {
            activePageSearchMatchIndex = preservedIndex
            if autoSelectFirst {
                selectSearchMatch(at: preservedIndex)
            }
            return
        }

        activePageSearchMatchIndex = 0
        if autoSelectFirst {
            selectSearchMatch(at: 0)
        }
    }

    private func moveToSearchMatch(offset: Int) {
        guard !pageSearchMatches.isEmpty else { return }
        let count = pageSearchMatches.count
        let current = activePageSearchMatchIndex ?? 0
        let next = (current + offset + count) % count
        selectSearchMatch(at: next)
    }

    private func selectSearchMatch(at index: Int) {
        guard pageSearchMatches.indices.contains(index) else { return }
        activePageSearchMatchIndex = index
        let match = pageSearchMatches[index]
        pendingSelectionAutoScroll = true
        store.selectPage(match.noteID)
        textBoxFocusedID = nil
    }

    private func buildPageSearchMatches(for query: String, notes: [Note]) -> [PageSearchMatch] {
        var matches: [PageSearchMatch] = []
        for note in notes {
            for box in note.inlineTextBoxes {
                for range in matchRanges(of: query, in: box.text) {
                    matches.append(
                        PageSearchMatch(
                            noteID: note.id,
                            boxID: box.id,
                            location: range.location,
                            length: range.length
                        )
                    )
                }
            }
        }
        return matches
    }

    private func matchRanges(of query: String, in text: String) -> [NSRange] {
        guard !query.isEmpty, !text.isEmpty else { return [] }

        let source = text as NSString
        guard source.length > 0 else { return [] }

        var ranges: [NSRange] = []
        var searchRange = NSRange(location: 0, length: source.length)
        while searchRange.length > 0 {
            let found = source.range(
                of: query,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: searchRange
            )
            guard found.location != NSNotFound, found.length > 0 else { break }
            ranges.append(found)
            let nextLocation = found.location + found.length
            guard nextLocation < source.length else { break }
            searchRange = NSRange(location: nextLocation, length: source.length - nextLocation)
        }

        return ranges
    }

    private var scanDestinationSummary: String {
        let count = pendingScannedImages.count
        if count == 1 {
            return "Choose where to put this scan."
        }
        return "Choose where to put \(count) scanned pages."
    }

    private func clearPendingScans() {
        pendingScannedImages = []
        isShowingScanDestinationDialog = false
        shouldShowScanDestinationAfterScannerDismiss = false
    }

    private func handleScannedImages(_ images: [UIImage]) {
        let validImages = images.filter { $0.size.width > 0 && $0.size.height > 0 }
        guard !validImages.isEmpty else { return }
        pendingScannedImages = validImages
        if isShowingDocumentScanner {
            shouldShowScanDestinationAfterScannerDismiss = true
        } else {
            isShowingScanDestinationDialog = true
        }
    }

    private func importScannedImagesAsPages(_ images: [UIImage]) {
        let imageData = images.compactMap { encodedImageData(from: $0) }
        guard !imageData.isEmpty else { return }
        store.importPDFPages(imageData, sourceName: "Scan", insertAfter: store.selectedNoteID)
    }

    private func addPageFromOverview(style: NotebookPaperStyle) {
        let anchorID = currentViewedNoteID ?? store.selectedNoteID
        store.createPage(after: anchorID, paperStyleOverride: style)
    }

    private func addPickedImagesAsPages(_ images: [UIImage]) {
        let imageData = images.compactMap { encodedImageData(from: $0) }
        guard !imageData.isEmpty else { return }
        let anchorID = currentViewedNoteID ?? store.selectedNoteID
        for (index, data) in imageData.enumerated() {
            store.createPage(
                after: index == 0 ? anchorID : store.selectedNoteID,
                paperStyleOverride: .blank,
                backgroundImageData: data,
                title: "Image Page \(index + 1)"
            )
        }
    }

    private func placeScannedImagesOnCurrentPage(_ images: [UIImage]) {
        interactionMode = .draw
        clearInlineTextSelection()
        if store.selectedNoteID == nil {
            store.createPage()
        }
        let targetNoteID = currentViewedNoteID ?? store.selectedNoteID ?? store.visibleNotes.first?.id
        guard let selectedNoteID = targetNoteID else {
            importScannedImagesAsPages(images)
            return
        }
        let existingMediaCount = store.note(withID: selectedNoteID)?.mediaBoxes.count ?? 0
        let viewportAnchor = currentViewportCenterNormalized(for: selectedNoteID)
        var lastCreatedBoxID: UUID?
        for (index, image) in images.enumerated() {
            guard let imageData = encodedImageData(from: image) else { continue }
            let boxSize = preferredScanPlacementBoxSize(for: image.size)
            let placementIndex = existingMediaCount + index
            let center = preferredScanPlacementCenter(index: placementIndex, boxSize: boxSize, anchor: viewportAnchor)
            if let boxID = store.addMediaBox(
                for: selectedNoteID,
                imageData: imageData,
                isContainerStyle: true,
                centerX: center.x,
                centerY: center.y,
                width: boxSize.width,
                height: boxSize.height
            ) {
                lastCreatedBoxID = boxID
            }
        }
        if let lastCreatedBoxID {
            ignoreDrawModePageTapUntil = CACurrentMediaTime() + 0.35
            selectMediaBox(noteID: selectedNoteID, boxID: lastCreatedBoxID)
        } else {
            clearMediaSelection(for: selectedNoteID)
        }
    }

    private func encodedImageData(from image: UIImage) -> Data? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }

        let maxDimension: CGFloat = 2200
        let longestSide = max(image.size.width, image.size.height)
        let scale = min(1, maxDimension / max(longestSide, 1))
        let targetSize = CGSize(
            width: max(1, image.size.width * scale),
            height: max(1, image.size.height * scale)
        )

        if scale >= 0.999 {
            return image.jpegData(compressionQuality: 0.88) ?? image.pngData()
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.jpegData(compressionQuality: 0.88) ?? rendered.pngData()
    }

    private func preferredScanPlacementBoxSize(for imageSize: CGSize) -> (width: Double, height: Double) {
        let pageAspect = 794.0 / 1123.0
        let sourceAspect = max(Double(imageSize.width), 1) / max(Double(imageSize.height), 1)

        var width = 0.72
        var height = width * pageAspect / sourceAspect

        if height > 0.78 {
            height = 0.78
            width = min(0.72, height * sourceAspect / pageAspect)
        }

        return (width: max(0.18, width), height: max(0.16, height))
    }

    private func preferredScanPlacementCenter(
        index: Int,
        boxSize: (width: Double, height: Double),
        anchor: (x: Double, y: Double)? = nil
    ) -> (x: Double, y: Double) {
        let halfWidth = boxSize.width / 2
        let halfHeight = boxSize.height / 2

        let anchorX = anchor?.x ?? 0.5
        let anchorY = anchor?.y ?? 0.3
        let proposedX = anchorX + min(Double(index) * 0.015, 0.12)
        let proposedY = anchorY + (Double(index) * 0.11)

        let clampedX = min(max(proposedX, halfWidth), 1 - halfWidth)
        let clampedY = min(max(proposedY, halfHeight), 1 - halfHeight)
        return (x: clampedX, y: clampedY)
    }

    private func currentViewportCenterNormalized(for noteID: UUID) -> (x: Double, y: Double)? {
        guard let viewport = pageViewportStates[noteID] else { return nil }

        let pageWidth = max(1, viewportSize.width * pageLayoutScale)
        let pageHeight = pageWidth * (1123.0 / 794.0)
        guard pageWidth > 0, pageHeight > 0 else { return nil }

        let viewCenter = CGPoint(x: pageWidth / 2, y: pageHeight / 2)
        let zoom = max(viewport.zoomFactor, 1)
        let pageX = (viewCenter.x + viewport.contentOffset.x - viewport.contentOrigin.x) / zoom
        let pageY = (viewCenter.y + viewport.contentOffset.y - viewport.contentOrigin.y) / zoom

        let normalizedX = Double(min(max(pageX / pageWidth, 0), 1))
        let normalizedY = Double(min(max(pageY / pageHeight, 0), 1))
        return (x: normalizedX, y: normalizedY)
    }

    private func enterDrawMode() {
        diagnostics.log("mode.change to=draw inlineBefore=\(selectedInlineSelection?.boxID.uuidString ?? "nil") mediaBefore=\(selectedMediaSelection?.boxID.uuidString ?? "nil")")
        interactionMode = .draw
        clearInlineTextSelection()
        clearMediaSelection()
        textBoxFocusedID = nil
        isShowingTextFormatPopover = false
    }

    private func enterTextMode() {
        diagnostics.log("mode.change to=text inlineBefore=\(selectedInlineSelection?.boxID.uuidString ?? "nil") mediaBefore=\(selectedMediaSelection?.boxID.uuidString ?? "nil")")
        interactionMode = .text
        clearInlineTextSelection()
        clearMediaSelection()
    }

    private func selectInlineTextBox(noteID: UUID, boxID: UUID) {
        interactionMode = .text
        selectedInlineSelection = ScopedBoxSelection(noteID: noteID, boxID: boxID)
        clearMediaSelection()
        store.selectPage(noteID)
    }

    private func selectMediaBox(noteID: UUID, boxID: UUID) {
        interactionMode = .draw
        selectedMediaSelection = ScopedBoxSelection(noteID: noteID, boxID: boxID)
        clearInlineTextSelection()
        store.selectPage(noteID)
    }

    private func clearInlineTextSelection(for noteID: UUID? = nil) {
        if let noteID {
            guard selectedInlineSelection?.noteID == noteID else { return }
        }
        selectedInlineSelection = nil
        textBoxFocusedID = nil
    }

    private func clearMediaSelection(for noteID: UUID? = nil) {
        if let noteID {
            guard selectedMediaSelection?.noteID == noteID else { return }
        }
        selectedMediaSelection = nil
    }

    private func insertPickedImagesOnCurrentPage(_ images: [UIImage]) {
        interactionMode = .draw
        clearInlineTextSelection()
        let targetNoteID = currentViewedNoteID ?? store.selectedNoteID ?? store.visibleNotes.first?.id
        guard let selectedNoteID = targetNoteID else {
            return
        }
        let existingMediaCount = store.note(withID: selectedNoteID)?.mediaBoxes.count ?? 0

        var importedAssets: [(data: Data, size: CGSize)] = []
        importedAssets.reserveCapacity(images.count)
        for image in images {
            guard let imageData = encodedImageData(from: image) else { continue }
            importedAssets.append((data: imageData, size: image.size))
        }

        guard !importedAssets.isEmpty else { return }

        let anchor = currentViewportCenterNormalized(for: selectedNoteID)
        var lastCreatedBoxID: UUID?
        for (index, asset) in importedAssets.enumerated() {
            let boxSize = preferredScanPlacementBoxSize(for: asset.size)
            let placementIndex = existingMediaCount + index
            let center = preferredScanPlacementCenter(
                index: placementIndex,
                boxSize: boxSize,
                anchor: anchor
            )
            if let newID = store.addMediaBox(
                for: selectedNoteID,
                imageData: asset.data,
                isContainerStyle: true,
                centerX: center.x, centerY: center.y,
                width: boxSize.width, height: boxSize.height
            ) {
                lastCreatedBoxID = newID
            }
        }
        if let lastCreatedBoxID {
            ignoreDrawModePageTapUntil = CACurrentMediaTime() + 0.35
            selectMediaBox(noteID: selectedNoteID, boxID: lastCreatedBoxID)
        } else {
            clearMediaSelection(for: selectedNoteID)
        }
    }

    private var textFormatPopoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Text Format")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))

            HStack {
                Text("Font").font(.subheadline)
                Spacer(minLength: 8)
                Menu {
                    ForEach(openSourceFontNames, id: \.self) { fontName in
                        Button(fontName) { textFormatStyleBinding(\.fontName).wrappedValue = fontName }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(textFormatStyleBinding(\.fontName).wrappedValue).lineLimit(1)
                        Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 10).frame(height: 32)
                    .background(Color(uiColor: .secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(uiColor: .separator).opacity(0.6), lineWidth: 1))
                }
            }

            HStack(spacing: 10) {
                Text("Size").font(.subheadline)
                Spacer(minLength: 0)
                Button {
                    textFormatStyleBinding(\.fontSize).wrappedValue =
                        max(8, textFormatStyleBinding(\.fontSize).wrappedValue - 1)
                } label: {
                    Image(systemName: "chevron.left").frame(width: 30, height: 30)
                        .background(Color(uiColor: .secondarySystemBackground),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(uiColor: .separator).opacity(0.6), lineWidth: 1))
                }.buttonStyle(.borderless)

                TextField("22", text: Binding(
                    get: { String(Int(round(textFormatStyleBinding(\.fontSize).wrappedValue))) },
                    set: { raw in
                        let v = raw.filter(\.isNumber)
                        if let d = Double(v) { textFormatStyleBinding(\.fontSize).wrappedValue = min(max(d,8),120) }
                    }
                ))
                .multilineTextAlignment(.center).keyboardType(.numberPad)
                .frame(width: 56, height: 32)
                .background(Color(uiColor: .secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.6), lineWidth: 1))

                Button {
                    textFormatStyleBinding(\.fontSize).wrappedValue =
                        min(120, textFormatStyleBinding(\.fontSize).wrappedValue + 1)
                } label: {
                    Image(systemName: "chevron.right").frame(width: 30, height: 30)
                        .background(Color(uiColor: .secondarySystemBackground),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(uiColor: .separator).opacity(0.6), lineWidth: 1))
                }.buttonStyle(.borderless)
            }

            HStack(spacing: 10) {
                formatToggleButton(title: "B", isOn: textFormatStyleBinding(\.isBold))
                formatToggleButton(title: "I", isOn: textFormatStyleBinding(\.isItalic))
                formatToggleButton(title: "U", isOn: textFormatStyleBinding(\.isUnderlined))
            }
        }
        .padding(12).frame(width: 300)
        .background(Color(uiColor: .systemBackground))
    }

    private func textFormatStyleBinding<T>(_ keyPath: WritableKeyPath<NoteTextStyle, T>) -> Binding<T> {
        Binding(
            get: {
                guard let selectedNoteID = store.selectedNoteID,
                      let note = store.note(withID: selectedNoteID) else {
                    return NoteTextStyle()[keyPath: keyPath]
                }
                if let selectedInlineTextBoxID,
                   let box = note.inlineTextBoxes.first(where: { $0.id == selectedInlineTextBoxID }) {
                    return box.style[keyPath: keyPath]
                }
                return note.typedTextStyle[keyPath: keyPath]
            },
            set: { newValue in
                guard let selectedNoteID = store.selectedNoteID,
                      let note = store.note(withID: selectedNoteID) else { return }
                if let selectedInlineTextBoxID,
                   let box = note.inlineTextBoxes.first(where: { $0.id == selectedInlineTextBoxID }) {
                    var style = box.style
                    style[keyPath: keyPath] = newValue
                    store.updateInlineTextBoxStyle(for: selectedNoteID, boxID: selectedInlineTextBoxID, to: style)
                    return
                }
                var style = note.typedTextStyle
                style[keyPath: keyPath] = newValue
                store.updateTypedTextStyle(for: selectedNoteID, to: style)
            }
        )
    }

    private func formatToggleButton(title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 34, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isOn.wrappedValue ? Color.accentInk.opacity(0.2) : Color(uiColor: .secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isOn.wrappedValue ? Color.accentInk : Color(uiColor: .separator).opacity(0.6), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var openSourceFontNames: [String] {
        [
            "Noto Sans",
            "Noto Serif",
            "Noto Mono",
            "Inter",
            "Source Sans 3",
            "Source Serif 4",
            "IBM Plex Sans",
            "IBM Plex Serif",
            "IBM Plex Mono",
            "Fira Sans",
            "Fira Code",
            "JetBrains Mono",
            "Inconsolata"
        ]
    }

    private func titleBinding(for noteID: UUID) -> Binding<String> {
        Binding(
            get: { store.note(withID: noteID)?.title ?? "" },
            set: { store.updateTitle(for: noteID, to: $0) }
        )
    }

    private func bodyBinding(for noteID: UUID) -> Binding<String> {
        Binding(
            get: { store.note(withID: noteID)?.body ?? "" },
            set: { store.updateBody(for: noteID, to: $0) }
        )
    }

    private func handlePDFImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importErrorMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                try importPDFPages(from: url)
            } catch {
                importErrorMessage = error.localizedDescription
            }
        }
    }

    private func importPDFPages(from url: URL) throws {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let document = PDFDocument(url: url), document.pageCount > 0 else {
            throw NSError(
                domain: "iPadNotes.Import",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not open PDF or it has no pages."]
            )
        }

        var pageImages: [Data] = []
        pageImages.reserveCapacity(document.pageCount)

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            if let imageData = renderPDFPageImage(page) {
                pageImages.append(imageData)
            }
        }

        guard !pageImages.isEmpty else {
            throw NSError(
                domain: "iPadNotes.Import",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "This PDF could not be rendered into writable pages."]
            )
        }

        let sourceName = url.deletingPathExtension().lastPathComponent
        store.importPDFPages(pageImages, sourceName: sourceName, insertAfter: store.selectedNoteID)
    }

    private func renderPDFPageImage(_ page: PDFPage) -> Data? {
        let pdfRect = page.bounds(for: .mediaBox)
        guard pdfRect.width > 0, pdfRect.height > 0 else { return nil }

        let maxDimension: CGFloat = 1800
        let sourceMax = max(pdfRect.width, pdfRect.height)
        let scale = max(1, min(2.0, maxDimension / max(sourceMax, 1)))
        let targetSize = CGSize(width: max(1, pdfRect.width * scale), height: max(1, pdfRect.height * scale))

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: targetSize, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: targetSize))

            ctx.cgContext.saveGState()
            ctx.cgContext.translateBy(x: 0, y: targetSize.height)
            ctx.cgContext.scaleBy(x: targetSize.width / pdfRect.width, y: -targetSize.height / pdfRect.height)
            page.draw(with: .mediaBox, to: ctx.cgContext)
            ctx.cgContext.restoreGState()
        }

        return image.jpegData(compressionQuality: 0.92)
    }

    private func sanitizeFilename(_ raw: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?*\"<>|")
        let cleaned = raw.components(separatedBy: invalid).joined(separator: "-")
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Page" : trimmed
    }

    private func findMainScrollView() -> UIScrollView? {
        func search(_ view: UIView) -> UIScrollView? {
            if let sv = view as? UIScrollView, sv.contentSize.height > sv.bounds.height { return sv }
            for sub in view.subviews { if let f = search(sub) { return f } }
            return nil
        }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first?.windows.first
            .flatMap { search($0) }
    }

    private func startAutoScrollIfNeeded(globalY: CGFloat?) {
        dragEdgeY = globalY
        guard globalY != nil else {
            autoScrollTimer?.invalidate()
            autoScrollTimer = nil
            return
        }
        guard autoScrollTimer == nil else { return }
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            guard let y = dragEdgeY, let sv = findMainScrollView() else { return }
            let screenH = viewportSize.height
            let triggerZone = screenH * 0.22
            var speed: CGFloat = 0
            if y > screenH - triggerZone {
                let t = (y - (screenH - triggerZone)) / triggerZone
                speed = t * t * 20
            } else if y < triggerZone {
                let t = (triggerZone - y) / triggerZone
                speed = -(t * t * 20)
            }
            guard abs(speed) > 0.1 else { return }
            let maxY = max(0, sv.contentSize.height - sv.bounds.height)
            sv.setContentOffset(
                CGPoint(x: sv.contentOffset.x, y: min(max(sv.contentOffset.y + speed, 0), maxY)),
                animated: false
            )
        }
    }
}

private enum PageInkTool: Hashable {
    case pen
    case pencil
    case marker
    case eraser
}

private struct CanvasViewportState: Equatable {
    var zoomFactor: CGFloat = 1
    var contentOffset: CGPoint = .zero
    var contentOrigin: CGPoint = .zero
}


private struct VisiblePageFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct TextSearchHighlight: Hashable {
    var location: Int
    var length: Int
    var isActive: Bool
}

private struct PageSearchMatch: Identifiable, Hashable {
    var noteID: UUID
    var boxID: UUID
    var location: Int
    var length: Int

    var id: String {
        "\(noteID.uuidString)-\(boxID.uuidString)-\(location)-\(length)"
    }
}

private struct NotebookScrollPageCard: View {
    @ObservedObject var store: NotesStore
    let notebook: Notebook
    let note: Note
    let isActive: Bool
    let isFirstPage: Bool
    let isLastPage: Bool
    let inlineTextBoxes: [NoteTextBox]
    let mediaBoxes: [NoteTextBox]
    let selectedInlineTextBoxID: UUID?
    let selectedMediaBoxID: UUID?
    let isTextMode: Bool
    let zoomCommandNonce: Int
    let canvasZoomFactorTarget: CGFloat?
    let sharedZoomFactor: CGFloat
    let pageLayoutScale: CGFloat
    let pageWidth: CGFloat
    let searchQuery: String
    let searchMatches: [PageSearchMatch]
    let activeSearchMatchID: String?
    let ignorePageTapUntil: CFTimeInterval
    let ignoreDrawModePageTapUntil: CFTimeInterval
    let onInlineTextBoxTextChange: (UUID, String) -> Void
    let onInlineTextBoxStyleChange: (UUID, NoteTextStyle) -> Void
    let onInlineTextBoxFrameChange: (UUID, Double, Double, Double, Double, Double) -> Void
    let onMediaBoxFrameChange: (UUID, Double, Double, Double, Double, Double) -> Void
    let onBeginEditingInlineTextBox: (UUID) -> Void
    let onBeginEditingMediaBox: (UUID) -> Void
    let onCreateInlineTextBoxAt: (Double, Double) -> UUID?
    let onDeleteInlineTextBox: (UUID) -> Void
    let onDeleteMediaBox: (UUID) -> Void
    let onCrossPageDrop: (UUID, UUID, Double, Double, Double, Double) -> Void
    let onRequestIgnorePageTap: () -> Void
    let onRequestIgnoreDrawModePageTap: () -> Void
    let onEdgeScroll: ((CGFloat?) -> Void)?
    let isAnyMediaDragActive: Bool
    let onMediaDragActiveChanged: ((Bool) -> Void)?
    let onExitInlineTextBox: () -> Void
    let onExitMediaBox: () -> Void
    let onViewportStateChange: (CanvasViewportState) -> Void
    let onZoomFactorChange: (CGFloat) -> Void
    @State private var canvasViewportState = CanvasViewportState()
    @State private var lockedViewportState: CanvasViewportState?
    @State private var draggingMediaBoxID: UUID?

    // ── FIX: pageSurface is the base view, overlays are in .overlay{}
    // so media boxes can overflow page bounds without being clipped.
    var body: some View {
        pageSurface
            .onChange(of: hasSelectedManipulableBox) { _, selected in
                if selected {
                    lockedViewportState = stabilizedViewportState
                } else {
                    lockedViewportState = nil
                }
            }
            .frame(width: pageWidth, height: pageHeight)
            .frame(maxWidth: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .overlay(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    // Mode-specific page tap catcher — sits behind overlays.
                    // Uses tap only, so drags still pass through to ScrollView.
                    if isTextMode {
                        Color.clear
                            .contentShape(Rectangle())
                            .highPriorityGesture(
                                SpatialTapGesture()
                                    .onEnded { value in handleTextModeTap(at: value.location) }
                            )
                    } else {
                        Color.clear
                            .contentShape(Rectangle())
                            .highPriorityGesture(
                                SpatialTapGesture()
                                    .onEnded { value in handleDrawModeTap(at: value.location) }
                            )
                    }

                    ForEach(orderedMediaBoxes) { box in
                        PageMediaBoxOverlay(
                            box: box,
                            isSelected: box.id == selectedMediaBoxID,
                            isFirstPage: isFirstPage,
                            isLastPage: isLastPage,
                            isTextMode: isTextMode,
                            viewportState: effectiveViewportState,
                            onTapAtLocation: { location in
                                handleDrawModeTap(at: location)
                            },
                            onDelete: {
                                onRequestIgnoreDrawModePageTap()
                                onDeleteMediaBox(box.id)
                            },
                            onRequestIgnorePageTap: onRequestIgnoreDrawModePageTap,
                            onFrameChange: { cx, cy, w, h, r in
                                onMediaBoxFrameChange(box.id, cx, cy, w, h, r)
                            },
                            onDragActiveChanged: { active in
                                if active {
                                    guard draggingMediaBoxID != box.id else { return }
                                    let wasDragging = draggingMediaBoxID != nil
                                    draggingMediaBoxID = box.id
                                    if !wasDragging {
                                        onMediaDragActiveChanged?(true)
                                    }
                                } else {
                                    guard draggingMediaBoxID == box.id else { return }
                                    draggingMediaBoxID = nil
                                    onMediaDragActiveChanged?(false)
                                }
                            },
                            onEdgeScroll: onEdgeScroll
                        )
                    }

                    ForEach(inlineTextBoxes) { box in
                        PageInlineTextOverlay(
                            box: box,
                            isSelected: box.id == selectedInlineTextBoxID,
                            isTextMode: isTextMode,
                            viewportState: effectiveViewportState,
                            pageLayoutScale: pageLayoutScale,
                            searchQuery: searchQuery,
                            searchHighlights: searchHighlights(for: box.id),
                            onBeginEditing: { onBeginEditingInlineTextBox(box.id) },
                            onTextChange: { text in onInlineTextBoxTextChange(box.id, text) },
                            onStyleChange: { style in onInlineTextBoxStyleChange(box.id, style) },
                            onDelete: {
                                onRequestIgnorePageTap()
                                onDeleteInlineTextBox(box.id)
                            },
                            onRequestIgnorePageTap: onRequestIgnorePageTap,
                            onFrameChange: { cx, cy, w, h, r in
                                onInlineTextBoxFrameChange(box.id, cx, cy, w, h, r)
                            }
                        )
                    }
                }
                .frame(width: pageWidth, height: pageHeight)
            }
            // Dragging must always win stacking over any merely-selected page.
            // This prevents the dragged image from slipping under the adjacent page.
            .zIndex(draggingMediaBoxID != nil ? 3000 : ((selectedMediaBoxID != nil || selectedMediaOverflowsPageBounds) ? 1000 : 0))
    }

    private var pageSurface: some View {
        ZoomablePaperCanvasPageRepresentable(
            noteID: note.id,
            paperStyle: note.pagePaperStyleOverride ?? notebook.paperStyle,
            backgroundImageData: note.backgroundImageData,
            drawingData: note.drawingData,
            isActive: isActive,
            isCanvasToolingEnabled: isActive && !isTextMode && !hasSelectedManipulableBox,
            isViewportGesturesEnabled: !hasSelectedManipulableBox,
            zoomCommandNonce: zoomCommandNonce,
            zoomFactorTarget: canvasZoomFactorTarget,
            sharedZoomFactor: sharedZoomFactor,
            onZoomFactorChange: onZoomFactorChange,
            onViewportStateChange: { viewport in
                if hasSelectedManipulableBox {
                    if lockedViewportState == nil {
                        lockedViewportState = stabilizedViewportState
                    }
                    return
                }
                guard viewport != canvasViewportState else { return }
                canvasViewportState = viewport
                onViewportStateChange(viewport)
            },
            onInteraction: {
                guard !isAnyMediaDragActive else { return }
                store.selectPage(note.id)
            },
            onDrawingChange: { data in store.updateDrawing(for: note.id, to: data) }
        )
        .id(note.id)
        .clipped()
    }

    private var pageHeight: CGFloat { pageWidth * (1123.0 / 794.0) }

    private var hasSelectedManipulableBox: Bool {
        guard let selectedMediaBox else { return false }
        return selectedMediaBox.contentType == .image || selectedMediaBox.isContainerStyle
    }

    private var selectedMediaBox: NoteTextBox? {
        guard let selectedMediaBoxID else { return nil }
        return mediaBoxes.first(where: { $0.id == selectedMediaBoxID && ($0.contentType == .image || $0.isContainerStyle) })
    }

    private var selectedMediaOverflowsPageBounds: Bool {
        guard let selectedMediaBox else { return false }
        let radians = selectedMediaBox.rotationDegrees * .pi / 180
        let halfWidth = selectedMediaBox.width / 2
        let halfHeight = selectedMediaBox.height / 2
        let verticalExtent = abs(sin(radians)) * halfWidth + abs(cos(radians)) * halfHeight
        return selectedMediaBox.centerY - verticalExtent < 0 || selectedMediaBox.centerY + verticalExtent > 1
    }

    private var stabilizedViewportState: CanvasViewportState {
        var state = canvasViewportState
        if state.zoomFactor <= 1.001 {
            if abs(state.contentOffset.x) < 0.5 { state.contentOffset.x = 0 }
            if abs(state.contentOffset.y) < 0.5 { state.contentOffset.y = 0 }
            return state
        }
        if abs(state.contentOffset.x) < 0.5 { state.contentOffset.x = 0 }
        if abs(state.contentOffset.y) < 0.5 { state.contentOffset.y = 0 }
        if abs(state.contentOrigin.x) < 0.5 { state.contentOrigin.x = 0 }
        if abs(state.contentOrigin.y) < 0.5 { state.contentOrigin.y = 0 }
        return state
    }

    private var effectiveViewportState: CanvasViewportState {
        lockedViewportState ?? stabilizedViewportState
    }

    private var orderedMediaBoxes: [NoteTextBox] {
        guard let selectedMediaBoxID else { return mediaBoxes }
        let unselected = mediaBoxes.filter { $0.id != selectedMediaBoxID }
        guard let selected = mediaBoxes.first(where: { $0.id == selectedMediaBoxID }) else {
            return mediaBoxes
        }
        return unselected + [selected]
    }

    private func handleDrawModeTap(at location: CGPoint) {
        store.selectPage(note.id)
        guard CACurrentMediaTime() >= ignoreDrawModePageTapUntil else { return }
        TextBoxDiagnosticsLogger.shared.log(
            "draw.tap note=\(note.id.uuidString) point=(\(Int(location.x)),\(Int(location.y))) selectedMedia=\(selectedMediaBoxID?.uuidString ?? "nil")"
        )

        if let selectedID = selectedMediaBoxID,
           let selectedBox = orderedMediaBoxes.first(where: { $0.id == selectedID }) {
            let boxRect = screenRect(for: selectedBox)
            let deleteButtonCenter = CGPoint(x: boxRect.maxX + 10, y: boxRect.minY - 10)
            if hypot(location.x - deleteButtonCenter.x, location.y - deleteButtonCenter.y) < 20 {
                onDeleteMediaBox(selectedID)
                return
            }
        }

        switch drawModeSelectionAction(for: location) {
        case .select(let boxID):
            TextBoxDiagnosticsLogger.shared.log("draw.tap.select note=\(note.id.uuidString) to=\(boxID.uuidString)")
            onBeginEditingMediaBox(boxID)
        case .deselect(let boxID):
            TextBoxDiagnosticsLogger.shared.log("draw.tap.deselect note=\(note.id.uuidString) box=\(boxID.uuidString)")
            onExitMediaBox()
        case .none:
            break
        }
    }

    private enum DrawModeSelectionAction {
        case select(UUID)
        case deselect(UUID)
        case none
    }

    private func drawModeSelectionAction(for location: CGPoint) -> DrawModeSelectionAction {
        let hits = mediaHitBoxes(at: location)
        if let selectedID = selectedMediaBoxID {
            if let other = hits.first(where: { $0.id != selectedID }) {
                return .select(other.id)
            }
            if hits.contains(where: { $0.id == selectedID }) {
                return .none
            }
            return .deselect(selectedID)
        } else if let hit = hits.first {
            return .select(hit.id)
        }
        return .none
    }

    private func mediaHitBoxes(at location: CGPoint) -> [NoteTextBox] {
        orderedMediaBoxes
            .reversed()
            .filter { ($0.contentType == .image || $0.isContainerStyle) && mediaHitTest(point: location, box: $0) }
    }

    private func mediaHitTest(point: CGPoint, box: NoteTextBox) -> Bool {
        let rect = screenRect(for: box)
        let testPoint = unrotatedPoint(point, around: CGPoint(x: rect.midX, y: rect.midY), rotationDegrees: box.rotationDegrees)
        guard box.contentType == .image else {
            return rect.contains(testPoint)
        }
        let visualRect = visibleImageRect(for: box, in: rect)
        return visualRect.contains(testPoint)
    }

    private func visibleImageRect(for box: NoteTextBox, in frame: CGRect) -> CGRect {
        let padded = frame.insetBy(dx: 6, dy: 6)
        guard padded.width > 1, padded.height > 1 else { return frame }
        guard let imageData = box.imageData,
              let image = UIImage(data: imageData),
              image.size.width > 0,
              image.size.height > 0 else {
            return padded
        }
        let imageAspect = image.size.width / image.size.height
        let frameAspect = padded.width / padded.height
        if imageAspect > frameAspect {
            let fittedHeight = padded.width / imageAspect
            return CGRect(
                x: padded.minX,
                y: padded.midY - (fittedHeight / 2),
                width: padded.width,
                height: fittedHeight
            )
        } else {
            let fittedWidth = padded.height * imageAspect
            return CGRect(
                x: padded.midX - (fittedWidth / 2),
                y: padded.minY,
                width: fittedWidth,
                height: padded.height
            )
        }
    }

    private func handleTextModeTap(at location: CGPoint) {
        store.selectPage(note.id)
        guard CACurrentMediaTime() >= ignorePageTapUntil else { return }
        TextBoxDiagnosticsLogger.shared.log("text.tap note=\(note.id.uuidString) point=(\(Int(location.x)),\(Int(location.y))) selectedInline=\(selectedInlineTextBoxID?.uuidString ?? "nil")")

        if let hit = inlineTextBoxes.reversed().first(where: {
            $0.contentType == .text && hitTest(point: location, box: $0)
        }) {
            TextBoxDiagnosticsLogger.shared.log("text.tap.selectText note=\(note.id.uuidString) box=\(hit.id.uuidString)")
            onBeginEditingInlineTextBox(hit.id)
            return
        }

        let pt = normalizedPoint(for: location)
        if let currentBoxID = selectedInlineTextBoxID {
            if let currentBox = inlineTextBoxes.first(where: { $0.id == currentBoxID }) {
                if currentBox.contentType == .text,
                   currentBox.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    TextBoxDiagnosticsLogger.shared.log("text.tap.deleteEmpty note=\(note.id.uuidString) box=\(currentBoxID.uuidString)")
                    onDeleteInlineTextBox(currentBoxID)
                }
            }
            TextBoxDiagnosticsLogger.shared.log("text.tap.deselect note=\(note.id.uuidString) box=\(currentBoxID.uuidString)")
            onExitInlineTextBox()
            return
        }
        TextBoxDiagnosticsLogger.shared.log("text.tap.createInline note=\(note.id.uuidString) normalized=(\(String(format: "%.4f", pt.x)),\(String(format: "%.4f", pt.y)))")
        _ = onCreateInlineTextBoxAt(pt.x, pt.y)
    }

    private func normalizedPoint(for location: CGPoint) -> (x: Double, y: Double) {
        let viewport = stabilizedViewportState
        let zoom = max(viewport.zoomFactor, 1)
        let bx = (location.x + viewport.contentOffset.x - viewport.contentOrigin.x) / zoom
        let by = (location.y + viewport.contentOffset.y - viewport.contentOrigin.y) / zoom
        return (x: Double(min(max(bx / max(pageWidth, 1), 0), 1)),
                y: Double(min(max(by / max(pageHeight, 1), 0), 1)))
    }

    private func unrotatedPoint(_ point: CGPoint, around center: CGPoint, rotationDegrees: Double) -> CGPoint {
        guard rotationDegrees != 0 else { return point }
        let rad = CGFloat(rotationDegrees) * .pi / 180
        let dx = point.x - center.x
        let dy = point.y - center.y
        return CGPoint(
            x: dx * cos(-rad) - dy * sin(-rad) + center.x,
            y: dx * sin(-rad) + dy * cos(-rad) + center.y
        )
    }

    private func hitTest(point: CGPoint, box: NoteTextBox) -> Bool {
        let rect = screenRect(for: box)
        let cx = rect.midX
        let cy = rect.midY
        guard box.rotationDegrees != 0 else { return rect.contains(point) }
        let rad = CGFloat(box.rotationDegrees) * .pi / 180
        let dx = point.x - cx, dy = point.y - cy
        let ux = dx * cos(-rad) - dy * sin(-rad) + cx
        let uy = dx * sin(-rad) + dy * cos(-rad) + cy
        return rect.contains(CGPoint(x: ux, y: uy))
    }

    private func screenRect(for box: NoteTextBox) -> CGRect {
        let viewport = effectiveViewportState
        let zoom = max(viewport.zoomFactor, 1)
        let bw = CGFloat(box.width) * pageWidth * zoom
        let bh = CGFloat(box.height) * pageHeight * zoom
        let cx = CGFloat(box.centerX) * pageWidth * zoom - viewport.contentOffset.x + viewport.contentOrigin.x
        let cy = CGFloat(box.centerY) * pageHeight * zoom - viewport.contentOffset.y + viewport.contentOrigin.y
        return CGRect(x: cx - bw / 2, y: cy - bh / 2, width: bw, height: bh)
    }

    private func searchHighlights(for boxID: UUID) -> [TextSearchHighlight] {
        guard !searchQuery.isEmpty else { return [] }
        return searchMatches.compactMap { match in
            guard match.noteID == note.id, match.boxID == boxID else { return nil }
            return TextSearchHighlight(location: match.location, length: match.length,
                                       isActive: match.id == activeSearchMatchID)
        }
    }
}

private struct PageInlineTextOverlay: View {
    let box: NoteTextBox
    let isSelected: Bool
    let isTextMode: Bool
    let viewportState: CanvasViewportState
    let pageLayoutScale: CGFloat
    let searchQuery: String
    let searchHighlights: [TextSearchHighlight]
    let onBeginEditing: () -> Void
    let onTextChange: (String) -> Void
    let onStyleChange: (NoteTextStyle) -> Void
    let onDelete: () -> Void
    let onRequestIgnorePageTap: () -> Void
    let onFrameChange: (Double, Double, Double, Double, Double) -> Void

    @FocusState private var isFocused: Bool
    @State private var transientFrame: OverlayBoxFrame?
    @State private var dragStartFrame: OverlayBoxFrame?
    @State private var textPinchStartFontSize: Double?
    @State private var isTextPinchSizing = false
    @State private var isDraggingBox = false
    @State private var didTriggerSelectionTouch = false
    @State private var dragSampleCounter = 0
    @GestureState private var isDragGestureActive = false
    @GestureState private var isTextPinchGestureActive = false

    private var isEditing: Bool {
        isSelected && isTextMode
    }

    private var showsDeleteControl: Bool {
        isEditing
    }

    private var isTransformingOverlay: Bool {
        isDraggingBox || isTextPinchSizing
    }

    private var effectiveTextScale: CGFloat {
        let outerScale = max(pageLayoutScale, 0.000_1)
        let innerScale = max(viewportState.zoomFactor, 1)
        return max(0.2, outerScale * innerScale)
    }

    private var scaledTextInset: CGFloat {
        max(1.0, 8.0 * effectiveTextScale)
    }

    private var modelFrame: OverlayBoxFrame {
        OverlayBoxFrame(
            centerX: box.centerX,
            centerY: box.centerY,
            width: box.width,
            height: box.height,
            rotationDegrees: 0
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let pageSize = proxy.size
            let currentFrame = transientFrame ?? modelFrame
            let boxFrame = frame(for: currentFrame, in: pageSize)

            ZStack(alignment: .topLeading) {
                content(for: pageSize)
                    .background(isEditing ? Color.white.opacity(0.001) : Color.clear)
                    .overlay { borderOverlay }
                    .frame(width: boxFrame.width, height: boxFrame.height)
                    .rotationEffect(.degrees(currentFrame.rotationDegrees))
                    .offset(x: boxFrame.minX, y: boxFrame.minY)
                    .contentShape(Rectangle())
                    .highPriorityGesture(dragGesture(pageSize: pageSize), including: isEditing ? .all : .none)
                    .highPriorityGesture(
                        selectionTouchGesture(),
                        including: (!isSelected && isTextMode) ? .gesture : .none
                    )
                    .animation(
                        isTransformingOverlay
                            ? nil
                            : .interactiveSpring(response: 0.22, dampingFraction: 0.86),
                        value: transientFrame
                    )
                    .onAppear {
                        guard isEditing else { return }
                        requestKeyboardFocus()
                    }
                    .onChange(of: isSelected) { _, selected in
                        TextBoxDiagnosticsLogger.shared.log("inline.selection box=\(box.id.uuidString) selected=\(selected ? "true" : "false") mode=\(isTextMode ? "text" : "draw")")
                        if selected {
                            transientFrame = nil
                            dragStartFrame = nil
                            isDraggingBox = false
                            textPinchStartFontSize = nil
                            isTextPinchSizing = false
                            didTriggerSelectionTouch = false
                        } else {
                            resetInteractionState()
                        }
                        if selected && isTextMode {
                            requestKeyboardFocus()
                        }
                    }
                    .onChange(of: isEditing) { _, editing in
                        TextBoxDiagnosticsLogger.shared.log("inline.editing box=\(box.id.uuidString) editing=\(editing ? "true" : "false")")
                        if editing {
                            requestKeyboardFocus()
                        } else {
                            resetInteractionState()
                        }
                    }
                    .onChange(of: box.style) { _, style in
                        guard isEditing else { return }
                        autosizeEditor(for: box.text, style: style, pageSize: pageSize)
                    }
                    .onChange(of: isDragGestureActive) { _, active in
                        guard !active else { return }
                        if dragStartFrame != nil || isDraggingBox {
                            commitTransientFrameIfNeeded()
                        }
                        dragStartFrame = nil
                        isDraggingBox = false
                        dragSampleCounter = 0
                    }
                    .onChange(of: isTextPinchGestureActive) { _, active in
                        guard !active else { return }
                        textPinchStartFontSize = nil
                        isTextPinchSizing = false
                    }
                    .onChange(of: modelFrame) { _, _ in
                        guard let transientFrame else { return }
                        if isFrameClose(transientFrame, modelFrame) {
                            self.transientFrame = nil
                        }
                    }
                    .onDisappear {
                        resetInteractionState()
                    }
                    .allowsHitTesting(isTextMode)

                if showsDeleteControl {
                    deleteButton
                        .position(x: boxFrame.maxX + 10, y: boxFrame.minY - 10)
                        .zIndex(2)
                }
            }
        }
    }

    @ViewBuilder
    private func content(for pageSize: CGSize) -> some View {
        if isEditing {
            editingContent(pageSize: pageSize)
        } else {
            readOnlyContent
        }
    }

    private func editingContent(pageSize: CGSize) -> some View {
        TextEditor(text: editorBinding(pageSize: pageSize))
            .font(font(for: box.style, scale: effectiveTextScale))
            .foregroundColor(.black)
            .tint(Color.accentInk)
            .underline(box.style.isUnderlined, color: .black)
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .focused($isFocused)
            .padding(scaledTextInset)
            .simultaneousGesture(textFontPinchGesture(), including: .all)
            .onAppear {
                requestKeyboardFocus()
                DispatchQueue.main.async {
                    autosizeEditor(for: box.text, style: box.style, pageSize: pageSize)
                }
            }
    }

    private var readOnlyContent: some View {
        Text(highlightedDisplayText)
            .font(font(for: box.style, scale: effectiveTextScale))
            .foregroundColor(.black)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .underline(box.style.isUnderlined, color: .black)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(scaledTextInset)
    }

    private var highlightedDisplayText: AttributedString {
        guard !searchQuery.isEmpty, !searchHighlights.isEmpty, !box.text.isEmpty else {
            return AttributedString(box.text)
        }

        var attributed = AttributedString(box.text)
        for highlight in searchHighlights {
            let nsRange = NSRange(location: highlight.location, length: highlight.length)
            guard let stringRange = Range(nsRange, in: box.text),
                  let lower = AttributedString.Index(stringRange.lowerBound, within: attributed),
                  let upper = AttributedString.Index(stringRange.upperBound, within: attributed) else { continue }
            let color = highlight.isActive
                ? Color(red: 1.0, green: 0.89, blue: 0.50)
                : Color(red: 1.0, green: 0.95, blue: 0.74)
            attributed[lower..<upper].backgroundColor = color
        }
        return attributed
    }

    @ViewBuilder
    private var borderOverlay: some View {
        if isEditing {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.accentInk, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        }
    }

    private var deleteButton: some View {
        Button {
            onDelete()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(Color.accentInk)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func requestKeyboardFocus() {
        DispatchQueue.main.async {
            isFocused = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            if isEditing {
                isFocused = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if isEditing {
                isFocused = true
            }
        }
    }

    private func editorBinding(pageSize: CGSize) -> Binding<String> {
        Binding(
            get: { box.text },
            set: { newText in
                onTextChange(newText)
                autosizeEditor(for: newText, style: box.style, pageSize: pageSize)
            }
        )
    }

    private func selectionTouchGesture() -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !didTriggerSelectionTouch else { return }
                didTriggerSelectionTouch = true
                onRequestIgnorePageTap()
                onBeginEditing()
            }
            .onEnded { _ in
                didTriggerSelectionTouch = false
            }
    }

    private func dragGesture(pageSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($isDragGestureActive) { _, state, _ in
                state = true
            }
            .onChanged { value in
                guard isEditing, !isTextPinchSizing else { return }
                onRequestIgnorePageTap()
                isDraggingBox = true
                if isFocused {
                    isFocused = false
                }
                if dragStartFrame == nil {
                    let start = transientFrame ?? modelFrame
                    dragStartFrame = start
                    transientFrame = start
                    dragSampleCounter = 0
                }
                guard let start = dragStartFrame else { return }
                transientFrame = dragUpdatedFrame(from: start, translation: value.translation, pageSize: pageSize)
                dragSampleCounter += 1
            }
            .onEnded { _ in
                if isDraggingBox {
                    commitTransientFrameIfNeeded()
                }
                dragStartFrame = nil
                isDraggingBox = false
                dragSampleCounter = 0
            }
    }

    private func textFontPinchGesture() -> some Gesture {
        MagnificationGesture()
            .updating($isTextPinchGestureActive) { _, state, _ in
                state = true
            }
            .onChanged { value in
                guard isEditing else { return }
                isTextPinchSizing = true
                if textPinchStartFontSize == nil {
                    textPinchStartFontSize = box.style.fontSize
                }
                guard let startSize = textPinchStartFontSize else { return }
                let scaled = min(max(startSize * Double(value), 8), 180)
                let snapped = (scaled * 2).rounded() / 2
                guard abs(snapped - box.style.fontSize) >= 0.25 else { return }
                var updatedStyle = box.style
                updatedStyle.fontSize = snapped
                onStyleChange(updatedStyle)
            }
            .onEnded { _ in
                textPinchStartFontSize = nil
                isTextPinchSizing = false
            }
    }

    private func frame(for frame: OverlayBoxFrame, in pageSize: CGSize) -> CGRect {
        let baseWidth = CGFloat(frame.width) * pageSize.width
        let baseHeight = CGFloat(frame.height) * pageSize.height
        let zoom = max(viewportState.zoomFactor, 1)
        let width = baseWidth * zoom
        let height = baseHeight * zoom
        let baseCenter = CGPoint(
            x: CGFloat(frame.centerX) * pageSize.width,
            y: CGFloat(frame.centerY) * pageSize.height
        )
        let center = CGPoint(
            x: (baseCenter.x * zoom) - viewportState.contentOffset.x + viewportState.contentOrigin.x,
            y: (baseCenter.y * zoom) - viewportState.contentOffset.y + viewportState.contentOrigin.y
        )
        return CGRect(x: center.x - (width / 2), y: center.y - (height / 2), width: width, height: height)
    }

    private func dragUpdatedFrame(
        from start: OverlayBoxFrame,
        translation: CGSize,
        pageSize: CGSize
    ) -> OverlayBoxFrame {
        let zoom = max(viewportState.zoomFactor, 1)
        let newCenterX = start.centerX + Double(translation.width / max(pageSize.width * zoom, 1))
        let newCenterY = start.centerY + Double(translation.height / max(pageSize.height * zoom, 1))
        let clamped = clampedCenter(
            centerX: newCenterX,
            centerY: newCenterY,
            width: start.width,
            height: start.height,
            rotationDegrees: start.rotationDegrees
        )
        return OverlayBoxFrame(
            centerX: clamped.x,
            centerY: clamped.y,
            width: start.width,
            height: start.height,
            rotationDegrees: start.rotationDegrees
        )
    }

    private func commitTransientFrameIfNeeded() {
        guard let transient = transientFrame else { return }
        if isFrameClose(transient, modelFrame) {
            transientFrame = nil
            return
        }
        onFrameChange(
            transient.centerX,
            transient.centerY,
            transient.width,
            transient.height,
            transient.rotationDegrees
        )
    }

    private func isFrameClose(_ lhs: OverlayBoxFrame, _ rhs: OverlayBoxFrame) -> Bool {
        abs(lhs.centerX - rhs.centerX) < 0.0005 &&
            abs(lhs.centerY - rhs.centerY) < 0.0005 &&
            abs(lhs.width - rhs.width) < 0.0005 &&
            abs(lhs.height - rhs.height) < 0.0005 &&
            abs(normalizeRotation(lhs.rotationDegrees - rhs.rotationDegrees)) < 0.2
    }

    private func normalizeRotation(_ value: Double) -> Double {
        var normalized = value.truncatingRemainder(dividingBy: 360)
        if normalized > 180 {
            normalized -= 360
        } else if normalized <= -180 {
            normalized += 360
        }
        return normalized
    }

    private func clampedCenter(
        centerX: Double,
        centerY: Double,
        width: Double,
        height: Double,
        rotationDegrees: Double
    ) -> (x: Double, y: Double) {
        let radians = rotationDegrees * .pi / 180
        let halfWidth = width / 2
        let halfHeight = height / 2
        let horizontalExtent = abs(cos(radians)) * halfWidth + abs(sin(radians)) * halfHeight
        let verticalExtent = abs(sin(radians)) * halfWidth + abs(cos(radians)) * halfHeight
        let clampedX = min(max(centerX, horizontalExtent), 1 - horizontalExtent)
        let clampedY = min(max(centerY, verticalExtent), 1 - verticalExtent)
        return (x: clampedX, y: clampedY)
    }

    private func resetInteractionState() {
        isFocused = false
        transientFrame = nil
        dragStartFrame = nil
        textPinchStartFontSize = nil
        isTextPinchSizing = false
        isDraggingBox = false
        didTriggerSelectionTouch = false
        dragSampleCounter = 0
    }

    private struct OverlayBoxFrame: Equatable {
        var centerX: Double
        var centerY: Double
        var width: Double
        var height: Double
        var rotationDegrees: Double
    }

    private func font(for style: NoteTextStyle, scale: CGFloat = 1) -> Font {
        let size = max(1, style.fontSize * Double(max(scale, 0.01)))
        let weight: Font.Weight = style.isBold ? .bold : .regular
        var value: Font
        if UIFont(name: style.fontName, size: size) != nil {
            value = Font.custom(style.fontName, size: size).weight(weight)
        } else {
            value = fallbackFont(for: style.fontName, size: size, weight: weight)
        }
        if style.isItalic {
            value = value.italic()
        }
        return value
    }

    private func fallbackFont(for fontName: String, size: Double, weight: Font.Weight) -> Font {
        let lower = fontName.lowercased()
        if lower.contains("serif") {
            return .system(size: size, weight: weight, design: .serif)
        }
        if lower.contains("mono") || lower.contains("code") {
            return .system(size: size, weight: weight, design: .monospaced)
        }
        return .system(size: size, weight: weight, design: .rounded)
    }

    private func autosizeEditor(for text: String, style: NoteTextStyle, pageSize: CGSize) {
        guard pageSize.width > 0, pageSize.height > 0 else { return }
        let targetSize = recommendedEditorSize(for: text, style: style, pageSize: pageSize)
        let basePageSize = unscaledPageSize(for: pageSize)
        var normalizedWidth = Double(targetSize.width / max(basePageSize.width, 1))
        var normalizedHeight = Double(targetSize.height / max(basePageSize.height, 1))

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            normalizedWidth = max(normalizedWidth, box.width)
            normalizedHeight = max(normalizedHeight, box.height)
        }

        if abs(normalizedWidth - box.width) < 0.002, abs(normalizedHeight - box.height) < 0.002 {
            return
        }

        let anchor = CGPoint(
            x: box.centerX - (box.width / 2),
            y: box.centerY - (box.height / 2)
        )
        let nextCenterX = anchor.x + (normalizedWidth / 2)
        let nextCenterY = anchor.y + (normalizedHeight / 2)
        let clamped = clampedCenter(
            centerX: nextCenterX,
            centerY: nextCenterY,
            width: normalizedWidth,
            height: normalizedHeight,
            rotationDegrees: box.rotationDegrees
        )
        onFrameChange(clamped.x, clamped.y, normalizedWidth, normalizedHeight, box.rotationDegrees)
    }

    private func recommendedEditorSize(for text: String, style: NoteTextStyle, pageSize: CGSize) -> CGSize {
        let horizontalPadding: CGFloat = 34
        let verticalPadding: CGFloat = 18
        let basePageSize = unscaledPageSize(for: pageSize)
        let maxWidth = basePageSize.width * 0.94
        let font = resolvedUIFont(for: style)

        let logicalLines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        let lines = logicalLines.isEmpty ? [""] : logicalLines

        let widestLine = lines.reduce(CGFloat(0)) { current, line in
            max(current, ceil((line as NSString).size(withAttributes: [.font: font]).width))
        }

        let minimumWidth = max(30, font.pointSize * 0.9 + horizontalPadding)
        let targetWidth = min(maxWidth, max(minimumWidth, widestLine + horizontalPadding))
        let lineCount = max(1, lines.count)
        let textHeight = ceil(CGFloat(lineCount) * font.lineHeight)
        let minimumHeight = max(font.lineHeight + verticalPadding, 28)
        let targetHeight = min(basePageSize.height * 0.7, max(minimumHeight, textHeight + verticalPadding))
        return CGSize(width: targetWidth, height: targetHeight)
    }

    private func unscaledPageSize(for pageSize: CGSize) -> CGSize {
        let outerScale = max(pageLayoutScale, 0.000_1)
        return CGSize(
            width: pageSize.width / outerScale,
            height: pageSize.height / outerScale
        )
    }

    private func resolvedUIFont(for style: NoteTextStyle) -> UIFont {
        let base = UIFont(name: style.fontName, size: style.fontSize) ?? fallbackUIFont(for: style.fontName, size: style.fontSize)
        var descriptor = base.fontDescriptor
        var traits = descriptor.symbolicTraits
        if style.isBold {
            traits.insert(.traitBold)
        }
        if style.isItalic {
            traits.insert(.traitItalic)
        }
        if let updated = descriptor.withSymbolicTraits(traits) {
            descriptor = updated
        }
        return UIFont(descriptor: descriptor, size: style.fontSize)
    }

    private func fallbackUIFont(for fontName: String, size: Double) -> UIFont {
        let lower = fontName.lowercased()
        let baseDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
        if lower.contains("serif") {
            if let serif = baseDescriptor.withDesign(.serif) {
                return UIFont(descriptor: serif, size: size)
            }
            return UIFont.systemFont(ofSize: size, weight: .regular)
        }
        if lower.contains("mono") || lower.contains("code") {
            return UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
        if let rounded = baseDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: rounded, size: size)
        }
        return UIFont.systemFont(ofSize: size, weight: .regular)
    }
}


private struct PageMediaBoxOverlay: View {
    let box: NoteTextBox
    let isSelected: Bool
    let isFirstPage: Bool
    let isLastPage: Bool
    let isTextMode: Bool
    let viewportState: CanvasViewportState
    let onTapAtLocation: (CGPoint) -> Void
    let onDelete: () -> Void
    let onRequestIgnorePageTap: () -> Void
    let onFrameChange: (Double, Double, Double, Double, Double) -> Void
    let onDragActiveChanged: (Bool) -> Void
    let onEdgeScroll: ((CGFloat?) -> Void)?

    @State private var transientFrame: OverlayBoxFrame?
    @State private var dragStartFrame: OverlayBoxFrame?
    @State private var pinchStartFrame: OverlayBoxFrame?
    @State private var rotationStartFrame: OverlayBoxFrame?
    @State private var decodedOverlayImage: UIImage?
    @State private var isDraggingBox = false
    @State private var isPinchResizing = false
    @State private var isRotatingBox = false
    @State private var dragTouchOffset: CGSize?

    private var canManipulate: Bool {
        !isTextMode && (box.contentType == .image || box.isContainerStyle)
    }

    private var isEditing: Bool {
        isSelected && canManipulate
    }

    private var modelFrame: OverlayBoxFrame {
        OverlayBoxFrame(
            centerX: box.centerX,
            centerY: box.centerY,
            width: box.width,
            height: box.height,
            rotationDegrees: box.rotationDegrees
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let pageSize = proxy.size
            let pageGlobalFrame = proxy.frame(in: .global)
            let currentFrame = transientFrame ?? modelFrame
            let boxFrame = frame(for: currentFrame, in: pageSize)

            ZStack(alignment: .topTrailing) {
                content
                    .overlay { borderOverlay }
                    .frame(width: boxFrame.width, height: boxFrame.height)
                    .rotationEffect(.degrees(currentFrame.rotationDegrees))

                if isEditing {
                    deleteButton
                        .offset(x: 10, y: -10)
                }
            }
            .frame(width: boxFrame.width, height: boxFrame.height, alignment: .center)
            .position(x: boxFrame.midX, y: boxFrame.midY)
            .contentShape(Rectangle())
            .highPriorityGesture(
                dragGesture(pageSize: pageSize, pageGlobalFrame: pageGlobalFrame, boxFrame: boxFrame),
                including: isEditing ? .all : .none
            )
            .simultaneousGesture(pinchResizeGesture(), including: isEditing ? .all : .none)
            .simultaneousGesture(rotationGesture(), including: isEditing ? .all : .none)
            .simultaneousGesture(
                SpatialTapGesture().onEnded { value in
                    onTapAtLocation(value.location)
                },
                including: isEditing ? .gesture : .none
            )
            .animation(nil, value: transientFrame)
            .onAppear {
                refreshDecodedOverlayImage()
            }
            .onChange(of: box.imageData) { _, _ in
                refreshDecodedOverlayImage()
            }
            .onChange(of: box.contentType) { _, _ in
                refreshDecodedOverlayImage()
            }
            .onChange(of: isSelected) { _, selected in
                if selected {
                    transientFrame = nil
                    dragStartFrame = nil
                    pinchStartFrame = nil
                    rotationStartFrame = nil
                    isDraggingBox = false
                    isPinchResizing = false
                    isRotatingBox = false
                } else {
                    if !isDraggingBox {
                        resetInteractionState()
                    }
                }
            }
            .onChange(of: isEditing) { _, editing in
                if !editing && !isDraggingBox {
                    resetInteractionState()
                }
            }
            .onChange(of: modelFrame) { _, _ in
                guard let transientFrame else { return }
                if isFrameClose(transientFrame, modelFrame) {
                    self.transientFrame = nil
                }
            }
            .onDisappear {
                resetInteractionState()
            }
            .allowsHitTesting(isEditing || isDraggingBox)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let image = decodedOverlayImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(6)
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
                .padding(6)
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        if isEditing {
            shape.stroke(Color.accentInk, lineWidth: 2)
        } else {
            shape.stroke(Color(uiColor: .separator).opacity(0.50), lineWidth: 1)
        }
    }

    private var deleteButton: some View {
        Button {
            onRequestIgnorePageTap()
            onDelete()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(Color.accentInk)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func dragGesture(pageSize: CGSize, pageGlobalFrame: CGRect, boxFrame: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                guard isEditing || isDraggingBox else { return }
                let movedEnough = abs(value.translation.width) > 0.5 || abs(value.translation.height) > 0.5
                guard movedEnough else { return }

                if dragStartFrame == nil {
                    onRequestIgnorePageTap()
                    let start = transientFrame ?? modelFrame
                    dragStartFrame = start
                    transientFrame = start
                    dragTouchOffset = CGSize(
                        width: value.startLocation.x - (pageGlobalFrame.minX + boxFrame.midX),
                        height: value.startLocation.y - (pageGlobalFrame.minY + boxFrame.midY)
                    )
                }

                if !isDraggingBox {
                    isDraggingBox = true
                    onDragActiveChanged(true)
                }

                guard let startFrame = dragStartFrame else { return }
                let nextFrame = dragUpdatedFrame(
                    from: startFrame,
                    location: value.location,
                    pageSize: pageSize,
                    pageGlobalFrame: pageGlobalFrame,
                    touchOffset: dragTouchOffset ?? .zero
                )
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    transientFrame = nextFrame
                }
                onEdgeScroll?(value.location.y)
            }
            .onEnded { value in
                let movedEnough = abs(value.translation.width) > 0.5 || abs(value.translation.height) > 0.5
                if movedEnough, let startFrame = dragStartFrame {
                    let finalFrame = dragUpdatedFrame(
                        from: startFrame,
                        location: value.location,
                        pageSize: pageSize,
                        pageGlobalFrame: pageGlobalFrame,
                        touchOffset: dragTouchOffset ?? .zero
                    )
                    transientFrame = finalFrame
                }
                if movedEnough && (isDraggingBox || dragStartFrame != nil) {
                    commitTransientFrameIfNeeded()
                    onRequestIgnorePageTap()
                }
                onEdgeScroll?(nil)
                dragTouchOffset = nil
                dragStartFrame = nil
                isDraggingBox = false
                onDragActiveChanged(false)
            }
    }

    private func pinchResizeGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard isEditing else { return }
                isPinchResizing = true
                if pinchStartFrame == nil {
                    onRequestIgnorePageTap()
                    let start = transientFrame ?? modelFrame
                    pinchStartFrame = start
                    transientFrame = start
                }
                guard let start = pinchStartFrame else { return }
                let scale = Double(value)
                let newWidth = min(max(start.width * scale, 0.035), 0.92)
                let newHeight = min(max(start.height * scale, 0.03), 0.86)
                let clamped = clampedCenter(
                    centerX: start.centerX,
                    centerY: start.centerY,
                    width: newWidth,
                    height: newHeight,
                    rotationDegrees: start.rotationDegrees
                )
                transientFrame = OverlayBoxFrame(
                    centerX: clamped.x,
                    centerY: clamped.y,
                    width: newWidth,
                    height: newHeight,
                    rotationDegrees: start.rotationDegrees
                )
            }
            .onEnded { _ in
                commitTransientFrameIfNeeded()
                onRequestIgnorePageTap()
                pinchStartFrame = nil
                isPinchResizing = false
            }
    }

    private func rotationGesture() -> some Gesture {
        RotationGesture()
            .onChanged { value in
                guard isEditing else { return }
                isRotatingBox = true
                if rotationStartFrame == nil {
                    onRequestIgnorePageTap()
                    let start = transientFrame ?? modelFrame
                    rotationStartFrame = start
                    transientFrame = start
                }
                guard let start = rotationStartFrame else { return }
                let snapped = snappedRightAngle(start.rotationDegrees + value.degrees)
                let clamped = clampedCenter(
                    centerX: start.centerX,
                    centerY: start.centerY,
                    width: start.width,
                    height: start.height,
                    rotationDegrees: snapped
                )
                transientFrame = OverlayBoxFrame(
                    centerX: clamped.x,
                    centerY: clamped.y,
                    width: start.width,
                    height: start.height,
                    rotationDegrees: snapped
                )
            }
            .onEnded { value in
                guard let start = rotationStartFrame else { return }
                let snapped = snappedRightAngle(start.rotationDegrees + value.degrees, threshold: 10)
                let clamped = clampedCenter(
                    centerX: start.centerX,
                    centerY: start.centerY,
                    width: start.width,
                    height: start.height,
                    rotationDegrees: snapped
                )
                transientFrame = OverlayBoxFrame(
                    centerX: clamped.x,
                    centerY: clamped.y,
                    width: start.width,
                    height: start.height,
                    rotationDegrees: snapped
                )
                commitTransientFrameIfNeeded()
                onRequestIgnorePageTap()
                rotationStartFrame = nil
                isRotatingBox = false
            }
    }

    private func refreshDecodedOverlayImage() {
        guard box.contentType == .image, let imageData = box.imageData else {
            decodedOverlayImage = nil
            return
        }
        decodedOverlayImage = downsampledOverlayImage(from: imageData, maxPixelSize: 2400)
            ?? UIImage(data: imageData)
    }

    private func downsampledOverlayImage(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
            return nil
        }
        let pixelLimit = max(1, Int(maxPixelSize))
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelLimit,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private func frame(for frame: OverlayBoxFrame, in pageSize: CGSize) -> CGRect {
        let baseWidth = CGFloat(frame.width) * pageSize.width
        let baseHeight = CGFloat(frame.height) * pageSize.height
        let zoom = max(viewportState.zoomFactor, 1)
        let width = baseWidth * zoom
        let height = baseHeight * zoom
        let baseCenter = CGPoint(
            x: CGFloat(frame.centerX) * pageSize.width,
            y: CGFloat(frame.centerY) * pageSize.height
        )
        let center = CGPoint(
            x: (baseCenter.x * zoom) - viewportState.contentOffset.x + viewportState.contentOrigin.x,
            y: (baseCenter.y * zoom) - viewportState.contentOffset.y + viewportState.contentOrigin.y
        )
        return CGRect(x: center.x - (width / 2), y: center.y - (height / 2), width: width, height: height)
    }

    private func dragUpdatedFrame(
        from start: OverlayBoxFrame,
        location: CGPoint,
        pageSize: CGSize,
        pageGlobalFrame: CGRect,
        touchOffset: CGSize
    ) -> OverlayBoxFrame {
        let localCenterX = location.x - pageGlobalFrame.minX - touchOffset.width
        let localCenterY = location.y - pageGlobalFrame.minY - touchOffset.height
        let zoom = max(viewportState.zoomFactor, 1)

        let baseCenterX = (localCenterX + viewportState.contentOffset.x - viewportState.contentOrigin.x) / zoom
        let baseCenterY = (localCenterY + viewportState.contentOffset.y - viewportState.contentOrigin.y) / zoom

        let normalizedCenterX = Double(baseCenterX / max(pageSize.width, 1))
        let normalizedCenterY = Double(baseCenterY / max(pageSize.height, 1))

        let clamped = clampedCenter(
            centerX: normalizedCenterX,
            centerY: normalizedCenterY,
            width: start.width,
            height: start.height,
            rotationDegrees: start.rotationDegrees
        )
        return OverlayBoxFrame(
            centerX: clamped.x,
            centerY: clamped.y,
            width: start.width,
            height: start.height,
            rotationDegrees: start.rotationDegrees
        )
    }

    private func commitTransientFrameIfNeeded() {
        guard let transient = transientFrame else { return }
        if isFrameClose(transient, modelFrame) {
            transientFrame = nil
            return
        }
        onFrameChange(
            transient.centerX,
            transient.centerY,
            transient.width,
            transient.height,
            transient.rotationDegrees
        )
    }

    private func isFrameClose(_ lhs: OverlayBoxFrame, _ rhs: OverlayBoxFrame) -> Bool {
        abs(lhs.centerX - rhs.centerX) < 0.0005 &&
            abs(lhs.centerY - rhs.centerY) < 0.0005 &&
            abs(lhs.width - rhs.width) < 0.0005 &&
            abs(lhs.height - rhs.height) < 0.0005 &&
            abs(normalizeRotation(lhs.rotationDegrees) - normalizeRotation(rhs.rotationDegrees)) < 0.25
    }

    private func clampedCenter(
        centerX: Double,
        centerY: Double,
        width: Double,
        height: Double,
        rotationDegrees: Double
    ) -> (x: Double, y: Double) {
        let extents = rotatedHalfExtents(width: width, height: height, rotationDegrees: rotationDegrees)
        let clampedX = min(max(centerX, extents.horizontal), 1 - extents.horizontal)
        let minY = isFirstPage ? extents.vertical : -Double.infinity
        let maxY = isLastPage ? 1.0 - extents.vertical : Double.infinity
        let clampedY = min(max(centerY, minY), maxY)
        return (x: clampedX, y: clampedY)
    }

    private func rotatedHalfExtents(width: Double, height: Double, rotationDegrees: Double) -> (horizontal: Double, vertical: Double) {
        let radians = rotationDegrees * .pi / 180
        let halfWidth = width / 2
        let halfHeight = height / 2
        let horizontal = abs(cos(radians)) * halfWidth + abs(sin(radians)) * halfHeight
        let vertical = abs(sin(radians)) * halfWidth + abs(cos(radians)) * halfHeight
        return (horizontal, vertical)
    }

    private func normalizeRotation(_ value: Double) -> Double {
        var normalized = value.truncatingRemainder(dividingBy: 360)
        if normalized > 180 {
            normalized -= 360
        } else if normalized <= -180 {
            normalized += 360
        }
        return normalized
    }

    private func snappedRightAngle(_ value: Double, threshold: Double = 8) -> Double {
        let normalized = normalizeRotation(value)
        let snapPoints: [Double] = [-180, -90, 0, 90, 180]
        if let snap = snapPoints.min(by: { abs($0 - normalized) < abs($1 - normalized) }),
           abs(snap - normalized) <= threshold {
            return snap == 180 ? -180 : snap
        }
        return normalized
    }

    private func resetInteractionState() {
        transientFrame = nil
        dragStartFrame = nil
        pinchStartFrame = nil
        rotationStartFrame = nil
        dragTouchOffset = nil
        isPinchResizing = false
        isDraggingBox = false
        isRotatingBox = false
        onDragActiveChanged(false)
        onEdgeScroll?(nil)
    }

    private struct OverlayBoxFrame: Equatable {
        var centerX: Double
        var centerY: Double
        var width: Double
        var height: Double
        var rotationDegrees: Double
    }
}


private struct PageOverviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var store: NotesStore
    let notebook: Notebook
    let currentViewedNoteID: UUID?
    let onSelectPage: (UUID) -> Void
    let onAddBlankPage: () -> Void
    let onAddLinedPage: () -> Void
    let onAddImagePage: () -> Void
    let onAddPDFPage: () -> Void
    let onDeletePage: (UUID) -> Void
    let onMovePages: (IndexSet, Int) -> Void

    private var notes: [Note] {
        store.visibleNotes
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Add Page") {
                    Button {
                        onAddBlankPage()
                    } label: {
                        Label("Blank Page", systemImage: "doc")
                    }

                    Button {
                        onAddLinedPage()
                    } label: {
                        Label("Lined Page", systemImage: "line.3.horizontal")
                    }

                    Button {
                        onAddImagePage()
                    } label: {
                        Label("Image Page", systemImage: "photo")
                    }

                    Button {
                        onAddPDFPage()
                    } label: {
                        Label("PDF Pages", systemImage: "doc.richtext")
                    }
                }

                Section("All Pages") {
                    ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                        Button {
                            onSelectPage(note.id)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                PageOverviewThumbnail(
                                    note: note,
                                    notebook: notebook,
                                    pageNumber: index + 1
                                )

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(note.displayTitle)
                                            .font(.system(.headline, design: .rounded))
                                            .lineLimit(1)

                                        if note.id == currentViewedNoteID {
                                            Text("Current")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(Color.accentInk)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Color.accentInk.opacity(0.14), in: Capsule())
                                        }
                                    }

                                    Text("Page \(index + 1)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if note.backgroundImageData != nil {
                                        Text("Image / PDF page")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text((note.pagePaperStyleOverride ?? notebook.paperStyle).displayName)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer(minLength: 0)

                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        let ids = offsets.compactMap { notes[$0].id }
                        ids.forEach(onDeletePage)
                    }
                    .onMove(perform: onMovePages)
                }
            }
            .navigationTitle("Pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct PageOverviewThumbnail: View {
    let note: Note
    let notebook: Notebook
    let pageNumber: Int

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white)
                .overlay {
                    if let data = note.backgroundImageData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .clipped()
                    } else {
                        PaperTemplateBackground(style: note.pagePaperStyleOverride ?? notebook.paperStyle)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

            Text("\(pageNumber)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(6)
                .background(Color.white.opacity(0.92), in: Capsule())
                .padding(6)
        }
        .frame(width: 72, height: 96)
        .shadow(color: Color.black.opacity(0.05), radius: 6, y: 3)
    }
}

private struct TypedNotesEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var title: String
    @Binding var notesBody: String

    var bodyView: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextField("Page title", text: $title)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )

                TextEditor(text: $notesBody)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
            }
            .padding(16)
            .background(Color(red: 0.96, green: 0.95, blue: 0.93).ignoresSafeArea())
            .navigationTitle("Typed Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    var body: some View {
        bodyView
            .presentationDetents([.medium, .large])
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct PhotoLibraryPickerSheet: UIViewControllerRepresentable {
    let onCancel: () -> Void
    let onCompletion: ([UIImage]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCancel: onCancel, onCompletion: onCompletion)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 0
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onCancel: () -> Void
        let onCompletion: ([UIImage]) -> Void

        init(onCancel: @escaping () -> Void, onCompletion: @escaping ([UIImage]) -> Void) {
            self.onCancel = onCancel
            self.onCompletion = onCompletion
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else {
                onCancel()
                return
            }

            var imagesByIndex: [Int: UIImage] = [:]
            let imagesLock = NSLock()
            let group = DispatchGroup()

            for (index, result) in results.enumerated() {
                let provider = result.itemProvider
                guard provider.canLoadObject(ofClass: UIImage.self) else { continue }
                group.enter()
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    defer { group.leave() }
                    guard let image = object as? UIImage else { return }
                    imagesLock.lock()
                    imagesByIndex[index] = image
                    imagesLock.unlock()
                }
            }

            group.notify(queue: .main) {
                let orderedImages = results.indices.compactMap { imagesByIndex[$0] }
                self.onCompletion(orderedImages)
            }
        }
    }
}

private struct DocumentScannerSheet: UIViewControllerRepresentable {
    static var isSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }

    let onCancel: () -> Void
    let onCompletion: ([UIImage]) -> Void
    let onError: (Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCancel: onCancel, onCompletion: onCompletion, onError: onError)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onCancel: () -> Void
        let onCompletion: ([UIImage]) -> Void
        let onError: (Error) -> Void

        init(onCancel: @escaping () -> Void, onCompletion: @escaping ([UIImage]) -> Void, onError: @escaping (Error) -> Void) {
            self.onCancel = onCancel
            self.onCompletion = onCompletion
            self.onError = onError
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onError(error)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            onCompletion(images)
        }
    }
}

private struct FloatingInkToolbar: View {
    @Binding var selectedInkTool: PageInkTool
    @Binding var isCollapsed: Bool

    var body: some View {
        Group {
            if isCollapsed {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isCollapsed = false
                    }
                } label: {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "pencil.tip")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 8) {
                    toolButton(.pen, icon: "pencil.line")
                    toolButton(.pencil, icon: "pencil")
                    toolButton(.marker, icon: "highlighter")
                    toolButton(.eraser, icon: "eraser")

                    Divider()
                        .frame(height: 18)

                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isCollapsed = true
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
                .gesture(
                    DragGesture(minimumDistance: 8)
                        .onEnded { value in
                            if value.translation.height > 20 {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    isCollapsed = true
                                }
                            }
                        }
                )
            }
        }
    }

    private func toolButton(_ tool: PageInkTool, icon: String) -> some View {
        let isSelected = selectedInkTool == tool
        return Button {
            selectedInkTool = tool
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .black)
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(isSelected ? Color.black : Color.clear)
                )
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(isSelected ? 0 : 0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(toolAccessibilityLabel(tool))
    }

    private func toolAccessibilityLabel(_ tool: PageInkTool) -> String {
        switch tool {
        case .pen: return "Black Pen"
        case .pencil: return "Black Pencil"
        case .marker: return "Black Marker"
        case .eraser: return "Eraser"
        }
    }
}

private struct MarkdownPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let note: Note

    var body: some View {
        NavigationStack {
            MarkdownPreviewPane(markdown: note.body)
                .padding(16)
                .background(Color(red: 0.96, green: 0.96, blue: 0.94).ignoresSafeArea())
                .navigationTitle(note.displayTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

private struct MarkdownPreviewPane: View {
    let markdown: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView(
                        "No Typed Notes",
                        systemImage: "eye",
                        description: Text("Add typed markdown notes to preview them here.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
                } else if let rendered {
                    Text(rendered)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                } else {
                    Text(markdown)
                        .font(.system(.body, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private var rendered: AttributedString? {
        try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .full))
    }
}

private struct PaperTemplateBackground: View {
    let style: NotebookPaperStyle

    var body: some View {
        GeometryReader { proxy in
            switch style {
            case .blank:
                RoundedRectangle(cornerRadius: 0, style: .continuous)
                    .fill(Color.paperBlank)
            case .lined:
                Canvas { context, size in
                    let backgroundRect = CGRect(origin: .zero, size: size)
                    context.fill(Path(backgroundRect), with: .color(Color.paperBlank))

                    let lineSpacing: CGFloat = max(8, size.height * 0.054)
                    let topOffset: CGFloat = max(80, size.height * 0.15)
                    let bottomInset: CGFloat = max(16, size.height * 0.03)
                    let marginX: CGFloat = max(14, size.width * 0.12)
                    let lineColor = Color(red: 0.18, green: 0.62, blue: 0.90).opacity(1.0)
                    let marginColor = Color(red: 0.78, green: 0.16, blue: 0.38).opacity(0.95)

                    var horizontal = Path()
                    var y = topOffset
                    while y < size.height - bottomInset {
                        horizontal.move(to: CGPoint(x: 0, y: y))
                        horizontal.addLine(to: CGPoint(x: size.width, y: y))
                        y += lineSpacing
                    }

                    var margin = Path()
                    margin.move(to: CGPoint(x: marginX, y: 0))
                    margin.addLine(to: CGPoint(x: marginX, y: size.height))

                    context.stroke(horizontal, with: .color(lineColor), lineWidth: 0.9)
                    context.stroke(margin, with: .color(marginColor), lineWidth: 0.9)
                }
            }
        }
    }
}

private struct ZoomablePaperCanvasPageRepresentable: UIViewRepresentable {
    let noteID: UUID
    let paperStyle: NotebookPaperStyle
    let backgroundImageData: Data?
    let drawingData: Data?
    let isActive: Bool
    let isCanvasToolingEnabled: Bool
    let isViewportGesturesEnabled: Bool
    let zoomCommandNonce: Int
    let zoomFactorTarget: CGFloat?
    let sharedZoomFactor: CGFloat
    let onZoomFactorChange: (CGFloat) -> Void
    let onViewportStateChange: (CanvasViewportState) -> Void
    let onInteraction: () -> Void
    let onDrawingChange: (Data?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onInteraction: onInteraction,
            onDrawingChange: onDrawingChange,
            onZoomFactorChange: onZoomFactorChange,
            onViewportStateChange: onViewportStateChange
        )
    }

    func makeUIView(context: Context) -> ZoomablePaperCanvasHostView {
        let hostView = ZoomablePaperCanvasHostView()
        hostView.canvasView.delegate = context.coordinator
        hostView.canvasView.onTouchBegan = { context.coordinator.onInteraction() }
        hostView.onZoomGestureBegan = { context.coordinator.onInteraction() }
        hostView.onZoomFactorChanged = { factor in
            guard isActive else { return }
            context.coordinator.onZoomFactorChange(factor)
        }
        hostView.onViewportStateChanged = { state in
            guard isActive else { return }
            context.coordinator.onViewportStateChange(state)
        }
        hostView.canvasView.drawingPolicy = .pencilOnly
        context.coordinator.prepareForNote(noteID)
        hostView.paperStyle = paperStyle
        hostView.setBackgroundImageData(backgroundImageData)
        context.coordinator.applyExternalDrawing(drawingData, to: hostView.canvasView)
        hostView.setCanvasActive(isCanvasToolingEnabled)
        hostView.setViewportGesturesEnabled(isViewportGesturesEnabled)
        hostView.setZoomFactor(sharedZoomFactor, animated: false)
        context.coordinator.lastAppliedZoomCommandNonce = zoomCommandNonce
        context.coordinator.lastAppliedZoomFactor = sharedZoomFactor
        context.coordinator.wasActive = isActive
        return hostView
    }

    func updateUIView(_ uiView: ZoomablePaperCanvasHostView, context: Context) {
        context.coordinator.onInteraction = onInteraction
        context.coordinator.onDrawingChange = onDrawingChange
        context.coordinator.onZoomFactorChange = onZoomFactorChange
        context.coordinator.onViewportStateChange = onViewportStateChange
        uiView.canvasView.onTouchBegan = { context.coordinator.onInteraction() }
        uiView.onZoomGestureBegan = { context.coordinator.onInteraction() }
        uiView.onZoomFactorChanged = { factor in
            guard isActive else { return }
            context.coordinator.onZoomFactorChange(factor)
        }
        uiView.onViewportStateChanged = { state in
            guard isActive else { return }
            context.coordinator.onViewportStateChange(state)
        }
        context.coordinator.prepareForNote(noteID)
        uiView.paperStyle = paperStyle
        uiView.setBackgroundImageData(backgroundImageData)
        context.coordinator.applyExternalDrawing(drawingData, to: uiView.canvasView)
        uiView.setCanvasActive(isCanvasToolingEnabled)
        uiView.setViewportGesturesEnabled(isViewportGesturesEnabled)

        if context.coordinator.lastAppliedZoomCommandNonce != zoomCommandNonce {
            if let zoomFactorTarget {
                uiView.setZoomFactor(zoomFactorTarget, animated: false)
            } else {
                uiView.resetZoomToOverview(animated: false)
            }
            context.coordinator.lastAppliedZoomCommandNonce = zoomCommandNonce
            context.coordinator.lastAppliedZoomFactor = sharedZoomFactor
        } else if abs(uiView.currentZoomFactor - sharedZoomFactor) > 0.001 {
            uiView.setZoomFactor(sharedZoomFactor, animated: false)
            context.coordinator.lastAppliedZoomFactor = sharedZoomFactor
        }

        context.coordinator.wasActive = isActive
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var onInteraction: () -> Void
        var onDrawingChange: (Data?) -> Void
        var onZoomFactorChange: (CGFloat) -> Void
        var onViewportStateChange: (CanvasViewportState) -> Void
        var wasActive = false
        var lastAppliedZoomCommandNonce = -1
        var lastAppliedZoomFactor: CGFloat = 1
        private var boundNoteID: UUID?
        private var lastSerializedData = Data()
        private var isApplyingExternalChange = false

        init(
            onInteraction: @escaping () -> Void,
            onDrawingChange: @escaping (Data?) -> Void,
            onZoomFactorChange: @escaping (CGFloat) -> Void,
            onViewportStateChange: @escaping (CanvasViewportState) -> Void
        ) {
            self.onInteraction = onInteraction
            self.onDrawingChange = onDrawingChange
            self.onZoomFactorChange = onZoomFactorChange
            self.onViewportStateChange = onViewportStateChange
        }

        func prepareForNote(_ noteID: UUID) {
            guard boundNoteID != noteID else { return }
            boundNoteID = noteID
            lastSerializedData = Data()
            isApplyingExternalChange = false
        }

        func applyExternalDrawing(_ drawingData: Data?, to canvas: PKCanvasView) {
            let normalized = drawingData ?? Data()
            guard normalized != lastSerializedData else { return }

            isApplyingExternalChange = true
            if let drawingData,
               let drawing = try? PKDrawing(data: drawingData) {
                canvas.drawing = drawing
                lastSerializedData = drawing.strokes.isEmpty ? Data() : drawing.dataRepresentation()
            } else {
                canvas.drawing = PKDrawing()
                lastSerializedData = Data()
            }
            isApplyingExternalChange = false
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingExternalChange else { return }
            let data: Data? = canvasView.drawing.strokes.isEmpty ? nil : canvasView.drawing.dataRepresentation()
            let normalized = data ?? Data()
            guard normalized != lastSerializedData else { return }
            lastSerializedData = normalized
            onDrawingChange(data)
        }
    }
}

private final class ZoomablePaperCanvasHostView: UIView {
    let scrollView = UIScrollView()
    let contentView = UIView()
    let paperView = PaperCanvasBackgroundUIView()
    let backgroundImageView = UIImageView()
    let canvasView = InteractiveCanvasView()

    private let zoomCoordinator = ZoomCoordinator()
    private var hasConfiguredViewHierarchy = false
    private var toolPicker: PKToolPicker?
    private var isCanvasActive = false
    private var isApplyingProgrammaticZoom = false
    private var programmaticZoomToken = 0
    private var desiredZoomFactor: CGFloat = 1
    private var isViewportGesturesEnabled = true
    private var lastBackgroundImageData = Data()
    private var lastLoggedPanEnabled: Bool?
    private var lastLoggedPinchEnabled: Bool?
    var onZoomGestureBegan: (() -> Void)?
    var onZoomFactorChanged: ((CGFloat) -> Void)?
    var onViewportStateChanged: ((CanvasViewportState) -> Void)?

    var paperStyle: NotebookPaperStyle = .lined {
        didSet {
            paperView.paperStyle = paperStyle
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        configureToolPickerIfNeeded()
        updateToolPickerVisibility()
    }

    private func configure() {
        guard !hasConfiguredViewHierarchy else { return }
        hasConfiguredViewHierarchy = true

        backgroundColor = .clear

        scrollView.backgroundColor = .clear
        scrollView.delegate = zoomCoordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.bouncesZoom = true
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.panGestureRecognizer.minimumNumberOfTouches = 1
        scrollView.panGestureRecognizer.allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.direct.rawValue)
        ]
        zoomCoordinator.hostView = self

        contentView.backgroundColor = .clear

        paperView.isUserInteractionEnabled = false
        paperView.backgroundColor = .clear

        backgroundImageView.isUserInteractionEnabled = false
        backgroundImageView.backgroundColor = .clear
        backgroundImageView.contentMode = .scaleAspectFit
        backgroundImageView.clipsToBounds = true
        backgroundImageView.isHidden = true

        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.alwaysBounceHorizontal = false
        canvasView.alwaysBounceVertical = false
        canvasView.showsHorizontalScrollIndicator = false
        canvasView.showsVerticalScrollIndicator = false
        canvasView.isScrollEnabled = false
        canvasView.drawingPolicy = .pencilOnly
        canvasView.drawingGestureRecognizer.allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.pencil.rawValue)
        ]

        addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(paperView)
        contentView.addSubview(backgroundImageView)
        contentView.addSubview(canvasView)

        updateViewportGestureAvailability()
    }

    static let a4Size = CGSize(width: 794, height: 1123)

    override func layoutSubviews() {
        super.layoutSubviews()

        let a4 = Self.a4Size
        scrollView.frame = bounds

        contentView.frame = CGRect(origin: .zero, size: a4)
        paperView.frame = CGRect(origin: .zero, size: a4)
        backgroundImageView.frame = CGRect(origin: .zero, size: a4)
        canvasView.frame = CGRect(origin: .zero, size: a4)
        scrollView.contentSize = a4

        guard bounds.width > 0, bounds.height > 0 else { return }
        let scaleX = bounds.width / a4.width
        let scaleY = bounds.height / a4.height
        let fitScale = min(scaleX, scaleY)
        scrollView.minimumZoomScale = fitScale
        scrollView.maximumZoomScale = max(fitScale * 4.0, fitScale + 0.01)

        let targetScale = min(max(fitScale * max(desiredZoomFactor, 1), fitScale), scrollView.maximumZoomScale)
        if abs(scrollView.zoomScale - targetScale) > 0.001 {
            scrollView.zoomScale = targetScale
        }

        updateViewportGestureAvailability()
        centerContentIfNeeded()
        publishViewportState()
    }

    func resetZoomToFit(animated: Bool) {
        setZoomFactor(1, animated: animated)
    }

    func resetZoomToOverview(animated: Bool) {
        setZoomFactor(1, animated: animated)
    }

    func setZoomFactor(_ factor: CGFloat, animated: Bool) {
        let fitScale = max(scrollView.minimumZoomScale, 0.000_1)
        desiredZoomFactor = max(1, factor)
        let requestedScale = fitScale * desiredZoomFactor
        let clamped = min(max(requestedScale, fitScale), scrollView.maximumZoomScale)
        desiredZoomFactor = max(1, clamped / fitScale)
        programmaticZoomToken += 1
        let token = programmaticZoomToken
        isApplyingProgrammaticZoom = true
        scrollView.setZoomScale(clamped, animated: animated)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.programmaticZoomToken == token else { return }
            self.isApplyingProgrammaticZoom = false
        }
        let clampedFactor = clamped / fitScale
        if clampedFactor <= 1.01 {
            scrollView.contentOffset = .zero
        }
        updateViewportGestureAvailability()
        centerContentIfNeeded()
        lockHorizontalOffsetForOverviewAndBelow()
        lockVerticalOffsetForOverviewAndBelow()
        publishViewportState()
    }

    var currentZoomFactor: CGFloat {
        let fitScale = max(scrollView.minimumZoomScale, 0.000_1)
        return scrollView.zoomScale / fitScale
    }

    func setCanvasActive(_ isActive: Bool) {
        isCanvasActive = isActive
        canvasView.isUserInteractionEnabled = isActive
        configureToolPickerIfNeeded()
        updateToolPickerVisibility()
        TextBoxDiagnosticsLogger.shared.log("canvas.active enabled=\(isActive ? "true" : "false")")
    }

    func setViewportGesturesEnabled(_ isEnabled: Bool) {
        guard isViewportGesturesEnabled != isEnabled else { return }
        isViewportGesturesEnabled = isEnabled
        TextBoxDiagnosticsLogger.shared.log("viewportGestures.request enabled=\(isEnabled ? "true" : "false")")
        updateViewportGestureAvailability()
    }

    func setBackgroundImageData(_ data: Data?) {
        let normalized = data ?? Data()
        guard normalized != lastBackgroundImageData else { return }
        lastBackgroundImageData = normalized

        if let data,
           let image = UIImage(data: data) {
            backgroundImageView.image = image
            backgroundImageView.isHidden = false
            paperView.isHidden = true
        } else {
            backgroundImageView.image = nil
            backgroundImageView.isHidden = true
            paperView.isHidden = false
        }
    }

    private func configureToolPickerIfNeeded() {
        guard window != nil else { return }
        guard toolPicker == nil else { return }

        let picker = PKToolPicker()
        picker.addObserver(canvasView)
        toolPicker = picker
    }

    private func updateToolPickerVisibility() {
        guard let toolPicker else { return }

        if isCanvasActive {
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            canvasView.becomeFirstResponder()
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isCanvasActive else { return }
                self.toolPicker?.setVisible(true, forFirstResponder: self.canvasView)
                self.canvasView.becomeFirstResponder()
            }
        } else {
            toolPicker.setVisible(false, forFirstResponder: canvasView)
            if canvasView.isFirstResponder {
                canvasView.resignFirstResponder()
            }
        }
    }

    func setInkTool(_ tool: PageInkTool) {
        switch tool {
        case .pen:
            canvasView.tool = PKInkingTool(.pen, color: .black, width: 4.5)
        case .pencil:
            canvasView.tool = PKInkingTool(.pencil, color: .black, width: 4.0)
        case .marker:
            canvasView.tool = PKInkingTool(.marker, color: .black, width: 8.0)
        case .eraser:
            canvasView.tool = PKEraserTool(.vector)
        }
    }

    private func centerContentIfNeeded() {
        let scrollBounds = scrollView.bounds.size
        let scaledWidth = Self.a4Size.width * scrollView.zoomScale
        let scaledHeight = Self.a4Size.height * scrollView.zoomScale
        var frame = contentView.frame

        frame.origin.x = scaledWidth < scrollBounds.width
            ? (scrollBounds.width - scaledWidth) / 2
            : 0

        frame.origin.y = scaledHeight < scrollBounds.height
            ? (scrollBounds.height - scaledHeight) / 2
            : 0

        contentView.frame = frame
    }

    private func publishViewportState() {
        let fitScale = max(scrollView.minimumZoomScale, 0.000_1)
        let normalizedZoom = max(1, scrollView.zoomScale / fitScale)
        let state = CanvasViewportState(
            zoomFactor: normalizedZoom,
            contentOffset: scrollView.contentOffset,
            contentOrigin: contentView.frame.origin
        )
        onViewportStateChanged?(state)
    }

    private func lockVerticalOffsetForOverviewAndBelow() {
        guard scrollView.zoomScale <= scrollView.minimumZoomScale + 0.005 else { return }
        if abs(scrollView.contentOffset.y) > 0.5 {
            scrollView.contentOffset.y = 0
        }
    }

    private func lockHorizontalOffsetForOverviewAndBelow() {
        guard scrollView.zoomScale <= scrollView.minimumZoomScale + 0.005 else { return }
        if abs(scrollView.contentOffset.x) > 0.5 {
            scrollView.contentOffset.x = 0
        }
    }

    private func updateViewportGestureAvailability() {
        scrollView.pinchGestureRecognizer?.isEnabled = isViewportGesturesEnabled
        let pinchEnabled = scrollView.pinchGestureRecognizer?.isEnabled ?? false
        if lastLoggedPinchEnabled != pinchEnabled {
            lastLoggedPinchEnabled = pinchEnabled
            TextBoxDiagnosticsLogger.shared.log("viewportGestures.pinch enabled=\(pinchEnabled ? "true" : "false") zoom=\(String(format: "%.3f", currentZoomFactor))")
        }
        guard isViewportGesturesEnabled else {
            scrollView.panGestureRecognizer.isEnabled = false
            if lastLoggedPanEnabled != false {
                lastLoggedPanEnabled = false
                TextBoxDiagnosticsLogger.shared.log("viewportGestures.pan enabled=false zoom=\(String(format: "%.3f", currentZoomFactor))")
            }
            return
        }
        let fitScale = max(scrollView.minimumZoomScale, 0.000_1)
        scrollView.panGestureRecognizer.isEnabled = scrollView.zoomScale > fitScale + 0.01
        let panEnabled = scrollView.panGestureRecognizer.isEnabled
        if lastLoggedPanEnabled != panEnabled {
            lastLoggedPanEnabled = panEnabled
            TextBoxDiagnosticsLogger.shared.log("viewportGestures.pan enabled=\(panEnabled ? "true" : "false") zoom=\(String(format: "%.3f", currentZoomFactor))")
        }
    }

    private final class ZoomCoordinator: NSObject, UIScrollViewDelegate {
        weak var hostView: ZoomablePaperCanvasHostView?

        func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
            hostView?.onZoomGestureBegan?()
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostView?.contentView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let hostView else { return }
            let fitScale = max(scrollView.minimumZoomScale, 0.000_1)
            let normalizedFactor = scrollView.zoomScale / fitScale
            hostView.desiredZoomFactor = max(1, normalizedFactor)
            hostView.updateViewportGestureAvailability()
            hostView.centerContentIfNeeded()
            hostView.lockHorizontalOffsetForOverviewAndBelow()
            hostView.lockVerticalOffsetForOverviewAndBelow()
            hostView.publishViewportState()
            guard !hostView.isApplyingProgrammaticZoom else { return }
            hostView.onZoomFactorChanged?(normalizedFactor)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            hostView?.publishViewportState()
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            guard let hostView else { return }
            guard !hostView.isApplyingProgrammaticZoom else { return }
            let fitScale = max(scrollView.minimumZoomScale, 0.000_1)
            let normalizedFactor = scale / fitScale
            hostView.desiredZoomFactor = max(1, normalizedFactor)
            hostView.onZoomFactorChanged?(normalizedFactor)
        }
    }
}

private final class InteractiveCanvasView: PKCanvasView {
    var onTouchBegan: (() -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        onTouchBegan?()
        super.touchesBegan(touches, with: event)
    }
}

private final class PaperCanvasBackgroundUIView: UIView {
    var paperStyle: NotebookPaperStyle = .lined {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = true
        backgroundColor = UIColor(Color.paperBlank)
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isOpaque = true
        backgroundColor = UIColor(Color.paperBlank)
        contentMode = .redraw
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        context.setFillColor(UIColor(Color.paperBlank).cgColor)
        context.fill(rect)

        guard paperStyle == .lined else { return }

        let lineSpacing: CGFloat = max(10, rect.height * 0.024)
        let topOffset: CGFloat = max(40, rect.height * 0.075)
        let bottomInset: CGFloat = max(16, rect.height * 0.03)
        let marginX: CGFloat = max(28, rect.width * 0.12)
        let lineColor = UIColor(red: 0.18, green: 0.62, blue: 0.90, alpha: 1.0)
        let marginColor = UIColor(red: 0.78, green: 0.16, blue: 0.38, alpha: 0.95)

        context.setLineWidth(0.9)
        context.setStrokeColor(lineColor.cgColor)
        var y = topOffset
        while y < rect.height - bottomInset {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: rect.width, y: y))
            y += lineSpacing
        }
        context.strokePath()

        context.setStrokeColor(marginColor.cgColor)
        context.move(to: CGPoint(x: marginX, y: 0))
        context.addLine(to: CGPoint(x: marginX, y: rect.height))
        context.strokePath()
    }
}

private struct NotePDFDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.pdf]
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private enum NotePDFExporter {
    static func makePDF(for note: Note, in notebook: Notebook) throws -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let printableRect = pageRect.insetBy(dx: 36, dy: 36)

        let renderer = UIPrintPageRenderer()
        renderer.setValue(pageRect, forKey: "paperRect")
        renderer.setValue(printableRect, forKey: "printableRect")

        let textView = UITextView(frame: printableRect)
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.attributedText = makeAttributedExport(for: note, in: notebook, maxImageWidth: printableRect.width)

        renderer.addPrintFormatter(textView.viewPrintFormatter(), startingAtPageAt: 0)
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: 1))
        let pageCount = max(renderer.numberOfPages, 1)

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return pdfRenderer.pdfData { context in
            for page in 0..<pageCount {
                context.beginPage()
                renderer.drawPage(at: page, in: pageRect)
            }
        }
    }

    private static func makeAttributedExport(for note: Note, in notebook: Notebook, maxImageWidth: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let titleFont = UIFont.systemFont(ofSize: 22, weight: .bold)
        let sectionFont = UIFont.systemFont(ofSize: 14.5, weight: .semibold)
        let bodyFont = UIFont.systemFont(ofSize: 12.5, weight: .regular)
        let metaFont = UIFont.systemFont(ofSize: 10.5, weight: .regular)

        result.appendLine(note.displayTitle, font: titleFont, color: .label)
        result.appendLine(notebook.displayName + " • " + notebook.paperStyle.displayName + " paper", font: sectionFont, color: notebook.theme.uiColor)
        result.appendLine(
            "Created: \(note.createdAt.formatted(date: .abbreviated, time: .shortened))   •   Updated: \(note.updatedAt.formatted(date: .abbreviated, time: .shortened))",
            font: metaFont,
            color: .secondaryLabel
        )
        result.appendLine("", font: bodyFont, color: .clear)

        if let image = makeSketchImage(for: note, maxWidth: maxImageWidth) {
            result.appendLine("Sketch", font: sectionFont, color: .label)
            let attachment = NSTextAttachment()
            attachment.image = image
            attachment.bounds = CGRect(origin: .zero, size: image.size)
            result.append(NSAttributedString(attachment: attachment))
            result.appendLine("", font: bodyFont, color: .clear)
            result.appendLine("", font: bodyFont, color: .clear)
        }

        result.appendLine("Typed Notes (Markdown)", font: sectionFont, color: .label)

        let trimmed = note.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            result.appendLine("No typed notes", font: bodyFont, color: .secondaryLabel)
        } else if let parsed = try? AttributedString(markdown: note.body, options: .init(interpretedSyntax: .full)) {
            let ns = NSMutableAttributedString(attributedString: NSAttributedString(parsed))
            ns.addAttribute(.foregroundColor, value: UIColor.label, range: NSRange(location: 0, length: ns.length))
            result.append(ns)
        } else {
            result.appendLine(note.body, font: bodyFont, color: .label)
        }

        return result
    }

    private static func makeSketchImage(for note: Note, maxWidth: CGFloat) -> UIImage? {
        guard let drawingData = note.drawingData,
              let drawing = try? PKDrawing(data: drawingData),
              !drawing.strokes.isEmpty else { return nil }

        var bounds = drawing.bounds
        if bounds.isNull || bounds.isEmpty { return nil }
        bounds = bounds.insetBy(dx: -18, dy: -18)

        let source = drawing.image(from: bounds, scale: 2)
        guard source.size.width > 0, source.size.height > 0 else { return nil }

        let targetWidth = min(maxWidth, source.size.width)
        let scale = targetWidth / source.size.width
        let targetSize = CGSize(width: targetWidth, height: max(1, source.size.height * scale))

        return UIGraphicsImageRenderer(size: targetSize).image { _ in
            source.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

private extension NSMutableAttributedString {
    func appendLine(_ string: String, font: UIFont, color: UIColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.paragraphSpacing = 4
        append(
            NSAttributedString(
                string: string + "\n",
                attributes: [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: paragraph
                ]
            )
        )
    }
}

private extension View {
    func editorCardStyle() -> some View {
        self
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 14, y: 6)
    }
}

private extension NotebookTheme {
    var accentColor: Color {
        switch self {
        case .graphite: return Color(red: 0.29, green: 0.31, blue: 0.35)
        case .fern: return Color(red: 0.15, green: 0.55, blue: 0.30)
        case .ocean: return Color(red: 0.10, green: 0.45, blue: 0.78)
        case .amber: return Color(red: 0.82, green: 0.55, blue: 0.12)
        case .rose: return Color(red: 0.78, green: 0.33, blue: 0.41)
        case .violet: return Color(red: 0.44, green: 0.33, blue: 0.78)
        }
    }

    var coverGradient: LinearGradient {
        let colors: [Color] = {
            switch self {
            case .graphite:
                return [Color(red: 0.26, green: 0.28, blue: 0.31), Color(red: 0.43, green: 0.46, blue: 0.50)]
            case .fern:
                return [Color(red: 0.11, green: 0.47, blue: 0.24), Color(red: 0.34, green: 0.68, blue: 0.42)]
            case .ocean:
                return [Color(red: 0.07, green: 0.33, blue: 0.66), Color(red: 0.30, green: 0.61, blue: 0.90)]
            case .amber:
                return [Color(red: 0.72, green: 0.46, blue: 0.07), Color(red: 0.94, green: 0.72, blue: 0.24)]
            case .rose:
                return [Color(red: 0.63, green: 0.26, blue: 0.34), Color(red: 0.91, green: 0.52, blue: 0.60)]
            case .violet:
                return [Color(red: 0.30, green: 0.23, blue: 0.63), Color(red: 0.63, green: 0.53, blue: 0.94)]
            }
        }()
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var uiColor: UIColor {
        switch self {
        case .graphite: return UIColor(red: 0.29, green: 0.31, blue: 0.35, alpha: 1)
        case .fern: return UIColor(red: 0.15, green: 0.55, blue: 0.30, alpha: 1)
        case .ocean: return UIColor(red: 0.10, green: 0.45, blue: 0.78, alpha: 1)
        case .amber: return UIColor(red: 0.82, green: 0.55, blue: 0.12, alpha: 1)
        case .rose: return UIColor(red: 0.78, green: 0.33, blue: 0.41, alpha: 1)
        case .violet: return UIColor(red: 0.44, green: 0.33, blue: 0.78, alpha: 1)
        }
    }
}

private extension Color {
    static let accentInk = Color(red: 0.14, green: 0.50, blue: 0.33)
    static let paperBlank = Color(red: 0.995, green: 0.995, blue: 0.985)
}

private final class TextBoxDiagnosticsLogger {
    static let shared = TextBoxDiagnosticsLogger()
    private static let isEnabled: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.environment["TEXTBOX_DIAGNOSTICS"] == "1"
        #else
        return false
        #endif
    }()

    private let queue = DispatchQueue(label: "com.cortex.ipadnotes.textbox-diagnostics")
    private let fileManager = FileManager.default
    private let formatter: ISO8601DateFormatter
    private let fileURL: URL

    private init() {
        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            fileURL = docs.appendingPathComponent("TextBoxDiagnostics.log")
        } else {
            fileURL = fileManager.temporaryDirectory.appendingPathComponent("TextBoxDiagnostics.log")
        }

        guard Self.isEnabled else { return }
        ensureLogFileExists()
        log("session.start appVersion=\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown") build=\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown") device=\(UIDevice.current.model) system=\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
    }

    var persistentLogURL: URL {
        fileURL
    }

    func clear() {
        guard Self.isEnabled else { return }
        queue.sync {
            try? fileManager.removeItem(at: fileURL)
            ensureLogFileExists()
        }
        log("session.clear")
    }

    func exportSnapshotURL() -> URL? {
        guard Self.isEnabled else { return nil }
        return queue.sync {
            ensureLogFileExists()
            guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
            let stamp = snapshotTimestamp()
            let snapshotURL = fileManager.temporaryDirectory
                .appendingPathComponent("TextBoxDiagnostics-\(stamp)")
                .appendingPathExtension("log")
            try? fileManager.removeItem(at: snapshotURL)
            do {
                try fileManager.copyItem(at: fileURL, to: snapshotURL)
                return snapshotURL
            } catch {
                return nil
            }
        }
    }

    func log(_ message: String) {
        guard Self.isEnabled else { return }
        let timestamp = formatter.string(from: Date())
        let line = "\(timestamp) \(message)"
        queue.async { [self] in
            ensureLogFileExists()
            guard let data = (line + "\n").data(using: .utf8) else { return }
            guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
        }
    }

    private func ensureLogFileExists() {
        if !fileManager.fileExists(atPath: fileURL.path) {
            fileManager.createFile(atPath: fileURL.path, contents: nil)
        }
    }

    private func snapshotTimestamp() -> String {
        let date = Date()
        let calendar = Calendar(identifier: .gregorian)
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = comps.year ?? 0
        let month = comps.month ?? 0
        let day = comps.day ?? 0
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        let second = comps.second ?? 0
        return String(format: "%04d%02d%02d-%02d%02d%02d", year, month, day, hour, minute, second)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
