import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var showAuthErrorAlert = false

    /// Hero title size scales with the user's preferred text size so
    /// "Interval" stays readable at accessibility text sizes.
    @ScaledMetric(relativeTo: .largeTitle) private var heroTitleSize: CGFloat = 46

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                heroSection
                Spacer()
                featuresSection
                Spacer()
                bottomButtons
                    .padding(.bottom, 52)
            }
            .padding(.horizontal, 40)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        // Observe errorVersion (monotonic) so identical errors thrown
        // back-to-back still re-present.
        .onChange(of: auth.errorVersion) { _, _ in
            if auth.errorMessage != nil { showAuthErrorAlert = true }
        }
        .alert("Inloggen mislukt", isPresented: $showAuthErrorAlert) {
            Button("OK", role: .cancel) { auth.errorMessage = nil }
        } message: {
            Text(auth.errorMessage ?? "")
        }
    }

    // MARK: - Hero
    private var heroSection: some View {
        VStack(spacing: 20) {
            ZStack {
                // Respect Reduce Motion: skip the scale pops, keep the fade
                // (same pattern as FinishedView's trophy entrance).
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 120, height: 120)
                    .scaleEffect(reduceMotion ? 1 : (appeared ? 1 : 0.4))
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.1), value: appeared)

                Image(systemName: "timer")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(.white)
                    .scaleEffect(reduceMotion ? 1 : (appeared ? 1 : 0.3))
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.2), value: appeared)
            }

            VStack(spacing: 10) {
                Text("Interval")
                    .font(.system(size: heroTitleSize, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.5).delay(0.3), value: appeared)

                Text("Intervaltimer voor coaches\nen kinesitherapeuten")
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(.easeOut(duration: 0.5).delay(0.4), value: appeared)
            }
        }
        .onAppear { appeared = true }
    }

    // MARK: - Features
    private var featuresSection: some View {
        VStack(spacing: 16) {
            featureRow(
                icon: "slider.horizontal.3",
                title: "Snel instellen",
                sub: "Work, rest en ronden in één oogopslag"
            )
            featureRow(
                icon: "speaker.wave.2.fill",
                title: "Voice cues",
                sub: "Three, two, one — GO bij elke ronde"
            )
            // Favorites are the paid feature — say so here already, so the
            // free promise stays honest and the paywall later isn't a surprise.
            featureRow(
                icon: "heart.fill",
                title: "Favorieten",
                sub: "Sla je schema's op met Interval Pro"
            )
        }
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.5), value: appeared)
    }

    private func featureRow(icon: String, title: LocalizedStringKey, sub: LocalizedStringKey) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .foregroundStyle(.white)
                    .font(.headline.weight(.semibold))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                Text(sub)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .clipShape(.rect(cornerRadius: 18))
    }

    // MARK: - Buttons
    private var bottomButtons: some View {
        VStack(spacing: 14) {
            // Primary: Sign in with Apple. Once signed in, AuthManager bridges
            // the credential into Supabase Auth so the user's favorites sync
            // across devices.
            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    auth.configureSignInRequest(request)
                },
                onCompletion: { result in
                    auth.handleAuthorization(result)
                }
            )
            .signInWithAppleButtonStyle(.white)
            .frame(height: 56)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)

            // Secondary: continue without an account (local-only mode).
            Button(action: auth.skipOnboarding) {
                Text("Verder zonder account")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.vertical, 8)
            }
            .accessibilityLabel("Verder zonder account")
        }
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.65), value: appeared)
    }

    // MARK: - Background
    //
    // Decorative blobs — sizes scale with the container via
    // `containerRelativeFrame`. Corner-bleed offsets scale with the blob's
    // own size via `visualEffect`, so the proportions look right from
    // iPhone SE all the way to 13" iPad without device-specific tuning.
    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xE8826B), Color(hex: 0xD4705A), Color(hex: 0xC96A4A)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.white.opacity(0.07))
                .containerRelativeFrame(.horizontal) { width, _ in width * 0.85 }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .visualEffect { content, proxy in
                    content.offset(x: proxy.size.width * 0.1, y: -proxy.size.height * 0.1)
                }
            Circle()
                .fill(Color(hex: 0xF4B860).opacity(0.2))
                .containerRelativeFrame(.horizontal) { width, _ in width * 0.65 }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .visualEffect { content, proxy in
                    content.offset(x: -proxy.size.width * 0.08, y: proxy.size.height * 0.08)
                }
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AuthManager())
}
