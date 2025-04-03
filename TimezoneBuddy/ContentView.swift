import SwiftUI
import AppKit
import CoreLocation

struct Teammate: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var timeZoneIdentifier: String
    var imageData: Data?
    var email: String?
    var slackId: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, timeZoneIdentifier, imageData, email, slackId
    }
    
    init(id: UUID = UUID(), name: String, timeZoneIdentifier: String, imageData: Data?, email: String? = nil, slackId: String? = nil) {
        self.id = id
        self.name = name
        self.timeZoneIdentifier = timeZoneIdentifier
        self.imageData = imageData
        self.email = email
        self.slackId = slackId
    }
    
    var timeZone: TimeZone? {
        TimeZone(identifier: timeZoneIdentifier)
    }

    var localTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = timeZone
        return formatter.string(from: Date())
    }
    
    var timeDifference: String {
        guard let tz = timeZone else { return "" }
        let userTZ = TimeZone.current
        
        let userOffsetSeconds = userTZ.secondsFromGMT()
        let teammateOffsetSeconds = tz.secondsFromGMT()
        let diffHours = (teammateOffsetSeconds - userOffsetSeconds) / 3600
        
        if diffHours == 0 {
            return "Same time"
        } else if diffHours > 0 {
            return "+\(diffHours)h"
        } else {
            return "\(diffHours)h"
        }
    }
    
    static func == (lhs: Teammate, rhs: Teammate) -> Bool {
        lhs.id == rhs.id
    }
}

class TeammateStore: ObservableObject {
    @Published var teammates: [Teammate] = [] {
        didSet {
            saveTeammates()
        }
    }
    
    init() {
        loadTeammates()
    }
    
    func addTeammate(_ teammate: Teammate) {
        teammates.append(teammate)
    }
    
    func updateTeammate(_ teammate: Teammate) {
        if let index = teammates.firstIndex(where: { $0.id == teammate.id }) {
            teammates[index] = teammate
        }
    }
    
    func deleteTeammate(at index: Int) {
        teammates.remove(at: index)
    }
    
    private func saveTeammates() {
        if let encoded = try? JSONEncoder().encode(teammates) {
            UserDefaults.standard.set(encoded, forKey: "teammates")
        }
    }
    
    private func loadTeammates() {
        if let data = UserDefaults.standard.data(forKey: "teammates"),
           let decoded = try? JSONDecoder().decode([Teammate].self, from: data) {
            teammates = decoded
        }
    }
    
    func exportTeammates() -> Data? {
        try? JSONEncoder().encode(teammates)
    }
    
    func importTeammates(from data: Data) -> Bool {
        guard let imported = try? JSONDecoder().decode([Teammate].self, from: data) else {
            return false
        }
        teammates = imported
        return true
    }
}

struct ContentView: View {
    @ObservedObject var store: TeammateStore
    @State private var showingAddSheet = false
    @State private var searchText = ""
    @State private var editingTeammate: Teammate? = nil
    @State private var currentTime = Date()
    @State private var sortOrder: SortOrder = .name
    
    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case time = "Time"
        
        var systemImage: String {
            switch self {
            case .name: return "person"
            case .time: return "clock"
            }
        }
    }
    
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    init(store: TeammateStore = TeammateStore()) {
        self.store = store
    }

    var filteredTeammates: [Teammate] {
        var teammates = store.teammates
        
        // Filter by search text
        if !searchText.isEmpty {
            teammates = teammates.filter { 
                $0.name.lowercased().contains(searchText.lowercased()) ||
                $0.timeZoneIdentifier.lowercased().contains(searchText.lowercased())
            }
        }
        
        // Sort based on selected order
        switch sortOrder {
        case .name:
            teammates.sort { $0.name.lowercased() < $1.name.lowercased() }
        case .time:
            teammates.sort { 
                guard let tz1 = $0.timeZone, let tz2 = $1.timeZone else { return false }
                return tz1.secondsFromGMT() < tz2.secondsFromGMT()
            }
        }
        
        return teammates
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("TimezoneBuddy")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .help("Add Teammate")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.windowBackgroundColor))
            
            // Search and Sort
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search cities or time zones...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                }
                .padding(8)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
                
                Menu {
                    Picker("Sort by", selection: $sortOrder) {
                        Text("Name").tag(SortOrder.name)
                        Text("Time Difference").tag(SortOrder.time)
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.windowBackgroundColor))
            
            // Teammates List
            if filteredTeammates.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No teammates yet")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    Button(action: { showingAddSheet = true }) {
                        Text("Add Your First Teammate")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.windowBackgroundColor))
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredTeammates) { teammate in
                            teammateRow(teammate)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(Color(.windowBackgroundColor))
            }
        }
        .frame(width: 320, height: 400)
        .background(Color(.windowBackgroundColor))
        .sheet(isPresented: $showingAddSheet) {
            TeammateEditorView(store: store, teammate: editingTeammate)
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    private func teammateRow(_ teammate: Teammate) -> some View {
        HStack(spacing: 12) {
            // Profile Image
            if let imageData = teammate.imageData,
               let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(.separatorColor), lineWidth: 1))
                    .onTapGesture {
                        showingAddSheet = true
                        editingTeammate = teammate
                    }
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.secondary)
                    .onTapGesture {
                        showingAddSheet = true
                        editingTeammate = teammate
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(teammate.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Text(teammate.localTime)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    Text(teammate.timeDifference)
                        .font(.system(size: 13))
                        .foregroundColor(teammate.timeDifference.hasPrefix("-") ? .red : .green)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if let email = teammate.email, !email.isEmpty {
                    Button(action: {
                        NSWorkspace.shared.open(URL(string: "mailto:\(email)")!)
                    }) {
                        Image("Outlook")
                            .resizable()
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.plain)
                    .help("Email \(teammate.name)")
                }
                
                if let slackId = teammate.slackId, !slackId.isEmpty {
                    Button(action: {
                        let slackURL = "slack://channel?team=E026NQBKFHU&id=\(slackId)"
                        NSWorkspace.shared.open(URL(string: slackURL)!)
                    }) {
                        Image("Slack")
                            .resizable()
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.plain)
                    .help("Message \(teammate.name) on Slack")
                }
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: { editingTeammate = teammate }) {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive, action: {
                if let index = store.teammates.firstIndex(where: { $0.id == teammate.id }) {
                    store.deleteTeammate(at: index)
                }
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct TeammateEditorView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: TeammateStore
    @State private var name: String
    @State private var timeZone: TimeZone
    @State private var imageData: Data?
    @State private var email: String?
    @State private var slackId: String?
    var teammateToEdit: Teammate?
    
    init(store: TeammateStore, teammate: Teammate? = nil) {
        self.store = store
        _name = State(initialValue: teammate?.name ?? "")
        _timeZone = State(initialValue: teammate?.timeZone ?? TimeZone.current)
        _imageData = State(initialValue: teammate?.imageData)
        _email = State(initialValue: teammate?.email)
        _slackId = State(initialValue: teammate?.slackId)
        self.teammateToEdit = teammate
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Text(teammateToEdit == nil ? "Add Teammate" : "Edit Teammate")
                .font(.title3.bold())
                
            ImagePickerView(imageData: $imageData)
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Time Zone")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    CitySearchField(timeZone: $timeZone)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Email (Optional)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("Email", text: Binding(
                        get: { email ?? "" },
                        set: { email = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Slack ID (Optional)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("Slack ID", text: Binding(
                        get: { slackId ?? "" },
                        set: { slackId = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            }
            .padding(.horizontal, 8)
            
            Spacer()
            
            HStack {
                Button("Cancel") { 
                    dismiss() 
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button(teammateToEdit == nil ? "Add" : "Save") {
                    let teammate = Teammate(
                        id: teammateToEdit?.id ?? UUID(),
                        name: name, 
                        timeZoneIdentifier: timeZone.identifier, 
                        imageData: imageData,
                        email: email,
                        slackId: slackId
                    )
                    
                    if teammateToEdit != nil {
                        store.updateTeammate(teammate)
                    } else {
                        store.addTeammate(teammate)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
                .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}

struct CitySearchField: View {
    @Binding var timeZone: TimeZone
    @State private var searchText = ""
    @State private var searchResults: [TimeZone] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Search city or time zone", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                
                Text(formattedTimeZoneName(timeZone))
                    .font(.callout)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
            }
            
            if isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if !searchResults.isEmpty && !searchText.isEmpty {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(searchResults, id: \.identifier) { tz in
                            Button(action: {
                                timeZone = tz
                                searchText = ""
                            }) {
                                HStack {
                                    Text(formattedTimeZoneName(tz))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(formatTimeForTZ(tz))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: min(CGFloat(searchResults.count) * 28, 150))
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .onChange(of: searchText) { oldValue, newValue in
            // Cancel any previous search task
            searchTask?.cancel()
            
            // Create a new search task with debounce
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                if !Task.isCancelled {
                    await searchCities(for: newValue)
                }
            }
        }
    }
    
    private func searchCities(for query: String) async {
        guard !query.isEmpty else { 
            await MainActor.run {
                searchResults = []
                isSearching = false
            }
            return 
        }
        
        await MainActor.run {
            isSearching = true
        }
        
        let searchQuery = query.lowercased()
        
        // Try direct timezone matches first
        let directMatches = TimeZone.knownTimeZoneIdentifiers
            .filter { $0.lowercased().contains(searchQuery) }
            .prefix(20) // Increased from 10 to 20
            .compactMap { TimeZone(identifier: $0) }
        
        if !directMatches.isEmpty {
            await MainActor.run {
                searchResults = directMatches
                isSearching = false
            }
            return
        }
        
        // Fallback to geocoding
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.geocodeAddressString(query)
            
            if let tz = placemarks.first?.timeZone {
                await MainActor.run {
                    self.searchResults = [tz]
                    self.isSearching = false
                }
            } else {
                // If geocoding fails, do a more comprehensive search
                let allTimeZones = TimeZone.knownTimeZoneIdentifiers
                    .compactMap { TimeZone(identifier: $0) }
                
                // Search in both the identifier and the localized name
                let matches = allTimeZones.filter { tz in
                    tz.identifier.lowercased().contains(searchQuery) ||
                    tz.localizedName(for: .generic, locale: .current)?.lowercased().contains(searchQuery) == true ||
                    tz.localizedName(for: .standard, locale: .current)?.lowercased().contains(searchQuery) == true
                }
                .prefix(20)
                .sorted { $0.identifier < $1.identifier }
                
                await MainActor.run {
                    self.searchResults = matches
                    self.isSearching = false
                }
            }
        } catch {
            // If geocoding fails, do a more comprehensive search
            let allTimeZones = TimeZone.knownTimeZoneIdentifiers
                .compactMap { TimeZone(identifier: $0) }
            
            // Search in both the identifier and the localized name
            let matches = allTimeZones.filter { tz in
                tz.identifier.lowercased().contains(searchQuery) ||
                tz.localizedName(for: .generic, locale: .current)?.lowercased().contains(searchQuery) == true ||
                tz.localizedName(for: .standard, locale: .current)?.lowercased().contains(searchQuery) == true
            }
            .prefix(20)
            .sorted { $0.identifier < $1.identifier }
            
            await MainActor.run {
                self.searchResults = matches
                self.isSearching = false
            }
        }
    }
    
    func formattedTimeZoneName(_ tz: TimeZone) -> String {
        let parts = tz.identifier.split(separator: "/")
        if parts.count > 1 {
            return "\(parts.last?.replacingOccurrences(of: "_", with: " ") ?? ""), \(parts.first ?? "")"
        }
        return tz.identifier
    }
    
    func formatTimeForTZ(_ tz: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = tz
        return formatter.string(from: Date())
    }
}

struct ImagePickerView: View {
    @Binding var imageData: Data?
    @State private var isPickerActive = false
    
    var body: some View {
        VStack(spacing: 8) {
            if let data = imageData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .onTapGesture {
                        isPickerActive = true
                        showImagePicker()
                    }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                    )
                    .onTapGesture {
                        isPickerActive = true
                        showImagePicker()
                    }
            }
            
            HStack(spacing: 8) {
                Button("Choose Photo") {
                    isPickerActive = true
                    showImagePicker()
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                
                if imageData != nil {
                    Button("Remove") {
                        imageData = nil
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                }
            }
            .font(.footnote)
        }
        .onChange(of: isPickerActive) { _, newValue in
            if !newValue {
                // Bring the app back to front when the picker is dismissed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let app = NSApp {
                        app.activate(ignoringOtherApps: true)
                    }
                }
            }
        }
    }
    
    private func showImagePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        // Keep a reference to the app to bring it back to front
        let app = NSApp
        
        // Bring the panel to front
        panel.makeKeyAndOrderFront(nil)
        
        panel.begin { response in
            isPickerActive = false
            
            if response == .OK, let url = panel.url {
                // Process the image in a background thread
                DispatchQueue.global(qos: .userInitiated).async {
                    if let image = NSImage(contentsOf: url) {
                        let resizedImage = image.resized(to: CGSize(width: 400, height: 400))
                        if let data = resizedImage.tiffRepresentation,
                           let bitmap = NSBitmapImageRep(data: data),
                           let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
                            DispatchQueue.main.async {
                                imageData = jpegData
                                // Bring the app back to front
                                if let app = app {
                                    app.activate(ignoringOtherApps: true)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - NSImage Extension
extension NSImage {
    func resized(to size: CGSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        defer { newImage.unlockFocus() }
        
        NSGraphicsContext.current?.imageInterpolation = .high
        let rect = NSRect(origin: .zero, size: size)
        
        // Preserve aspect ratio
        let originalAspect = self.size.width / self.size.height
        let targetAspect = size.width / size.height
        
        var drawRect = rect
        
        if originalAspect > targetAspect {
            // Original is wider
            let scaledHeight = size.width / originalAspect
            drawRect.origin.y = (size.height - scaledHeight) / 2
            drawRect.size.height = scaledHeight
        } else if originalAspect < targetAspect {
            // Original is taller
            let scaledWidth = size.height * originalAspect
            drawRect.origin.x = (size.width - scaledWidth) / 2
            drawRect.size.width = scaledWidth
        }
        
        draw(in: drawRect)
        return newImage
    }
}

@main
struct TimezoneBuddyMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = TeammateStore()

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var statusItem: NSStatusItem?
    var popover = NSPopover()
    var store = TeammateStore()
    private var timer: Timer?
    private var contentViewController: NSHostingController<ContentView>?
    
    private var mainMenu: NSMenu {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Open Timezone Buddy", action: #selector(togglePopover(_:)), keyEquivalent: "o"))
        
        menu.addItem(NSMenuItem.separator())
        
        let exportItem = NSMenuItem(title: "Export Teammates", action: #selector(exportTeammates), keyEquivalent: "e")
        exportItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(exportItem)
        
        let importItem = NSMenuItem(title: "Import Teammates", action: #selector(importTeammates), keyEquivalent: "i")
        importItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(importItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        return menu
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = ContentView(store: store)
        let hostingController = NSHostingController(rootView: contentView)
        self.contentViewController = hostingController
        
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = hostingController

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Timezone Buddy")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        // Register for workspace notifications to handle closing popover when user clicks outside
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.popover.isShown else { return }
            self.popover.performClose(event)
        }
        
        // Set app to only show in status bar
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func updateStatusItemTitle() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        statusItem?.button?.title = " \(formatter.string(from: Date()))"
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            statusItem?.menu = mainMenu
            statusItem?.button?.performClick(nil)
            return
        }
        
        if let button = statusItem?.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                
                // Bring focus to popover
                popover.contentViewController?.view.window?.makeKey()
                if let app = NSApp {
                    app.activate(ignoringOtherApps: true)
                }
            }
        }
    }
    
    @objc func exportTeammates() {
        guard let data = store.exportTeammates() else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "TimezoneBuddyExport.json"
        savePanel.title = "Export Teammates"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? data.write(to: url)
                // Bring the app back to front
                DispatchQueue.main.async {
                    if let app = NSApp {
                        app.activate(ignoringOtherApps: true)
                    }
                }
            }
        }
    }
    
    @objc func importTeammates() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Import Teammates"
        
        openPanel.begin { [weak self] response in
            guard let self = self, response == .OK, let url = openPanel.url else { return }
            
            do {
                let data = try Data(contentsOf: url)
                if self.store.importTeammates(from: data) {
                    // Update the UI
                    DispatchQueue.main.async {
                        self.contentViewController?.rootView = ContentView(store: self.store)
                        // Bring the app back to front
                        if let app = NSApp {
                            app.activate(ignoringOtherApps: true)
                        }
                    }
                } else {
                    self.showAlert(title: "Import Failed", message: "The selected file doesn't contain valid teammate data.")
                }
            } catch {
                self.showAlert(title: "Import Failed", message: "Error reading file: \(error.localizedDescription)")
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }
}


