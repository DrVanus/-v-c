//
//  MarketCacheManager.swift
//  CSAI1
//
//  Created by DM on 4/29/25.
//

import Foundation

/// Manages caching of market coin data to disk
final class MarketCacheManager {
    static let shared = MarketCacheManager()
    private init() {}

    private let fileName = "cached_coins.json"

    private var fileURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent(fileName)
    }

    /// Save an array of MarketCoin to disk
    func saveCoinsToDisk(_ coins: [MarketCoin]) {
        guard let url = fileURL else { return }
        do {
            let data = try JSONEncoder().encode(coins)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save coins to disk: \(error)")
        }
    }

    /// Load cached coins from disk
    func loadCoinsFromDisk() -> [MarketCoin]? {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        do {
            return try JSONDecoder().decode([MarketCoin].self, from: data)
        } catch {
            print("Failed to load coins from disk: \(error)")
            return nil
        }
    }
}

/// Manages caching of global market summary to disk
final class GlobalCacheManager {
    static let shared = GlobalCacheManager()
    private init() {}

    private let fileName = "cached_global.json"

    private var fileURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent(fileName)
    }

    /// Save GlobalMarketData to disk
    func saveGlobalDataToDisk(_ data: GlobalMarketData) {
        guard let url = fileURL else { return }
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: url, options: .atomic)
        } catch {
            print("Failed to save global data to disk: \(error)")
        }
    }

    /// Load cached GlobalMarketData from disk
    func loadGlobalDataFromDisk() -> GlobalMarketData? {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(GlobalMarketData.self, from: data)
        } catch {
            print("Failed to load global data from disk: \(error)")
            return nil
        }
    }
}
