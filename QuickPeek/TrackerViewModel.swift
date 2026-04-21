import SwiftUI
import OSLog

@MainActor
class TrackerViewModel: ObservableObject {
    @Published var trackers: [Tracker] = []
    @Published var refreshingTrackerIDs: Set<UUID> = []

    @Published var youtubeAPIKey: String = "" {
        didSet { persistSecret(youtubeAPIKey, key: .youtubeAPIKey) }
    }
    @Published var xBearerToken: String = "" {
        didSet { persistSecret(xBearerToken, key: .xBearerToken) }
    }

    private let saveKey = "trackers"
    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.dodo-reach.QuickPeek", category: "tracking")
    
    init() {
        loadSecrets()
        load()
    }
    
    func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else { return }
        do {
            let loadedTrackers = try JSONDecoder().decode([Tracker].self, from: data)
            
            // Automatic Merging logic: Group by urlOrID and merge metrics
            var mergedMap = [String: Tracker]()
            for tracker in loadedTrackers {
                if var existing = mergedMap[tracker.urlOrID] {
                    // Combine metrics, avoiding duplicates by category label
                    for metric in tracker.metrics {
                        if !existing.metrics.contains(where: { $0.category == metric.category }) {
                            existing.metrics.append(metric)
                        }
                    }
                    mergedMap[tracker.urlOrID] = existing
                } else {
                    mergedMap[tracker.urlOrID] = tracker
                }
            }
            
            // Re-sort merged trackers according to their original appearance if possible, 
            // but for simplicity we'll just use the values
            trackers = Array(mergedMap.values).sorted(by: { $0.lastUpdated ?? Date() > $1.lastUpdated ?? Date() })
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
    
    func addTracker(urlOrID: String, type: MetricType, categories: [MetricCategory], customName: String) {
        let name = customName.isEmpty ? extractDisplayName(from: urlOrID, type: type) : customName
        let metrics = categories.map { MetricValue(category: $0) }
        let tracker = Tracker(name: name, urlOrID: urlOrID, type: type, metrics: metrics)
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
            urlString = URLCleaner.youTubeChannelURL(from: tracker.urlOrID)
        case .x:
            if tracker.metrics.contains(where: { $0.category == .xPostLikes }) {
                if !urlString.contains("x.com") && !urlString.contains("twitter.com") {
                    urlString = "https://x.com/i/status/\(URLCleaner.extractXTweetID(tracker.urlOrID))"
                }
            } else if !urlString.contains("x.com") && !urlString.contains("twitter.com") {
                urlString = "https://x.com/\(tracker.urlOrID)"
            }
        case .bluesky:
            if !urlString.contains("bsky.app/profile/") { urlString = "https://bsky.app/profile/\(URLCleaner.cleanBlueskyHandle(tracker.urlOrID))" }
        case .npm:
            if !urlString.contains("npmjs.com") { urlString = "https://www.npmjs.com/package/\(tracker.urlOrID)" }
        case .discord:
            if !urlString.contains("discord.gg") && !urlString.contains("discord.com") { urlString = "https://discord.gg/\(tracker.urlOrID)" }
        case .instagram:
            if tracker.metrics.contains(where: { $0.category == .instagramFollowers }) {
                if !urlString.contains("instagram.com") { urlString = "https://instagram.com/\(URLCleaner.cleanInstagramHandle(tracker.urlOrID))" }
            } else {
                urlString = URLCleaner.cleanInstagramPostURL(tracker.urlOrID)
            }
        default:
            if !urlString.hasPrefix("http") { urlString = "https://\(urlString)" }
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    func refreshTracker(id: UUID) async {
        guard !refreshingTrackerIDs.contains(id) else {
            logger.debug("Skipping overlapping refresh for tracker id=\(id.uuidString, privacy: .public)")
            return
        }

        await refreshTracker(id: id, spinnerManagedExternally: false)
    }

    private func refreshTracker(id: UUID, spinnerManagedExternally: Bool) async {
        if !spinnerManagedExternally {
            refreshingTrackerIDs.insert(id)
            defer { refreshingTrackerIDs.remove(id) }
        }

        guard let index = trackers.firstIndex(where: { $0.id == id }) else { return }

        if trackers[index].type == .github {
            let categories = trackers[index].metrics.map(\.category)
            let results = await MetricService.fetchGitHubMetrics(for: trackers[index].urlOrID, categories: categories)

            for metric in trackers[index].metrics {
                guard let result = results[metric.category],
                      let mIndex = trackers[index].metrics.firstIndex(where: { $0.category == metric.category }) else { continue }

                switch result {
                case .success(let count):
                    trackers[index].metrics[mIndex].lastCount = trackers[index].metrics[mIndex].count
                    trackers[index].metrics[mIndex].count = count
                    trackers[index].metrics[mIndex].lastErrorMessage = nil
                case .failure(let error):
                    let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    trackers[index].metrics[mIndex].lastErrorMessage = msg
                    self.logger.error("Refresh failed tracker=\(self.trackers[index].name, privacy: .public) type=\(self.trackers[index].type.rawValue, privacy: .public) metric=\(metric.category.rawValue, privacy: .public) input=\(self.trackers[index].urlOrID, privacy: .public) error=\(msg, privacy: .public)")
                }
            }

            trackers[index].lastUpdated = Date()
            save()
            return
        }
        
        // Refresh each metric in parallel
        await withTaskGroup(of: (Int, MetricCategory, String?).self) { group in
            for metric in trackers[index].metrics {
                let trackerName = trackers[index].name
                let trackerType = trackers[index].type.rawValue
                let trackerInput = trackers[index].urlOrID
                group.addTask {
                    do {
                        let count = try await self.fetchMetricValue(for: trackerInput, category: metric.category)
                        return (count, metric.category, nil)
                    } catch {
                        let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                        self.logger.error("Refresh failed tracker=\(trackerName, privacy: .public) type=\(trackerType, privacy: .public) metric=\(metric.category.rawValue, privacy: .public) input=\(trackerInput, privacy: .public) error=\(msg, privacy: .public)")
                        return (metric.count, metric.category, msg)
                    }
                }
            }
            
            for await (count, category, errorMsg) in group {
                if let mIndex = trackers[index].metrics.firstIndex(where: { $0.category == category }) {
                    trackers[index].metrics[mIndex].lastCount = trackers[index].metrics[mIndex].count
                    trackers[index].metrics[mIndex].count = count
                    trackers[index].metrics[mIndex].lastErrorMessage = errorMsg
                }
            }
        }
        
        trackers[index].lastUpdated = Date()
        save()
    }
    
    func refreshAll() async {
        let ids = trackers.map(\.id)
        refreshingTrackerIDs.formUnion(ids)

        for tracker in trackers {
            await refreshTracker(id: tracker.id, spinnerManagedExternally: true)
            refreshingTrackerIDs.remove(tracker.id)
        }
    }
    
    private func extractDisplayName(from string: String, type: MetricType) -> String {
        let components = string.components(separatedBy: "/")
        switch type {
        case .github: return components.suffix(2).joined(separator: "/")
        case .reddit:
            if string.contains("/r/") || string.contains("/u/") { return components.last(where: { !$0.isEmpty }) ?? "Reddit" }
            return "Reddit Post"
        case .x:
            return string.contains("/status/") ? "X Post" : "@\(URLCleaner.cleanXUsername(string))"
        case .bluesky:
            let handle = URLCleaner.cleanBlueskyHandle(string)
            return handle.hasPrefix("did:") ? "Bluesky Profile" : "@\(handle)"
        case .youtube:
            let identifier = URLCleaner.cleanYouTubeIdentifier(string)
            return identifier.isEmpty ? "YouTube Channel" : identifier
        case .npm: return URLCleaner.cleanNpmName(string)
        case .discord: return "Discord Server"
        case .instagram:
            return URLCleaner.isInstagramPostURL(string) ? "Instagram Post" : "@\(URLCleaner.cleanInstagramHandle(string))"
        }
    }
    
    private func fetchMetricValue(for input: String, category: MetricCategory) async throws -> Int {
        try await MetricService.fetchMetric(
            for: input,
            category: category,
            youtubeKey: youtubeAPIKey,
            xToken: xBearerToken
        )
    }

    private func loadSecrets() {
        youtubeAPIKey = loadSecret(for: .youtubeAPIKey, legacyDefaultsKey: "youtubeAPIKey")
        xBearerToken = loadSecret(for: .xBearerToken, legacyDefaultsKey: "xBearerToken")
    }

    private func loadSecret(for key: KeychainStore.Key, legacyDefaultsKey: String) -> String {
        let keychainValue = KeychainStore.string(for: key)
        if !keychainValue.isEmpty {
            defaults.removeObject(forKey: legacyDefaultsKey)
            return keychainValue
        }

        let legacyValue = defaults.string(forKey: legacyDefaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !legacyValue.isEmpty else { return "" }

        let status = KeychainStore.set(legacyValue, for: key)
        if status == errSecSuccess {
            defaults.removeObject(forKey: legacyDefaultsKey)
            return legacyValue
        }

        logger.error("Failed to migrate secret from UserDefaults for key=\(legacyDefaultsKey, privacy: .public) status=\(status, privacy: .public)")
        return legacyValue
    }

    private func persistSecret(_ value: String, key: KeychainStore.Key) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let status = KeychainStore.set(trimmed, for: key)
        guard status == errSecSuccess else {
            logger.error("Failed to persist secret for key=\(key.rawValue, privacy: .public) status=\(status, privacy: .public)")
            return
        }
    }
}
