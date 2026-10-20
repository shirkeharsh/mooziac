import Foundation

public struct ManagedExtension: Codable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var version: String
    public var isEnabled: Bool
    public var relativePath: String
    public var optionsPath: String?
    public var popupPath: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        version: String = "1.0",
        isEnabled: Bool = true,
        relativePath: String,
        optionsPath: String? = nil,
        popupPath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.isEnabled = isEnabled
        self.relativePath = relativePath
        self.optionsPath = optionsPath
        self.popupPath = popupPath
    }
}
