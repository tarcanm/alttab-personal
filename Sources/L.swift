import Foundation

/// Tiny localization helper. English is the primary text (this is a public repo);
/// Turkish follows for local use. The app shows Turkish when the user's preferred
/// language starts with "tr", otherwise English.
///
/// Küçük yerelleştirme yardımcısı. Birincil metin İngilizce (burası public bir repo),
/// Türkçe yerel kullanım için ikinci sırada. Kullanıcının tercih ettiği dil "tr" ile
/// başlıyorsa Türkçe, aksi halde İngilizce gösterilir.
enum L {

    private static let isTurkish: Bool = Locale.preferredLanguages.first?.hasPrefix("tr") ?? false

    private static func pick(_ en: String, _ tr: String) -> String { isTurkish ? tr : en }

    static var untitledWindow: String { pick("Untitled window", "Başlıksız pencere") }
    static var application: String { pick("Application", "Uygulama") }
    static var minimized: String { pick("minimized", "küçültülmüş") }

    static var navigationHint: String {
        pick("Hold ⌥ · Tab/←→ to move · release to switch · Esc to cancel",
             "⌥ basılı tut · Tab/←→ gez · bırak = seç · Esc iptal")
    }

    static func windowCount(total: Int, shown: Int) -> String {
        pick("\(total) windows, showing \(shown)", "\(total) pencere, \(shown) tanesi gösteriliyor")
    }

    static var menuHint: String {
        pick("Hold ⌥ + Tab to switch windows", "⌥ + Tab ile pencereler arasında gezin")
    }
    static var menuPermissions: String { pick("Permissions…", "İzinler…") }
    static var menuLogs: String { pick("Open log folder", "Log klasörünü aç") }
    static var menuQuit: String { pick("Quit", "Çıkış") }

    static var tapCreationFailed: String {
        pick("AltTabPersonal: could not create the event tap (Accessibility permission required)",
             "AltTabPersonal: event tap oluşturulamadı (erişilebilirlik izni gerekiyor)")
    }
}
