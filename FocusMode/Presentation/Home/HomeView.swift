//
//  HomeView.swift
//  FocusMode
//

import SwiftUI

struct HomeView: View {

    // SessionManager llega desde el environment — se crea en FocusModeApp
    @Environment(SessionManager.self) private var sessionManager

    @State private var listsViewModel = ListsViewModel()

    // El ViewModel se crea aquí con el SessionManager del environment.
    // @State asegura que no se recree en cada render.
    @State private var viewModel: HomeViewModel?

    var body: some View {
        // Si el viewModel no está listo todavía, mostrar nada brevemente
        if let vm = viewModel {
            content(vm: vm)
        } else {
            Color.clear
                .onAppear {
                    viewModel = HomeViewModel(sessionManager: sessionManager)
                }
        }
    }

    @ViewBuilder
    private func content(vm: HomeViewModel) -> some View {
        VStack(spacing: 0) {

            // --- Encabezado ---
            HStack {
                Text("FocusMode")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                listsButton(vm: vm)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)

            Divider()

            // --- Cuerpo ---
            VStack(spacing: 16) {

                // El selector de modo se desactiva si hay sesión activa
                ModePickerView(selectedMode: Binding(
                    get: { vm.selectedMode },
                    set: { if !vm.sessionIsActive { vm.selectedMode = $0 } }
                ))
                .disabled(vm.sessionIsActive)

                if !vm.sessionIsActive {
                    TimerPickerView(
                        timerInputMode: Binding(get: { vm.timerInputMode }, set: { vm.timerInputMode = $0 }),
                        selectedHours: Binding(get: { vm.selectedHours }, set: { vm.selectedHours = $0 }),
                        selectedMinutes: Binding(get: { vm.selectedMinutes }, set: { vm.selectedMinutes = $0 }),
                        selectedEndDate: Binding(get: { vm.selectedEndDate }, set: { vm.selectedEndDate = $0 })
                    )
                }

                if vm.sessionIsActive {
                    activeSessionBanner(vm: vm)
                }

                // Mensaje de error si algo falló
                if let error = vm.errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)

            Divider()

            // --- Botón principal ---
            // Durante sesión activa: el botón no hace nada (sesión irrevocable)
            // Sin sesión: activa la sesión
            Button {
                if !vm.sessionIsActive {
                    vm.startSession(lists: listsViewModel.lists)
                    listsViewModel.sessionIsActive = true
                }
            } label: {
                Text(vm.sessionIsActive ? "Sesión activa" : "Iniciar sesión")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.sessionIsActive ? Color.green : Color.accentColor)
            .controlSize(.large)
            .disabled(vm.sessionIsActive)
            .padding(24)
        }
        .frame(width: 360)
        // Sincroniza el estado de sesión con ListsViewModel cuando cambia
        .onChange(of: vm.sessionIsActive) { _, isActive in
            listsViewModel.sessionIsActive = isActive
        }
    }

    // Botón que abre la lista correspondiente al modo actual
    @ViewBuilder
    private func listsButton(vm: HomeViewModel) -> some View {
        let isBlock = vm.selectedMode == .block

        NavigationLink {
            if isBlock {
                BlockListsView(viewModel: listsViewModel)
            } else {
                AllowListsView(viewModel: listsViewModel)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "list.bullet")
                Text(isBlock ? "Lista de bloqueo" : "Lista de permitidos")
                    .font(.system(size: 12))
            }
            .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
    }

    private func activeSessionBanner(vm: HomeViewModel) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text(vm.displayMode == .block ? "Block Mode activo" : "Allow Mode activo")
                    .font(.system(size: 13, weight: .semibold))
            }

            Text("Termina \(vm.displayEndDate.formatted(date: .omitted, time: .shortened))")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
    NavigationStack {
        HomeView()
            .environment(SessionManager(
                store: FocusStore(),
                blockEngine: BlockEngine(
                    hostsManager: StubHostsManager(),
                    dnsManager: StubDNSManager(),
                    appMonitor: StubAppMonitor()
                )
            ))
    }
}
