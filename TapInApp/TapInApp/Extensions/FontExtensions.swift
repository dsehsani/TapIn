//
//  FontExtensions.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//

import SwiftUI

extension Font {
    // MARK: - Headlines
    static let articleTitle = Font.system(size: 24, weight: .bold)
    static let articleTitleSmall = Font.system(size: 16, weight: .bold)
    static let sectionTitle = Font.system(size: 18, weight: .bold)

    // MARK: - Body Text
    static let articleExcerpt = Font.system(size: 14, weight: .regular)
    static let bodyText = Font.system(size: 14, weight: .regular)

    // MARK: - Labels & Tags
    static let categoryTag = Font.system(size: 10, weight: .bold)
    static let categoryPill = Font.system(size: 14, weight: .semibold)
    static let timestamp = Font.system(size: 10, weight: .regular)
    static let tabLabel = Font.system(size: 10, weight: .semibold)

    // MARK: - Buttons
    static let buttonText = Font.system(size: 12, weight: .black)
    static let buttonTextSmall = Font.system(size: 14, weight: .bold)

    // MARK: - Banner
    static let bannerTitle = Font.system(size: 18, weight: .bold)
    static let bannerSubtitle = Font.system(size: 12, weight: .regular)
}
