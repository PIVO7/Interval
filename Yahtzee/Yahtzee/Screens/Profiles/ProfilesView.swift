import SwiftUI

struct ProfilesView: View {
    @Environment(ProfileStore.self) private var profileStore
    @State private var newName = ""
    @State private var renameTarget: PlayerProfile?
    @State private var renameText = ""

    var body: some View {
        ZStack {
            AppTheme.feltDeep.ignoresSafeArea()

            List {
                Section {
                    HStack {
                        TextField("Naam van je kind", text: $newName)
                            .textInputAutocapitalization(.words)
                        Button("Voeg toe") {
                            profileStore.addProfile(name: newName)
                            newName = ""
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    Text("Nieuw profiel")
                        .foregroundStyle(AppTheme.cream.opacity(0.8))
                }

                Section {
                    if profileStore.humanProfiles.isEmpty {
                        Text("Nog geen profielen. Maak er een aan om te spelen.")
                            .foregroundStyle(AppTheme.ink.opacity(0.7))
                    } else {
                        ForEach(profileStore.humanProfiles) { profile in
                            HStack(spacing: 14) {
                                AvatarBadge(profile: profile)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(profile.name)
                                        .font(AppTheme.headlineFont)
                                        .foregroundStyle(AppTheme.ink)
                                    Text("\(profile.wins)× gewonnen · \(profile.gamesPlayed) gespeeld")
                                        .font(AppTheme.captionFont)
                                        .foregroundStyle(AppTheme.ink.opacity(0.65))
                                }
                                Spacer()
                                Button("Hernoem") {
                                    renameTarget = profile
                                    renameText = profile.name
                                }
                                .font(AppTheme.captionFont)
                            }
                            .listRowBackground(AppTheme.cream.opacity(0.95))
                        }
                        .onDelete { indexSet in
                            let ids = indexSet.compactMap { profileStore.humanProfiles[safe: $0]?.id }
                            ids.forEach(profileStore.deleteProfile)
                        }
                    }
                } header: {
                    Text("Spelers")
                        .foregroundStyle(AppTheme.cream.opacity(0.8))
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Profielen")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Naam wijzigen", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Naam", text: $renameText)
            Button("Bewaar") {
                if let id = renameTarget?.id {
                    profileStore.renameProfile(id: id, to: renameText)
                }
                renameTarget = nil
            }
            Button("Annuleer", role: .cancel) {
                renameTarget = nil
            }
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
