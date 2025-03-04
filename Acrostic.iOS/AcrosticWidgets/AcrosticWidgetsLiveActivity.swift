// AcrosticWidgets/AcrosticWidgetsConstrol.swift
import ActivityKit
import WidgetKit
import SwiftUI

struct AcrosticWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct AcrosticWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AcrosticWidgetsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension AcrosticWidgetsAttributes {
    fileprivate static var preview: AcrosticWidgetsAttributes {
        AcrosticWidgetsAttributes(name: "World")
    }
}

extension AcrosticWidgetsAttributes.ContentState {
    fileprivate static var smiley: AcrosticWidgetsAttributes.ContentState {
        AcrosticWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: AcrosticWidgetsAttributes.ContentState {
         AcrosticWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: AcrosticWidgetsAttributes.preview) {
    AcrosticWidgetsLiveActivity()
} contentStates: {
    AcrosticWidgetsAttributes.ContentState.smiley
    AcrosticWidgetsAttributes.ContentState.starEyes
}
