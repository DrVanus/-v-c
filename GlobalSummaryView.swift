import SwiftUI

struct GlobalSummaryView: View {
    @EnvironmentObject var marketVM: MarketViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Global Market Summary")
                .font(.largeTitle)
                .padding(.bottom, 4)

            if marketVM.isLoadingGlobal {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else if let error = marketVM.globalError {
                DataUnavailableView(message: error) {
                    Task { await marketVM.fetchGlobal() }
                }
                .padding(.vertical, 8)
            } else if let data = marketVM.globalData {
                // Data available – formatted display
                let cap       = data.totalMarketCap["usd"] ?? 0
                let volume    = data.totalVolume["usd"] ?? 0
                let dominance = data.marketCapPercentage["btc"] ?? 0
                let change = data.marketCapChangePercentage24HUsd

                Text("Total Market Cap: \(cap.formatted(.currency(code: "USD")))")
                Text("Total Volume:    \(volume.formatted(.currency(code: "USD")))")
                Text("BTC Dominance:   \(String(format: "%.2f", dominance))%")
                Text("24h Change:      \(String(format: "%.2f", change))%")
            } else {
                Text("Global data unavailable")
                    .foregroundColor(.gray)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .task { await marketVM.fetchGlobal() }
    }
}
