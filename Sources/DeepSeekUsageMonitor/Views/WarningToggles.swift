import SwiftUI
import DeepSeekUsageMonitorCore

/// 通用预警开关列表：基于 CaseIterable 枚举动态渲染各计费模式的独立开关
struct WarningToggles<T: WarningLabelProvider>: View {
    @Binding var selectedModes: Set<T>

    var body: some View {
        ForEach(Array(T.allCases), id: \.self) { mode in
            Toggle(isOn: Binding(
                get: { selectedModes.contains(mode) },
                set: {
                    if $0 {
                        selectedModes.insert(mode)
                    } else {
                        selectedModes.remove(mode)
                    }
                }
            )) {
                Text(mode.warningLabel)
                    .foregroundStyle(.primary)
            }
            .toggleStyle(.checkbox)
        }
    }
}
