//
//  HomeView.swift
//  FocusMode
//

import SwiftUI

struct HomeView: View {

    @State private var viewModel = HomeViewModel()

    var body: some View {
        VStack(spacing: 0) {

            // --- Encabezado ---
            HStack {
                Text("FocusMode")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)

            Divider()

            // --- Cuerpo ---
            VStack(spacing: 16) {

                // Selector de modo
                ModePickerView(selectedMode: $viewModel.selectedMode)

                // Selector de tiempo (solo cuando no hay sesión activa)
                if !viewModel.sessionIsActive {
                    TimerPickerView(
                        timerInputMode: $viewModel.timerInputMode,
                        selectedHours: $viewModel.selectedHours,
                        selectedMinutes: $viewModel.selectedMinutes,
                        selectedEndDate: $viewModel.selectedEndDate
                    )
                }

                // Banner de sesión activa
                if viewModel.sessionIsActive {
                    activeSessionBanner
                }
            }
            .padding(24)

            Divider()

            // --- Pie con botón ---
            Button {
                viewModel.toggleSession()
            } label: {
                Text(viewModel.sessionIsActive ? "Cancelar sesión" : "Iniciar sesión")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.sessionIsActive ? .red : .accentColor)
            .controlSize(.large)
            .padding(24)
        }
        .frame(width: 360)
    }

    private var activeSessionBanner: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.selectedMode == .block ? "Block Mode activo" : "Allow Mode activo")
                    .font(.system(size: 13, weight: .semibold))

                Text("Termina \(viewModel.computedEndDate.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.green.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    HomeView()
}
