//
//  EditProfileView.swift
//  TapInApp
//
//  Edit profile sheet — photo, name, email, role picker.
//  Reuses the visual style from ProfileSetupView (onboarding).
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var year: String = ""
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var profileImageData: Data?
    @State private var selectedInterests: Set<String> = []
    @State private var isSaving: Bool = false
    @State private var showPhotoOptions: Bool = false
    @State private var showCamera: Bool = false
    @State private var showPhotoPicker: Bool = false
    @FocusState private var focusedField: Field?

    private enum Field { case name, email }

    private let roles = ["Freshman", "Sophomore", "Junior", "Senior", "Graduate Student", "Professor", "Staff", "Faculty", "Alumni"]

    private let darkGradient = LinearGradient(
        colors: [Color(hex: "#0d1b4b"), Color(hex: "#1a1060"), Color(hex: "#2d0e52")],
        startPoint: .top, endPoint: .bottom
    )
    private let lightGradient = LinearGradient(
        colors: [Color(hex: "#F5A623"), Color(hex: "#F06B3F"), Color(hex: "#E8485A")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

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
                    interestsSection
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 52)
                }
            }
        }
        .onAppear { loadCurrentValues() }
        .onChange(of: photoPickerItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    profileImageData = data
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
                    profileImageData = data
                    profileImage = Image(uiImage: uiImage)
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Load Current Values

    private func loadCurrentValues() {
        name = viewModel.userName
        email = viewModel.userEmail
        year = viewModel.user?.year ?? ""
        selectedInterests = Set(viewModel.user?.interests ?? [])

        if let data = UserDefaults.standard.data(forKey: "profileImageData"),
           let uiImage = UIImage(data: data) {
            profileImageData = data
            profileImage = Image(uiImage: uiImage)
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.15), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
            }
            Spacer()
            Button(action: { saveProfile() }) {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 42, height: 42)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .background(.white.opacity(0.15), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                }
            }
            .disabled(isSaving)
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
                        } else if let firstChar = name.first, !name.isEmpty {
                            Text(String(firstChar).uppercased())
                                .font(.system(size: 46, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }

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
                Text("Edit Profile")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("Update your information")
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

                TextField("Enter your name", text: $name)
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

                TextField("your@email.com", text: $email)
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

            EditProfileFlowLayout(spacing: 8) {
                ForEach(roles, id: \.self) { role in
                    Button(action: {
                        year = (year == role) ? "" : role
                    }) {
                        Text(role)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(year == role ? 1 : 0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                .white.opacity(year == role ? 0.25 : 0.10),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().stroke(
                                    .white.opacity(year == role ? 0.6 : 0.2),
                                    lineWidth: year == role ? 1.5 : 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: year == role)
                }
            }
        }
    }

    // MARK: - Interests Section

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Interests")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .padding(.leading, 4)

            EditProfileFlowLayout(spacing: 8) {
                ForEach(OnboardingViewModel.availableInterests, id: \.self) { interest in
                    let isSelected = selectedInterests.contains(interest)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if isSelected {
                                selectedInterests.remove(interest)
                            } else {
                                selectedInterests.insert(interest)
                            }
                        }
                    }) {
                        Text(interest)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(isSelected ? 1 : 0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                .white.opacity(isSelected ? 0.25 : 0.10),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().stroke(
                                    .white.opacity(isSelected ? 0.6 : 0.2),
                                    lineWidth: isSelected ? 1.5 : 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Save

    private func saveProfile() {
        Task {
            isSaving = true
            await viewModel.updateProfile(
                name: name,
                email: email,
                year: year,
                imageData: profileImageData,
                interests: Array(selectedInterests)
            )
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Flow Layout (wrapping HStack)

private struct EditProfileFlowLayout: Layout {
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

// MARK: - Camera Picker (UIImagePickerController wrapper)

struct CameraPicker: UIViewControllerRepresentable {
    var onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
