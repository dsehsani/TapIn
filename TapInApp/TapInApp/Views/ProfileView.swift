//
//  ProfileView.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @ObservedObject var savedViewModel: SavedViewModel
    @ObservedObject var gamesViewModel: GamesViewModel

    @Environment(\.colorScheme) var colorScheme
    @State private var showEditProfile = false
    @State private var showDeleteConfirmation = false

    // Load persisted profile image
    private var profileImage: UIImage? {
        guard let data = UserDefaults.standard.data(forKey: "profileImageData") else { return nil }
        return UIImage(data: data)
    }

    private var yearLabel: String? {
        guard let year = viewModel.user?.year, !year.isEmpty else { return nil }
        return year
    }

    var body: some View {
        ZStack {
            Color.adaptiveBackground(colorScheme)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // MARK: - Gradient Header
                    headerContent
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: colorScheme == .dark
                                    ? [Color(hex: "#1e2545"), Color(hex: "#302050")]
                                    : [Color.accentCoral, Color.accentOrange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 32,
                                bottomTrailingRadius: 32,
                                topTrailingRadius: 0
                            )
                        )

                    // MARK: - Stats (overlaps header)
                    statsRow
                        .padding(.top, -28)
                        .padding(.horizontal, 16)

                    // MARK: - Settings
                    settingsSection
                        .padding(.top, 24)
                        .padding(.horizontal, 16)

                    // MARK: - Sign Out & Delete Account
                    if viewModel.isLoggedIn {
                        Button(action: { viewModel.logout() }) {
                            Text("Sign Out")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(colorScheme == .dark ? Color(hex: "#1a2033") : .white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.04), radius: 8)
                        }
                        .padding(.top, 16)
                        .padding(.horizontal, 16)

                        Button(action: { showDeleteConfirmation = true }) {
                            Text("Delete Account")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.red.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(colorScheme == .dark ? Color(hex: "#1a2033") : .white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.04), radius: 8)
                        }
                        .padding(.top, 8)
                        .padding(.horizontal, 16)
                    }

                    Text("TapIn v1.0.4")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                }
            }
            .ignoresSafeArea(edges: .top)
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(viewModel: viewModel)
            }
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteAccount()
                    }
                }
            } message: {
                Text("Are you sure you want to permanently delete your account? All your data will be removed and this action cannot be undone.")
            }
        }
    }

    // MARK: - Header Content

    private var headerContent: some View {
        VStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(.white.opacity(colorScheme == .dark ? 0.1 : 0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(colorScheme == .dark ? 0.2 : 0.4), lineWidth: 2)
                    )

                if let uiImage = profileImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else {
                    Text(String(viewModel.userName.prefix(1)).uppercased())
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            // Name
            Text(viewModel.userName)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            // Email
            if !viewModel.userEmail.isEmpty {
                Text(viewModel.userEmail)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }

            // Year badge (from onboarding)
            if let year = yearLabel {
                Text(year)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            }

            // Edit Profile / Sign In
            if viewModel.isLoggedIn {
                Button(action: { showEditProfile = true }) {
                    Text("Edit Profile")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .overlay(
                            Capsule()
                                .stroke(.white, lineWidth: 2)
                        )
                }
                .padding(.top, 4)
            }
        }
        .padding(.top, 70)
        .padding(.bottom, 44)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            ProfileStatCard(
                value: "\(savedViewModel.savedArticles.count)",
                label: "ARTICLES",
                colorScheme: colorScheme
            )
            ProfileStatCard(
                value: "\(savedViewModel.savedEvents.count)",
                label: "EVENTS",
                colorScheme: colorScheme
            )
            ProfileStatCard(
                value: "\(gamesViewModel.userStats.gamesPlayed)",
                label: "GAMES",
                colorScheme: colorScheme
            )
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(spacing: 0) {
            SettingsRow(icon: "bell.fill", title: "Notifications", colorScheme: colorScheme) {
                Toggle("", isOn: $viewModel.notificationsEnabled)
                    .labelsHidden()
                    .tint(colorScheme == .dark ? Color.ucdGold : Color.accentCoral)
            }

            Divider().padding(.leading, 56)

            SettingsRow(icon: "moon.fill", title: "Dark Mode", colorScheme: colorScheme) {
                Toggle("", isOn: $viewModel.darkModeEnabled)
                    .labelsHidden()
                    .tint(colorScheme == .dark ? Color.ucdGold : Color.accentCoral)
            }

            Divider().padding(.leading, 56)

            Link(destination: APIConfig.privacyURL) {
                SettingsRow(icon: "hand.raised.fill", title: "Privacy Policy", colorScheme: colorScheme) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                }
            }

            Divider().padding(.leading, 56)

            Link(destination: APIConfig.termsURL) {
                SettingsRow(icon: "doc.text.fill", title: "Terms of Service", colorScheme: colorScheme) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                }
            }

            Divider().padding(.leading, 56)

            SettingsRow(icon: "info.circle.fill", title: "About TapIn", colorScheme: colorScheme) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
            }

            Divider().padding(.leading, 56)

            SettingsRow(icon: "questionmark.circle.fill", title: "Help & Support", colorScheme: colorScheme) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
            }
        }
        .background(colorScheme == .dark ? Color(hex: "#1a2033") : .white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8)
    }
}

// MARK: - Stat Card

struct ProfileStatCard: View {
    let value: String
    let label: String
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(colorScheme == .dark ? Color.ucdGold : Color.accentCoral)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(colorScheme == .dark ? Color(hex: "#1a2033") : .white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Settings Row

struct SettingsRow<Accessory: View>: View {
    let icon: String
    let title: String
    let colorScheme: ColorScheme
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(colorScheme == .dark ? Color.ucdGold : Color.accentCoral)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
            Spacer()
            accessory()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    ProfileView(
        viewModel: ProfileViewModel(),
        savedViewModel: SavedViewModel(),
        gamesViewModel: GamesViewModel()
    )
}
