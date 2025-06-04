import Foundation

struct Announcement: Identifiable, Codable {
    let id: Int
    let title: String
    let body: String
}

class AnnouncementManager {
    private static let announcementsURL = "https://raw.githubusercontent.com/0-Blu/StikJIT/main/StikJIT/Resources/announcements.json"

    static func fetchAnnouncements(completion: @escaping ([Announcement]) -> Void) {
        guard let url = URL(string: announcementsURL) else {
            completion([])
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, _ in
            guard let data = data,
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let announcements = try? JSONDecoder().decode([Announcement].self, from: data) else {
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }

            DispatchQueue.main.async {
                completion(announcements)
            }
        }.resume()
    }
}
