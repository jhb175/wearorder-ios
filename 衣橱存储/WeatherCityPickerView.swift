import SwiftUI

struct WeatherCityPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let savedCity: String
    let onSave: (String) -> Void
    let onUseCurrentLocation: () -> Void
    @State private var cityName: String

    init(
        savedCity: String,
        onSave: @escaping (String) -> Void,
        onUseCurrentLocation: @escaping () -> Void
    ) {
        self.savedCity = savedCity
        self.onSave = onSave
        self.onUseCurrentLocation = onUseCurrentLocation
        let initialCity = savedCity.trimmingCharacters(in: .whitespacesAndNewlines)
        _cityName = State(initialValue: initialCity)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("城市天气") {
                    TextField("城市名称", text: $cityName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text("可输入上海、Tokyo、New York、Paris 等全球城市。选择城市只是选择天气预报地点，不会让你手动改天气或温度。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        onUseCurrentLocation()
                        dismiss()
                    } label: {
                        Label("使用当前位置天气", systemImage: "location.fill")
                    }
                } footer: {
                    Text("如果定位权限已开启，会优先读取当前位置的真实天气。")
                }
            }
            .navigationTitle("选择天气城市")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("获取天气") {
                        onSave(trimmedCityName)
                        dismiss()
                    }
                    .disabled(trimmedCityName.isEmpty)
                }
            }
        }
    }

    private var trimmedCityName: String {
        cityName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
