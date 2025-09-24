import SwiftUI

enum Tab: String, CaseIterable {
    case events = "Events"
    case activities = "Activities"
    case socials = "Socials"
}

struct Event: Identifiable {
    let id = UUID()
    let title: String
    let start: String
    let end: String
}

struct CalendarEventsView: View {
    @State private var selectedTab: Tab = .events
    @State private var selectedEvent: Event? = nil
    let days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    let dates = [12, 13, 14, 15, 16, 17, 18]
    
    var body: some View {
        VStack {
            Text("September 16")
                .font(.title)
            
            HStack {
                ForEach(0..<7) { index in
                    VStack {
                        Text(days[index])
                        Text("\(dates[index])")
                            .bold()
                            .foregroundColor(index == 4 ? .red : .black) // Highlight Friday 16
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            
            Picker("Tab", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            List {
                if selectedTab == .events {
                    Text("Starbucks - 10:00am to 11:00am")
                        .onTapGesture {
                            selectedEvent = Event(title: "Starbucks", start: "10:00am", end: "11:00am")
                        }
                } else {
                    Text("No \(selectedTab.rawValue) Available")
                }
            }
        }
        .navigationTitle("Calendar")
        .navigationDestination(item: $selectedEvent) { event in
            EventDetailView(event: event)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("+") {
                    // Add event
                }
            }
        }
        .gesture(DragGesture(minimumDistance: 50, coordinateSpace: .global)
            .onEnded { value in
                if value.translation.width > 0 {
                    // Long left-to-right swipe to go home
                }
            })
    }
}

struct EventDetailView: View {
    let event: Event
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(event.title)
                .font(.title)
            Text("Start: \(event.start)")
            Text("End: \(event.end)")
            Spacer()
        }
        .navigationTitle("Event Details")
    }
}

#Preview {
    CalendarEventsView()
}