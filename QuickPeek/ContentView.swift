import SwiftUI
import UniformTypeIdentifiers

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
            VStack(spacing: 0) {
                header
                
                if viewModel.trackers.isEmpty {
                    emptyState
                } else {
                    trackersList
                }
                
                footer
            }
            .frame(width: 380, height: 480)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
            
            if let mode = overlayMode {
                Color.black.opacity(0.3)
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
                .frame(width: 340, height: 420)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
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
        .background(.ultraThinMaterial)
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
                            Button("Refresh") {
                                Task { await viewModel.refreshTracker(id: tracker.id) }
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                withAnimation { viewModel.deleteTracker(id: tracker.id) }
                            }
                        }
                }
            }
            .padding()
            .animation(.spring(), value: viewModel.trackers)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.3))
            
            Text("Get Started")
                .font(.headline)
            
            Text("Add your first GitHub repository, subreddit, or YouTube channel to track metrics.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Add Tracker") {
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
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Add Tracker")
            
            Button(action: { Task { await viewModel.refreshAll() } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline)
                    .frame(width: 40, height: 40)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Refresh All")
            
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
        .background(.ultraThinMaterial.opacity(0.5))
    }
}

struct TrackerCard: View {
    let tracker: Tracker
    let isRefreshing: Bool
    let isHovered: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: tracker.type.icon)
                    .font(.title3)
                    .foregroundStyle(tracker.isError ? Color.red : Color.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tracker.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(tracker.urlOrID)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                } else if tracker.isError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .help(tracker.lastErrorMessage ?? "Unknown error")
                } else {
                    HStack(spacing: 8) {
                        deltaIndicator
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(tracker.count)")
                                .font(.system(.title3, design: .rounded).bold())
                                .foregroundStyle(Color.accentColor)
                            Text(tracker.category.label)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                        }
                    }
                }
            }
            
            if let date = tracker.lastUpdated {
                HStack {
                    Spacer()
                    Text("Updated \(date.formatted(.relative(presentation: .numeric)))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary.opacity(0.8))
                }
            }
        }
        .padding(14)
        .background(isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tracker.isError ? Color.red.opacity(0.3) : Color.primary.opacity(isHovered ? 0.1 : 0.05), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
    }
    
    @ViewBuilder
    private var deltaIndicator: some View {
        if let lastCount = tracker.lastCount, lastCount != tracker.count {
            let delta = tracker.count - lastCount
            HStack(spacing: 2) {
                Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                    .font(.system(size: 10, weight: .bold))
                Text("\(abs(delta))")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundStyle(delta > 0 ? .green : .red)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((delta > 0 ? Color.green : Color.red).opacity(0.1))
            .cornerRadius(6)
        }
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
