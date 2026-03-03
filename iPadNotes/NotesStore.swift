import Foundation
import SwiftUI

@MainActor
final class NotesStore: ObservableObject {
    @Published private(set) var notebooks: [Notebook] = []
    @Published private(set) var notes: [Note] = []
    @Published var selectedNotebookID: Notebook.ID?
    @Published var selectedNoteID: Note.ID?
    @Published var searchText = ""

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init() {
        load()

        if notebooks.isEmpty {
            let sample = Self.sampleLibrary()
            notebooks = sample.notebooks
            notes = sample.notes
        }

        ensurePageOrderingAssigned()
        normalizeInlineTextBoxesGeometry()
        normalizeMediaBoxesGeometry()
        sortInMemory()
        ensureSelections()
        save()
    }

    var selectedNotebook: Notebook? {
        guard let selectedNotebookID else { return nil }
        return notebooks.first(where: { $0.id == selectedNotebookID })
    }

    var selectedNote: Note? {
        guard let selectedNoteID else { return nil }
        return notes.first(where: { $0.id == selectedNoteID })
    }

    var visibleNotes: [Note] {
        guard let selectedNotebookID else { return [] }
        return notes
            .filter { $0.notebookID == selectedNotebookID }
            .sorted(by: noteSort)
    }

    func notebook(withID id: Notebook.ID) -> Notebook? {
        notebooks.first(where: { $0.id == id })
    }

    func note(withID id: Note.ID) -> Note? {
        notes.first(where: { $0.id == id })
    }

    func pageCount(in notebookID: Notebook.ID) -> Int {
        notes.reduce(into: 0) { count, note in
            if note.notebookID == notebookID { count += 1 }
        }
    }

    @discardableResult
    func createNotebook(named rawName: String? = nil, theme: NotebookTheme? = nil, paperStyle: NotebookPaperStyle = .lined) -> Notebook.ID {
        let now = Date()
        let notebook = Notebook(
            name: normalizedNotebookName(rawName),
            theme: theme ?? nextNotebookTheme(),
            paperStyle: paperStyle,
            createdAt: now,
            updatedAt: now
        )
        notebooks.append(notebook)
        selectedNotebookID = notebook.id
        createPage(in: notebook.id, title: "Page 1", selectAfterCreate: true)
        sortAndPersist()
        return notebook.id
    }

    func updateNotebookPaperStyle(_ paperStyle: NotebookPaperStyle, for notebookID: Notebook.ID) {
        guard let index = notebooks.firstIndex(where: { $0.id == notebookID }) else { return }
        guard notebooks[index].paperStyle != paperStyle else { return }
        notebooks[index].paperStyle = paperStyle
        notebooks[index].updatedAt = Date()
        sortAndPersist()
    }

    func deleteNotebook(_ notebookID: Notebook.ID) {
        notebooks.removeAll { $0.id == notebookID }
        notes.removeAll { $0.notebookID == notebookID }

        if notebooks.isEmpty {
            let replacement = Notebook(name: "Notebook 1", theme: .graphite, paperStyle: .lined)
            let firstPage = Note(notebookID: replacement.id, title: "Page 1", pageOrder: 1)
            notebooks = [replacement]
            notes = [firstPage]
            selectedNotebookID = replacement.id
            selectedNoteID = firstPage.id
            save()
            return
        }

        sortInMemory()
        ensureSelections()
        save()
    }

    func createPage() {
        guard let notebookID = selectedNotebookID ?? notebooks.first?.id else { return }
        let nextPageNumber = pageCount(in: notebookID) + 1
        createPage(in: notebookID, title: "Page \(nextPageNumber)", selectAfterCreate: true)
        sortAndPersist()
    }

    func insertPageBeforeSelected() {
        guard let selectedNoteID else {
            createPage()
            return
        }
        insertPage(before: selectedNoteID)
    }

    func insertPageAfterSelected() {
        guard let selectedNoteID else {
            createPage()
            return
        }
        insertPage(after: selectedNoteID)
    }

    func insertPage(before noteID: Note.ID) {
        guard let anchor = note(withID: noteID) else { return }
        let pageNumber = pageCount(in: anchor.notebookID) + 1
        let order = insertedPageOrder(in: anchor.notebookID, relativeTo: anchor.id, before: true)
        createPage(
            in: anchor.notebookID,
            title: "Page \(pageNumber)",
            pageOrder: order,
            selectAfterCreate: true
        )
        sortAndPersist()
    }

    func insertPage(after noteID: Note.ID) {
        guard let anchor = note(withID: noteID) else { return }
        let pageNumber = pageCount(in: anchor.notebookID) + 1
        let order = insertedPageOrder(in: anchor.notebookID, relativeTo: anchor.id, before: false)
        createPage(
            in: anchor.notebookID,
            title: "Page \(pageNumber)",
            pageOrder: order,
            selectAfterCreate: true
        )
        sortAndPersist()
    }

    func importPDFPages(_ pageImages: [Data], sourceName: String? = nil, insertAfter selectedPageID: Note.ID? = nil) {
        guard !pageImages.isEmpty else { return }
        guard let notebookID = selectedNotebookID ?? notebooks.first?.id else { return }

        let anchorID = selectedPageID ?? selectedNoteID
        let pageTitlePrefix: String = {
            let trimmed = (sourceName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Imported PDF" : trimmed
        }()

        var lastInsertedID = anchorID
        let now = Date()

        for (index, imageData) in pageImages.enumerated() {
            let order = lastInsertedID.map { insertedPageOrder(in: notebookID, relativeTo: $0, before: false) } ?? nextPageOrder(in: notebookID)
            let page = Note(
                notebookID: notebookID,
                title: "\(pageTitlePrefix) • Page \(index + 1)",
                body: "",
                drawingData: nil,
                pageOrder: order,
                backgroundImageData: imageData,
                createdAt: now,
                updatedAt: now
            )
            notes.append(page)
            lastInsertedID = page.id
            selectedNoteID = page.id
        }

        selectedNotebookID = notebookID
        touchNotebook(notebookID, at: now)
        sortAndPersist()
    }

    func duplicateSelectedPage() {
        guard let page = selectedNote else { return }
        let now = Date()
        let duplicate = Note(
            notebookID: page.notebookID,
            title: page.displayTitle + " Copy",
            body: page.body,
            drawingData: page.drawingData,
            pageOrder: insertedPageOrder(in: page.notebookID, relativeTo: page.id, before: false),
            backgroundImageData: page.backgroundImageData,
            pagePaperStyleOverride: page.pagePaperStyleOverride,
            typedTextStyle: page.typedTextStyle,
            inlineTextBoxes: page.inlineTextBoxes,
            mediaBoxes: page.mediaBoxes,
            createdAt: now,
            updatedAt: now
        )
        notes.append(duplicate)
        selectedNotebookID = page.notebookID
        selectedNoteID = duplicate.id
        touchNotebook(page.notebookID, at: now)
        sortAndPersist()
    }

    func deleteSelectedPage() {
        guard let selectedNoteID else { return }
        deletePage(id: selectedNoteID)
    }

    func deletePage(id: Note.ID) {
        guard let note = note(withID: id) else { return }
        notes.removeAll { $0.id == id }
        touchNotebook(note.notebookID, at: Date())

        if pageCount(in: note.notebookID) == 0 {
            createPage(in: note.notebookID, title: "Page 1", selectAfterCreate: true)
        }

        sortInMemory()
        ensureSelections()
        save()
    }

    func selectNotebook(_ notebookID: Notebook.ID) {
        selectedNotebookID = notebookID
        ensureSelections()
    }

    func selectPage(_ noteID: Note.ID) {
        selectedNoteID = noteID
        if let note = note(withID: noteID) {
            selectedNotebookID = note.notebookID
        }
    }

    func updateTitle(for noteID: Note.ID, to title: String) {
        updateNote(noteID: noteID) { note in
            guard note.title != title else { return }
            note.title = title
            note.updatedAt = Date()
        }
    }

    func updateBody(for noteID: Note.ID, to body: String) {
        updateNote(noteID: noteID) { note in
            guard note.body != body else { return }
            note.body = body
            note.updatedAt = Date()
        }
    }

    func updateTypedTextStyle(for noteID: Note.ID, to style: NoteTextStyle) {
        updateNote(noteID: noteID) { note in
            guard note.typedTextStyle != style else { return }
            note.typedTextStyle = style
            note.updatedAt = Date()
        }
    }

    @discardableResult
    func addInlineTextBox(
        for noteID: Note.ID,
        text: String = "",
        centerX: Double = 0.5,
        centerY: Double = 0.5,
        width: Double = 0.42,
        height: Double = 0.16,
        rotationDegrees: Double = 0
    ) -> UUID? {
        var insertedID: UUID?
        updateNote(noteID: noteID) { note in
            let box = NoteTextBox(
                contentType: .text,
                text: text,
                imageData: nil,
                isContainerStyle: false,
                centerX: centerX,
                centerY: centerY,
                width: width,
                height: height,
                rotationDegrees: rotationDegrees,
                style: note.typedTextStyle
            )
            note.inlineTextBoxes.append(box)
            note.updatedAt = Date()
            insertedID = box.id
        }
        return insertedID
    }

    @discardableResult
    func addMediaBox(
        for noteID: Note.ID,
        imageData: Data? = nil,
        isContainerStyle: Bool = true,
        centerX: Double = 0.5,
        centerY: Double = 0.5,
        width: Double = 0.42,
        height: Double = 0.16,
        rotationDegrees: Double = 0
    ) -> UUID? {
        var insertedID: UUID?
        updateNote(noteID: noteID) { note in
            let box = NoteTextBox(
                contentType: .image,
                text: "",
                imageData: imageData,
                isContainerStyle: isContainerStyle,
                centerX: centerX,
                centerY: centerY,
                width: width,
                height: height,
                rotationDegrees: rotationDegrees,
                style: note.typedTextStyle
            )
            note.mediaBoxes.append(box)
            note.updatedAt = Date()
            insertedID = box.id
        }
        return insertedID
    }

    func updateInlineTextBoxText(for noteID: Note.ID, boxID: UUID, to text: String) {
        updateNote(noteID: noteID) { note in
            guard let index = note.inlineTextBoxes.firstIndex(where: { $0.id == boxID }) else { return }
            let existing = note.inlineTextBoxes[index]
            guard existing.text != text || existing.contentType != .text || existing.imageData != nil else { return }
            note.inlineTextBoxes[index].text = text
            note.inlineTextBoxes[index].contentType = .text
            note.inlineTextBoxes[index].imageData = nil
            note.inlineTextBoxes[index].isContainerStyle = false
            note.updatedAt = Date()
        }
    }

    func updateInlineTextBoxFrame(
        for noteID: Note.ID,
        boxID: UUID,
        centerX: Double,
        centerY: Double,
        width: Double,
        height: Double,
        rotationDegrees: Double? = nil
    ) {
        updateNote(noteID: noteID) { note in
            guard let index = note.inlineTextBoxes.firstIndex(where: { $0.id == boxID }) else { return }
            let clampedWidth = sanitizedDimension(width, fallback: note.inlineTextBoxes[index].width, min: 0.035, max: 0.92)
            let clampedHeight = sanitizedDimension(height, fallback: note.inlineTextBoxes[index].height, min: 0.03, max: 0.86)
            let normalizedRotation = normalizeRotationDegrees(rotationDegrees ?? note.inlineTextBoxes[index].rotationDegrees)
            let radians = normalizedRotation * .pi / 180
            let halfWidth = clampedWidth / 2
            let halfHeight = clampedHeight / 2
            let horizontalExtent = abs(cos(radians)) * halfWidth + abs(sin(radians)) * halfHeight
            let verticalExtent = abs(sin(radians)) * halfWidth + abs(cos(radians)) * halfHeight
            let safeCenterX = finiteOr(centerX, fallback: note.inlineTextBoxes[index].centerX)
            let safeCenterY = finiteOr(centerY, fallback: note.inlineTextBoxes[index].centerY)
            let clampedCenterX = min(max(safeCenterX, horizontalExtent), 1.0 - horizontalExtent)
            let clampedCenterY = min(max(safeCenterY, verticalExtent), 1.0 - verticalExtent)
            let existing = note.inlineTextBoxes[index]
            guard existing.centerX != clampedCenterX ||
                  existing.centerY != clampedCenterY ||
                  existing.width != clampedWidth ||
                  existing.height != clampedHeight ||
                  existing.rotationDegrees != normalizedRotation else { return }
            note.inlineTextBoxes[index].centerX = clampedCenterX
            note.inlineTextBoxes[index].centerY = clampedCenterY
            note.inlineTextBoxes[index].width = clampedWidth
            note.inlineTextBoxes[index].height = clampedHeight
            note.inlineTextBoxes[index].rotationDegrees = normalizedRotation
            note.updatedAt = Date()
        }
    }

    func updateMediaBoxFrame(
        for noteID: Note.ID,
        boxID: UUID,
        centerX: Double,
        centerY: Double,
        width: Double,
        height: Double,
        rotationDegrees: Double? = nil,
        clampTopEdge: Bool = true,
        clampBottomEdge: Bool = true
    ) {
        updateNote(noteID: noteID) { note in
            guard let index = note.mediaBoxes.firstIndex(where: { $0.id == boxID }) else { return }
            let clampedWidth = sanitizedDimension(width, fallback: note.mediaBoxes[index].width, min: 0.035, max: 0.92)
            let clampedHeight = sanitizedDimension(height, fallback: note.mediaBoxes[index].height, min: 0.03, max: 0.86)
            let normalizedRotation = normalizeRotationDegrees(rotationDegrees ?? note.mediaBoxes[index].rotationDegrees)
            let extents = rotatedHalfExtents(width: clampedWidth, height: clampedHeight, rotationDegrees: normalizedRotation)
            let safeCenterX = finiteOr(centerX, fallback: note.mediaBoxes[index].centerX)
            let safeCenterY = finiteOr(centerY, fallback: note.mediaBoxes[index].centerY)
            let clampedCenterX = min(max(safeCenterX, extents.horizontal), 1.0 - extents.horizontal)
            let minY = clampTopEdge ? extents.vertical : -Double.infinity
            let maxY = clampBottomEdge ? (1.0 - extents.vertical) : Double.infinity
            let clampedCenterY = min(max(safeCenterY, minY), maxY)
            let existing = note.mediaBoxes[index]
            guard existing.centerX != clampedCenterX ||
                  existing.centerY != clampedCenterY ||
                  existing.width != clampedWidth ||
                  existing.height != clampedHeight ||
                  existing.rotationDegrees != normalizedRotation else { return }
            note.mediaBoxes[index].centerX = clampedCenterX
            note.mediaBoxes[index].centerY = clampedCenterY
            note.mediaBoxes[index].width = clampedWidth
            note.mediaBoxes[index].height = clampedHeight
            note.mediaBoxes[index].rotationDegrees = normalizedRotation
            note.updatedAt = Date()
        }
    }

    private func normalizeMediaBoxesGeometry() {
        var firstPageIDs: Set<UUID> = []
        var lastPageIDs: Set<UUID> = []
        let notebookIDs = Set(notes.map(\.notebookID))
        for notebookID in notebookIDs {
            let ordered = notes
                .filter { $0.notebookID == notebookID }
                .sorted(by: noteSort)
            if let first = ordered.first?.id {
                firstPageIDs.insert(first)
            }
            if let last = ordered.last?.id {
                lastPageIDs.insert(last)
            }
        }

        for noteIndex in notes.indices {
            var note = notes[noteIndex]
            var changed = false
            let clampTopEdge = firstPageIDs.contains(note.id)
            let clampBottomEdge = lastPageIDs.contains(note.id)
            for boxIndex in note.mediaBoxes.indices {
                let existing = note.mediaBoxes[boxIndex]
                let clampedWidth = sanitizedDimension(existing.width, fallback: 0.42, min: 0.035, max: 0.92)
                let clampedHeight = sanitizedDimension(existing.height, fallback: 0.16, min: 0.03, max: 0.86)
                let normalizedRotation = normalizeRotationDegrees(existing.rotationDegrees)
                let extents = rotatedHalfExtents(width: clampedWidth, height: clampedHeight, rotationDegrees: normalizedRotation)
                let safeCenterX = finiteOr(existing.centerX, fallback: 0.5)
                let safeCenterY = finiteOr(existing.centerY, fallback: 0.5)
                let clampedCenterX = min(max(safeCenterX, extents.horizontal), 1.0 - extents.horizontal)
                let minY = clampTopEdge ? extents.vertical : -Double.infinity
                let maxY = clampBottomEdge ? (1.0 - extents.vertical) : Double.infinity
                let clampedCenterY = min(max(safeCenterY, minY), maxY)

                if existing.centerX != clampedCenterX ||
                    existing.centerY != clampedCenterY ||
                    existing.width != clampedWidth ||
                    existing.height != clampedHeight ||
                    existing.rotationDegrees != normalizedRotation {
                    note.mediaBoxes[boxIndex].centerX = clampedCenterX
                    note.mediaBoxes[boxIndex].centerY = clampedCenterY
                    note.mediaBoxes[boxIndex].width = clampedWidth
                    note.mediaBoxes[boxIndex].height = clampedHeight
                    note.mediaBoxes[boxIndex].rotationDegrees = normalizedRotation
                    changed = true
                }
            }
            if changed {
                note.updatedAt = Date()
                notes[noteIndex] = note
            }
        }
    }

    private func normalizeInlineTextBoxesGeometry() {
        for noteIndex in notes.indices {
            var note = notes[noteIndex]
            var changed = false
            for boxIndex in note.inlineTextBoxes.indices {
                let existing = note.inlineTextBoxes[boxIndex]
                let clampedWidth = sanitizedDimension(existing.width, fallback: 0.42, min: 0.035, max: 0.92)
                let clampedHeight = sanitizedDimension(existing.height, fallback: 0.16, min: 0.03, max: 0.86)
                let normalizedRotation = normalizeRotationDegrees(existing.rotationDegrees)
                let extents = rotatedHalfExtents(width: clampedWidth, height: clampedHeight, rotationDegrees: normalizedRotation)
                let safeCenterX = finiteOr(existing.centerX, fallback: 0.5)
                let safeCenterY = finiteOr(existing.centerY, fallback: 0.5)
                let clampedCenterX = min(max(safeCenterX, extents.horizontal), 1.0 - extents.horizontal)
                let clampedCenterY = min(max(safeCenterY, extents.vertical), 1.0 - extents.vertical)

                if existing.centerX != clampedCenterX ||
                    existing.centerY != clampedCenterY ||
                    existing.width != clampedWidth ||
                    existing.height != clampedHeight ||
                    existing.rotationDegrees != normalizedRotation {
                    note.inlineTextBoxes[boxIndex].centerX = clampedCenterX
                    note.inlineTextBoxes[boxIndex].centerY = clampedCenterY
                    note.inlineTextBoxes[boxIndex].width = clampedWidth
                    note.inlineTextBoxes[boxIndex].height = clampedHeight
                    note.inlineTextBoxes[boxIndex].rotationDegrees = normalizedRotation
                    changed = true
                }
            }
            if changed {
                note.updatedAt = Date()
                notes[noteIndex] = note
            }
        }
    }

    func updateInlineTextBoxStyle(for noteID: Note.ID, boxID: UUID, to style: NoteTextStyle) {
        updateNote(noteID: noteID) { note in
            guard let index = note.inlineTextBoxes.firstIndex(where: { $0.id == boxID }) else { return }
            guard note.inlineTextBoxes[index].style != style else { return }
            note.inlineTextBoxes[index].style = style
            note.updatedAt = Date()
        }
    }

    func updateMediaBoxImage(for noteID: Note.ID, boxID: UUID, imageData: Data) {
        updateNote(noteID: noteID) { note in
            guard let index = note.mediaBoxes.firstIndex(where: { $0.id == boxID }) else { return }
            note.mediaBoxes[index].contentType = .image
            note.mediaBoxes[index].imageData = imageData
            note.mediaBoxes[index].text = ""
            note.mediaBoxes[index].isContainerStyle = true
            note.updatedAt = Date()
        }
    }

    func deleteInlineTextBox(for noteID: Note.ID, boxID: UUID) {
        updateNote(noteID: noteID) { note in
            let originalCount = note.inlineTextBoxes.count
            note.inlineTextBoxes.removeAll { $0.id == boxID }
            guard note.inlineTextBoxes.count != originalCount else { return }
            note.updatedAt = Date()
        }
    }

    func deleteMediaBox(for noteID: Note.ID, boxID: UUID) {
        updateNote(noteID: noteID) { note in
            let originalCount = note.mediaBoxes.count
            note.mediaBoxes.removeAll { $0.id == boxID }
            guard note.mediaBoxes.count != originalCount else { return }
            note.updatedAt = Date()
        }
    }
    
    func moveMediaBox(
        boxID: UUID,
        fromNoteID: Note.ID,
        toNoteID: Note.ID,
        centerX: Double,
        centerY: Double,
        width: Double,
        height: Double,
        rotationDegrees: Double = 0,
        clampTopEdge: Bool = true,
        clampBottomEdge: Bool = true
    ) {
        guard fromNoteID != toNoteID else { return }
        var boxToMove: NoteTextBox?
        updateNote(noteID: fromNoteID) { note in
            guard let index = note.mediaBoxes.firstIndex(where: { $0.id == boxID }) else { return }
            boxToMove = note.mediaBoxes[index]
            note.mediaBoxes.remove(at: index)
            note.updatedAt = Date()
        }
        guard var box = boxToMove else { return }
        let normalizedRotation = normalizeRotationDegrees(rotationDegrees)
        let safeWidth = sanitizedDimension(width, fallback: box.width, min: 0.035, max: 0.92)
        let safeHeight = sanitizedDimension(height, fallback: box.height, min: 0.03, max: 0.86)
        let extents = rotatedHalfExtents(width: safeWidth, height: safeHeight, rotationDegrees: normalizedRotation)
        let safeCenterX = finiteOr(centerX, fallback: box.centerX)
        let safeCenterY = finiteOr(centerY, fallback: box.centerY)
        box.centerX = min(max(safeCenterX, extents.horizontal), 1.0 - extents.horizontal)
        let minY = clampTopEdge ? extents.vertical : -Double.infinity
        let maxY = clampBottomEdge ? (1.0 - extents.vertical) : Double.infinity
        box.centerY = min(max(safeCenterY, minY), maxY)
        box.width = safeWidth
        box.height = safeHeight
        box.rotationDegrees = normalizedRotation
        updateNote(noteID: toNoteID) { note in
            note.mediaBoxes.append(box)
            note.updatedAt = Date()
        }
    }

    private func normalizeRotationDegrees(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        var normalized = value.truncatingRemainder(dividingBy: 360)
        if normalized > 180 {
            normalized -= 360
        } else if normalized <= -180 {
            normalized += 360
        }
        return normalized
    }

    private func finiteOr(_ value: Double, fallback: Double) -> Double {
        if value.isFinite { return value }
        return fallback.isFinite ? fallback : 0
    }

    private func sanitizedDimension(_ value: Double, fallback: Double, min: Double, max: Double) -> Double {
        let safe = finiteOr(value, fallback: fallback)
        return Swift.min(Swift.max(safe, min), max)
    }

    private func rotatedHalfExtents(width: Double, height: Double, rotationDegrees: Double) -> (horizontal: Double, vertical: Double) {
        let radians = rotationDegrees * .pi / 180
        let halfWidth = width / 2
        let halfHeight = height / 2
        let horizontal = abs(cos(radians)) * halfWidth + abs(sin(radians)) * halfHeight
        let vertical = abs(sin(radians)) * halfWidth + abs(cos(radians)) * halfHeight
        return (horizontal, vertical)
    }


    func updateDrawing(for noteID: Note.ID, to drawingData: Data?) {
        let normalized = drawingData?.isEmpty == true ? nil : drawingData
        updateNote(noteID: noteID) { note in
            guard note.drawingData != normalized else { return }
            note.drawingData = normalized
            note.updatedAt = Date()
        }
    }


    func createPage(after noteID: Note.ID? = nil, paperStyleOverride: NotebookPaperStyle? = nil, backgroundImageData: Data? = nil, title: String? = nil) {
        guard let notebookID = selectedNotebookID ?? notebooks.first?.id else { return }
        let baseTitle = title ?? "Page \(pageCount(in: notebookID) + 1)"
        let order = noteID.map { insertedPageOrder(in: notebookID, relativeTo: $0, before: false) } ?? nextPageOrder(in: notebookID)
        createPage(
            in: notebookID,
            title: baseTitle,
            pageOrder: order,
            backgroundImageData: backgroundImageData,
            paperStyleOverride: paperStyleOverride,
            selectAfterCreate: true
        )
        sortAndPersist()
    }

    func reorderPages(in notebookID: Notebook.ID, fromOffsets: IndexSet, toOffset: Int) {
        var ordered = notes
            .filter { $0.notebookID == notebookID }
            .sorted(by: noteSort)
        guard !ordered.isEmpty else { return }
        ordered.move(fromOffsets: fromOffsets, toOffset: toOffset)
        let now = Date()
        for (index, page) in ordered.enumerated() {
            guard let noteIndex = notes.firstIndex(where: { $0.id == page.id }) else { continue }
            notes[noteIndex].pageOrder = Double(index + 1)
            notes[noteIndex].updatedAt = now
        }
        touchNotebook(notebookID, at: now)
        sortAndPersist()
    }

    func clearBackgroundImage(for noteID: Note.ID) {
        updateNote(noteID: noteID) { note in
            guard note.backgroundImageData != nil else { return }
            note.backgroundImageData = nil
            note.updatedAt = Date()
        }
    }

    private func createPage(
        in notebookID: Notebook.ID,
        title: String,
        pageOrder: Double? = nil,
        backgroundImageData: Data? = nil,
        paperStyleOverride: NotebookPaperStyle? = nil,
        selectAfterCreate: Bool
    ) {
        let now = Date()
        let note = Note(
            notebookID: notebookID,
            title: title,
            body: "",
            drawingData: nil,
            pageOrder: pageOrder ?? nextPageOrder(in: notebookID),
            backgroundImageData: backgroundImageData,
            pagePaperStyleOverride: paperStyleOverride,
            createdAt: now,
            updatedAt: now
        )
        notes.append(note)
        touchNotebook(notebookID, at: now)
        if selectAfterCreate {
            selectedNotebookID = notebookID
            selectedNoteID = note.id
        }
    }

    private func updateNote(noteID: Note.ID, mutation: (inout Note) -> Void) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        let before = notes[index]
        mutation(&notes[index])
        guard notes[index] != before else { return }
        touchNotebook(notes[index].notebookID, at: notes[index].updatedAt)
        sortAndPersist()
    }

    private func nextPageOrder(in notebookID: Notebook.ID) -> Double {
        let existing = notes
            .filter { $0.notebookID == notebookID }
            .compactMap(\.pageOrder)
        if let maxOrder = existing.max() {
            return maxOrder + 1
        }
        let count = notes.reduce(into: 0) { total, note in
            if note.notebookID == notebookID { total += 1 }
        }
        return Double(count + 1)
    }

    private func insertedPageOrder(in notebookID: Notebook.ID, relativeTo anchorID: Note.ID, before: Bool) -> Double {
        ensurePageOrderingAssigned(in: notebookID)
        let ordered = notes
            .filter { $0.notebookID == notebookID }
            .sorted(by: noteSort)
        guard let anchorIndex = ordered.firstIndex(where: { $0.id == anchorID }) else {
            return nextPageOrder(in: notebookID)
        }

        let anchorOrder = ordered[anchorIndex].pageOrder ?? Double(anchorIndex + 1)
        let neighborIndex = before ? anchorIndex - 1 : anchorIndex + 1

        if neighborIndex >= 0 && neighborIndex < ordered.count {
            let neighborOrder = ordered[neighborIndex].pageOrder ?? Double(neighborIndex + 1)
            let low = before ? neighborOrder : anchorOrder
            let high = before ? anchorOrder : neighborOrder
            let candidate = (low + high) / 2
            if abs(high - low) > 0.000_001 {
                return candidate
            }
        }

        if before {
            return anchorOrder - 1
        }
        return anchorOrder + 1
    }

    private func touchNotebook(_ notebookID: Notebook.ID, at date: Date) {
        guard let index = notebooks.firstIndex(where: { $0.id == notebookID }) else { return }
        if notebooks[index].updatedAt < date {
            notebooks[index].updatedAt = date
        }
    }

    private func matchesSearch(_ note: Note) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let haystack = [note.title, note.body].joined(separator: "\n")
        return haystack.localizedCaseInsensitiveContains(query)
    }

    private func normalizedNotebookName(_ rawName: String?) -> String {
        let trimmed = (rawName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return nextNotebookName()
    }

    private func nextNotebookName() -> String {
        let existing = Set(notebooks.map { $0.displayName.lowercased() })
        var number = max(1, notebooks.count + 1)
        while existing.contains("notebook \(number)") {
            number += 1
        }
        return "Notebook \(number)"
    }

    private func nextNotebookTheme() -> NotebookTheme {
        let themes = NotebookTheme.allCases
        guard !themes.isEmpty else { return .graphite }
        return themes[notebooks.count % themes.count]
    }

    private func ensurePageOrderingAssigned() {
        let notebookIDs = Set(notes.map(\.notebookID))
        for notebookID in notebookIDs {
            ensurePageOrderingAssigned(in: notebookID)
        }
    }

    private func ensurePageOrderingAssigned(in notebookID: Notebook.ID) {
        let indexes = notes.indices.filter { notes[$0].notebookID == notebookID }
        guard !indexes.isEmpty else { return }

        let needsRepair = indexes.contains { notes[$0].pageOrder == nil }
        guard needsRepair else { return }

        let sortedIndexes = indexes.sorted { lhs, rhs in
            let left = notes[lhs]
            let right = notes[rhs]
            if left.createdAt != right.createdAt { return left.createdAt < right.createdAt }
            return left.id.uuidString < right.id.uuidString
        }

        for (offset, idx) in sortedIndexes.enumerated() {
            notes[idx].pageOrder = Double(offset + 1)
        }
    }

    private func ensureSelections() {
        if selectedNotebookID == nil || !notebooks.contains(where: { $0.id == selectedNotebookID }) {
            selectedNotebookID = notebooks.first?.id
        }

        if let selectedNoteID,
           let selectedNotebookID,
           notes.contains(where: { $0.id == selectedNoteID && $0.notebookID == selectedNotebookID }) {
            return
        }

        if let selectedNotebookID {
            selectedNoteID = notes
                .filter { $0.notebookID == selectedNotebookID }
                .sorted(by: noteSort)
                .first?
                .id
        } else {
            selectedNoteID = nil
        }
    }

    private func sortAndPersist() {
        sortInMemory()
        ensureSelections()
        save()
    }

    private func sortInMemory() {
        notebooks.sort(by: notebookSort)
        notes.sort(by: noteSort)
    }

    private func notebookSort(_ lhs: Notebook, _ rhs: Notebook) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        return lhs.createdAt > rhs.createdAt
    }

    private func noteSort(_ lhs: Note, _ rhs: Note) -> Bool {
        if lhs.notebookID == rhs.notebookID {
            let lhsOrder = lhs.pageOrder ?? .greatestFiniteMagnitude
            let rhsOrder = rhs.pageOrder ?? .greatestFiniteMagnitude
            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        return lhs.createdAt > rhs.createdAt
    }

    private func storageURL() throws -> URL {
        let fm = FileManager.default
        let base = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("iPadNotes", isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("notes.json", isDirectory: false)
    }

    private func load() {
        do {
            let url = try storageURL()
            guard FileManager.default.fileExists(atPath: url.path()) else {
                notebooks = []
                notes = []
                return
            }

            let data = try Data(contentsOf: url)

            if let document = try? decoder.decode(NotesLibraryDocument.self, from: data) {
                notebooks = document.notebooks
                notes = document.notes
                return
            }

            if let legacyNotes = try? decoder.decode([LegacyNoteV1].self, from: data) {
                let migrated = Self.migrateLegacyNotes(legacyNotes)
                notebooks = migrated.notebooks
                notes = migrated.notes
                return
            }

            notebooks = []
            notes = []
        } catch {
            notebooks = []
            notes = []
        }
    }

    private func save() {
        do {
            // Defensive sweep in case gesture state ever produces a non-finite geometry value.
            normalizeInlineTextBoxesGeometry()
            normalizeMediaBoxesGeometry()
            let document = NotesLibraryDocument(notebooks: notebooks, notes: notes)
            let data = try encoder.encode(document)
            let url = try storageURL()
            try data.write(to: url, options: [.atomic])
        } catch {
            assertionFailure("Failed to save notes library: \(error)")
        }
    }

    private static func migrateLegacyNotes(_ legacyNotes: [LegacyNoteV1]) -> (notebooks: [Notebook], notes: [Note]) {
        let notebook = Notebook(name: "Imported Notebook", theme: .graphite, paperStyle: .lined)
        let migratedNotes = legacyNotes.map { legacy in
            Note(
                id: legacy.id,
                notebookID: notebook.id,
                title: legacy.title,
                body: legacy.body,
                drawingData: legacy.drawingData,
                createdAt: legacy.createdAt,
                updatedAt: legacy.updatedAt
            )
        }
        return ([notebook], migratedNotes.isEmpty ? [Note(notebookID: notebook.id, title: "Page 1")] : migratedNotes)
    }

    private static func sampleLibrary() -> (notebooks: [Notebook], notes: [Note]) {
        let now = Date()

        let school = Notebook(
            name: "School Notes",
            theme: .ocean,
            paperStyle: .lined,
            createdAt: now.addingTimeInterval(-86_400 * 6),
            updatedAt: now.addingTimeInterval(-1_400)
        )
        let ideas = Notebook(
            name: "Concept Sketches",
            theme: .fern,
            paperStyle: .blank,
            createdAt: now.addingTimeInterval(-86_400 * 2),
            updatedAt: now.addingTimeInterval(-4_000)
        )

        let notes = [
            Note(
                notebookID: school.id,
                title: "Meeting Notes",
                body: "Math lecture summary and formulas.",
                createdAt: now.addingTimeInterval(-86_400 * 2),
                updatedAt: now.addingTimeInterval(-2_400)
            ),
            Note(
                notebookID: school.id,
                title: "Homework Workings",
                body: "Use lined pages for derivations and problem steps.",
                createdAt: now.addingTimeInterval(-86_400),
                updatedAt: now.addingTimeInterval(-5_200)
            ),
            Note(
                notebookID: ideas.id,
                title: "Storyboard 01",
                body: "Blank page for sketching rough layouts.",
                createdAt: now.addingTimeInterval(-43_200),
                updatedAt: now.addingTimeInterval(-3_200)
            )
        ]

        return ([school, ideas], notes)
    }
}
