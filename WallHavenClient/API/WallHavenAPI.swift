//
//  WallHavenAPI.swift
//  WallHavenClient
//
//  Created by Venti on 15/04/2023.
//

import Foundation

struct WallHavenAPISearchParameters {
    var query: String
    var categoryGeneral: Bool
    var categoryAnime: Bool
    var categoryPeople: Bool
    var puritySFW: Bool
    var puritySketchy: Bool
    var purityWhy: Bool
    var sorting: WallHavenSorting
    var order: WallHavenOrder
    var page: Int

    init(query: String,
         categoryGeneral: Bool,
         categoryAnime: Bool,
         categoryPeople: Bool,
         puritySFW: Bool,
         puritySketchy: Bool,
         purityWhy: Bool,
         sorting: WallHavenSorting,
         order: WallHavenOrder,
         page: Int) {
        self.query = query
        self.categoryGeneral = categoryGeneral
        self.categoryAnime = categoryAnime
        self.categoryPeople = categoryPeople
        self.puritySFW = puritySFW
        self.puritySketchy = puritySketchy
        self.purityWhy = purityWhy
        self.sorting = sorting
        self.order = order
        self.page = page
    }

    init() {
        self.init(query: "Venti",
                  categoryGeneral: true,
                  categoryAnime: true,
                  categoryPeople: true,
                  puritySFW: true,
                  puritySketchy: false,
                  purityWhy: false,
                  sorting: .relevance,
                  order: .desc,
                  page: 1)
    }
}

enum WallHavenCategory: Int {
    case general
    case anime
    case people
}

enum WallHavenPurity: Int {
    case sfw
    case sketchy
    case nsfw
}

enum WallHavenSorting: String {
    case relevance = "relevance"
    case random = "random"
    case dateAdded = "date_added"
    case views = "views"
    case favorites = "favorites"
}

enum WallHavenOrder: String {
    case desc
    case asc
}

struct WallHavenImage: Codable {
    let id: String
    let url: String
    let shortURL: String
    let views: Int
    let favorites: Int
    let source: String
    let purity: String
    let category: String
    let dimensionX: Int
    let dimensionY: Int
    let resolution: String
    let ratio: String
    let fileSize: Int
    let fileType: String
    let createdAt: String
    let colors: [String]
    let path: String
    let thumbs: WallHavenThumbs

    enum CodingKeys: String, CodingKey {
        case id, url
        case shortURL = "short_url"
        case views, favorites, source, purity, category
        case dimensionX = "dimension_x"
        case dimensionY = "dimension_y"
        case resolution, ratio
        case fileSize = "file_size"
        case fileType = "file_type"
        case createdAt = "created_at"
        case colors, path, thumbs
    }
}

struct WallHavenThumbs: Codable {
    let large: String
    let original: String
    let small: String
}

struct WallHavenAPIMeta: Codable {
    let currentPage: Int
    let lastPage: Int
    let perPage: Int
    let total: Int
    let query: String?
    let seed: String?

    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case lastPage = "last_page"
        case perPage = "per_page"
        case total, query, seed
    }
}

struct WallHavenAPIResponse: Codable {
    let data: [WallHavenImage]
    let meta: WallHavenAPIMeta
}

struct WallHavenAPIError: Error {
    static let noData = WallHavenAPIError()
}

struct WallHavenAPIClient {
    static var shared = WallHavenAPIClient(apiKey: nil)

    let base = "https://wallhaven.cc/api/v1"
    let apiKey: String?

    func search(parameters: WallHavenAPISearchParameters,
                completion: @escaping (Result<WallHavenAPIResponse, Error>) -> Void) {
        let url = URL(string: "\(base)/search")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!

        // Calculate the bitmask for the categories and purity 
        let categoryOpt = [parameters.categoryGeneral ? 1 : 0,
                           parameters.categoryAnime ? 1 : 0,
                           parameters.categoryPeople ? 1 : 0]

        let purityOpt = [parameters.puritySFW ? 1 : 0,
                         parameters.puritySketchy ? 1 : 0,
                         parameters.purityWhy ? 1 : 0]

        components.queryItems = [
            URLQueryItem(name: "q", value: parameters.query),
            URLQueryItem(name: "categories", value: categoryOpt.map(String.init).joined()),
            URLQueryItem(name: "purity", value: purityOpt.map(String.init).joined()),
            URLQueryItem(name: "sorting", value: parameters.sorting.rawValue),
            URLQueryItem(name: "order", value: parameters.order.rawValue),
            URLQueryItem(name: "page", value: String(parameters.page))
        ]

        debugPrint(components.url!)

        if apiKey != nil {
            components.queryItems?.append(URLQueryItem(name: "apikey", value: apiKey))
        }

        let request = URLRequest(url: components.url!)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(WallHavenAPIError.noData))
                return
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(WallHavenAPIResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }

        task.resume()
    }
}
