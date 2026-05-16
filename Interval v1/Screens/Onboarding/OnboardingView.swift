import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var appeared = false

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
    }

    // MARK: - Hero
    private var heroSection: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 120, height: 120)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .animation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.1), value: appeared)

                Image(systemName: "timer")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(.white)
                    .scaleEffect(appeared ? 1 : 0.3)
                    .animation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.2), value: appeared)
            }

            VStack(spacing: 10) {
                Text("Interval")
                    .font(.system(size: 46, weight: .black, design: .rounded))
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
                icon: "waveform.circle.fill",
                title: "Ambient geluiden",
                sub: "Regen, oceaan, bos — loopt door op slot"
            )
            featureRow(
                icon: "heart.fill",
                title: "Favorieten",
                sub: "Sla je schema's op voor hergebruik"
            )
        }
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.5), value: appeared)
    }

    private func featureRow(icon: String, title: String, sub: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .foregroundStyle(.white)
                    .font(.system(size: 18, weight: .semibold))
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
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Buttons
    private var bottomButtons: some View {
        VStack(spacing: 14) {
            // Sign in with Apple
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                auth.handleAuthorization(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 54)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)

            // Skip
            Button {
                auth.skipOnboarding()
            } label: {
                Text("Overslaan")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .accessibilityLabel("Onboarding overslaan")

            if let err = auth.errorMessage {
                Text(err)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.65), value: appeared)
    }

    // MARK: - Background
    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xE8826B), Color(hex: 0xD4705A), Color(hex: 0xC96A4A)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Decorative blobs
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 340, height: 340)
                .offset(x: 160, y: -200)
            Circle()
                .fill(Color(hex: 0xF4B860).opacity(0.2))
                .frame(width: 260, height: 260)
                .offset(x: -140, y: 280)
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthManager())
}
