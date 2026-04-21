import SwiftUI
import UniformTypeIdentifiers

fileprivate enum QuickPeekLayout {
    static let windowSize = CGSize(width: 380, height: 480)
    static let cardCornerRadius: CGFloat = 24
    static let buttonSize: CGFloat = 40
    static let overlaySize = CGSize(width: 352, height: 432)
}

struct ContentView: View {
    @EnvironmentObject var viewModel: TrackerViewModel
    @State private var overlayMode: OverlayMode? = nil
    @State private var hoveredID: UUID? = nil
    @State private var draggingItem: Tracker?
    
    enum OverlayMode: Identifiable {
        case add, settings
        var id: Int { hashValue }
    }
    var body: some View {
        ZStack {
            windowBackground

            VStack(spacing: 0) {
                header

                Group {
                    if viewModel.trackers.isEmpty {
                        emptyState
                    } else {
                        trackersList
                    }
                }

                footer
            }
            .frame(width: QuickPeekLayout.windowSize.width, height: QuickPeekLayout.windowSize.height)
            
            if let mode = overlayMode {
                Color.black.opacity(0.4)
                    .transition(.opacity)
                    .onTapGesture { withAnimation(.spring()) { overlayMode = nil } }
                
                Group {
                    switch mode {
                    case .add:
                        AddTrackerSheet(onDismiss: {
                            withAnimation(.spring()) { overlayMode = nil }
                        })
                    case .settings:
                        SettingsSheet(onDismiss: {
                            withAnimation(.spring()) { overlayMode = nil }
                        })
                    }
                }
                .frame(width: QuickPeekLayout.overlaySize.width, height: QuickPeekLayout.overlaySize.height)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .frame(width: QuickPeekLayout.windowSize.width, height: QuickPeekLayout.windowSize.height)
    }
    
    private var header: some View {
        HStack {
            Image(systemName: "chart.bar.xaxis")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            
            Text("QuickPeek")
                .font(.headline)
            
            Spacer()
            
            if !viewModel.refreshingTrackerIDs.isEmpty {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.85))
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(.white.opacity(0.05))
        }
    }
    
    private var trackersList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(viewModel.trackers) { tracker in
                    TrackerCard(tracker: tracker,
                                isRefreshing: viewModel.refreshingTrackerIDs.contains(tracker.id),
                                isHovered: hoveredID == tracker.id)
                        .onHover { isHovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                hoveredID = isHovering ? tracker.id : nil
                            }
                        }
                        .onTapGesture {
                            viewModel.openInBrowser(tracker: tracker)
                        }
                        .onDrag {
                            draggingItem = tracker
                            return NSItemProvider(object: tracker.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: TrackerDropDelegate(item: tracker, viewModel: viewModel, draggingItem: $draggingItem))
                        .contextMenu {
                            Button("Synchronize Now") {
                                Task { await viewModel.refreshTracker(id: tracker.id) }
                            }
                            Divider()
                            Button("Remove Monitor", role: .destructive) {
                                withAnimation { viewModel.deleteTracker(id: tracker.id) }
                            }
                        }
                }
            }
            .padding(16)
            .animation(.spring(), value: viewModel.trackers)
        }
        .scrollIndicators(.hidden)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.3))
            
            Text("Ready to track?")
                .font(.headline)
            
            Text("Add your first public metric from GitHub, Reddit, YouTube, TikTok, or Bluesky to begin monitoring your growth.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 40)
            
            Button("Add First Project") {
                withAnimation(.spring()) { overlayMode = .add }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
    }
    
    private var footer: some View {
        HStack(spacing: 20) {
            Button(action: { withAnimation(.spring()) { overlayMode = .add } }) {
                Image(systemName: "plus")
                    .font(.headline)
                    .frame(width: QuickPeekLayout.buttonSize, height: QuickPeekLayout.buttonSize)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Monitor New Project")
            
            Button(action: { Task { await viewModel.refreshAll() } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline)
                    .frame(width: QuickPeekLayout.buttonSize, height: QuickPeekLayout.buttonSize)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Synchronize All Metrics")
            
            Spacer()
            
            Button(action: { withAnimation(.spring()) { overlayMode = .settings } }) {
                Image(systemName: "gearshape")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.7))
        .overlay(alignment: .top) {
            Divider()
                .overlay(.white.opacity(0.04))
        }
    }

    private var windowBackground: some View {
        Rectangle()
            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.97))
            .background(.ultraThinMaterial.opacity(0.9))
    }
}

struct TrackerCard: View {
    let tracker: Tracker
    let isRefreshing: Bool
    let isHovered: Bool
    @State private var hoveredErrorMetricID: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Image(systemName: tracker.type.icon)
                    .font(.title2)
                    .foregroundStyle(tracker.isError ? Color.red : Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tracker.name)
                        .font(.headline)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(tracker.urlOrID)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
                
                if isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            
            VStack(spacing: 10) {
                ForEach(tracker.metrics) { metric in
                    HStack {
                        Text(metric.category.label)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        
                        Spacer()
                        
                        if let error = metric.lastErrorMessage {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                                .onHover { isHovering in
                                    hoveredErrorMetricID = isHovering ? metric.id : nil
                                }
                                .popover(isPresented: errorPopoverBinding(for: metric.id), attachmentAnchor: .point(.topTrailing), arrowEdge: .bottom) {
                                    ErrorInfoPopover(
                                        title: errorTitle(for: metric, rawError: error),
                                        message: errorExplanation(for: metric, rawError: error),
                                        details: error
                                    )
                                }
                        } else {
                            HStack(spacing: 8) {
                                deltaIndicator(for: metric)
                                
                                Text("\(metric.count)")
                                    .font(.system(.body, design: .rounded).bold())
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            if let date = tracker.lastUpdated {
                HStack {
                    Spacer()
                    Text("Last synchronized \(date.formatted(.relative(presentation: .numeric)))")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
                .padding(.top, -4)
            }
        }
        .padding(16)
        .background(isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: QuickPeekLayout.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: QuickPeekLayout.cardCornerRadius, style: .continuous)
                .stroke(
                    tracker.isError ? Color.red.opacity(0.2) : Color.white.opacity(isHovered ? 0.12 : 0.06),
                    lineWidth: 1
                )
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
    }
    
    @ViewBuilder
    private func deltaIndicator(for metric: MetricValue) -> some View {
        if let lastCount = metric.lastCount, lastCount != metric.count {
            let delta = metric.count - lastCount
            HStack(spacing: 2) {
                Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                    .font(.system(size: 9, weight: .black))
                Text("\(abs(delta))")
                    .font(.system(size: 9, weight: .black, design: .rounded))
            }
            .foregroundStyle(delta > 0 ? .green : .red)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background((delta > 0 ? Color.green : Color.red).opacity(0.1))
            .cornerRadius(4)
        }
    }

    private func errorPopoverBinding(for metricID: String) -> Binding<Bool> {
        Binding(
            get: { hoveredErrorMetricID == metricID },
            set: { isPresented in
                if !isPresented && hoveredErrorMetricID == metricID {
                    hoveredErrorMetricID = nil
                }
            }
        )
    }

    private func errorTitle(for metric: MetricValue, rawError: String) -> String {
        let lowercased = rawError.lowercased()

        if lowercased.contains("rate limited") {
            return "Source Rate Limit"
        }

        if lowercased.contains("youtube response incomplete") {
            return "YouTube Response Incomplete"
        }

        if lowercased.contains("youtube format changed") {
            return "YouTube Format Changed"
        }

        if lowercased.contains("tiktok format changed") {
            return "TikTok Format Changed"
        }

        if lowercased.contains("tiktok response incomplete") {
            return "TikTok Response Incomplete"
        }

        if lowercased.contains("failed to parse") {
            switch tracker.type {
            case .youtube:
                return "YouTube Parsing Issue"
            case .tiktok:
                return "TikTok Parsing Issue"
            case .github:
                return "GitHub Response Changed"
            default:
                return "Parsing Issue"
            }
        }

        if lowercased.contains("invalid url") {
            return "Input Format Issue"
        }

        if lowercased.contains("server error") {
            return "Source Server Error"
        }

        return "\(metric.category.label) Error"
    }

    private func errorExplanation(for metric: MetricValue, rawError: String) -> String {
        let lowercased = rawError.lowercased()

        if lowercased.contains("rate limited") {
            return "The source temporarily blocked repeated requests for this metric. Quick refreshes in sequence can trigger it."
        }

        if lowercased.contains("youtube response incomplete") {
            return "YouTube replied, but the page was incomplete for scraping. This often means a consent wall, anti-bot response, or missing structured fields."
        }

        if lowercased.contains("youtube format changed") {
            return "YouTube returned the page, but the subscriber count was not where our scraper expected it. This points more to an inconsistent or changed page format than to a generic parsing bug."
        }

        if lowercased.contains("tiktok response incomplete") {
            return "TikTok replied, but the public embed page did not include the full state we need. This can happen when an embed is unavailable for that profile or video."
        }

        if lowercased.contains("tiktok format changed") {
            return "TikTok returned the embed page, but the metric field we expected was missing or moved."
        }

        if lowercased.contains("failed to parse") {
            switch tracker.type {
            case .youtube:
                return "YouTube returned page data in a format we could not read this time. Subscriber tracking is more scrape-based than most other sources."
            case .tiktok:
                return "TikTok returned a public embed page, but the metric fields did not match the format we expected."
            case .github where metric.category == .githubIssues || metric.category == .githubPullRequests:
                return "GitHub search or its HTML fallback returned a response that did not match the expected format."
            case .github:
                return "GitHub replied, but the response was not in the format expected for this metric."
            default:
                return "The source replied, but the returned data did not match the expected format."
            }
        }

        if lowercased.contains("invalid url") {
            return "The saved input does not match what this metric expects. This usually happens when a profile metric receives a post URL, or vice versa."
        }

        if lowercased.contains("server error: 403") {
            return "The source refused this request. This can happen due to anti-bot checks, missing access, or temporary restrictions."
        }

        if lowercased.contains("server error: 429") {
            return "The source is asking us to slow down. Waiting a bit before refreshing usually fixes it."
        }

        if lowercased.contains("server error") {
            return "The source returned a temporary server error while this metric was refreshing."
        }

        return "This metric could not be refreshed this time. Try again in a few seconds if the issue looks temporary."
    }
}

struct ErrorInfoPopover: View {
    let title: String
    let message: String
    let details: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Text(details)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            if let snapshotPath = extractSnapshotPath(from: details) {
                Divider()

                Text(snapshotPath)
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.9))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 250, alignment: .leading)
        .padding(14)
    }

    private func extractSnapshotPath(from details: String) -> String? {
        guard let start = details.range(of: "[snapshot: "),
              let end = details[start.upperBound...].firstIndex(of: "]") else {
            return nil
        }

        return String(details[start.upperBound..<end])
    }
}

// MARK: - Drag and Drop Delegate

struct TrackerDropDelegate: DropDelegate {
    let item: Tracker
    let viewModel: TrackerViewModel
    @Binding var draggingItem: Tracker?
    
    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem,
              draggingItem != item,
              let fromIndex = viewModel.trackers.firstIndex(of: draggingItem),
              let toIndex = viewModel.trackers.firstIndex(of: item) else { return }
        
        withAnimation(.spring()) {
            viewModel.moveTracker(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}
