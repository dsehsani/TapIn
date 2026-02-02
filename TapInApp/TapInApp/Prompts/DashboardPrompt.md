# SwiftUI Conversion Prompt for UC Davis News App

## IMPORTANT CONTEXT - READ FIRST

**This is a UI-ONLY implementation.** I need you to create the visual interface that matches my Google Stitch design, but I will handle the actual data implementation (web scraping, games, backend) separately later.

**Your Goal:**
- Build the complete UI structure using MVVM architecture
- Use mock/placeholder data to make the UI look complete and functional
- Set up ViewModels with empty functions that I can fill in later
- Make it crystal clear WHERE I need to add my web scraping, games logic, and data sources
- Ensure when I do have real data, I can simply drop it into the ViewModels without touching the Views

**What I'm handling separately:**
- Web scraping for news articles
- Games implementation and logic  
- Backend API integration
- Real data fetching

**What you should provide:**
- Complete, polished UI that matches the design
- MVVM structure with placeholder ViewModels ready for my data
- Sample data so the app looks functional in preview
- Clear `// TODO: ADD YOUR DATA HERE` comments in ViewModels

---

Please convert the Google Stitch HTML/CSS design I've created into a modular, scalable SwiftUI app for iOS using MVVM architecture. Focus on creating reusable components and clear separation of concerns for easy future data integration.

## Project Structure
**IMPORTANT:** Before writing any code, please ask me to create the necessary Swift files for this project. Swift requires specific file organization and I need to set these up properly in Xcode.

Recommended file structure (MVVM Architecture):
- **Models/** - Data structures (NewsArticle, Event, etc.)
- **ViewModels/** - Business logic & state management (placeholder implementations ready for my data)
- **Views/** - SwiftUI views (UI-only, no business logic)
- **Components/** - Reusable UI components
- **Utilities/** - Extensions, helpers, constants
- **Services/** - (Future) API, web scraping, data fetching services

---

## 1. Data Models (Foundation for Expansion)

Create clear, expandable data structures with detailed comments:

```swift
// MARK: - NewsArticle Model
// Represents a single news article
// EXPAND: Add properties like: author, reactions, commentCount, shareURL, isPinned
struct NewsArticle: Identifiable {
    let id: UUID
    let title: String
    let excerpt: String
    let imageURL: String  // Placeholder for now
    let category: String
    let timestamp: Date
    
    // TODO: Add these when implementing backend
    // let author: String
    // let fullContent: String
    // let tags: [String]
}

// MARK: - Tab Items Enum
// Defines bottom navigation tabs
// EXPAND: Easy to add/remove tabs by modifying this enum
enum TabItem: String, CaseIterable {
    case news = "News"
    case campus = "Campus"
    case games = "Games"
    case saved = "Saved"
    case profile = "Profile"
    
    var icon: String {
        // SF Symbols icons
        // EDIT: Change icons here
    }
}
```

---

## 2. ViewModels (MVVM - Business Logic Layer)

**CRITICAL:** ViewModels contain ALL business logic and state management. Views should ONLY display data from ViewModels. This is where you'll add web scraping, data fetching, and game logic later.

### NewsViewModel
```swift
// MARK: - News ViewModel
// Handles all news-related business logic and state
// TODO: ADD YOUR WEB SCRAPING LOGIC HERE

import Foundation
import SwiftUI

class NewsViewModel: ObservableObject {
    // MARK: - Published Properties (UI updates automatically when these change)
    @Published var articles: [NewsArticle] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedCategory: String = "All"
    @Published var searchText: String = ""
    
    // MARK: - Initialization
    init() {
        // Load sample data for UI preview
        loadSampleData()
    }
    
    // MARK: - Data Fetching
    // TODO: REPLACE THIS WITH YOUR WEB SCRAPING IMPLEMENTATION
    func fetchArticles() {
        isLoading = true
        errorMessage = nil
        
        // PLACEHOLDER IMPLEMENTATION
        // When you're ready, replace this entire function with:
        // 1. Your web scraping logic (BeautifulSoup equivalent)
        // 2. API calls to your backend
        // 3. Database queries
        
        // Simulated network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.loadSampleData()
            self.isLoading = false
        }
        
        // EXAMPLE OF WHAT YOUR REAL IMPLEMENTATION MIGHT LOOK LIKE:
        // Task {
        //     do {
        //         let scrapedArticles = try await NewsScraperService.scrapeUCDavisNews()
        //         await MainActor.run {
        //             self.articles = scrapedArticles
        //             self.isLoading = false
        //         }
        //     } catch {
        //         await MainActor.run {
        //             self.errorMessage = error.localizedDescription
        //             self.isLoading = false
        //         }
        //     }
        // }
    }
    
    // MARK: - Filtering & Search
    // TODO: Implement real filtering when you have category data
    func filterByCategory(_ category: String) {
        selectedCategory = category
        // PLACEHOLDER: Add filtering logic here
        // articles = allArticles.filter { $0.category == category }
    }
    
    // TODO: Implement search functionality
    func searchArticles(_ query: String) {
        searchText = query
        // PLACEHOLDER: Add search logic here
        // articles = allArticles.filter { $0.title.contains(query) }
    }
    
    // MARK: - Refresh
    func refreshArticles() {
        fetchArticles()
    }
    
    // MARK: - Sample Data (DELETE THIS WHEN YOU ADD REAL DATA)
    private func loadSampleData() {
        articles = NewsArticle.sampleData
    }
}
```

### GamesViewModel
```swift
// MARK: - Games ViewModel
// Manages game state and available games
// TODO: ADD YOUR GAME LOGIC HERE

import Foundation
import SwiftUI

class GamesViewModel: ObservableObject {
    @Published var availableGames: [Game] = []
    @Published var currentGame: Game?
    @Published var isLoading: Bool = false
    
    init() {
        loadAvailableGames()
    }
    
    // TODO: REPLACE WITH YOUR GAMES IMPLEMENTATION
    func loadAvailableGames() {
        isLoading = true
        
        // PLACEHOLDER IMPLEMENTATION
        // Replace this with your actual games list
        // This could come from:
        // 1. Hardcoded list of your implemented games
        // 2. Backend API that tracks available games
        // 3. Dynamic game discovery system
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.availableGames = Game.sampleData
            self.isLoading = false
        }
    }
    
    // TODO: Implement game launching logic
    func startGame(_ game: Game) {
        currentGame = game
        // PLACEHOLDER: Navigate to game view
        // This is where you'll present your Wordle-style game
    }
    
    // TODO: Add game-specific functions as needed
    // func saveGameProgress() { }
    // func loadGameProgress() { }
    // func submitScore(_ score: Int, for game: Game) { }
}

// MARK: - Game Model
struct Game: Identifiable {
    let id: UUID
    let name: String
    let description: String
    let iconName: String
    let isMultiplayer: Bool
    
    // TODO: Add your game-specific properties when implementing
    // let gameType: GameType
    // let difficulty: Difficulty
    // let estimatedPlayTime: Int
}

extension Game {
    static let sampleData: [Game] = [
        Game(
            id: UUID(),
            name: "Aggie Wordle",
            description: "UC Davis themed daily word puzzle",
            iconName: "gamecontroller.fill",
            isMultiplayer: false
        ),
        Game(
            id: UUID(),
            name: "Campus Trivia",
            description: "Test your Davis knowledge with friends",
            iconName: "questionmark.circle.fill",
            isMultiplayer: true
        ),
        Game(
            id: UUID(),
            name: "Aggie Crossword",
            description: "Weekly campus-themed crossword",
            iconName: "square.grid.3x3.fill",
            isMultiplayer: false
        )
    ]
}
```

### CampusViewModel (Events)
```swift
// MARK: - Campus/Events ViewModel  
// Manages campus events and activities
// TODO: ADD YOUR EVENTS DATA SOURCE HERE

import Foundation
import SwiftUI

class CampusViewModel: ObservableObject {
    @Published var events: [CampusEvent] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var filterType: EventFilterType = .all
    
    init() {
        loadEvents()
    }
    
    // TODO: REPLACE WITH YOUR EVENTS DATA SOURCE
    func fetchEvents() {
        isLoading = true
        errorMessage = nil
        
        // PLACEHOLDER IMPLEMENTATION
        // Replace this with your actual data source:
        // Option 1: Web scraping official UC Davis events calendar
        // Option 2: Backend API for student-posted events
        // Option 3: Hybrid approach (official + student events)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.loadEvents()
            self.isLoading = false
        }
        
        // EXAMPLE REAL IMPLEMENTATION:
        // Task {
        //     do {
        //         // Fetch official events
        //         let officialEvents = try await EventScraperService.scrapeOfficialEvents()
        //         // Fetch student-posted events  
        //         let studentEvents = try await EventAPIService.fetchStudentEvents()
        //         
        //         await MainActor.run {
        //             self.events = officialEvents + studentEvents
        //             self.isLoading = false
        //         }
        //     } catch {
        //         await MainActor.run {
        //             self.errorMessage = error.localizedDescription
        //             self.isLoading = false
        //         }
        //     }
        // }
    }
    
    // TODO: Implement filtering logic
    func filterEvents(by type: EventFilterType) {
        filterType = type
        // PLACEHOLDER: Filter events based on type
        // let filtered = allEvents.filter { event in
        //     switch type {
        //     case .all: return true
        //     case .official: return event.isOfficial
        //     case .studentPosted: return !event.isOfficial
        //     case .today: return Calendar.current.isDateInToday(event.date)
        //     case .thisWeek: return event.date < Date().addingTimeInterval(7*86400)
        //     }
        // }
    }
    
    func refreshEvents() {
        fetchEvents()
    }
    
    // MARK: - Sample Data (DELETE WHEN ADDING REAL DATA)
    private func loadEvents() {
        events = CampusEvent.sampleData
    }
}

// MARK: - Campus Event Model
struct CampusEvent: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let date: Date
    let location: String
    let isOfficial: Bool  // Distinguishes official vs student-posted
    let imageURL: String?
    
    // TODO: Add properties when implementing
    // let organizerName: String
    // let category: EventCategory
    // let attendeeCount: Int
    // let rsvpURL: String?
}

enum EventFilterType: String, CaseIterable {
    case all = "All Events"
    case official = "Official"
    case studentPosted = "Student Events"
    case today = "Today"
    case thisWeek = "This Week"
}

extension CampusEvent {
    static let sampleData: [CampusEvent] = [
        CampusEvent(
            id: UUID(),
            title: "Spring Career Fair 2026",
            description: "Connect with top employers and explore internship opportunities",
            date: Date().addingTimeInterval(86400 * 7),
            location: "ARC Pavilion",
            isOfficial: true,
            imageURL: nil
        ),
        CampusEvent(
            id: UUID(),
            title: "CS Study Group - Algorithms",
            description: "Weekly coding practice and problem-solving session",
            date: Date().addingTimeInterval(3600 * 2),
            location: "Shields Library, Room 101",
            isOfficial: false,
            imageURL: nil
        ),
        CampusEvent(
            id: UUID(),
            title: "Picnic Day Planning Meeting",
            description: "Help plan UC Davis's annual open house event",
            date: Date().addingTimeInterval(86400 * 3),
            location: "Memorial Union",
            isOfficial: true,
            imageURL: nil
        )
    ]
}
```

### SavedViewModel
```swift
// MARK: - Saved Articles ViewModel
// Manages bookmarked/saved content
// TODO: ADD PERSISTENCE LOGIC HERE (UserDefaults, CoreData, or backend)

import Foundation
import SwiftUI

class SavedViewModel: ObservableObject {
    @Published var savedArticles: [NewsArticle] = []
    @Published var savedEvents: [CampusEvent] = []
    
    init() {
        loadSavedContent()
    }
    
    // TODO: IMPLEMENT PERSISTENCE
    func saveArticle(_ article: NewsArticle) {
        // PLACEHOLDER: Save to UserDefaults, CoreData, or backend
        if !savedArticles.contains(where: { $0.id == article.id }) {
            savedArticles.append(article)
            // Save to persistent storage here
        }
    }
    
    func removeArticle(_ article: NewsArticle) {
        savedArticles.removeAll { $0.id == article.id }
        // Remove from persistent storage here
    }
    
    func saveEvent(_ event: CampusEvent) {
        if !savedEvents.contains(where: { $0.id == event.id }) {
            savedEvents.append(event)
            // Save to persistent storage here
        }
    }
    
    func removeEvent(_ event: CampusEvent) {
        savedEvents.removeAll { $0.id == event.id }
        // Remove from persistent storage here
    }
    
    // MARK: - Persistence (TODO: IMPLEMENT)
    private func loadSavedContent() {
        // PLACEHOLDER: Load from UserDefaults/CoreData
        // let saved = UserDefaults.standard.data(forKey: "savedArticles")
        // savedArticles = decode(saved)
    }
    
    private func persistContent() {
        // PLACEHOLDER: Save to UserDefaults/CoreData
        // let encoded = encode(savedArticles)
        // UserDefaults.standard.set(encoded, forKey: "savedArticles")
    }
}
```

### ProfileViewModel  
```swift
// MARK: - Profile ViewModel
// Manages user profile and settings
// TODO: ADD USER AUTHENTICATION AND PROFILE MANAGEMENT

import Foundation
import SwiftUI

class ProfileViewModel: ObservableObject {
    @Published var userName: String = "Guest"
    @Published var userEmail: String = ""
    @Published var isLoggedIn: Bool = false
    @Published var notificationsEnabled: Bool = true
    
    // TODO: IMPLEMENT AUTHENTICATION
    func login(email: String, password: String) {
        // PLACEHOLDER: Implement login logic
        // This would connect to your auth backend
    }
    
    func logout() {
        userName = "Guest"
        userEmail = ""
        isLoggedIn = false
    }
    
    func updateProfile(name: String, email: String) {
        // PLACEHOLDER: Update profile on backend
        userName = name
        userEmail = email
    }
    
    func toggleNotifications() {
        notificationsEnabled.toggle()
        // PLACEHOLDER: Update notification preferences
    }
}
```
    
    // MARK: - Initialization
    init() {
        // Load sample data for UI testing
        loadSampleData()
    }
    
    // MARK: - Data Loading Methods
    // TODO: REPLACE THIS WITH YOUR WEB SCRAPING IMPLEMENTATION
    func loadSampleData() {
        // For now, just load mock data
        self.articles = NewsArticle.sampleData
    }
    
    // TODO: ADD YOUR WEB SCRAPING HERE
    func fetchArticles() async {
        isLoading = true
        
        // ⚠️ THIS IS WHERE YOUR WEB SCRAPING GOES
        // Example structure:
        // do {
        //     let scrapedArticles = try await YourWebScrapingService.scrapeNews()
        //     await MainActor.run {
        //         self.articles = scrapedArticles
        //         self.isLoading = false
        //     }
        // } catch {
        //     await MainActor.run {
        //         self.errorMessage = error.localizedDescription
        //         self.isLoading = false
        //     }
        // }
        
        // For now: simulate loading with sample data
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await MainActor.run {
            self.articles = NewsArticle.sampleData
            self.isLoading = false
        }
    }
    
    // TODO: ADD FILTERING LOGIC HERE
    func filterByCategory(_ category: String) {
        selectedCategory = category
        // ⚠️ Filter your scraped articles here
        if category == "All" {
            loadSampleData()
        } else {
            // Filter logic
            self.articles = NewsArticle.sampleData.filter { $0.category == category }
        }
    }
    
    // TODO: ADD REFRESH LOGIC HERE
    func refreshArticles() async {
        // ⚠️ Re-scrape or reload data from your source
        await fetchArticles()
    }
}

// MARK: - Campus/Events ViewModel
// Handles campus events and activities
// ⚠️ TODO: ADD YOUR EVENTS DATA SOURCE HERE

class CampusViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var isLoading: Bool = false
    
    init() {
        loadSampleEvents()
    }
    
    // TODO: REPLACE WITH YOUR ACTUAL DATA SOURCE
    func loadSampleEvents() {
        // ⚠️ ADD YOUR EVENT SCRAPING/FETCHING HERE
        self.events = Event.sampleData
    }
    
    func fetchEvents() async {
        // ⚠️ YOUR EVENT DATA FETCHING LOGIC GOES HERE
        isLoading = true
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await MainActor.run {
            self.events = Event.sampleData
            self.isLoading = false
        }
    }
}

// MARK: - Games ViewModel  
// Handles games state and logic
// ⚠️ TODO: ADD YOUR GAMES IMPLEMENTATION HERE

class GamesViewModel: ObservableObject {
    @Published var availableGames: [Game] = []
    @Published var userStats: GameStats?
    
    init() {
        loadSampleGames()
    }
    
    // TODO: IMPLEMENT YOUR GAMES LOGIC
    func loadSampleGames() {
        // ⚠️ YOUR GAMES LIST GOES HERE
        self.availableGames = Game.sampleData
    }
    
    // TODO: ADD GAME LAUNCHING LOGIC
    func launchGame(_ game: Game) {
        // ⚠️ NAVIGATE TO YOUR GAME VIEW HERE
        print("Launching game: \(game.name)")
    }
}

// MARK: - Saved Articles ViewModel
// Handles bookmarked/saved articles
// ⚠️ TODO: ADD PERSISTENCE LOGIC (UserDefaults, CoreData, etc.)

class SavedViewModel: ObservableObject {
    @Published var savedArticles: [NewsArticle] = []
    
    // TODO: IMPLEMENT SAVE/UNSAVE LOGIC
    func saveArticle(_ article: NewsArticle) {
        // ⚠️ ADD TO PERSISTENT STORAGE HERE
        if !savedArticles.contains(where: { $0.id == article.id }) {
            savedArticles.append(article)
        }
    }
    
    func unsaveArticle(_ article: NewsArticle) {
        // ⚠️ REMOVE FROM PERSISTENT STORAGE HERE
        savedArticles.removeAll { $0.id == article.id }
    }
    
    func isArticleSaved(_ article: NewsArticle) -> Bool {
        return savedArticles.contains(where: { $0.id == article.id })
    }
}

// MARK: - Profile ViewModel
// Handles user profile and settings
// ⚠️ TODO: ADD USER AUTHENTICATION AND PROFILE LOGIC

class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoggedIn: Bool = false
    
    // TODO: IMPLEMENT AUTHENTICATION
    func login(email: String, password: String) async {
        // ⚠️ YOUR LOGIN LOGIC HERE
        isLoggedIn = true
    }
    
    func logout() {
        // ⚠️ YOUR LOGOUT LOGIC HERE
        isLoggedIn = false
        user = nil
    }
}
```

**Additional Model Structures Needed:**
```swift
// MARK: - Supporting Models
// Add these to your Models folder

struct Event: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let date: Date
    let location: String
    let isOfficial: Bool // true = official UC Davis, false = student-posted
    
    static let sampleData: [Event] = [
        Event(id: UUID(), title: "Campus Career Fair", description: "Meet employers...", 
              date: Date(), location: "Memorial Union", isOfficial: true),
        Event(id: UUID(), title: "Study Group - CS101", description: "Preparing for midterm...", 
              date: Date(), location: "Shields Library", isOfficial: false)
    ]
}

struct Game: Identifiable {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    
    static let sampleData: [Game] = [
        Game(id: UUID(), name: "UC Davis Wordle", description: "Guess the Aggie word!", icon: "gamecontroller.fill"),
        Game(id: UUID(), name: "Campus Trivia", description: "Test your UC Davis knowledge", icon: "questionmark.circle.fill")
    ]
}

struct GameStats: Codable {
    var gamesPlayed: Int
    var currentStreak: Int
    var maxStreak: Int
}

struct User: Identifiable, Codable {
    let id: UUID
    var name: String
    var email: String
    var profileImageURL: String?
}
```

---

## 3. Reusable Components (Modular Design)

Break the UI into small, reusable components. Each component should be in its own file for easy editing:

### ArticleCardView Component
```swift
// MARK: - Article Card Component
// Reusable card for displaying news articles
// EXPAND: Add features like: bookmark button, share sheet, read time indicator
// EDIT: Modify card styling, layout, shadows, corners here

struct ArticleCardView: View {
    let article: NewsArticle
    
    // TODO: Add these for interactivity
    // @Binding var isBookmarked: Bool
    // var onTap: () -> Void
    
    var body: some View {
        // Card layout here
    }
}
```

### CustomTabBar Component
```swift
// MARK: - Custom Tab Bar Component
// Bottom navigation bar
// EXPAND: Add notification badges, custom animations, haptic feedback
// EDIT: Modify tab bar styling, spacing, icon sizes here

struct CustomTabBar: View {
    @Binding var selectedTab: TabItem
    
    var body: some View {
        // Tab bar layout here
    }
}
```

### TopNavigationBar Component
```swift
// MARK: - Top Navigation Bar Component
// Header with app branding and account icon
// EXPAND: Add search button, notification bell, settings
// EDIT: Modify header styling here

struct TopNavigationBar: View {
    var onAccountTap: () -> Void
    
    var body: some View {
        // Navigation bar layout here
    }
}
```

---

## 4. Main Screen Architecture (MVVM Pattern)

Structure the main view to use ViewModels properly. **Views should NEVER contain business logic - only display data from ViewModels.**

```swift
// MARK: - Main Content View
// Primary container for the app - MVVM Architecture
// Views: Multiple view screens (NewsView, CampusView, etc.)
// ViewModels: Each view has its own ViewModel for state/logic
// ARCHITECTURE: Uses TabView for navigation between main sections

struct ContentView: View {
    // MARK: - State Properties
    @State private var selectedTab: TabItem = .news
    
    // MARK: - ViewModels (MVVM - create once and pass to views)
    // ⚠️ These ViewModels are where ALL your data logic lives
    @StateObject private var newsViewModel = NewsViewModel()
    @StateObject private var campusViewModel = CampusViewModel()
    @StateObject private var gamesViewModel = GamesViewModel()
    @StateObject private var savedViewModel = SavedViewModel()
    @StateObject private var profileViewModel = ProfileViewModel()
    
    // TODO: Add these for future features
    // @State private var searchText: String = ""
    // @State private var isRefreshing: Bool = false
    // @State private var selectedCategory: String = "All"
    
    var body: some View {
        // MARK: - Main Container
        // EXPAND: Wrap in NavigationView for deep linking later
        TabView(selection: $selectedTab) {
            
            // MARK: - News Tab
            // Passes NewsViewModel to NewsView (MVVM pattern)
            NewsView(viewModel: newsViewModel)
                .tabItem {
                    Label(TabItem.news.rawValue, systemImage: TabItem.news.icon)
                }
                .tag(TabItem.news)
            
            // MARK: - Campus Tab
            // TODO: When you create CampusView, replace PlaceholderView with:
            // CampusView(viewModel: campusViewModel)
            PlaceholderView(title: "Campus")
                .tabItem {
                    Label(TabItem.campus.rawValue, systemImage: TabItem.campus.icon)
                }
                .tag(TabItem.campus)
            
            // MARK: - Games Tab
            // TODO: When you implement your games, replace PlaceholderView with:
            // GamesView(viewModel: gamesViewModel)
            // ⚠️ THIS IS WHERE YOU'LL CONNECT YOUR GAMES IMPLEMENTATION
            PlaceholderView(title: "Games")
                .tabItem {
                    Label(TabItem.games.rawValue, systemImage: TabItem.games.icon)
                }
                .tag(TabItem.games)
            
            // MARK: - Saved Tab
            // TODO: When you create SavedArticlesView, replace PlaceholderView with:
            // SavedArticlesView(viewModel: savedViewModel)
            PlaceholderView(title: "Saved")
                .tabItem {
                    Label(TabItem.saved.rawValue, systemImage: TabItem.saved.icon)
                }
                .tag(TabItem.saved)
            
            // MARK: - Profile Tab
            // TODO: When you create ProfileView, replace PlaceholderView with:
            // ProfileView(viewModel: profileViewModel)
            PlaceholderView(title: "Profile")
                .tabItem {
                    Label(TabItem.profile.rawValue, systemImage: TabItem.profile.icon)
                }
                .tag(TabItem.profile)
        }
        .accentColor(Color.ucdBlue) // UC Davis blue for selected tabs
    }
}

// MARK: - Placeholder View
// Temporary view for unimplemented tabs
// DELETE: Remove this once all views are connected
struct PlaceholderView: View {
    let title: String
    
    var body: some View {
        VStack {
            Text("\(title) View")
                .font(.largeTitle)
            Text("Coming Soon")
                .foregroundColor(.gray)
        }
    }
}
```

---

## 5. News Feed View (MVVM - View Layer Only)

```swift
// MARK: - News Feed View
// Displays scrollable list of articles from NewsViewModel
// ⚠️ IMPORTANT: This view has NO business logic - it only displays data from the ViewModel
// EXPAND: Add filtering UI, sorting options, pull-to-refresh, search bar
// PERFORMANCE: Uses LazyVStack for efficient scrolling

struct NewsView: View {
    // MARK: - ViewModel (MVVM pattern)
    // ⚠️ All data comes from this ViewModel
    @ObservedObject var viewModel: NewsViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                // MARK: - Top Navigation Bar
                TopNavigationBar(onAccountTap: {
                    // TODO: Navigate to account/profile
                })
                
                // MARK: - Loading Indicator
                if viewModel.isLoading {
                    ProgressView("Loading articles...")
                        .padding()
                }
                
                // MARK: - Article Feed
                // Data comes from viewModel.articles (MVVM)
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.articles) { article in
                        ArticleCardView(article: article)
                            .onTapGesture {
                                // TODO: Navigate to article detail view
                                // NavigationLink or sheet presentation
                            }
                    }
                }
                .padding()
            }
            .navigationBarHidden(true) // Using custom top bar
            .refreshable {
                // Pull-to-refresh calls ViewModel method
                await viewModel.refreshArticles()
            }
        }
        .onAppear {
            // Optionally fetch fresh data when view appears
            // Task {
            //     await viewModel.fetchArticles()
            // }
        }
    }
}
```

---

## 6. Color Scheme & Styling (Centralized Theme)

```swift
// MARK: - UC Davis Color Extensions
// Centralized color definitions for easy theme changes
// EXPAND: Add dark mode variants, accessibility colors

extension Color {
    // MARK: - Primary Colors
    static let ucdBlue = Color(hex: "#022851")
    static let ucdGold = Color(hex: "#FFBF00")
    
    // MARK: - UI Colors
    // EDIT: Modify app-wide colors here
    static let cardBackground = Color.white
    static let textPrimary = Color.black
    static let textSecondary = Color.gray
    
    // TODO: Add dark mode support
    // static let cardBackgroundDark = Color(hex: "#1C1C1E")
    
    // MARK: - Helper: Hex Color Initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (no alpha)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography Extensions
// Consistent text styles across the app
// EDIT: Modify font sizes, weights, styles here

extension Font {
    static let articleTitle = Font.system(size: 18, weight: .bold)
    static let articleExcerpt = Font.system(size: 14, weight: .regular)
    static let categoryTag = Font.system(size: 12, weight: .medium)
    static let timestamp = Font.system(size: 12, weight: .regular)
}
```

---

## 6. Sample Data (For Testing)

```swift
// MARK: - Sample Data Extension
// Mock data for preview and testing
// DELETE: Replace with real API data later

extension NewsArticle {
    static let sampleData: [NewsArticle] = [
        NewsArticle(
            id: UUID(),
            title: "UC Davis Researchers Make Breakthrough in Climate Science",
            excerpt: "New findings from the Department of Environmental Science could reshape our understanding of...",
            imageURL: "placeholder1",
            category: "Research",
            timestamp: Date().addingTimeInterval(-3600)
        ),
        NewsArticle(
            id: UUID(),
            title: "Aggies Win Big in Homecoming Game",
            excerpt: "The UC Davis football team secured a decisive victory against rivals in Saturday's homecoming...",
            imageURL: "placeholder2",
            category: "Sports",
            timestamp: Date().addingTimeInterval(-7200)
        ),
        NewsArticle(
            id: UUID(),
            title: "New Student Center Opens Next Month",
            excerpt: "After two years of construction, the expanded student center will feature modern study spaces...",
            imageURL: "placeholder3",
            category: "Campus Life",
            timestamp: Date().addingTimeInterval(-10800)
        )
    ]
}
```

---

## 7. Navigation Connection Guide

When you're ready to connect your other screens, follow this pattern:

```swift
// MARK: - How to Connect New Views

// Step 1: Create your new view file (e.g., GamesView.swift)
// Step 2: In ContentView, replace PlaceholderView with your view:

// BEFORE:
PlaceholderView(title: "Games")
    .tabItem { ... }

// AFTER:
GamesView()
    .tabItem { ... }

// For passing data between views:
GamesView(userProfile: userProfile) // Pass necessary data
    .tabItem { ... }
```

---

## 8. Future Expansion Checklist

Mark these sections in your code with `// FUTURE:` comments for easy searching:

**Features to add later:**
- [ ] Pull-to-refresh on news feed
- [ ] Search functionality
- [ ] Category filtering
- [ ] Article detail view with full content
- [ ] Bookmark/save functionality
- [ ] Dark mode support
- [ ] Push notifications
- [ ] User authentication
- [ ] Backend API integration
- [ ] Image caching
- [ ] Offline reading mode
- [ ] Social sharing
- [ ] Comments section

---

## 🚨 CRITICAL: MVVM Separation Reminder

Before generating code, remember:

**ViewModels (Business Logic Layer):**
- ✅ Data fetching, web scraping, API calls
- ✅ Data manipulation, filtering, sorting
- ✅ State management (@Published properties)
- ✅ Business rules and validation
- ⚠️ **THIS IS WHERE I ADD MY WEB SCRAPING AND GAMES LOGIC**

**Views (UI Layer):**
- ✅ Display data from ViewModel
- ✅ Handle user interactions (button taps, gestures)
- ✅ Call ViewModel methods
- ❌ NO data fetching or business logic
- ❌ NO direct manipulation of data

**Example of proper separation:**
```swift
// ❌ WRONG - Business logic in View
struct NewsView: View {
    @State private var articles: [NewsArticle] = []
    
    func fetchArticles() {
        // Scraping logic here - WRONG!
    }
}

// ✅ CORRECT - Business logic in ViewModel
class NewsViewModel: ObservableObject {
    @Published var articles: [NewsArticle] = []
    
    func fetchArticles() {
        // ⚠️ My web scraping goes here
    }
}

struct NewsView: View {
    @ObservedObject var viewModel: NewsViewModel
    // Just displays viewModel.articles
}
```

---

## Output Requirements

Please provide:

1. **File Structure List** - Ask me to create these Swift files before writing code:
   
   **Models/** (Data structures only - no logic)
   - Models/NewsArticle.swift
   - Models/Event.swift  
   - Models/Game.swift
   - Models/User.swift
   - Models/TabItem.swift
   
   **ViewModels/** (⚠️ THIS IS WHERE MY DATA LOGIC GOES)
   - ViewModels/NewsViewModel.swift (web scraping for news goes here)
   - ViewModels/CampusViewModel.swift (events data source goes here)
   - ViewModels/GamesViewModel.swift (games logic goes here)
   - ViewModels/SavedViewModel.swift (save/bookmark logic goes here)
   - ViewModels/ProfileViewModel.swift (user auth goes here)
   
   **Views/** (UI only - no business logic)
   - Views/ContentView.swift (main tab container)
   - Views/NewsView.swift (news feed screen)
   - Views/PlaceholderView.swift (temporary for unimplemented tabs)
   
   **Components/** (Reusable UI pieces)
   - Components/ArticleCardView.swift
   - Components/TopNavigationBar.swift
   - Components/CustomTabBar.swift (optional - can use native TabView)
   
   **Utilities/** (Helpers and extensions)
   - Utilities/ColorExtensions.swift
   - Utilities/FontExtensions.swift

2. **Complete Code** - For each file with:
   - Clear `// MARK:` sections
   - `// TODO:` for connection points
   - `// EXPAND:` for future features
   - `// EDIT:` for customization points
   - Inline comments explaining complex logic

3. **Setup Instructions** - Include:
   - Asset requirements (placeholder images, app icon)
   - Any required capabilities or permissions
   - How to preview in Xcode Canvas

4. **Architecture Notes** - Brief explanation of:
   - MVVM pattern: How Views, ViewModels, and Models connect
   - Data flow: User taps button → View calls ViewModel method → ViewModel updates @Published property → View automatically refreshes
   - Where to add my web scraping logic (ViewModels only)
   - Where to add my games implementation (GamesViewModel)
   - How Views should NEVER contain business logic

---

## Design Match Requirements

Ensure the SwiftUI implementation matches the Google Stitch design:
- Maintain exact spacing and padding from design
- Preserve UC Davis color scheme (#022851 blue, #FFBF00 gold)
- Match card shadows, corner radius, and visual hierarchy
- Use appropriate SF Symbols for icons
- Ensure responsive layout for different iPhone sizes

---

## Key Reminder
**Start by asking me which Swift files to create before writing any code!**
