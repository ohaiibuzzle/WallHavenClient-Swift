//
//  ContentView.swift
//  WallHavenClient
//
//  Created by Venti on 15/04/2023.
//

import SwiftUI

struct ContentView: View {
    @State var queryString = ""
    @State var wallHavenAPISearchParameters = WallHavenAPISearchParameters()
    @State var wallHavenAPIMeta: WallHavenAPIMeta?
    @State var wallpaperObservable = WallpaperObservable()
    @State var maxWidth: CGFloat = 250
    @State var searchOptionsShown = false

    var body: some View {
        VStack {
            HStack {
                TextField("Type something to search", text: $wallHavenAPISearchParameters.query)
                    .onSubmit {
                        Task {
                            wallHavenAPISearchParameters.page = 1
                            search()
                        }
                    }
                Button("Search") {
                    Task {
                        wallHavenAPISearchParameters.page = 1
                        search()
                    }
                }
            }
            .padding()
            Button("Search Options") {
                searchOptionsShown.toggle()
            }
            WallpaperView(maxWidth: $maxWidth, wallpaperObservable: wallpaperObservable)
                .padding()
            // Paging controls
            HStack {
                if wallHavenAPIMeta != nil {
                    Button("<") {
                        previousPage()
                    }
                    Text("Page \(wallHavenAPISearchParameters.page) of \(wallHavenAPIMeta?.lastPage ?? 10)")
                    Button(">") {
                        nextPage()
                    }
                }
                Spacer()
                // Slider to adjust max width of images
                Slider(value: $maxWidth, in: 100...500)
                    .frame(width: 200)
            }
        }
        .onAppear {
            search()
        }
        .padding()
        .sheet(isPresented: $searchOptionsShown) {
            SearchOptionsView(wallHavenAPISearchParameters: $wallHavenAPISearchParameters,
                              searchOptionsShown: $searchOptionsShown)
            .onDisappear {
                search()
            }
        }
    }

    func search() {
        wallpaperObservable.wallhavenImages = []
        wallpaperObservable.imagesToDisplay = []
        let wallHavenAPI = WallHavenAPIClient.shared
        wallHavenAPI.search(parameters: wallHavenAPISearchParameters) { result in
            switch result {
            case .success(let wallHavenAPIResponse):
                print("Search successful")
                // print(wallHavenImages)
                Task { @MainActor in
                    wallHavenAPIMeta = wallHavenAPIResponse.meta
                    wallpaperObservable.wallhavenImages = wallHavenAPIResponse.data
                }
                for image in wallHavenAPIResponse.data {
                    wallpaperObservable.downloadImage(from: image)
                }
            case .failure(let error):
                print("Search failed")
                print(error)
            }
        }
    }

    func nextPage() {
        if wallHavenAPIMeta?.lastPage == wallHavenAPISearchParameters.page {
            return
        }
        wallHavenAPISearchParameters.page += 1
        search()
    }

    func previousPage() {
        if wallHavenAPISearchParameters.page > 1 {
            wallHavenAPISearchParameters.page -= 1
            search()
        }
    }
}

struct SearchOptionsView: View {
    @Binding var wallHavenAPISearchParameters: WallHavenAPISearchParameters
    @Binding var searchOptionsShown: Bool
    @State var apiKey = ""
    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading) {
                    VStack(alignment: .leading) {
                        Text("Categories:")
                            .font(.title3)
                            .bold()
                        Spacer()
                        HStack {
                            Toggle("General", isOn: $wallHavenAPISearchParameters.categoryGeneral)
                                .padding()
                            Spacer()
                            Toggle("Anime", isOn: $wallHavenAPISearchParameters.categoryAnime)
                                .padding()
                            Spacer()
                            Toggle("People", isOn: $wallHavenAPISearchParameters.categoryPeople)
                        }
                        .padding()
                    }
                    VStack(alignment: .leading) {
                        Text("Purity:")
                            .font(.title3)
                            .bold()
                        Spacer()
                        HStack {
                            Toggle("SFW", isOn: $wallHavenAPISearchParameters.puritySFW)
                                .padding()
                            Spacer()
                            Toggle("Sketchy", isOn: $wallHavenAPISearchParameters.puritySketchy)
                                .padding()
                            Spacer()
                            Toggle("NSFW", isOn: $wallHavenAPISearchParameters.purityWhy)
                                .disabled(apiKey.isEmpty)
                        }
                        .padding()
                    }
                    VStack {
                        HStack {
                            Text("Sorting:")
                            Spacer()
                            Picker("", selection: $wallHavenAPISearchParameters.sorting) {
                                Text("Relevance").tag(WallHavenSorting.relevance)
                                Text("Random").tag(WallHavenSorting.random)
                                Text("Date Added").tag(WallHavenSorting.dateAdded)
                                Text("Views").tag(WallHavenSorting.views)
                                Text("Favorites").tag(WallHavenSorting.favorites)
                            }
                            .pickerStyle(DefaultPickerStyle())
                        }
                        .padding()
                    }
                    TextField("API Key", text: $apiKey)
                        .padding()
                }
            }
            Button("Done") {
                WallHavenAPIClient.shared = WallHavenAPIClient(apiKey: apiKey)
                searchOptionsShown.toggle()
            }
        }
        .padding()
        .frame(width: 600, height: 600)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
