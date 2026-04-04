//
//  TimerPickerView.swift
//  FocusMode
//

import SwiftUI

struct TimerPickerView: View {

    @Binding var timerInputMode: HomeViewModel.TimerInputMode
    @Binding var selectedHours: Int
    @Binding var selectedMinutes: Int
    @Binding var selectedEndDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Segmented control
            Picker("", selection: $timerInputMode) {
                Text("Por duración").tag(HomeViewModel.TimerInputMode.byDuration)
                Text("Hora exacta").tag(HomeViewModel.TimerInputMode.byTime)
            }
            .pickerStyle(.segmented)

            Divider()

            // Contenido según el modo activo
            switch timerInputMode {
            case .byDuration:
                durationPicker
            case .byTime:
                exactTimePicker
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }

    // Steppers de horas y minutos con etiquetas claras
    private var durationPicker: some View {
        HStack(spacing: 0) {

            // Horas
            VStack(spacing: 6) {
                Text("Horas")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Stepper(value: $selectedHours, in: 0...23) {
                    Text("\(selectedHours)")
                        .font(.system(size: 22, weight: .semibold).monospacedDigit())
                        .frame(width: 40, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity)

            // Separador visual
            Text(":")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.secondary)
                .padding(.top, 18)

            // Minutos
            VStack(spacing: 6) {
                Text("Minutos")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Stepper(value: $selectedMinutes, in: 0...59) {
                    // Siempre dos dígitos: "05" en vez de "5"
                    Text(String(format: "%02d", selectedMinutes))
                        .font(.system(size: 22, weight: .semibold).monospacedDigit())
                        .frame(width: 40, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // Fecha en formato ISO (año-mes-día) + hora con stepper
    private var exactTimePicker: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Fecha: locale sv_SE da formato YYYY-MM-DD
            VStack(alignment: .leading, spacing: 4) {
                Text("Fecha")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                DatePicker("", selection: $selectedEndDate, in: Date.now..., displayedComponents: .date)
                    .datePickerStyle(.stepperField)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "sv_SE"))
            }

            // Hora
            VStack(alignment: .leading, spacing: 4) {
                Text("Hora")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                DatePicker("", selection: $selectedEndDate, in: Date.now..., displayedComponents: .hourAndMinute)
                    .datePickerStyle(.stepperField)
                    .labelsHidden()
            }
        }
    }
}

#Preview {
    @Previewable @State var timerMode = HomeViewModel.TimerInputMode.byDuration
    @Previewable @State var hours = 0
    @Previewable @State var minutes = 0
    @Previewable @State var endDate = Date.now.addingTimeInterval(3600)

    TimerPickerView(
        timerInputMode: $timerMode,
        selectedHours: $hours,
        selectedMinutes: $minutes,
        selectedEndDate: $endDate
    )
    .frame(width: 320)
    .padding()
}
