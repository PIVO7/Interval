import SwiftUI

struct AccountView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        profileCard
                        section(title: "Voorkeuren", rows: [
                            .init(icon: "globe", tint: AppTheme.sage, label: "Taal", value: "Systeem"),
                            .init(icon: "speaker.wave.2.fill", tint: AppTheme.coral, label: "Achtergrondgeluid", value: "Regen"),
                            .init(icon: "bell.badge", tint: AppTheme.amber, label: "Signaaltonen", value: "Aan"),
                            .init(icon: "waveform", tint: AppTheme.coral, label: "Haptic feedback", value: "Aan")
                        ])
                        section(title: "Binnenkort", rows: [
                            .init(icon: "bell", tint: AppTheme.secondaryText, label: "Notificaties", value: "v2"),
                            .init(icon: "creditcard", tint: AppTheme.secondaryText, label: "Betalingen", value: "v2")
                        ])
                        Button(role: .destructive) {} label: {
                            Text("Log out")
                                .font(.system(.headline, design: .rounded, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule().stroke(AppTheme.error.opacity(0.4), lineWidth: 1)
                                )
                                .foregroundStyle(AppTheme.error)
                        }
                        .padding(.top, 8)
                    }
                    .padding(20)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Account")
        }
    }

    private var profileCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(AppTheme.workGradient).frame(width: 64, height: 64)
                Image(systemName: "person.fill")
                    .font(.title)
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Welkom")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                Text("Meld je aan met Apple om je trainingen te synchroniseren.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
        }
        .padding(20)
        .softCard()
    }

    private struct Row: Identifiable {
        let id = UUID()
        let icon: String
        let tint: Color
        let label: String
        let value: String
    }

    @ViewBuilder
    private func section(title: String, rows: [Row]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .padding(.leading, 8)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(row.tint.opacity(0.18)).frame(width: 30, height: 30)
                            Image(systemName: row.icon).foregroundStyle(row.tint).font(.caption)
                        }
                        Text(row.label)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(AppTheme.primaryText)
                        Spacer()
                        Text(row.value)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    if idx < rows.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .softCard()
        }
    }
}

#Preview { AccountView() }
