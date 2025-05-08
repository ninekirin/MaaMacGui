//
//  CopilotsView.swift
//  MAA
//
//  Created by hguandl on 17/4/2023.
//

import SwiftUI

struct CopilotContent: View {
    @EnvironmentObject private var viewModel: MAAViewModel
    @Binding var selection: URL?
    
    private func toggleCopilotList() {
        viewModel.useCopilotList.toggle()
    }
    
    var body: some View {
        Group {
            if viewModel.useCopilotList {
                CopilotList()
            } else {
                RegularCopilotList(
                    selection: $selection,
                    onDeleteCopilot: deleteCopilot
                )
            }
        }
        .toolbar(content: listToolbar)
    }

    @ToolbarContentBuilder private func listToolbar() -> some ToolbarContent {
        ToolbarItemGroup {
            if !viewModel.useCopilotList {  // 只在非战斗列表模式显示移除按钮
                Button(action: {
                    if let selection {
                        deleteCopilot(url: selection)
                    }
                }) {
                    Label("移除", systemImage: "trash")
                }
                .help("移除作业")
                .disabled(!canDelete(selection))
                .keyboardShortcut(.delete, modifiers: [.command])
            }

            Button(action: toggleCopilotList) {
                Label(
                    "战斗列表",
                    systemImage: viewModel.useCopilotList ? "list.bullet.rectangle.fill" : "list.bullet.rectangle"
                )
            }
            .help(viewModel.useCopilotList ? "切换回单个作业模式" : "切换到战斗列表模式")
        }

        ToolbarItemGroup {
            switch viewModel.status {
            case .pending:
                Button(action: {}) {
                    ProgressView().controlSize(.small)
                }
                .disabled(true)
            case .busy:
                Button(action: stop) {
                    Label("停止", systemImage: "stop.fill")
                }
                .help("停止")
            case .idle:
                Button(action: start) {
                    Label("开始", systemImage: "play.fill")
                }
                .help("开始")
            }
        }
    }
    
    // MARK: - Actions
    
    private func stop() {
        Task {
            try await viewModel.stop()
        }
    }
    
    private func start() {
        Task {
            viewModel.copilotDetailMode = .log
            try await viewModel.startCopilot()
        }
    }
    
    private func deleteCopilot(url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    // MARK: - Helpers
    
    private func canDelete(_ url: URL?) -> Bool {
        guard let url else { return false }
        
        let bundledPath = Bundle.main.resourceURL!
            .appendingPathComponent("resource")
            .appendingPathComponent("copilot")
            .path
            
        return !url.path.starts(with: bundledPath)
    }
}

#Preview {
    CopilotContent(selection: .constant(nil))
        .environmentObject(MAAViewModel())
}
