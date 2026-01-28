import SwiftUI
import UniformTypeIdentifiers

// ActiveImporter moved here so the import section can be extracted into its own file.
enum ActiveImporter {
    case importFiles
    case importFolder
    case relink(MissingTrackSummary)

    var allowsMultipleSelection: Bool {
        switch self {
        case .importFiles:
            return true
        case .importFolder:
            return false
        case .relink:
            return false
        }
    }

    var allowedContentTypes: [UTType] {
        switch self {
        case .importFiles, .relink:
            return [.audio]
        case .importFolder:
            return [.folder]
        }
    }
}

struct LibraryImportSection: View {
    @Binding var importModeRaw: String
    @Binding var allowDeleteOriginal: Bool
    @Binding var isImporting: Bool
    @Binding var importStatus: String?
    @Binding var activeImporter: ActiveImporter?
    @Binding var isImporterPresented: Bool
    @EnvironmentObject private var progressCenter: ProgressCenter

    var body: some View {
        Section {
            Picker("Import Mode", selection: $importModeRaw) {
                ForEach(ImportMode.allCases, id: \.rawValue) { mode in
                    Text(importModeLabel(mode)).tag(mode.rawValue)
                }
            }

            if selectedImportMode == .copyThenDelete {
                Toggle("Delete original after copy", isOn: $allowDeleteOriginal)
            }

            Button {
                activeImporter = .importFiles
                isImporterPresented = true
            } label: {
                if isImporting {
                    ProgressView()
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

            if let progress = progressCenter.current {
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

            if let importStatus {
                Text(importStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var selectedImportMode: ImportMode {
        ImportMode(rawValue: importModeRaw) ?? .reference
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
}
