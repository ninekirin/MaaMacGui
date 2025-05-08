//
//  RegularCopilotList.swift
//  MAA
//
//  Created by ninekirin on 2025/5/6.
//

import SwiftUI

struct RegularCopilotList: View {
    @EnvironmentObject private var viewModel: MAAViewModel
    @Binding var selection: URL?

    @State private var copilots = Set<URL>()
    @State private var downloading = false
    @State private var expanded = false

    var onDeleteCopilot: (URL) -> Void

    private var bundledCopilots: [URL] { bundledDirectory.copilots }

    var body: some View {
        List(selection: $selection) {
            DisclosureGroup(isExpanded: $expanded) {
                ForEach(bundledCopilots, id: \.self) { url in
                    Text(url.lastPathComponent)
                }
            } label: {
                Text("内置作业")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            expanded.toggle()
                        }
                    }
            }

            Section {
                ForEach(copilots.urls, id: \.self) { url in
                    Text(url.lastPathComponent)
                }
            } header: {
                HStack {
                    Text("外部作业（可拖入文件）")
                    if downloading {
                        Spacer()
                        ProgressView().controlSize(.small)
                    }
                }
            }
        }
        .animation(.default, value: copilots)
        .animation(.default, value: downloading)
        .onAppear(perform: loadUserCopilots)
        .onDrop(of: [.fileURL], isTargeted: .none, perform: addCopilots)
        .onReceive(viewModel.$copilotDetailMode, perform: deselectCopilot)
        .onReceive(viewModel.$downloadCopilot, perform: downloadCopilot)
        .onReceive(viewModel.$videoRecoginition, perform: selectNewCopilot)
        .fileImporter(
            isPresented: $viewModel.showImportCopilot,
            allowedContentTypes: [.json],
            allowsMultipleSelection: true,
            onCompletion: addCopilots)
    }

    // MARK: - Actions

    private func loadUserCopilots() {
        copilots.formUnion(externalDirectory.copilots)
        copilots.formUnion(recordingDirectory.copilots)
    }

    private func addCopilots(_ providers: [NSItemProvider]) -> Bool {
        Task {
            for provider in providers {
                if let url = try? await provider.loadURL() {
                    let value = try? url.resourceValues(forKeys: [.contentTypeKey])
                    if value?.contentType == .json {
                        copilots.insert(url)
                    } else if value?.contentType?.conforms(to: .movie) == true {
                        try? await viewModel.recognizeVideo(video: url)
                    }
                }
            }
            self.selection = self.copilots.urls.last
        }

        return true
    }

    private func addCopilots(_ results: Result<[URL], Error>) {
        if case let .success(urls) = results {
            copilots.formUnion(urls)
            selection = copilots.urls.last
        }
    }

    private func downloadCopilot(id: String?) {
        guard let id else { return }

        let file =
            externalDirectory
            .appendingPathComponent(id)
            .appendingPathExtension("json")

        let url = URL(string: "https://prts.maa.plus/copilot/get/\(id)")!
        Task {
            self.downloading = true
            do {
                let data = try await URLSession.shared.data(from: url).0
                let response = try JSONDecoder().decode(CopilotResponse.self, from: data)
                try response.data.content.write(toFile: file.path, atomically: true, encoding: .utf8)
                copilots.insert(file)
                self.selection = file
            } catch {
                print(error)
            }
            self.downloading = false
        }
    }

    private func deselectCopilot(_ viewMode: MAAViewModel.CopilotDetailMode) {
        if viewMode != .copilotConfig {
            selection = nil
        }
    }

    private func selectNewCopilot(url: URL?) {
        if let url {
            copilots.insert(url)
            selection = copilots.urls.last
        }
    }

    // MARK: - File Paths

    private var bundledDirectory: URL {
        Bundle.main.resourceURL!
            .appendingPathComponent("resource")
            .appendingPathComponent("copilot")
    }

    private var externalDirectory: URL {
        let directory = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("copilot")

        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
        }

        return directory
    }

    private var recordingDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("cache")
            .appendingPathComponent("CombatRecord")
    }
}

// MARK: - Value Extensions

extension URL {
    fileprivate var copilots: [URL] {
        guard
            let urls = try? FileManager.default.contentsOfDirectory(
                at: self,
                includingPropertiesForKeys: [.contentTypeKey],
                options: .skipsHiddenFiles)
        else { return [] }

        return urls.filter { url in
            let value = try? url.resourceValues(forKeys: [.contentTypeKey])
            return value?.contentType == .json
        }
        .sorted { lhs, rhs in
            lhs.lastPathComponent < rhs.lastPathComponent
        }
    }
}

extension Set where Element == URL {
    fileprivate var urls: [URL] { sorted { $0.lastPathComponent < $1.lastPathComponent } }
}

private struct CopilotResponse: Codable {
    let data: CopilotData

    struct CopilotData: Codable {
        let content: String
    }
}

extension NSItemProvider {
    @MainActor fileprivate func loadURL() async throws -> URL {
        let handle = ProgressActor()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let progress = loadObject(ofClass: URL.self) { object, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let object else {
                        continuation.resume(throwing: MAAError.emptyItemObject)
                        return
                    }

                    continuation.resume(returning: object)
                }

                Task {
                    await handle.bind(progress: progress)
                }
            }
        } onCancel: {
            Task {
                await handle.cancel()
            }
        }
    }
}

private actor ProgressActor {
    private var progress: Progress?
    private var cancelled = false

    func bind(progress: Progress) {
        guard !cancelled else { return }
        self.progress = progress
        progress.resume()
    }

    func cancel() {
        cancelled = true
        progress?.cancel()
    }
}

#Preview {
    RegularCopilotList(selection: .constant(nil), onDeleteCopilot: { _ in })
        .environmentObject(MAAViewModel())
}
