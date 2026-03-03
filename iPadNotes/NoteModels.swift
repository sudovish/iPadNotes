import Foundation

enum NoteFontDesign: String, Codable, CaseIterable, Hashable, Identifiable {
    case system
    case serif
    case rounded
    case monospaced

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .serif: return "Serif"
        case .rounded: return "Rounded"
        case .monospaced: return "Monospace"
        }
    }
}

struct NoteTextStyle: Codable, Hashable {
    var fontName: String = "Noto Sans"
    var fontSize: Double = 22
    var isBold: Bool = false
    var isItalic: Bool = false
    var isUnderlined: Bool = false

    private enum CodingKeys: String, CodingKey {
        case fontName
        case fontDesign
        case fontSize
        case isBold
        case isItalic
        case isUnderlined
    }

    init(
        fontName: String = "Noto Sans",
        fontSize: Double = 22,
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderlined: Bool = false
    ) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderlined = isUnderlined
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let decodedName = try container.decodeIfPresent(String.self, forKey: .fontName) {
            fontName = decodedName
        } else {
            // Backward compatibility with older saved data that used enum-only design.
            let legacyDesign = try container.decodeIfPresent(NoteFontDesign.self, forKey: .fontDesign) ?? .rounded
            fontName = switch legacyDesign {
            case .system, .rounded: "Noto Sans"
            case .serif: "Noto Serif"
            case .monospaced: "JetBrains Mono"
            }
        }
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? 22
        isBold = try container.decodeIfPresent(Bool.self, forKey: .isBold) ?? false
        isItalic = try container.decodeIfPresent(Bool.self, forKey: .isItalic) ?? false
        isUnderlined = try container.decodeIfPresent(Bool.self, forKey: .isUnderlined) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fontName, forKey: .fontName)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(isBold, forKey: .isBold)
        try container.encode(isItalic, forKey: .isItalic)
        try container.encode(isUnderlined, forKey: .isUnderlined)
    }
}

enum NoteTextBoxContentType: String, Codable, Hashable {
    case text
    case image
}

struct NoteTextBox: Identifiable, Codable, Hashable {
    var id: UUID
    var contentType: NoteTextBoxContentType
    var text: String
    var imageData: Data?
    var isContainerStyle: Bool
    // Normalized geometry in page space [0, 1].
    var centerX: Double
    var centerY: Double
    var width: Double
    var height: Double
    var rotationDegrees: Double
    var style: NoteTextStyle

    private enum CodingKeys: String, CodingKey {
        case id
        case contentType
        case text
        case imageData
        case isContainerStyle
        case centerX
        case centerY
        case width
        case height
        case rotationDegrees
        case style
    }

    init(
        id: UUID = UUID(),
        contentType: NoteTextBoxContentType = .text,
        text: String = "",
        imageData: Data? = nil,
        isContainerStyle: Bool = false,
        centerX: Double = 0.5,
        centerY: Double = 0.5,
        width: Double = 0.42,
        height: Double = 0.16,
        rotationDegrees: Double = 0,
        style: NoteTextStyle = NoteTextStyle()
    ) {
        self.id = id
        self.contentType = contentType
        self.text = text
        self.imageData = imageData
        self.isContainerStyle = isContainerStyle
        self.centerX = centerX
        self.centerY = centerY
        self.width = width
        self.height = height
        self.rotationDegrees = rotationDegrees
        self.style = style
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        contentType = try container.decodeIfPresent(NoteTextBoxContentType.self, forKey: .contentType) ?? .text
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        isContainerStyle = try container.decodeIfPresent(Bool.self, forKey: .isContainerStyle) ?? false
        centerX = try container.decodeIfPresent(Double.self, forKey: .centerX) ?? 0.5
        centerY = try container.decodeIfPresent(Double.self, forKey: .centerY) ?? 0.5
        width = try container.decodeIfPresent(Double.self, forKey: .width) ?? 0.42
        height = try container.decodeIfPresent(Double.self, forKey: .height) ?? 0.16
        rotationDegrees = try container.decodeIfPresent(Double.self, forKey: .rotationDegrees) ?? 0
        style = try container.decodeIfPresent(NoteTextStyle.self, forKey: .style) ?? NoteTextStyle()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(imageData, forKey: .imageData)
        try container.encode(isContainerStyle, forKey: .isContainerStyle)
        try container.encode(centerX, forKey: .centerX)
        try container.encode(centerY, forKey: .centerY)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(rotationDegrees, forKey: .rotationDegrees)
        try container.encode(style, forKey: .style)
    }
}

enum NotebookTheme: String, Codable, CaseIterable, Hashable, Identifiable {
    case graphite
    case fern
    case ocean
    case amber
    case rose
    case violet

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .graphite: return "Graphite"
        case .fern: return "Fern"
        case .ocean: return "Ocean"
        case .amber: return "Amber"
        case .rose: return "Rose"
        case .violet: return "Violet"
        }
    }
}

enum NotebookPaperStyle: String, Codable, CaseIterable, Hashable, Identifiable {
    case lined
    case blank

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lined: return "Lined"
        case .blank: return "Blank"
        }
    }
}

struct Notebook: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var theme: NotebookTheme
    var paperStyle: NotebookPaperStyle
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        theme: NotebookTheme,
        paperStyle: NotebookPaperStyle = .lined,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.theme = theme
        self.paperStyle = paperStyle
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Notebook" : trimmed
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case theme
        case paperStyle
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        theme = try container.decode(NotebookTheme.self, forKey: .theme)
        paperStyle = try container.decodeIfPresent(NotebookPaperStyle.self, forKey: .paperStyle) ?? .lined
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(theme, forKey: .theme)
        try container.encode(paperStyle, forKey: .paperStyle)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

struct Note: Identifiable, Codable, Hashable {
    var id: UUID
    var notebookID: UUID
    var title: String
    var body: String
    var drawingData: Data?
    var pageOrder: Double?
    var backgroundImageData: Data?
    var pagePaperStyleOverride: NotebookPaperStyle?
    var typedTextStyle: NoteTextStyle
    var inlineTextBoxes: [NoteTextBox]
    var mediaBoxes: [NoteTextBox]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        notebookID: UUID,
        title: String = "",
        body: String = "",
        drawingData: Data? = nil,
        pageOrder: Double? = nil,
        backgroundImageData: Data? = nil,
        pagePaperStyleOverride: NotebookPaperStyle? = nil,
        typedTextStyle: NoteTextStyle = NoteTextStyle(),
        inlineTextBoxes: [NoteTextBox] = [],
        mediaBoxes: [NoteTextBox] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.notebookID = notebookID
        self.title = title
        self.body = body
        self.drawingData = drawingData
        self.pageOrder = pageOrder
        self.backgroundImageData = backgroundImageData
        self.pagePaperStyleOverride = pagePaperStyleOverride
        self.typedTextStyle = typedTextStyle
        self.inlineTextBoxes = inlineTextBoxes
        self.mediaBoxes = mediaBoxes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let firstLine = body
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) {
            return firstLine
        }
        return "Untitled Page"
    }

    var previewText: String {
        let source = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if source.isEmpty {
            return hasSketch ? "Sketch page" : "Blank page"
        }
        return source.replacingOccurrences(of: "\n", with: " ")
    }

    var wordCount: Int {
        body.split { $0.isWhitespace || $0.isNewline }.count
    }

    var hasSketch: Bool {
        guard let drawingData else { return false }
        return !drawingData.isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case notebookID
        case title
        case body
        case drawingData
        case pageOrder
        case backgroundImageData
        case pagePaperStyleOverride
        case typedTextStyle
        case inlineTextBoxes
        case mediaBoxes
        case textBoxes
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        notebookID = try container.decode(UUID.self, forKey: .notebookID)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        drawingData = try container.decodeIfPresent(Data.self, forKey: .drawingData)
        pageOrder = try container.decodeIfPresent(Double.self, forKey: .pageOrder)
        backgroundImageData = try container.decodeIfPresent(Data.self, forKey: .backgroundImageData)
        pagePaperStyleOverride = try container.decodeIfPresent(NotebookPaperStyle.self, forKey: .pagePaperStyleOverride)
        typedTextStyle = try container.decodeIfPresent(NoteTextStyle.self, forKey: .typedTextStyle) ?? NoteTextStyle()
        let decodedInline = try container.decodeIfPresent([NoteTextBox].self, forKey: .inlineTextBoxes)
        let decodedMedia = try container.decodeIfPresent([NoteTextBox].self, forKey: .mediaBoxes)
        if decodedInline != nil || decodedMedia != nil {
            inlineTextBoxes = (decodedInline ?? [])
                .filter { $0.contentType == .text && !$0.isContainerStyle }
            mediaBoxes = (decodedMedia ?? [])
                .filter { $0.contentType == .image || $0.isContainerStyle }
        } else {
            // Backward compatibility: split legacy combined textBoxes into the isolated stores.
            let legacyBoxes = try container.decodeIfPresent([NoteTextBox].self, forKey: .textBoxes) ?? []
            inlineTextBoxes = legacyBoxes
                .filter { $0.contentType == .text && !$0.isContainerStyle }
            mediaBoxes = legacyBoxes
                .filter { $0.contentType == .image || $0.isContainerStyle }
        }
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(notebookID, forKey: .notebookID)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encodeIfPresent(drawingData, forKey: .drawingData)
        try container.encodeIfPresent(pageOrder, forKey: .pageOrder)
        try container.encodeIfPresent(backgroundImageData, forKey: .backgroundImageData)
        try container.encodeIfPresent(pagePaperStyleOverride, forKey: .pagePaperStyleOverride)
        try container.encode(typedTextStyle, forKey: .typedTextStyle)
        try container.encode(inlineTextBoxes, forKey: .inlineTextBoxes)
        try container.encode(mediaBoxes, forKey: .mediaBoxes)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

struct NotesLibraryDocument: Codable {
    var notebooks: [Notebook]
    var notes: [Note]
}

struct LegacyNoteV1: Codable {
    var id: UUID
    var title: String
    var body: String
    var drawingData: Data?
    var tags: [String]?
    var isPinned: Bool?
    var createdAt: Date
    var updatedAt: Date
}

