//
//  ProfileSetupView.swift
//  TapInApp
//
//  Screen 5 — Profile photo, name, email, role picker.
//  "Let's Go" and "Skip for now" both call completeOnboarding().
//

import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) var colorScheme

    @State private var photoPickerItem: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var showPhotoOptions: Bool = false
    @State private var showCamera: Bool = false
    @State private var showPhotoPicker: Bool = false
    @FocusState private var focusedField: ProfileField?

    private enum ProfileField { case name, email }

    private let roles = ["Freshman", "Sophomore", "Junior", "Senior", "Graduate Student", "Professor", "Staff", "Faculty", "Alumni"]

    // Same gradients as WelcomeView / SignInOptionsView / PhoneEntry / OTP
    private let darkGradient = LinearGradient(
        colors: [Color(hex: "#0d1b4b"), Color(hex: "#1a1060"), Color(hex: "#2d0e52")],
        startPoint: .top, endPoint: .bottom
    )
    private let lightGradient = LinearGradient(
        colors: [Color(hex: "#F5A623"), Color(hex: "#F06B3F"), Color(hex: "#E8485A")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    private var isEmailValid: Bool {
        true
    }

    var body: some View {
        ZStack {
            Group {
                if colorScheme == .dark { darkGradient } else { lightGradient }
            }
            .ignoresSafeArea()

            // Ambient glow
            Color.white.opacity(0.06)
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -80, y: -160)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerBar
                    avatarSection
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    formSection
                        .padding(.horizontal, 24)
                    roleSection
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                    ctaSection
                        .padding(.horizontal, 24)
                        .padding(.top, 36)
                        .padding(.bottom, 52)
                }
            }
        }
        .onChange(of: photoPickerItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    viewModel.profileImageData = data
                    if let uiImage = UIImage(data: data) {
                        profileImage = Image(uiImage: uiImage)
                    }
                }
            }
        }
        .onTapGesture { focusedField = nil }
        .confirmationDialog("Profile Photo", isPresented: $showPhotoOptions, titleVisibility: .visible) {
            Button("Take Photo") { showCamera = true }
            Button("Choose from Library") { showPhotoPicker = true }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { uiImage in
                if let data = uiImage.jpegData(compressionQuality: 0.85) {
                    viewModel.profileImageData = data
                    profileImage = Image(uiImage: uiImage)
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            Button(action: { viewModel.goBack() }) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.15), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        VStack(spacing: 20) {
            Button(action: { showPhotoOptions = true }) {
                ZStack(alignment: .bottomTrailing) {
                    // Avatar circle
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.12))
                            .frame(width: 120, height: 120)
                            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 3))

                        if let profileImage {
                            profileImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 46))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }

                    // Camera badge
                    Circle()
                        .fill(.white)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? Color(hex: "#0d1b4b") : Color(hex: "#E8485A"))
                        )
                        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 2)
                        .offset(x: 4, y: 4)
                }
            }
            .buttonStyle(.plain)

            VStack(spacing: 6) {
                Text("Set up your profile")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("Tell us a bit about yourself")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
            }
        }
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(spacing: 14) {
            // Full Name
            VStack(alignment: .leading, spacing: 6) {
                Text("Full Name")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.leading, 4)

                TextField("Enter your name", text: $viewModel.displayName)
                    .focused($focusedField, equals: .name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .tint(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                focusedField == .name ? .white.opacity(0.6) : .white.opacity(0.2),
                                lineWidth: focusedField == .name ? 2 : 1.5
                            )
                    )
                    .animation(.easeInOut(duration: 0.2), value: focusedField == .name)
            }

            // Email
            VStack(alignment: .leading, spacing: 6) {
                Text("Email")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.leading, 4)

                TextField("your@email.com", text: $viewModel.email)
                    .focused($focusedField, equals: .email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .tint(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                focusedField == .email ? .white.opacity(0.6) : .white.opacity(0.2),
                                lineWidth: focusedField == .email ? 2 : 1.5
                            )
                    )
                    .animation(.easeInOut(duration: 0.2), value: focusedField == .email)
            }
        }
    }

    // MARK: - Role Picker

    private var roleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Role")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .padding(.leading, 4)

            ProfileFlowLayout(spacing: 8) {
                ForEach(roles, id: \.self) { role in
                    Button(action: { viewModel.year = role }) {
                        Text(role)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(viewModel.year == role ? 1 : 0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                .white.opacity(viewModel.year == role ? 0.25 : 0.10),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().stroke(
                                    .white.opacity(viewModel.year == role ? 0.6 : 0.2),
                                    lineWidth: viewModel.year == role ? 1.5 : 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: viewModel.year == role)
                }
            }
        }
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: 16) {
            Button(action: { Task { await viewModel.completeOnboarding() } }) {
                Text("Let's Go")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? Color(hex: "#0d1b4b") : Color(hex: "#E8485A"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(.white, in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
            }

            Button(action: { Task { await viewModel.completeOnboarding() } }) {
                Text("Skip for now")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Flow Layout (wrapping HStack)

private struct ProfileFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineH: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += lineH + spacing
                lineH = 0
            }
            x += size.width + spacing
            lineH = max(lineH, size.height)
        }
        return CGSize(width: maxWidth, height: y + lineH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineH: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineH + spacing
                lineH = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineH = max(lineH, size.height)
        }
    }
}

// MARK: - Previews

#Preview("Dark") {
    ProfileSetupView(viewModel: OnboardingViewModel())
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    ProfileSetupView(viewModel: OnboardingViewModel())
        .preferredColorScheme(.light)
}
