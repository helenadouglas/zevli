//
//  ContentView.swift
//  VitalsTrack Watch Watch App
//
//  Created by Helena Douglas on 15/08/2026.
//

import SwiftUI

struct ContentView: View {

    @State private var isRefreshing = false
    @State private var message = "Open Zevli to update your complications."

    private let health = WatchHealthDataProvider()

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {

                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 32))

                Text("Zevli")
                    .font(.headline)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    Task {
                        await refresh()
                    }
                } label: {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Label(
                            "Refresh",
                            systemImage: "arrow.clockwise"
                        )
                    }
                }
                .disabled(isRefreshing)
            }
            .padding()
        }
        .task {
            await refresh()
        }
    }

    @MainActor
    private func refresh() async {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        message = "Updating Health data…"

        await health.refreshSharedSnapshot()

        let snapshot = SharedHealthStore.load()

        if snapshot.updatedAt == .distantPast {
            message = "No health data has been saved yet."
        } else {
            message = "Updated just now"
        }

        isRefreshing = false
    }
}

#Preview {
    ContentView()
}
