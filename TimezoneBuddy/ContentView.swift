import SwiftUI
import AppKit
import CoreLocation
import ServiceManagement

struct Teammate: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var timeZoneIdentifier: String
    var imageData: Data?
    var email: String?
    var slackId: String?
    var groups: Set<String>
    
    enum CodingKeys: String, CodingKey {
        case id, name, timeZoneIdentifier, imageData, email, slackId, groups
    }
    
    init(id: UUID = UUID(), name: String, timeZoneIdentifier: String, imageData: Data?, email: String? = nil, slackId: String? = nil, groups: Set<String> = []) {
        self.id = id
        self.name = name
        self.timeZoneIdentifier = timeZoneIdentifier
        self.imageData = imageData
        self.email = email
        self.slackId = slackId
        self.groups = groups
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
    @Published var groups: Set<String> = [] {
        didSet {
            saveGroups()
        }
    }
    
    private let fileManager = FileManager.default
    
    private var appSupportURL: URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let bundleID = Bundle.main.bundleIdentifier ?? "com.timezonebuddy"
        let appFolder = appSupport.appendingPathComponent(bundleID)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: appFolder.path) {
            try? fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }
        
        return appFolder
    }
    
    private var teammatesFileURL: URL? {
        appSupportURL?.appendingPathComponent("teammates.json")
    }
    
    private var groupsFileURL: URL? {
        appSupportURL?.appendingPathComponent("groups.json")
    }
    
    init() {
        // Only load data if it exists in the user's Application Support directory
        loadTeammates()
        loadGroups()
        
        // If this is the first launch (no data exists), initialize with empty state
        if teammates.isEmpty {
            // Start with empty arrays - no pre-loaded data
            teammates = []
            groups = []
            
            // Save the empty state to create the files
            saveTeammates()
            saveGroups()
        }
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
    
    func addGroup(_ group: String) {
        groups.insert(group)
    }
    
    func removeGroup(_ group: String) {
        groups.remove(group)
        // Remove the group from all teammates
        for (index, teammate) in teammates.enumerated() {
            var updatedTeammate = teammate
            updatedTeammate.groups.remove(group)
            teammates[index] = updatedTeammate
        }
        saveTeammates()
    }
    
    private func saveTeammates() {
        guard let url = teammatesFileURL else { return }
        
        do {
            let data = try JSONEncoder().encode(teammates)
            try data.write(to: url)
        } catch {
            print("Error saving teammates: \(error)")
        }
    }
    
    private func loadTeammates() {
        guard let url = teammatesFileURL,
              fileManager.fileExists(atPath: url.path) else { return }
        
        do {
            let data = try Data(contentsOf: url)
            teammates = try JSONDecoder().decode([Teammate].self, from: data)
        } catch {
            print("Error loading teammates: \(error)")
            // If there's an error loading data, start fresh
            teammates = []
        }
    }
    
    private func saveGroups() {
        guard let url = groupsFileURL else { return }
        
        do {
            let data = try JSONEncoder().encode(Array(groups))
            try data.write(to: url)
        } catch {
            print("Error saving groups: \(error)")
        }
    }
    
    private func loadGroups() {
        guard let url = groupsFileURL,
              fileManager.fileExists(atPath: url.path) else { return }
        
        do {
            let data = try Data(contentsOf: url)
            groups = Set(try JSONDecoder().decode([String].self, from: data))
        } catch {
            print("Error loading groups: \(error)")
            // If there's an error loading data, start fresh
            groups = []
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
    
    // Clean up all stored data
    func resetAllData() {
        guard let appSupport = appSupportURL else { return }
        
        try? fileManager.removeItem(at: appSupport)
        teammates = []
        groups = []
    }
}

struct ContentView: View {
    @ObservedObject var store: TeammateStore
    @State private var showingAddSheet = false
    @State private var searchText = ""
    @State private var editingTeammate: Teammate? = nil
    @State private var currentTime = Date()
    @State private var sortOrder: SortOrder = .name
    @State private var groupBy: GroupBy = .none
    
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
    
    enum GroupBy: String, CaseIterable {
        case none = "None"
        case group = "Group"
        case timeZone = "Time Zone"
        
        var systemImage: String {
            switch self {
            case .none: return "rectangle.grid.1x2"
            case .group: return "folder"
            case .timeZone: return "globe"
            }
        }
    }
    
    var groupedTeammates: [(String, [Teammate])] {
        let filtered = filteredTeammates
        
        switch groupBy {
        case .none:
            return [("All", filtered)]
        case .group:
            let grouped = Dictionary(grouping: filtered) { $0.groups.first ?? "Ungrouped" }
            return grouped.sorted { $0.key < $1.key }
        case .timeZone:
            let grouped = Dictionary(grouping: filtered) { $0.timeZoneIdentifier }
            return grouped.sorted { $0.key < $1.key }
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
                Image("applogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 24)
                    .padding(.vertical, 2)
                    .saturation(1.1)
                    .contrast(1.1)
                Spacer()
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Add Teammate")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color(.windowBackgroundColor)
                    .opacity(0.95)
                    .background(.ultraThinMaterial)
            )
            
            // Search, Sort, and Group
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    TextField("Search cities or time zones...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                }
                .padding(6)
                .background(Color(.controlBackgroundColor).opacity(0.8))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                )
                
                Menu {
                    Picker("Sort by", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { option in
                            Label(option.rawValue, systemImage: option.systemImage)
                                .tag(option)
                        }
                    }
                } label: {
                    Image(systemName: sortOrder.systemImage)
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                        .frame(width: 24, height: 24)
                        .background(Color(.controlBackgroundColor).opacity(0.8))
                        .clipShape(Circle())
                }
                .menuStyle(.borderlessButton)
                
                Menu {
                    Picker("Group by", selection: $groupBy) {
                        ForEach(GroupBy.allCases, id: \.self) { option in
                            Label(option.rawValue, systemImage: option.systemImage)
                                .tag(option)
                        }
                    }
                } label: {
                    Image(systemName: groupBy.systemImage)
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                        .frame(width: 24, height: 24)
                        .background(Color(.controlBackgroundColor).opacity(0.8))
                        .clipShape(Circle())
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color(.windowBackgroundColor)
                    .opacity(0.95)
                    .background(.ultraThinMaterial)
            )
            
            // Teammates List
            if filteredTeammates.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.7))
                        .symbolEffect(.bounce, options: .repeating)
                    Text("No teammates yet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Button(action: { showingAddSheet = true }) {
                        Text("Add Your First Teammate")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor)
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.windowBackgroundColor))
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groupedTeammates, id: \.0) { group, teammates in
                            if groupBy != .none {
                                Text(group)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.windowBackgroundColor).opacity(0.95))
                            }
                            
                            ForEach(teammates) { teammate in
                                teammateRow(teammate)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                .padding(.vertical, 4)
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
            withAnimation {
                currentTime = Date()
            }
        }
    }
    
    private func teammateRow(_ teammate: Teammate) -> some View {
        HStack(spacing: 10) {
            // Profile Image
            if let imageData = teammate.imageData,
               let nsImage = NSImage(data: imageData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                    .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    .overlay(Circle().stroke(Color(.separatorColor).opacity(0.2), lineWidth: 0.5))
                    } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.secondary.opacity(0.5))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                        Text(teammate.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                        Text(teammate.localTime)
                        .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    
                    Text(teammate.timeDifference)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(teammate.timeDifference.hasPrefix("-") ? 
                            .red.opacity(0.7) : 
                            Color.green.opacity(0.7))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            teammate.timeDifference.hasPrefix("-") ?
                                Color.red.opacity(0.1) :
                                Color.green.opacity(0.1)
                        )
                        .cornerRadius(3)
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
                            .frame(width: 16, height: 16)
                            .saturation(1.1)
                            .opacity(0.8)
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
                            .frame(width: 16, height: 16)
                            .saturation(1.1)
                            .opacity(0.8)
                            }
                            .buttonStyle(.plain)
                    .help("Message \(teammate.name) on Slack")
                }
            }
        }
        .padding(8)
        .background(Color(.controlBackgroundColor).opacity(0.05))
        .cornerRadius(8)
        .modifier(HoverEffect())
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
    @State private var selectedGroups: Set<String>
    @State private var newGroup: String = ""
    @State private var isAddingGroup = false
    var teammateToEdit: Teammate?
    
    init(store: TeammateStore, teammate: Teammate? = nil) {
        self.store = store
        _name = State(initialValue: teammate?.name ?? "")
        _timeZone = State(initialValue: teammate?.timeZone ?? TimeZone.current)
        _imageData = State(initialValue: teammate?.imageData)
        _email = State(initialValue: teammate?.email)
        _slackId = State(initialValue: teammate?.slackId)
        _selectedGroups = State(initialValue: teammate?.groups ?? [])
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
                    Text("Groups")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(store.groups), id: \.self) { group in
                                Toggle(isOn: Binding(
                                    get: { selectedGroups.contains(group) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedGroups.insert(group)
                                        } else {
                                            selectedGroups.remove(group)
                                        }
                                    }
                                )) {
                                    Text(group)
                                        .font(.system(size: 11))
                                }
                                .toggleStyle(.button)
                                .buttonStyle(.borderless)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.removeGroup(group)
                                    } label: {
                                        Label("Delete Group", systemImage: "trash")
                                    }
                                }
                            }
                            
                            Button(action: { isAddingGroup = true }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $isAddingGroup) {
                                VStack(spacing: 12) {
                                    TextField("New Group Name", text: $newGroup)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 200)
                                    
                                    Button("Add Group") {
                                        if !newGroup.isEmpty {
                                            store.addGroup(newGroup)
                                            selectedGroups.insert(newGroup)
                                            newGroup = ""
                                            isAddingGroup = false
                                        }
                                    }
                                    .disabled(newGroup.isEmpty)
                                }
                                .padding()
                            }
                        }
                    }
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
                        slackId: slackId,
                        groups: selectedGroups
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
        
        // Bring the panel to front and make it modal
        panel.makeKeyAndOrderFront(nil)
        panel.level = .modalPanel
        
        panel.begin { response in
            isPickerActive = false
            
            if response == .OK, let url = panel.url {
                // Process the image in a background thread with high priority
                DispatchQueue.global(qos: .userInitiated).async {
                    autoreleasepool {
                        if let image = NSImage(contentsOf: url) {
                            // Optimize image size before processing
                            let maxSize: CGFloat = 400
                            let scale = min(maxSize / image.size.width, maxSize / image.size.height)
                            let targetSize = CGSize(
                                width: image.size.width * scale,
                                height: image.size.height * scale
                            )
                            
                            let resizedImage = image.resized(to: targetSize)
                            
                            // Convert to JPEG with optimized quality
                            if let tiffData = resizedImage.tiffRepresentation,
                               let bitmap = NSBitmapImageRep(data: tiffData),
                               let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) {
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
    private var loginService: SMAppService?
    
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
        
        // Add auto-launch toggle
        let autoLaunchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleAutoLaunch), keyEquivalent: "l")
        autoLaunchItem.keyEquivalentModifierMask = [.command]
        autoLaunchItem.state = isAutoLaunchEnabled ? .on : .off
        menu.addItem(autoLaunchItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add reset data option
        let resetItem = NSMenuItem(title: "Reset App Data", action: #selector(resetAppData), keyEquivalent: "")
        menu.addItem(resetItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit TimezoneBuddy", action: #selector(quitApp), keyEquivalent: "q"))
        
        return menu
    }
    
    private var isAutoLaunchEnabled: Bool {
        if #available(macOS 13.0, *) {
            return loginService?.status == .enabled
        } else {
            // Fallback for older macOS versions
            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                return SMLoginItemSetEnabled(bundleIdentifier as CFString, true)
            }
            return false
        }
    }
    
    @objc private func toggleAutoLaunch() {
        if #available(macOS 13.0, *) {
            do {
                if loginService == nil {
                    loginService = SMAppService.loginItem(identifier: "com.timezonebuddy")
                }
                
                if let service = loginService {
                    if service.status == .enabled {
                        try service.unregister()
                    } else {
                        try service.register()
                    }
                    
                    // Update menu item state
                    if let menu = statusItem?.menu {
                        if let item = menu.item(withTitle: "Launch at Login") {
                            item.state = service.status == .enabled ? .on : .off
                        }
                    }
                }
            } catch {
                print("Failed to toggle auto-launch: \(error)")
            }
        } else {
            // Fallback for older macOS versions
            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                let enabled = !isAutoLaunchEnabled
                SMLoginItemSetEnabled(bundleIdentifier as CFString, enabled)
                
                // Update menu item state
                if let menu = statusItem?.menu {
                    if let item = menu.item(withTitle: "Launch at Login") {
                        item.state = enabled ? .on : .off
                    }
                }
            }
        }
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize login service
        if #available(macOS 13.0, *) {
            loginService = SMAppService.loginItem(identifier: "com.timezonebuddy")
        }
        
        let contentView = ContentView(store: store)
        let hostingController = NSHostingController(rootView: contentView)
        self.contentViewController = hostingController
        
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = hostingController

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Use system globe icon
            button.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Timezone Buddy")
            button.imagePosition = .imageLeft
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
    
    @objc private func resetAppData() {
        let alert = NSAlert()
        alert.messageText = "Reset App Data"
        alert.informativeText = "Are you sure you want to reset all app data? This will remove all teammates and groups. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            store.resetAllData()
            // Update the UI
            contentViewController?.rootView = ContentView(store: store)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }
}

struct HoverEffect: ViewModifier {
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.pointingHand.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(isHovered ? 0.2 : 0))
            )
    }
}


