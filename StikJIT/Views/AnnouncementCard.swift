import SwiftUI

struct AnnouncementCard: View {
    var announcement: Announcement
    var onDismiss: (() -> Void)? = nil
    @AppStorage("customAccentColor") private var customAccentColorHex: String = ""

    private var accentColor: Color {
        if customAccentColorHex.isEmpty {
            return .blue
        } else {
            return Color(hex: customAccentColorHex) ?? .blue
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        if let date = formatter.date(from: "\(announcement.date) \(announcement.time)") {
            return formatter.string(from: date)
        } else {
            return "\(announcement.date) \(announcement.time)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(announcement.title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(announcement.body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(formattedDate)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accentColor, lineWidth: 2)
        )
        .overlay(
            HStack {
                Spacer()
                Button(action: {
                    onDismiss?()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 2)
    }
}

#Preview {
    AnnouncementCard(
        announcement: Announcement(
            id: 0,
            title: "Title",
            body: "Body",
            date: "2025-01-01",
            time: "00:00",
            visible: true
        )
    )
}
