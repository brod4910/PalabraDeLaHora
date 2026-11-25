import SwiftUI
import UserNotifications
import WidgetKit

@main
struct PalabraApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var router = AppRouter.shared
    @StateObject private var favorites = FavoritesStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(router)
                .environmentObject(favorites)
                .environmentObject(Speaker.shared)
                .onOpenURL { router.handle(url: $0) }
                .tint(Theme.coral)
        }
        .onChange(of: scenePhase) { _, phase in
            // Keep the local-notification queue topped up (iOS allows 64 pending).
            if phase == .active { Task { await NotificationScheduler.reschedule() } }
        }
    }
}

/// Routes deep links from the widget and taps on notifications.
@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    enum Tab: Hashable { case today, review, settings }

    @Published var tab: Tab = .today
    /// A word to present (from a widget tap or a notification) — may not be the current word.
    @Published var presentedWord: Word?
    @Published var autoplay = false

    /// palabra://word/<id>?play=1
    func handle(url: URL) {
        guard url.scheme == "palabra", url.host == "word" else { return }
        let id = url.pathComponents.dropFirst().first ?? ""
        let play = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "play" })?.value == "1"
        open(wordID: id, play: play)
    }

    func open(wordID: String, play: Bool) {
        guard let word = WordBank.word(id: wordID) else { return }
        tab = .today
        autoplay = play
        if word.id == WordSchedule.current.word(at: .now).id {
            presentedWord = nil
            if play { Speaker.shared.speak([word.spanish, word.example]) }
        } else {
            presentedWord = word
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        _ = AppSettings.startDate // stamp the first-launch date
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([NotificationScheduler.category])
        return true
    }

    // Show banners even while the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard let id = response.notification.request.content.userInfo["wordID"] as? String else { return }
        let play = response.actionIdentifier == NotificationScheduler.hearActionID
        await MainActor.run { AppRouter.shared.open(wordID: id, play: play) }
    }
}

/// Starred words, shared with the widget's App Group so they survive reinstalls of the widget.
@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var ids: Set<String> = AppSettings.favorites

    func contains(_ word: Word) -> Bool { ids.contains(word.id) }

    func toggle(_ word: Word) {
        if ids.contains(word.id) { ids.remove(word.id) } else { ids.insert(word.id) }
        AppSettings.favorites = ids
    }
}
