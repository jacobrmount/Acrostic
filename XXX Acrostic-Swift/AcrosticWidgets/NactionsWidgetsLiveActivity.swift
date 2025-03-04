//
//  NactionsWidgetsLiveActivity.swift
//  NactionsWidgets
//
//  Created by Jacob Mount on 3/4/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct NactionsWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct NactionsWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NactionsWidgetsAttributes.self) { context in
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

extension NactionsWidgetsAttributes {
    fileprivate static var preview: NactionsWidgetsAttributes {
        NactionsWidgetsAttributes(name: "World")
    }
}

extension NactionsWidgetsAttributes.ContentState {
    fileprivate static var smiley: NactionsWidgetsAttributes.ContentState {
        NactionsWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: NactionsWidgetsAttributes.ContentState {
         NactionsWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: NactionsWidgetsAttributes.preview) {
   NactionsWidgetsLiveActivity()
} contentStates: {
    NactionsWidgetsAttributes.ContentState.smiley
    NactionsWidgetsAttributes.ContentState.starEyes
}
