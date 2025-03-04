// NactionsWidgets/Views/WidgetViews.swift
import WidgetKit
import SwiftUI
import NactionsKit

// MARK: - Task Widget Views

struct TaskWidgetEntryView: View {
    var entry: TaskWidgetProvider.Entry
    @Environment(\.widgetFamily) private var widgetFamily
    
    var body: some View {
        ZStack {
            // Background
            Color("WidgetBackground")
                .edgesIgnoringSafeArea(.all)
            
            if let error = entry.error {
                VStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else if entry.tasks.isEmpty {
                VStack {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("No tasks to display")
                        .font(.caption)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    // Header
                    HStack {
                        Image(systemName: "checklist")
                            .foregroundColor(.blue)
                        Text("Tasks")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(entry.date, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 4)
                    
                    // Task List
                    taskListView()
                }
                .padding()
            }
        }
    }
    
    @ViewBuilder
    private func taskListView() -> some View {
        let tasksToShow = limitTasksForWidgetSize()
        
        VStack(alignment: .leading, spacing: 6) {
            ForEach(tasksToShow) { task in
                HStack(alignment: .center, spacing: 4) {
                    // Completion indicator
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.isCompleted ? .green : .gray)
                        .font(.system(size: 14))
                    
                    // Task title
                    Text(task.title)
                        .font(.subheadline)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Due date if available
                    if let dueDate = task.dueDate {
                        Text(relativeDateString(for: dueDate))
                            .font(.caption2)
                            .foregroundColor(isDueSoon(dueDate) ? .orange : .secondary)
                    }
                }
            }
            
            // Show count of remaining tasks if any were omitted
            if entry.tasks.count > tasksToShow.count {
                Text("+ \(entry.tasks.count - tasksToShow.count) more")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
    }
    
    private func limitTasksForWidgetSize() -> [NactionsKit.TaskItem] {
        switch widgetFamily {
        case .systemSmall:
            return Array(entry.tasks.prefix(3))
        case .systemMedium:
            return Array(entry.tasks.prefix(5))
        case .systemLarge:
            return Array(entry.tasks.prefix(10))
        default:
            return Array(entry.tasks.prefix(3))
        }
    }
    
    private func relativeDateString(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
    
    private func isDueSoon(_ date: Date) -> Bool {
        let now = Date()
        let timeInterval = date.timeIntervalSince(now)
        // Return true if due within 24 hours
        return timeInterval >= 0 && timeInterval <= 86400
    }
}

// MARK: - Progress Widget Views

struct ProgressWidgetEntryView: View {
    var entry: ProgressWidgetProvider.Entry
    @Environment(\.widgetFamily) private var widgetFamily
    
    var body: some View {
        ZStack {
            // Background
            Color("WidgetBackground")
                .edgesIgnoringSafeArea(.all)
            
            if let error = entry.error {
                VStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else {
                VStack {
                    // Header
                    Text(entry.progress.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Progress Visualization
                    progressView()
                    
                    // Progress details
                    progressDetailsView()
                }
                .padding()
            }
        }
    }
    
    @ViewBuilder
    private func progressView() -> some View {
        switch widgetFamily {
        case .systemSmall:
            circularProgressView()
        default:
            linearProgressView()
        }
    }
    
    private func circularProgressView() -> some View {
        ZStack {
            // Background Circle
            Circle()
                .stroke(lineWidth: 10)
                .opacity(0.3)
                .foregroundColor(.gray)
            
            // Progress Circle
            Circle()
                .trim(from: 0.0, to: CGFloat(entry.progress.percentComplete))
                .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                .foregroundColor(progressColor())
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear, value: entry.progress.percentComplete)
            
            // Percentage Text
            Text("\(Int(entry.progress.percentComplete * 100))%")
                .font(.title2)
                .bold()
                .foregroundColor(.primary)
        }
        .padding()
    }
    
    private func linearProgressView() -> some View {
        VStack {
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .frame(width: geometry.size.width, height: 20)
                        .opacity(0.3)
                        .foregroundColor(.gray)
                    
                    // Progress
                    Rectangle()
                        .frame(width: min(CGFloat(entry.progress.percentComplete) * geometry.size.width, geometry.size.width), height: 20)
                        .foregroundColor(progressColor())
                        .animation(.linear, value: entry.progress.percentComplete)
                }
                .cornerRadius(10)
            }
            .frame(height: 20)
            .padding(.vertical)
            
            // Percentage Text
            Text("\(Int(entry.progress.percentComplete * 100))%")
                .font(.headline)
                .foregroundColor(.primary)
        }
    }
    
    @ViewBuilder
    private func progressDetailsView() -> some View {
        if widgetFamily != .systemSmall {
            HStack {
                Text("\(Int(entry.progress.currentValue))")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("of \(Int(entry.progress.targetValue))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
    }
    
    private func progressColor() -> Color {
        let percent = entry.progress.percentComplete
        if percent < 0.3 {
            return .red
        } else if percent < 0.7 {
            return .orange
        } else {
            return .green
        }
    }
}
