// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct HiddenPreferenceStrings {
    let title: String
    let caption: String
    let reset: String
    let unset: String
}

extension FeatureStrings {
    static func hiddenPreferences(_ language: AppLanguage) -> HiddenPreferenceStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        case .uk: return .uk
        }
    }
}

extension HiddenPreferenceStrings {
    static let enUS = HiddenPreferenceStrings(
        title: "Hidden system preferences",
        caption: "These are the system’s own settings, not Vorssaint’s. Some take effect only after the owning app relaunches.",
        reset: "Reset",
        unset: "Not set"
    )

    static let ptBR = HiddenPreferenceStrings(
        title: "Preferências ocultas do sistema",
        caption: "São ajustes do próprio sistema, não do Vorssaint. Alguns só valem depois de reabrir o app.",
        reset: "Redefinir",
        unset: "Não definido"
    )

    static let tr = HiddenPreferenceStrings(
        title: "Gizli sistem tercihleri",
        caption: "Bunlar Vorssaint değil, sistemin ayarlarıdır. Bazıları uygulama yeniden açılınca etkin olur.",
        reset: "Sıfırla",
        unset: "Ayarlı değil"
    )

    static let ru = HiddenPreferenceStrings(
        title: "Скрытые настройки системы",
        caption: "Это настройки самой системы, а не Vorssaint. Некоторые применяются только после перезапуска приложения.",
        reset: "Сбросить",
        unset: "Не задано"
    )

    static let es = HiddenPreferenceStrings(
        title: "Preferencias ocultas del sistema",
        caption: "Son ajustes del propio sistema, no de Vorssaint. Algunos solo se aplican al reabrir la app.",
        reset: "Restablecer",
        unset: "Sin definir"
    )

    static let sk = HiddenPreferenceStrings(
        title: "Skryté systémové nastavenia",
        caption: "Sú to nastavenia samotného systému, nie Vorssaintu. Niektoré platia až po reštarte aplikácie.",
        reset: "Obnoviť",
        unset: "Nenastavené"
    )

    static let de = HiddenPreferenceStrings(
        title: "Versteckte Systemeinstellungen",
        caption: "Das sind Einstellungen des Systems, nicht von Vorssaint. Manche gelten erst nach einem Neustart der App.",
        reset: "Zurücksetzen",
        unset: "Nicht gesetzt"
    )

    static let fr = HiddenPreferenceStrings(
        title: "Réglages système masqués",
        caption: "Ce sont les réglages du système, pas ceux de Vorssaint. Certains ne s’appliquent qu’après relance de l’app.",
        reset: "Réinitialiser",
        unset: "Non défini"
    )

    static let it = HiddenPreferenceStrings(
        title: "Impostazioni di sistema nascoste",
        caption: "Sono impostazioni del sistema, non di Vorssaint. Alcune valgono solo dopo il riavvio dell’app.",
        reset: "Ripristina",
        unset: "Non impostato"
    )

    static let ja = HiddenPreferenceStrings(
        title: "システムの隠し設定",
        caption: "これは Vorssaint ではなくシステム側の設定です。アプリを再起動しないと反映されないものもあります。",
        reset: "リセット",
        unset: "未設定"
    )

    static let ko = HiddenPreferenceStrings(
        title: "시스템 숨김 설정",
        caption: "Vorssaint가 아니라 시스템 자체의 설정입니다. 일부는 앱을 다시 열어야 적용됩니다.",
        reset: "재설정",
        unset: "설정 안 됨"
    )

    static let zhHans = HiddenPreferenceStrings(
        title: "系统隐藏设置",
        caption: "这些是系统自身的设置，不是 Vorssaint 的设置。部分设置需要重新打开应用后生效。",
        reset: "重置",
        unset: "未设置"
    )

    static let zhTW = HiddenPreferenceStrings(
        title: "系統隱藏設定",
        caption: "這些是系統本身的設定，不是 Vorssaint 的設定。部分設定需要重新開啟應用程式後才生效。",
        reset: "重設",
        unset: "未設定"
    )

    static let zhHK = HiddenPreferenceStrings(
        title: "系統隱藏設定",
        caption: "這些是系統本身的設定，不是 Vorssaint 的設定。部分設定需要重新開啟應用程式後才生效。",
        reset: "重設",
        unset: "未設定"
    )

    static let uk = HiddenPreferenceStrings(
        title: "Приховані налаштування системи",
        caption: "Це налаштування самої системи, а не Vorssaint. Деякі діють лише після перезапуску програми.",
        reset: "Скинути",
        unset: "Не задано"
    )
}
