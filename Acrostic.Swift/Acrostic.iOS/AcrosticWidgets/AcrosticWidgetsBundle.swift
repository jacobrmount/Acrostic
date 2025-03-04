//
//  AcrosticWidgetsBundle.swift
//  AcrosticWidgets
//
//  Created by Jacob Mount on 3/4/25.
//

import WidgetKit
import SwiftUI

@main
struct AcrosticWidgetsBundle: WidgetBundle {
    var body: some Widget {
        AcrosticWidgets()
        AcrosticWidgetsControl()
        AcrosticWidgetsLiveActivity()
    }
}
