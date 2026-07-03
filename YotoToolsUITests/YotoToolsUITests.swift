import XCTest

final class YotoToolsUITests: XCTestCase {
    @MainActor
    func testLaunchShowsPixelArtTool() throws {
        let app = XCUIApplication()
        app.launch()
        // The sidebar lists available tools; Pixel Art is the first one.
        XCTAssertTrue(app.staticTexts["Pixel Art"].waitForExistence(timeout: 10))
    }
}
