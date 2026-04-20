import SwiftUI

@MainActor
class TrackerViewModel: ObservableObject {
    @Published var trackers: [Tracker] = []
    @Published var refreshingTrackerIDs: Set<UUID> = []
    
    @AppStorage("youtubeAPIKey") var youtubeAPIKey: String = ""
    @AppStorage("xBearerToken") var xBearerToken: String = ""
    
    private let saveKey = "trackers"
    
    init() {
        load()
    }
    
    func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else { return }
        do {
            trackers = try JSONDecoder().decode([Tracker].self, from: data)
        } catch {
            print("Error loading trackers: \(error)")
        }
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(trackers)
            UserDefaults.standard.set(data, forKey: saveKey)
        } catch {
            print("Error saving trackers: \(error)")
        }
    }
    
    func addTracker(urlOrID: String, type: MetricType, category: MetricCategory, customName: String) {
        let name = customName.isEmpty ? extractDisplayName(from: urlOrID, type: type) : customName
        let tracker = Tracker(name: name, urlOrID: urlOrID, type: type, category: category)
        trackers.append(tracker)
        save()
        
        Task {
            await refreshTracker(id: tracker.id)
        }
    }
    
    func deleteTracker(id: UUID) {
        trackers.removeAll { $0.id == id }
        save()
    }
    
    func moveTracker(fromOffsets: IndexSet, toOffset: Int) {
        trackers.move(fromOffsets: fromOffsets, toOffset: toOffset)
        save()
    }
    
    func openInBrowser(tracker: Tracker) {
        var urlString = tracker.urlOrID
        switch tracker.type {
        case .youtube:
            if !urlString.contains("youtube.com") { urlString = "https://youtube.com/channel/\(tracker.urlOrID)" }
        case .x:
            if !urlString.contains("x.com") && !urlString.contains("twitter.com") { urlString = "https://x.com/\(tracker.urlOrID)" }
        case .npm:
            if !urlString.contains("npmjs.com") { urlString = "https://www.npmjs.com/package/\(tracker.urlOrID)" }
        case .discord:
            if !urlString.contains("discord.gg") && !urlString.contains("discord.com") { urlString = "https://discord.gg/\(tracker.urlOrID)" }
        case .instagram:
            if !urlString.contains("instagram.com") { urlString = "https://instagram.com/\(URLCleaner.cleanInstagramHandle(tracker.urlOrID))" }
        default:
            if !urlString.hasPrefix("http") { urlString = "https://\(urlString)" }
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    func refreshTracker(id: UUID) async {
        guard let index = trackers.firstIndex(where: { $0.id == id }) else { return }
        
        let oldCount = trackers[index].count
        refreshingTrackerIDs.insert(id)
        defer { refreshingTrackerIDs.remove(id) }
        
        // Reset error state
        trackers[index].lastErrorMessage = nil
        
        do {
            let newCount = try await MetricService.fetchMetric(for: trackers[index], youtubeKey: youtubeAPIKey, xToken: xBearerToken)
            
            trackers[index].lastCount = oldCount
            trackers[index].count = newCount
            trackers[index].lastUpdated = Date()
            save()
        } catch {
            let errorMsg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            trackers[index].lastErrorMessage = errorMsg
            print("Refresh Error (\(trackers[index].name)): \(errorMsg)")
        }
    }
    
    func refreshAll() async {
        for tracker in trackers {
            await refreshTracker(id: tracker.id)
        }
    }
    
    private func extractDisplayName(from string: String, type: MetricType) -> String {
        let components = string.components(separatedBy: "/")
        switch type {
        case .github: return components.suffix(2).joined(separator: "/")
        case .reddit:
            if string.contains("/r/") || string.contains("/u/") { return components.last(where: { !$0.isEmpty }) ?? "Reddit" }
            return "Reddit Post"
        case .x: return "@" + URLCleaner.cleanXUsername(string)
        case .youtube: return "YouTube Channel"
        case .npm: return URLCleaner.cleanNpmName(string)
        case .discord: return "Discord Server"
        case .instagram: return "@" + URLCleaner.cleanInstagramHandle(string)
        }
    }
}
