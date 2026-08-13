import Foundation

/// Public URLs for App Store privacy/support requirements (also shown in Settings).
enum AppLegalLinks {
    static let siteBase = URL(string: "https://kaden-car-championships.vercel.app")!
    static let privacyPolicy = URL(string: "https://kaden-car-championships.vercel.app/privacy.html")!
    static let termsOfService = URL(string: "https://kaden-car-championships.vercel.app/terms.html")!
    /// Support contact page (App Store Connect “Support URL”).
    static let support = URL(string: "https://kaden-car-championships.vercel.app/support.html")!
    /// Marketing / App Store Connect marketing URL.
    static let marketing = siteBase
}
