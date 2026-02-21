// WelcomeView.swift
// OutliveEngine
//
// First onboarding screen. Displays the app identity, Sign in with Apple,
// and a privacy assurance message.

import SwiftUI
import AuthenticationServices

struct WelcomeView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(AppState.self) private var appState
    @State private var authService = AuthService()
    @State private var authError: String?
    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            logoSection
            Spacer().frame(height: OutliveSpacing.xxl)
            identitySection
            Spacer()

            signInSection
            privacyNote
        }
        .padding(.horizontal, OutliveSpacing.lg)
        .padding(.bottom, OutliveSpacing.xl)
        .background(Color.surfaceBackground)
        .navigationBarBackButtonHidden()
        .alert("Sign In Failed", isPresented: .init(
            get: { authError != nil },
            set: { if !$0 { authError = nil } }
        )) {
            Button("OK", role: .cancel) { authError = nil }
        } message: {
            Text(authError ?? "An unknown error occurred.")
        }
    }

    // MARK: - Logo

    private var logoSection: some View {
        ZStack {
            Circle()
                .fill(Color.domainTraining.opacity(0.12))
                .frame(width: 120, height: 120)

            Image(systemName: "heart.text.clipboard.fill")
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(Color.domainTraining)
        }
    }

    // MARK: - Identity

    private var identitySection: some View {
        VStack(spacing: OutliveSpacing.xs) {
            Text("Outlive Engine")
                .font(.outliveLargeTitle)
                .foregroundStyle(Color.textPrimary)

            Text("Genome-aware, protocol-driven health optimization")
                .font(.outliveCallout)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OutliveSpacing.lg)
        }
    }

    // MARK: - Sign In

    private var signInSection: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.email, .fullName]
        } onCompletion: { result in
            handleSignIn(result: result)
        }
        .signInWithAppleButtonStyle(.whiteOutline)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
        .disabled(isSigningIn)
        .opacity(isSigningIn ? 0.6 : 1.0)
        .padding(.bottom, OutliveSpacing.md)
    }

    // MARK: - Privacy

    private var privacyNote: some View {
        HStack(spacing: OutliveSpacing.xs) {
            Image(systemName: "lock.shield.fill")
                .font(.outliveCaption)
                .foregroundStyle(Color.textTertiary)

            Text("Your health data is encrypted and never leaves your control")
                .font(.outliveCaption)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, OutliveSpacing.sm)
    }

    // MARK: - Auth Handler

    private func handleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authError = "Invalid credential type received."
                return
            }
            isSigningIn = true

            Task {
                do {
                    try await authService.signInWithApple(credential: credential, appState: appState)
                    viewModel.next()
                } catch {
                    authError = error.localizedDescription
                }
                isSigningIn = false
            }

        case .failure(let error):
            // ASAuthorizationError.canceled is user-initiated; don't surface it.
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                return
            }
            authError = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WelcomeView(viewModel: OnboardingViewModel())
            .environment(AppState())
    }
}
