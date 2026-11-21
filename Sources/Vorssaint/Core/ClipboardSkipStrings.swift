// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct ClipboardSkipStrings {
    let skipNext: String
    let skipNextCaption: String
    let universalClipboard: String
    let universalClipboardCaption: String
}

extension FeatureStrings {
    static func clipboardSkip(_ language: AppLanguage) -> ClipboardSkipStrings {
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

extension ClipboardSkipStrings {
    static let enUS = ClipboardSkipStrings(
        skipNext: "Skip the next copy",
        skipNextCaption: "Leaves the next thing you copy out of the history, then records again.",
        universalClipboard: "Skip Universal Clipboard",
        universalClipboardCaption: "Copies that arrive from another device are never saved."
    )

    static let ptBR = ClipboardSkipStrings(
        skipNext: "Pular a próxima cópia",
        skipNextCaption: "Deixa de fora a próxima coisa que copiar e volta a guardar depois.",
        universalClipboard: "Pular a Área de Transferência Universal",
        universalClipboardCaption: "Cópias que chegam de outro dispositivo nunca são guardadas."
    )

    static let tr = ClipboardSkipStrings(
        skipNext: "Sonraki kopyayı atla",
        skipNextCaption: "Kopyaladığınız bir sonraki şeyi geçmişe almaz, sonra yeniden kaydeder.",
        universalClipboard: "Evrensel Panoyu atla",
        universalClipboardCaption: "Başka bir cihazdan gelen kopyalar asla kaydedilmez."
    )

    static let ru = ClipboardSkipStrings(
        skipNext: "Пропустить следующее копирование",
        skipNextCaption: "Не сохраняет следующую копию, затем запись возобновляется.",
        universalClipboard: "Пропускать универсальный буфер обмена",
        universalClipboardCaption: "Копии, пришедшие с другого устройства, не сохраняются."
    )

    static let es = ClipboardSkipStrings(
        skipNext: "Saltar la próxima copia",
        skipNextCaption: "Deja fuera lo próximo que copies y luego vuelve a guardar.",
        universalClipboard: "Saltar el Portapapeles universal",
        universalClipboardCaption: "Las copias que llegan de otro dispositivo nunca se guardan."
    )

    static let sk = ClipboardSkipStrings(
        skipNext: "Preskočiť nasledujúcu kópiu",
        skipNextCaption: "Nasledujúcu skopírovanú vec neuloží a potom pokračuje v ukladaní.",
        universalClipboard: "Preskočiť univerzálnu schránku",
        universalClipboardCaption: "Kópie z iného zariadenia sa nikdy neukladajú."
    )

    static let de = ClipboardSkipStrings(
        skipNext: "Nächste Kopie überspringen",
        skipNextCaption: "Lässt das nächste Kopierte aus und zeichnet danach wieder auf.",
        universalClipboard: "Universal-Zwischenablage überspringen",
        universalClipboardCaption: "Kopien von einem anderen Gerät werden nie gespeichert."
    )

    static let fr = ClipboardSkipStrings(
        skipNext: "Ignorer la prochaine copie",
        skipNextCaption: "Laisse de côté la prochaine copie, puis enregistre de nouveau.",
        universalClipboard: "Ignorer le presse-papiers universel",
        universalClipboardCaption: "Les copies venant d’un autre appareil ne sont jamais enregistrées."
    )

    static let it = ClipboardSkipStrings(
        skipNext: "Salta la prossima copia",
        skipNextCaption: "Lascia fuori la prossima copia, poi riprende a salvare.",
        universalClipboard: "Salta gli Appunti universali",
        universalClipboardCaption: "Le copie che arrivano da un altro dispositivo non vengono mai salvate."
    )

    static let ja = ClipboardSkipStrings(
        skipNext: "次のコピーをスキップ",
        skipNextCaption: "次にコピーする内容を保存せず、その後は再び保存します。",
        universalClipboard: "ユニバーサルクリップボードをスキップ",
        universalClipboardCaption: "別のデバイスから届いたコピーは保存されません。"
    )

    static let ko = ClipboardSkipStrings(
        skipNext: "다음 복사 건너뛰기",
        skipNextCaption: "다음에 복사하는 내용을 저장하지 않고, 그 뒤에는 다시 저장합니다.",
        universalClipboard: "유니버설 클립보드 건너뛰기",
        universalClipboardCaption: "다른 기기에서 도착한 복사본은 저장되지 않습니다."
    )

    static let zhHans = ClipboardSkipStrings(
        skipNext: "跳过下一次拷贝",
        skipNextCaption: "不保存下一次拷贝的内容，之后会继续保存。",
        universalClipboard: "跳过通用剪贴板",
        universalClipboardCaption: "来自其他设备的拷贝永远不会被保存。"
    )

    static let zhTW = ClipboardSkipStrings(
        skipNext: "略過下一次拷貝",
        skipNextCaption: "不儲存下一次拷貝的內容，之後會繼續儲存。",
        universalClipboard: "略過通用剪貼板",
        universalClipboardCaption: "來自其他裝置的拷貝永遠不會被儲存。"
    )

    static let zhHK = ClipboardSkipStrings(
        skipNext: "略過下一次拷貝",
        skipNextCaption: "不儲存下一次拷貝的內容，之後會繼續儲存。",
        universalClipboard: "略過通用剪貼板",
        universalClipboardCaption: "來自其他裝置的拷貝永遠不會被儲存。"
    )

    static let uk = ClipboardSkipStrings(
        skipNext: "Пропустити наступне копіювання",
        skipNextCaption: "Не зберігає наступну копію, потім запис поновлюється.",
        universalClipboard: "Пропускати універсальний буфер обміну",
        universalClipboardCaption: "Копії з іншого пристрою не зберігаються."
    )
}
