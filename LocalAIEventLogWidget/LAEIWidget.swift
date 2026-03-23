import WidgetKit
import SwiftUI

@main
struct LAEIWidgetBundle: WidgetBundle {
    var body: some Widget {
        LAEIWidget()
    }
}

struct LAEIWidget: Widget {
    let kind: String = "LAEIWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LAEITimelineProvider()) { entry in
            WidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Local AI Monitor")
        .description("See which AI models are running on your Mac.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
