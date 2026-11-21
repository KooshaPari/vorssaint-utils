// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct WindowPolicyStrings {
    let enabled: String
    let layout: String
    let tileNow: String
    let caption: String
    let resultFormat: String
    let limit: String
    let overflowBehavior: String
    let leaveInPlace: String
    let minimizedSummaryFormat: String
}

extension FeatureStrings {
    static func windowPolicy(_ language: AppLanguage) -> WindowPolicyStrings {
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

extension WindowPolicyStrings {
    static let enUS = WindowPolicyStrings(
        enabled: "Arrange windows automatically",
        layout: "Layout",
        tileNow: "Tile now",
        caption: "Only ordinary windows that can be moved are rearranged. Windows past the layout’s slots are left alone.",
        resultFormat: "Moved %d windows",
        limit: "Window limit",
        overflowBehavior: "Windows past the limit",
        leaveInPlace: "Leave in place",
        minimizedSummaryFormat: "%d minimized windows in %d apps"
    )

    static let ptBR = WindowPolicyStrings(
        enabled: "Organizar janelas automaticamente",
        layout: "Layout",
        tileNow: "Organizar agora",
        caption: "Só janelas comuns que podem ser movidas são reorganizadas. As que passam dos espaços ficam como estão.",
        resultFormat: "%d janelas movidas",
        limit: "Limite de janelas",
        overflowBehavior: "Janelas além do limite",
        leaveInPlace: "Deixar como estão",
        minimizedSummaryFormat: "%d janelas minimizadas em %d apps"
    )

    static let tr = WindowPolicyStrings(
        enabled: "Pencereleri otomatik düzenle",
        layout: "Düzen",
        tileNow: "Şimdi düzenle",
        caption: "Yalnızca taşınabilen sıradan pencereler yeniden düzenlenir. Yerleşimdeki yuvaları aşanlar olduğu gibi kalır.",
        resultFormat: "%d pencere taşındı",
        limit: "Pencere sınırı",
        overflowBehavior: "Sınırı aşan pencereler",
        leaveInPlace: "Olduğu gibi bırak",
        minimizedSummaryFormat: "%d uygulamada %d simge durumunda pencere"
    )

    static let ru = WindowPolicyStrings(
        enabled: "Упорядочивать окна автоматически",
        layout: "Раскладка",
        tileNow: "Упорядочить сейчас",
        caption: "Переставляются только обычные окна, которые можно перемещать. Окна сверх ячеек остаются на месте.",
        resultFormat: "Перемещено окон: %d",
        limit: "Предел окон",
        overflowBehavior: "Окна сверх предела",
        leaveInPlace: "Оставить на месте",
        minimizedSummaryFormat: "Свёрнутых окон: %d, приложений: %d"
    )

    static let es = WindowPolicyStrings(
        enabled: "Ordenar ventanas automáticamente",
        layout: "Disposición",
        tileNow: "Ordenar ahora",
        caption: "Solo se reordenan ventanas normales que se puedan mover. Las que superan los huecos se dejan como están.",
        resultFormat: "Ventanas movidas: %d",
        limit: "Límite de ventanas",
        overflowBehavior: "Ventanas por encima del límite",
        leaveInPlace: "Dejar como están",
        minimizedSummaryFormat: "%d ventanas minimizadas en %d apps"
    )

    static let sk = WindowPolicyStrings(
        enabled: "Usporiadať okná automaticky",
        layout: "Rozloženie",
        tileNow: "Usporiadať teraz",
        caption: "Preusporiadajú sa len bežné okná, ktoré sa dajú presúvať. Okná nad rámec polí zostanú tak, ako sú.",
        resultFormat: "Presunutých okien: %d",
        limit: "Limit okien",
        overflowBehavior: "Okná nad limit",
        leaveInPlace: "Nechať tak, ako sú",
        minimizedSummaryFormat: "%d minimalizovaných okien v %d aplikáciách"
    )

    static let de = WindowPolicyStrings(
        enabled: "Fenster automatisch anordnen",
        layout: "Anordnung",
        tileNow: "Jetzt anordnen",
        caption: "Nur gewöhnliche, verschiebbare Fenster werden neu angeordnet. Fenster jenseits der Plätze bleiben, wo sie sind.",
        resultFormat: "Fenster verschoben: %d",
        limit: "Fensterlimit",
        overflowBehavior: "Fenster über dem Limit",
        leaveInPlace: "An Ort und Stelle lassen",
        minimizedSummaryFormat: "%d minimierte Fenster in %d Apps"
    )

    static let fr = WindowPolicyStrings(
        enabled: "Disposer les fenêtres automatiquement",
        layout: "Disposition",
        tileNow: "Disposer maintenant",
        caption: "Seules les fenêtres ordinaires déplaçables sont réorganisées. Celles au-delà des emplacements restent en place.",
        resultFormat: "Fenêtres déplacées : %d",
        limit: "Limite de fenêtres",
        overflowBehavior: "Fenêtres au-delà de la limite",
        leaveInPlace: "Laisser en place",
        minimizedSummaryFormat: "%d fenêtres réduites dans %d apps"
    )

    static let it = WindowPolicyStrings(
        enabled: "Disponi le finestre automaticamente",
        layout: "Disposizione",
        tileNow: "Disponi ora",
        caption: "Vengono riorganizzate solo le finestre normali spostabili. Quelle oltre gli spazi restano dove sono.",
        resultFormat: "Finestre spostate: %d",
        limit: "Limite finestre",
        overflowBehavior: "Finestre oltre il limite",
        leaveInPlace: "Lascia dove sono",
        minimizedSummaryFormat: "%d finestre ridotte in %d app"
    )

    static let ja = WindowPolicyStrings(
        enabled: "ウインドウを自動で整列",
        layout: "レイアウト",
        tileNow: "今すぐ整列",
        caption: "移動できる通常のウインドウだけを並べ替えます。枠を超えたウインドウはそのままです。",
        resultFormat: "%d 個のウインドウを移動しました",
        limit: "ウインドウの上限",
        overflowBehavior: "上限を超えたウインドウ",
        leaveInPlace: "そのままにする",
        minimizedSummaryFormat: "%d 個のウインドウが %d 個のアプリで最小化"
    )

    static let ko = WindowPolicyStrings(
        enabled: "창 자동 정렬",
        layout: "레이아웃",
        tileNow: "지금 정렬",
        caption: "이동할 수 있는 일반 창만 다시 배치합니다. 슬롯을 넘는 창은 그대로 둡니다.",
        resultFormat: "%d개 창 이동됨",
        limit: "창 제한",
        overflowBehavior: "제한을 넘는 창",
        leaveInPlace: "그대로 두기",
        minimizedSummaryFormat: "%d개 앱에 최소화된 창 %d개"
    )

    static let zhHans = WindowPolicyStrings(
        enabled: "自动排列窗口",
        layout: "布局",
        tileNow: "立即排列",
        caption: "只重新排列可移动的普通窗口。超出布局空位的窗口保持不动。",
        resultFormat: "已移动 %d 个窗口",
        limit: "窗口上限",
        overflowBehavior: "超出上限的窗口",
        leaveInPlace: "保持不动",
        minimizedSummaryFormat: "%d 个窗口在 %d 个应用中已最小化"
    )

    static let zhTW = WindowPolicyStrings(
        enabled: "自動排列視窗",
        layout: "佈局",
        tileNow: "立即排列",
        caption: "只重新排列可移動的一般視窗。超出佈局空位的視窗維持不動。",
        resultFormat: "已移動 %d 個視窗",
        limit: "視窗上限",
        overflowBehavior: "超出上限的視窗",
        leaveInPlace: "維持不動",
        minimizedSummaryFormat: "%d 個視窗在 %d 個應用程式中已最小化"
    )

    static let zhHK = WindowPolicyStrings(
        enabled: "自動排列視窗",
        layout: "佈局",
        tileNow: "立即排列",
        caption: "只重新排列可移動的一般視窗。超出佈局空位的視窗維持不動。",
        resultFormat: "已移動 %d 個視窗",
        limit: "視窗上限",
        overflowBehavior: "超出上限的視窗",
        leaveInPlace: "維持不動",
        minimizedSummaryFormat: "%d 個視窗在 %d 個應用程式中已最小化"
    )

    static let uk = WindowPolicyStrings(
        enabled: "Упорядковувати вікна автоматично",
        layout: "Розкладка",
        tileNow: "Упорядкувати зараз",
        caption: "Переставляються лише звичайні вікна, які можна переміщати. Вікна понад комірки лишаються на місці.",
        resultFormat: "Переміщено вікон: %d",
        limit: "Межа вікон",
        overflowBehavior: "Вікна понад межу",
        leaveInPlace: "Залишити на місці",
        minimizedSummaryFormat: "Згорнутих вікон: %d, програм: %d"
    )
}
