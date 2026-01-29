import SwiftUI

struct HomeView: View {
    @Binding var showsSettings: Bool
    @Environment(\.appDatabase) private var appDatabase
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if viewModel.recentTracks.isEmpty {
                        Text("最近の曲がありません")
                            .foregroundStyle(.secondary)
                    } else {
                        RecentTracksColumnGridView(tracks: viewModel.recentTracks)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                    }
                } header: {
                    SectionHeaderLink(
                        title: "最近の曲",
                        destination: RecentTracksListView(viewModel: viewModel)
                    )
                }

                Section {
                    if viewModel.recentPlayedItems.isEmpty {
                        Text("最近の再生がありません")
                            .foregroundStyle(.secondary)
                    } else {
                        RecentPlaysRowView(items: viewModel.recentPlayedItems)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                    }
                } header: {
                    SectionHeaderLink(
                        title: "最近の再生",
                        destination: RecentTracksGridView(viewModel: viewModel)
                    )
                }

                Section("Top Artists (30d)") {
                    if viewModel.topArtists.isEmpty {
                        Text("No top artists yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.topArtists) { artist in
                            Text(artist.name)
                        }
                    }
                }
            }
            .appList()
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
        .appScreen()
        .onAppear {
            viewModel.loadIfNeeded(appDatabase: appDatabase)
        }
    }
}

#Preview {
    HomeView(showsSettings: .constant(false))
}
