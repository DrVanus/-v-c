import Foundation

enum CryptoAPIError: Error {
    case invalidURL
    case requestFailed
    case decodingError
}

class CryptoAPIService {
    static let shared = CryptoAPIService()
    private init() {}

    /// A dedicated URLSession to set timeouts.
    private let session: URLSession = {
        var config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()

    /// A generic fetch helper that validates status codes and decodes JSON.
    private func fetch<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw CryptoAPIError.requestFailed
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Simple Price

    private struct PriceResponse: Codable {
        let usd: Double
    }

    /// Fetches the current USD prices for a list of coin IDs.
    func getCurrentPrices(for coinIDs: [String]) async throws -> [String: Double] {
        let ids = coinIDs.joined(separator: ",")
        guard let url = URL(string:
            "https://api.coingecko.com/api/v3/simple/price?ids=\(ids)&vs_currencies=usd")
        else { throw CryptoAPIError.invalidURL }

        let raw: [String: PriceResponse] = try await fetch(url)
        return raw.mapValues { $0.usd }
    }

    // MARK: - Historical Prices

    private struct HistoricalResponse: Decodable {
        let prices: [[Double]]
    }

    /// Fetches historical price data for a specific coin over the past given number of days.
    func getHistoricalPrices(for coinID: String, days: Int) async throws -> [(Date, Double)] {
        guard let url = URL(string:
            "https://api.coingecko.com/api/v3/coins/\(coinID)/market_chart?vs_currency=usd&days=\(days)")
        else { throw CryptoAPIError.invalidURL }

        let wrapper: HistoricalResponse = try await fetch(url)
        return wrapper.prices.compactMap { entry in
            guard entry.count == 2 else { return nil }
            let timestamp = entry[0] / 1000
            let price = entry[1]
            return (Date(timeIntervalSince1970: timestamp), price)
        }
    }

    // MARK: - Global Market Data

    /// Fetches global market data from CoinGecko.
    func fetchGlobalData() async throws -> GlobalMarketData {
        guard let url = URL(string: "https://api.coingecko.com/api/v3/global")
        else { throw CryptoAPIError.invalidURL }

        struct Wrapper: Decodable { let data: GlobalMarketData }
        let wrapper: Wrapper = try await fetch(url)
        return wrapper.data
    }

    /// Fallback: Fetches global market data from CoinPaprika.
    func fetchGlobalDataFromPaprika() async throws -> GlobalMarketData {
        guard let url = URL(string: "https://api.coinpaprika.com/v1/global")
        else { throw CryptoAPIError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = (response as? HTTPURLResponse), (200...299).contains(http.statusCode) else {
            throw CryptoAPIError.requestFailed
        }
        struct PaprikaGlobal: Decodable {
            let market_cap_usd: Double
            let volume_24h_usd: Double
            let bitcoin_dominance_percentage: Double
        }
        let pg = try JSONDecoder().decode(PaprikaGlobal.self, from: data)
        return GlobalMarketData(
            totalMarketCap: ["usd": pg.market_cap_usd],
            totalVolume: ["usd": pg.volume_24h_usd],
            marketCapPercentage: ["btc": pg.bitcoin_dominance_percentage, "eth": 0],
            marketCapChangePercentage24HUsd: 0
        )
    }

    // MARK: - CoinGecko Market Coins

    enum CoinGeckoOrder: String {
        case marketCapDesc = "market_cap_desc"
    }

    /// Fetches market coin data from CoinGecko with the given parameters.
    func fetchCoinGeckoMarkets(
        vsCurrency: String,
        order: CoinGeckoOrder,
        perPage: Int,
        page: Int,
        sparkline: Bool
    ) async throws -> [MarketCoin] {
        var comps = URLComponents(string: "https://api.coingecko.com/api/v3/coins/markets")!
        comps.queryItems = [
            URLQueryItem(name: "vs_currency", value: vsCurrency),
            URLQueryItem(name: "order", value: order.rawValue),
            URLQueryItem(name: "per_page", value: String(perPage)),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "sparkline", value: sparkline ? "true" : "false"),
            URLQueryItem(name: "price_change_percentage", value: "1h,24h")
        ]
        guard let url = comps.url else {
            throw CryptoAPIError.invalidURL
        }
        return try await fetch(url)
    }

    // MARK: - CoinPaprika Market Coins Fallback

    /// Fetches market coin data from CoinPaprika as a fallback.
    func fetchCoinPaprikaMarkets(limit: Int, offset: Int) async throws -> [MarketCoin] {
        guard let url = URL(string: "https://api.coinpaprika.com/v1/tickers?limit=\(limit)&offset=\(offset)")
        else { throw CryptoAPIError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw CryptoAPIError.requestFailed
        }
        struct PaprikaTicker: Decodable {
            let id: String
            let name: String
            let symbol: String
            let quotes: [String: PaprikaQuote]
        }
        struct PaprikaQuote: Decodable {
            let price: Double
            let volume_24h: Double
            let market_cap: Double
            let percent_change_24h: Double
            let percent_change_1h: Double?
        }
        let tickers = try JSONDecoder().decode([PaprikaTicker].self, from: data)
        return tickers.map { t in
            let q = t.quotes["USD"]!
            return MarketCoin(
                id: t.id,
                symbol: t.symbol,
                name: t.name,
                price: q.price,
                dailyChange: q.percent_change_24h,
                hourlyChange: q.percent_change_1h ?? 0,
                volume: q.volume_24h,
                marketCap: q.market_cap,
                isFavorite: false,
                sparklineData: nil,
                imageUrl: nil,
                finalImageUrl: nil
            )
        }
    }
}
