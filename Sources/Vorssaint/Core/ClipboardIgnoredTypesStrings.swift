// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct ClipboardIgnoredTypesStrings {
    let listTitle: String
    let addButton: String
    let removeButton: String
    let caption: String
}

extension FeatureStrings {
    static func clipboardIgnoredTypes(_ language: AppLanguage) -> ClipboardIgnoredTypesStrings {
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

extension ClipboardIgnoredTypesStrings {
    static let enUS = ClipboardIgnoredTypesStrings(
        listTitle: "Pasteboard types to skip",
        addButton: "Add a type…",
        removeButton: "Remove",
        caption: "Copies that carry one of these pasteboard types are never saved. Add com.apple.is-remote-clipboard to skip Universal Clipboard, or a type your password manager writes."
    )

    static let ptBR = ClipboardIgnoredTypesStrings(
        listTitle: "Tipos de área de transferência para pular",
        addButton: "Adicionar tipo…",
        removeButton: "Remover",
        caption: "Cópias que trazem um destes tipos nunca são guardadas. Adicione com.apple.is-remote-clipboard para pular a Área de Transferência Universal, ou o tipo que o seu gestor de senhas escreve."
    )

    static let tr = ClipboardIgnoredTypesStrings(
        listTitle: "Atlanacak pano türleri",
        addButton: "Tür ekle…",
        removeButton: "Kaldır",
        caption: "Bu türlerden birini taşıyan kopyalar asla kaydedilmez. Evrensel Pano’yu atlamak için com.apple.is-remote-clipboard ekleyin ya da parola yöneticinizin yazdığı türü ekleyin."
    )

    static let ru = ClipboardIgnoredTypesStrings(
        listTitle: "Типы буфера обмена без записи",
        addButton: "Добавить тип…",
        removeButton: "Удалить",
        caption: "Копии с любым из этих типов не сохраняются. Добавьте com.apple.is-remote-clipboard, чтобы пропускать универсальный буфер обмена, или тип, который пишет ваш менеджер паролей."
    )

    static let es = ClipboardIgnoredTypesStrings(
        listTitle: "Tipos de portapapeles que se saltan",
        addButton: "Añadir tipo…",
        removeButton: "Quitar",
        caption: "Las copias que llevan uno de estos tipos nunca se guardan. Añade com.apple.is-remote-clipboard para omitir el Portapapeles universal, o el tipo que escribe tu gestor de contraseñas."
    )

    static let sk = ClipboardIgnoredTypesStrings(
        listTitle: "Typy schránky bez záznamu",
        addButton: "Pridať typ…",
        removeButton: "Odstrániť",
        caption: "Kópie s niektorým z týchto typov sa nikdy neukladajú. Pridajte com.apple.is-remote-clipboard na preskočenie univerzálnej schránky alebo typ, ktorý zapisuje váš správca hesiel."
    )

    static let de = ClipboardIgnoredTypesStrings(
        listTitle: "Zu überspringende Pasteboard-Typen",
        addButton: "Typ hinzufügen…",
        removeButton: "Entfernen",
        caption: "Kopien mit einem dieser Typen werden nie gespeichert. Füge com.apple.is-remote-clipboard hinzu, um die Universal-Zwischenablage zu überspringen, oder den Typ, den dein Passwortmanager schreibt."
    )

    static let fr = ClipboardIgnoredTypesStrings(
        listTitle: "Types de presse-papiers à ignorer",
        addButton: "Ajouter un type…",
        removeButton: "Retirer",
        caption: "Les copies portant l’un de ces types ne sont jamais enregistrées. Ajoutez com.apple.is-remote-clipboard pour ignorer le presse-papiers universel, ou le type écrit par votre gestionnaire de mots de passe."
    )

    static let it = ClipboardIgnoredTypesStrings(
        listTitle: "Tipi di appunti da saltare",
        addButton: "Aggiungi un tipo…",
        removeButton: "Rimuovi",
        caption: "Le copie con uno di questi tipi non vengono mai salvate. Aggiungi com.apple.is-remote-clipboard per saltare gli Appunti universali, o il tipo scritto dal tuo gestore di password."
    )

    static let ja = ClipboardIgnoredTypesStrings(
        listTitle: "除外するペーストボードタイプ",
        addButton: "タイプを追加…",
        removeButton: "削除",
        caption: "これらのタイプを持つコピーは保存されません。ユニバーサルクリップボードを除外するには com.apple.is-remote-clipboard を、パスワード管理アプリが書き込むタイプを追加してください。"
    )

    static let ko = ClipboardIgnoredTypesStrings(
        listTitle: "건너뛸 페이스트보드 유형",
        addButton: "유형 추가…",
        removeButton: "제거",
        caption: "이러한 유형이 있는 복사본은 저장되지 않습니다. 유니버설 클립보드를 건너뛰려면 com.apple.is-remote-clipboard를, 암호 관리자가 쓰는 유형을 추가하세요."
    )

    static let zhHans = ClipboardIgnoredTypesStrings(
        listTitle: "要跳过的剪贴板类型",
        addButton: "添加类型…",
        removeButton: "移除",
        caption: "带有这些类型的副本永远不会被保存。添加 com.apple.is-remote-clipboard 可跳过通用剪贴板，或添加你的密码管理器写入的类型。"
    )

    static let zhTW = ClipboardIgnoredTypesStrings(
        listTitle: "要略過的剪貼板類型",
        addButton: "加入類型…",
        removeButton: "移除",
        caption: "帶有這些類型的拷貝永遠不會被儲存。加入 com.apple.is-remote-clipboard 可略過通用剪貼板，或加入你的密碼管理器寫入的類型。"
    )

    static let zhHK = ClipboardIgnoredTypesStrings(
        listTitle: "要略過的剪貼板類型",
        addButton: "加入類型…",
        removeButton: "移除",
        caption: "帶有這些類型的拷貝永遠不會被儲存。加入 com.apple.is-remote-clipboard 可略過通用剪貼板，或加入你的密碼管理器寫入的類型。"
    )

    static let uk = ClipboardIgnoredTypesStrings(
        listTitle: "Типи буфера обміну без запису",
        addButton: "Додати тип…",
        removeButton: "Видалити",
        caption: "Копії з будь-яким із цих типів не зберігаються. Додайте com.apple.is-remote-clipboard, щоб пропускати універсальний буфер обміну, або тип, який записує ваш менеджер паролів."
    )
}
