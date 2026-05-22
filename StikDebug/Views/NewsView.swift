//
//  NewsView.swift
//  StikDebug
//

import Foundation
import SwiftUI
import UIKit

struct NewsView: View {
    @State private var items: [NewsItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let feedURL = NewsFeedEndpoint.url

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if items.isEmpty {
                        statusContent
                    } else {
                        if let errorMessage {
                            NewsBanner(message: errorMessage)
                        }

                        ForEach(items) { item in
                            NewsCard(item: item)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("News")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await loadNews() }
                    } label: {
                        Label(String(format: "Refresh".localized), systemImage: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .refreshable {
                await loadNews()
            }
        }
        .task {
            guard items.isEmpty, errorMessage == nil else { return }
            await loadNews()
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading News")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 220)
        } else if let errorMessage {
            ContentUnavailableView {
                Label(String(format: "Could Not Load News".localized), systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") {
                    Task { await loadNews() }
                }
            }
            .frame(minHeight: 280)
        } else {
            ContentUnavailableView(String(format: "No News".localized), systemImage: "newspaper")
                .frame(minHeight: 280)
        }
    }

    @MainActor
    private func loadNews() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            let feed = try await NewsFeedClient.fetch(from: feedURL)
            items = feed.items
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private enum NewsFeedEndpoint {
    static let url = URL(string: "https://raw.githubusercontent.com/StephenDev0/StikDebug/main/news.json")!
}

private enum NewsFeedClient {
    static func fetch(from url: URL) async throws -> NewsFeed {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadRevalidatingCacheData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NewsFeedError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NewsFeedError.badStatus(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(NewsFeed.self, from: data)
    }
}

private enum NewsFeedError: LocalizedError {
    case invalidResponse
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "GitHub returned an invalid news response."
        case .badStatus(let statusCode):
            return "GitHub returned status \(statusCode)."
        }
    }
}

private struct NewsFeed: Decodable {
    let items: [NewsItem]

    enum CodingKeys: String, CodingKey {
        case items
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let items = try? container.decode([NewsItem].self) {
            self.items = items
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decode([NewsItem].self, forKey: .items)
    }
}

private struct NewsItem: Decodable, Identifiable {
    let id: String
    let title: String
    let body: String
    let date: String
    let category: String
    let tint: String
    let symbol: String
    let imageURL: URL?
    let url: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case summary
        case description
        case date
        case publishedAt
        case category
        case tint
        case color
        case symbol
        case image
        case imageURL
        case imageUrl
        case image_url
        case link
        case url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decodeFirstString(for: [.body, .summary, .description])
        date = (try? container.decodeFirstString(for: [.date, .publishedAt])) ?? ""
        category = (try? container.decode(String.self, forKey: .category)) ?? "Update"
        tint = (try? container.decodeFirstString(for: [.tint, .color])) ?? "blue"
        symbol = (try? container.decode(String.self, forKey: .symbol)) ?? "sparkles"
        imageURL = container.decodeFirstURL(for: [.imageURL, .imageUrl, .image_url, .image])
        url = container.decodeFirstURL(for: [.url, .link])
        id = (try? container.decode(String.self, forKey: .id)) ?? Self.generatedID(title: title, date: date)
    }

    private static func generatedID(title: String, date: String) -> String {
        "\(date)-\(title)"
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

private extension KeyedDecodingContainer where Key == NewsItem.CodingKeys {
    func decodeFirstString(for keys: [Key]) throws -> String {
        for key in keys {
            if let value = try decodeIfPresent(String.self, forKey: key), !value.isEmpty {
                return value
            }
        }

        throw DecodingError.keyNotFound(
            keys.first ?? NewsItem.CodingKeys.body,
            DecodingError.Context(codingPath: codingPath, debugDescription: "Expected one of \(keys.map { $0.stringValue }.joined(separator: ", ")).")
        )
    }

    func decodeFirstURL(for keys: [Key]) -> URL? {
        for key in keys {
            if let value = try? decodeIfPresent(String.self, forKey: key),
               !value.isEmpty,
               let url = URL(string: value) {
                return url
            }
        }

        return nil
    }
}

private struct NewsCard: View {
    let item: NewsItem

    private var accentColor: Color {
        NewsTint.color(for: item.tint)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NewsMedia(item: item, accentColor: accentColor)

            HStack(alignment: .firstTextBaseline) {
                Text(item.category.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accentColor)
                Spacer(minLength: 12)
                if !item.date.isEmpty {
                    Text(item.date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(item.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.body)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let url = item.url {
                Link(destination: url) {
                    Label(String(format: "Read More".localized), systemImage: "arrow.up.right")
                        .font(.callout.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.18), lineWidth: 1)
        }
    }
}

private struct NewsMedia: View {
    let item: NewsItem
    let accentColor: Color

    var body: some View {
        Group {
            if let imageURL = item.imageURL {
                AsyncImage(url: imageURL, transaction: Transaction(animation: .easeInOut)) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            mediaBackground
                            ProgressView()
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        symbolHeader
                    @unknown default:
                        symbolHeader
                    }
                }
            } else {
                symbolHeader
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var symbolHeader: some View {
        ZStack {
            mediaBackground
            Image(systemName: item.symbol)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(accentColor)
        }
    }

    private var mediaBackground: some View {
        Rectangle()
            .fill(accentColor.opacity(0.14))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(accentColor)
                    .frame(height: 4)
            }
    }
}

private struct NewsBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private enum NewsTint {
    static func color(for value: String) -> Color {
        switch value.lowercased() {
        case "green":
            return .green
        case "mint":
            return .mint
        case "orange":
            return .orange
        case "pink":
            return .pink
        case "purple":
            return .purple
        case "red":
            return .red
        case "teal":
            return .teal
        case "yellow":
            return .yellow
        default:
            return .blue
        }
    }
}
