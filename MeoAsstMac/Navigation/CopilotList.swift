//
//  CopilotList.swift
//  MAA
//
//  Created by ninekirin on 2025/5/6.
//

import SwiftUI

struct CopilotList: View {
    @EnvironmentObject private var viewModel: MAAViewModel

    var body: some View {
        List {
            Section("战斗列表（自动模式）") {
                // REMOVEME: \.0 使用枚举的索引（即数组的位置）作为唯一标识
                // REMOVEME: \.1.name 使用每个元素的 item.name 作为唯一标识
                ForEach(Array(viewModel.copilotListConfig.items.enumerated()), id: \.0) { index, item in
                    HStack {
                        Toggle(
                            "",
                            isOn: .init(
                                get: { item.enabled },
                                set: { viewModel.copilotListConfig.items[index].enabled = $0 }
                            )
                        )
                        .labelsHidden()

                        Text(item.name)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if item.is_raid {
                            Text("突袭")
                                .foregroundStyle(.secondary)
                        }

                        Menu {
                            Button(action: {
                                var newItem = item
                                newItem.is_raid.toggle()
                                viewModel.copilotListConfig.items[index] = newItem
                            }) {
                                Label(
                                    item.is_raid ? "普通模式" : "突袭模式",
                                    systemImage: item.is_raid ? "shield.slash" : "shield.fill")
                            }

                            Button(
                                role: .destructive,
                                action: {
                                    viewModel.removeFromCopilotList(at: index)
                                }
                            ) {
                                Label("删除", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .onMove { from, to in
                    viewModel.moveCopilotItem(from: from.first ?? 0, to: to)
                }
            }
        }
        .animation(.default, value: viewModel.copilotListConfig.items.count)
    }

    private struct CopilotListSettings: View {
        @EnvironmentObject private var viewModel: MAAViewModel

        var body: some View {
            Form {
                Section("全局设置") {
                    Toggle("自动编队", isOn: $viewModel.copilotListConfig.formation)
                    Toggle("信赖干员", isOn: $viewModel.copilotListConfig.add_trust)
                    Toggle("允许使用理智药", isOn: $viewModel.copilotListConfig.use_sanity_potion)
                }
            }
        }
    }
}

#Preview {
    CopilotList()
        .environmentObject(MAAViewModel())
}
