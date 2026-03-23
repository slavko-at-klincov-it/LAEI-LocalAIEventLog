import WidgetKit

struct LAEIWidgetEntry: TimelineEntry {
    let date: Date
    let state: AppState
}

struct LAEITimelineProvider: TimelineProvider {
    private let reader = SharedStateReader()

    func placeholder(in context: Context) -> LAEIWidgetEntry {
        LAEIWidgetEntry(date: .now, state: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (LAEIWidgetEntry) -> Void) {
        let state = reader.read()
        completion(LAEIWidgetEntry(date: .now, state: state))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LAEIWidgetEntry>) -> Void) {
        let state = reader.read()
        let entry = LAEIWidgetEntry(date: .now, state: state)
        let nextUpdate = Calendar.current.date(byAdding: .second, value: 30, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}
