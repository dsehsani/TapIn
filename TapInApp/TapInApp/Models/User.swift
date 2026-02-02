//
//  User.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//

import Foundation

struct User: Identifiable, Codable {
    let id: UUID
    var name: String
    var email: String
    var profileImageURL: String?

    init(
        id: UUID = UUID(),
        name: String,
        email: String,
        profileImageURL: String? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.profileImageURL = profileImageURL
    }
}

// MARK: - Sample Data
extension User {
    static let sampleUser = User(
        name: "Aggie Student",
        email: "student@ucdavis.edu"
    )

    static let guest = User(
        name: "Guest",
        email: ""
    )
}
