import SwiftUI
import AuthenticationServices

struct AccountView: View {
    @EnvironmentObject private var audioSettings: AudioSettings
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        profileCard
                        audioSection
                        signalSection
                        comingSoonSection
                        logoutButton
                    }
                    .padding(20)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Account")
        }
    }

    // MARK: - Profile
    private var profileCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(AppTheme.workGradient).frame(width: 64, height: 64)
                Image(systemName: "person.fill").font(.title).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                if auth.isSignedIn {
                    Text(auth.user?.fullName ?? "Apple-gebruiker")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                    if let email = auth.user?.email {
                        Text(email)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryText)
                    } else {
                        Text("Ingelogd met Apple")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                } else {
                    Text("Niet ingelogd")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Meld je aan met Apple voor synchronisatie.")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            Spacer()
            if !auth.isSignedIn {
                SignInWithAppleButton(.signIn) { req in
                    req.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    auth.handleAuthorization(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(width: 140, height: 38)
                .clipShape(Capsule())
            }
        }
        .padding(20)
        .softCard()
    }

    // MARK: - Ambient audio
    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Achtergrondgeluid")
            VStack(spacing: 0) {
                // Sound picker
                ForEach(Array(AmbientSound.allCases.enumerated()), id: \.element.id) { idx, sound in
                    Button {
                        audioSettings.ambientSound = sound
                        if sound != .none {
                            AudioEngine.shared.playAmbient(sound, volume: audioSettings.ambientVolume)
                        } else {
                            AudioEngine.shared.stopAmbient()
                        }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.coral.opacity(0.15))
                                    .frame(width: 30, height: 30)
                                Image(systemName: sound.icon)
                                    .foregroundStyle(AppTheme.coral)
                                    .font(.caption)
                            }
                            Text(sound.displayName)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(AppTheme.primaryText)
                            Spacer()
                            if audioSettings.ambientSound == sound {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AppTheme.coral)
                                    .font(.callout.weight(.semibold))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    if idx < AmbientSound.allCases.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }

                if audioSettings.ambientSound != .none {
                    Divider().padding(.leading, 60)
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.fill")
                            .foregroundStyle(AppTheme.secondaryText)
                            .font(.callout)
                        Slider(
                            value: Binding(
                                get: { Double(audioSettings.ambientVolume) },
                                set: { v in
                                    audioSettings.ambientVolume = Float(v)
                                    AudioEngine.shared.setAmbientVolume(Float(v))
                                }
                            ),
                            in: 0...1
                        )
                        .tint(AppTheme.coral)
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundStyle(AppTheme.secondaryText)
                            .font(.callout)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .softCard()
        }
    }

    // MARK: - Signal tones & haptics
    private var signalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Signalen")
            VStack(spacing: 0) {
                toggleRow(
                    icon: "bell.badge.fill",
                    tint: AppTheme.amber,
                    label: "Signaaltonen",
                    sub: "Toon bij start work/rest en laatste 3s",
                    isOn: $audioSettings.signalTonesEnabled
                )
                Divider().padding(.leading, 60)
                toggleRow(
                    icon: "waveform",
                    tint: AppTheme.coral,
                    label: "Haptic feedback",
                    sub: "Trillen bij elke fase-overgang",
                    isOn: $audioSettings.hapticsEnabled
                )
            }
            .softCard()
        }
    }

    // MARK: - Coming soon
    private var comingSoonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Binnenkort")
            VStack(spacing: 0) {
                infoRow(icon: "bell", tint: AppTheme.secondaryText, label: "Notificaties", value: "v2")
                Divider().padding(.leading, 60)
                infoRow(icon: "creditcard", tint: AppTheme.secondaryText, label: "Betalingen", value: "v2")
            }
            .softCard()
        }
    }

    // MARK: - Logout
    private var logoutButton: some View {
        Group {
            if auth.isSignedIn {
                Button(role: .destructive) {
                    auth.signOut()
                } label: {
                    Text("Log out")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().stroke(AppTheme.error.opacity(0.4), lineWidth: 1))
                        .foregroundStyle(AppTheme.error)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Helpers
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(AppTheme.secondaryText)
            .padding(.leading, 8)
    }

    private func toggleRow(icon: String, tint: Color, label: String, sub: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(tint.opacity(0.18)).frame(width: 30, height: 30)
                Image(systemName: icon).foregroundStyle(tint).font(.caption)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(.body, design: .rounded)).foregroundStyle(AppTheme.primaryText)
                Text(sub).font(.system(.caption2, design: .rounded)).foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            Toggle("", isOn: isOn).tint(AppTheme.coral).labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func infoRow(icon: String, tint: Color, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(tint.opacity(0.18)).frame(width: 30, height: 30)
                Image(systemName: icon).foregroundStyle(tint).font(.caption)
            }
            Text(label).font(.system(.body, design: .rounded)).foregroundStyle(AppTheme.primaryText)
            Spacer()
            Text(value).font(.system(.subheadline, design: .rounded)).foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview { AccountView().environmentObject(AudioSettings()).environmentObject(AuthManager()) }
