import Foundation

/// The Yoto content/icon operations this app needs. Mockable for tests and previews.
protocol YotoAPI: Sendable {
    func getMyContent() async throws -> [CardSummary]
    func getContent(cardId: String) async throws -> CardDetail
    func updateContent(_ card: CardDetail) async throws -> CardDetail
    /// Uploads a PNG and returns the resulting `mediaId`.
    func uploadIcon(pngData: Data, filename: String, autoConvert: Bool) async throws -> String
    /// The user's previously uploaded display icons.
    func getUserIcons() async throws -> [UserIcon]
}
