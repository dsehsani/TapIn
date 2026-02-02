//
//  ProfileView.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Color.adaptiveBackground(colorScheme)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Text("Profile")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : Color.ucdBlue)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // Profile Card
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.ucdBlue)
                                .frame(width: 80, height: 80)
                            Text(String(viewModel.userName.prefix(1)).uppercased())
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }

                        VStack(spacing: 4) {
                            Text(viewModel.userName)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))

                            if !viewModel.userEmail.isEmpty {
                                Text(viewModel.userEmail)
                                    .font(.system(size: 14))
                                    .foregroundColor(.textSecondary)
                            }
                        }

                        if viewModel.isLoggedIn {
                            Button(action: {}) {
                                Text("Edit Profile")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.ucdBlue)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.ucdBlue, lineWidth: 1.5)
                                    )
                            }
                        } else {
                            Button(action: {
                                Task {
                                    await viewModel.login(email: "demo@ucdavis.edu", password: "demo")
                                }
                            }) {
                                Text("Sign In")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 12)
                                    .background(Color.ucdBlue)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(colorScheme == .dark ? Color(hex: "#0f172a") : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 8)
                    .padding(.horizontal, 16)

                    // Settings Section
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Settings")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)

                        VStack(spacing: 0) {
                            SettingsRow(icon: "bell.fill", title: "Notifications", colorScheme: colorScheme) {
                                Toggle("", isOn: $viewModel.notificationsEnabled)
                                    .labelsHidden()
                                    .tint(Color.ucdBlue)
                            }

                            Divider().padding(.leading, 56)

                            SettingsRow(icon: "moon.fill", title: "Dark Mode", colorScheme: colorScheme) {
                                Toggle("", isOn: $viewModel.darkModeEnabled)
                                    .labelsHidden()
                                    .tint(Color.ucdBlue)
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
                        .background(colorScheme == .dark ? Color(hex: "#0f172a") : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                    }

                    // Sign Out Button
                    if viewModel.isLoggedIn {
                        Button(action: { viewModel.logout() }) {
                            Text("Sign Out")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(colorScheme == .dark ? Color(hex: "#0f172a") : .white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.horizontal, 16)
                    }

                    Text("TapIn v1.0.0")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                        .padding(.top, 8)

                    Spacer(minLength: 0)
                        .frame(height: 8)
                }
            }
        }
    }
}

struct SettingsRow<Accessory: View>: View {
    let icon: String
    let title: String
    let colorScheme: ColorScheme
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color.ucdBlue)
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
    ProfileView(viewModel: ProfileViewModel())
}
