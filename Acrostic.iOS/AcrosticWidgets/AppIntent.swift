// AcrosticWidgets/AppIntent.swift
import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "This is an example widget." }

    // An example configurable parameter.
    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String
    
    // Add a method to refresh database options when configuration is opened
    func performInitialization() async throws {
        // Trigger data refresh in shared UserDefaults
        let appGroupID = "group.com.acrostic"
        if let defaults = UserDefaults(suiteName: appGroupID) {
            defaults.set(Date().timeIntervalSince1970, forKey: "widget_config_refresh_timestamp")
            defaults.synchronize()
        }
    }
}
