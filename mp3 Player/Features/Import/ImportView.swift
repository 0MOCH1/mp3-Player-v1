import GRDB
import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.appDatabase) private var appDatabase
    @EnvironmentObject private var progressCenter: ProgressCenter
    @AppStorage("import_mode") private var importModeRaw = ImportMode.copy.rawValue
    @AppStorage("import_allow_delete_original") private var allowDeleteOriginal = false
    @State private var isImporting = false
    @State private var importStatus: String?
    @State private var activeImporter: ActiveImporter?
    @State private var isImporterPresented = false

    var body: some View {
        NavigationStack {
            List {
                Section("Import Mode") {
                    Picker("Import Mode", selection: $importModeRaw) {
                        ForEach(ImportMode.allCases, id: \.rawValue) { mode in
                            Text(importModeLabel(mode)).tag(mode.rawValue)
                        }
                    }

                    if selectedImportMode == .copyThenDelete {
                        Toggle("Delete original after copy", isOn: $allowDeleteOriginal)
                    }
                }
                
                Section("Actions") {
                    Button {
                        activeImporter = .importFiles
                        isImporterPresented = true
                    } label: {
                        if isImporting {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Importing...")
                            }
                        } else {
                            Label("Import Files", systemImage: "square.and.arrow.down")
                        }
                    }
                    .disabled(isImporting)

                    Button {
                        activeImporter = .importFolder
                        isImporterPresented = true
                    } label: {
                        Label("Import Folder", systemImage: "folder")
                    }
                    .disabled(isImporting)
                }

                if let progress = progressCenter.current {
                    Section("Progress") {
                        VStack(alignment: .leading, spacing: 4) {
                            if let total = progress.total, total > 0 {
                                ProgressView(value: Double(progress.processed), total: Double(total)) {
                                    Text(progress.message)
                                }
                            } else {
                                ProgressView(progress.message)
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }

                if let importStatus {
                    Section("Status") {
                        Text(importStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: importerContentTypes,
                allowsMultipleSelection: activeImporter?.allowsMultipleSelection ?? false
            ) { result in
                guard let importer = activeImporter else { return }
                switch importer {
                case .importFiles:
                    handleFileImport(result)
                case .importFolder:
                    handleFolderImport(result)
                }
                activeImporter = nil
                isImporterPresented = false
            }
        }
    }

    private var selectedImportMode: ImportMode {
        ImportMode(rawValue: importModeRaw) ?? .reference
    }

    private var importerContentTypes: [UTType] {
        activeImporter?.allowedContentTypes ?? [.audio]
    }

    private func importModeLabel(_ mode: ImportMode) -> String {
        switch mode {
        case .reference:
            return "Reference"
        case .copy:
            return "Copy"
        case .copyThenDelete:
            return "Copy then delete"
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard let appDatabase else {
            importStatus = "Database unavailable."
            return
        }

        switch result {
        case .failure(let error):
            importStatus = "Import failed: \(error.localizedDescription)"
        case .success(let urls):
            guard !urls.isEmpty else {
                importStatus = "No files selected."
                return
            }

            isImporting = true
            importStatus = "Importing..."
            let mode = selectedImportMode
            let allowDelete = allowDeleteOriginal && mode == .copyThenDelete
            let importer = LocalImportService(appDatabase: appDatabase)
            let progressHandler: (OperationProgress) -> Void = { progress in
                Task { @MainActor in
                    progressCenter.update(progress)
                }
            }

            Task {
                let result = await importer.importFiles(
                    from: urls,
                    mode: mode,
                    allowDeleteOriginal: allowDelete,
                    progress: progressHandler
                )
                await MainActor.run {
                    isImporting = false
                    let summary = [
                        "Imported \(result.importedCount)",
                        "Relinked \(result.relinkedCount)",
                        "Skipped \(result.skippedCount)",
                        "Failed \(result.failures.count)",
                    ].joined(separator: ", ")
                    if result.failures.isEmpty {
                        importStatus = summary
                    } else {
                        let detail = result.failures.first ?? "Unknown error."
                        importStatus = "\(summary). \(detail)"
                    }
                    progressCenter.clear()
                }
            }
        }
    }

    private func handleFolderImport(_ result: Result<[URL], Error>) {
        guard let appDatabase else {
            importStatus = "Database unavailable."
            return
        }

        switch result {
        case .failure(let error):
            importStatus = "Import failed: \(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else {
                importStatus = "No folder selected."
                return
            }

            isImporting = true
            importStatus = "Importing..."
            let mode = selectedImportMode
            let allowDelete = allowDeleteOriginal && mode == .copyThenDelete
            let importer = LocalImportService(appDatabase: appDatabase)
            let progressHandler: (OperationProgress) -> Void = { progress in
                Task { @MainActor in
                    progressCenter.update(progress)
                }
            }

            Task {
                let result = await importer.importFolder(
                    from: url,
                    mode: mode,
                    allowDeleteOriginal: allowDelete,
                    progress: progressHandler
                )
                await MainActor.run {
                    isImporting = false
                    let summary = [
                        "Imported \(result.importedCount)",
                        "Relinked \(result.relinkedCount)",
                        "Skipped \(result.skippedCount)",
                        "Failed \(result.failures.count)",
                    ].joined(separator: ", ")
                    if result.failures.isEmpty {
                        importStatus = summary
                    } else {
                        let detail = result.failures.first ?? "Unknown error."
                        importStatus = "\(summary). \(detail)"
                    }
                    progressCenter.clear()
                }
            }
        }
    }
}

private enum ActiveImporter {
    case importFiles
    case importFolder

    var allowsMultipleSelection: Bool {
        switch self {
        case .importFiles:
            return true
        case .importFolder:
            return false
        }
    }

    var allowedContentTypes: [UTType] {
        switch self {
        case .importFiles:
            return [.audio]
        case .importFolder:
            return [.folder]
        }
    }
}

#Preview {
    ImportView()
}
