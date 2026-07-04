import Foundation
import Testing
@testable import YotoTools

@MainActor
struct IconBrowserViewModelTests {
    private func loadedModel(
        userIcons: [DisplayIcon] = [],
        publicIcons: [DisplayIcon] = []
    ) async -> IconBrowserViewModel {
        let api = MockYotoAPI()
        api.userIcons = userIcons
        api.publicIcons = publicIcons
        let vm = IconBrowserViewModel(api: api)
        await vm.load()
        return vm
    }

    @Test func loadPopulatesBothSections() async {
        let vm = await loadedModel(
            userIcons: [DisplayIcon(mediaId: "MINE")],
            publicIcons: [DisplayIcon(mediaId: "PUB", title: "Star")])

        #expect(vm.loadState == .loaded)
        #expect(vm.userIcons.map(\.mediaId) == ["MINE"])
        #expect(vm.filteredPublicIcons.map(\.mediaId) == ["PUB"])
        #expect(vm.showsUserIcons)
    }

    @Test func searchMatchesTitlesAndTagsCaseInsensitively() async {
        let vm = await loadedModel(publicIcons: [
            DisplayIcon(mediaId: "A", title: "Happy Seedling"),
            DisplayIcon(mediaId: "B", title: "Rocket", publicTags: ["space", "seed"]),
            DisplayIcon(mediaId: "C", title: "Drum"),
        ])

        vm.searchText = "SEED"
        #expect(vm.filteredPublicIcons.map(\.mediaId) == ["A", "B"])

        vm.searchText = "drum"
        #expect(vm.filteredPublicIcons.map(\.mediaId) == ["C"])

        vm.searchText = ""
        #expect(vm.filteredPublicIcons.count == 3)
    }

    @Test func searchingHidesUntitledUserUploads() async {
        let vm = await loadedModel(
            userIcons: [DisplayIcon(mediaId: "MINE")],
            publicIcons: [DisplayIcon(mediaId: "PUB", title: "Star")])

        #expect(vm.showsUserIcons)
        vm.searchText = "star"
        #expect(!vm.showsUserIcons)
    }

    @Test func loadFailureSurfacesMessage() async {
        let api = MockYotoAPI()
        api.getPublicIconsError = APIError.http(status: 500, body: nil)
        let vm = IconBrowserViewModel(api: api)
        await vm.load()

        guard case .failed = vm.loadState else {
            Issue.record("Expected failed state, got \(vm.loadState)")
            return
        }
    }
}
