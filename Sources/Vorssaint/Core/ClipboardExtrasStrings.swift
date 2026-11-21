// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct ClipboardExtrasStrings {
    let clearAll: String
    let clearAllConfirm: String
    let checkInterval: String
    let checkIntervalCaption: String
}

extension FeatureStrings {
    static func clipboardExtras(_ language: AppLanguage) -> ClipboardExtrasStrings {
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

extension ClipboardExtrasStrings {
    static let enUS = ClipboardExtrasStrings(
        clearAll: "Clear everything, pinned too",
        clearAllConfirm: "Every saved entry goes, including the ones you pinned. This cannot be undone.",
        checkInterval: "Check the clipboard every",
        checkIntervalCaption: "How often the history looks for a new copy. Shorter is quicker to notice, longer uses less power."
    )

    static let ptBR = ClipboardExtrasStrings(
        clearAll: "Limpar tudo, inclusive fixados",
        clearAllConfirm: "Todos os itens guardados somem, incluindo os fixados. Não dá para desfazer.",
        checkInterval: "Verificar a área de transferência a cada",
        checkIntervalCaption: "Com que frequência o histórico procura uma nova cópia. Mais curto percebe antes, mais longo gasta menos energia."
    )

    static let tr = ClipboardExtrasStrings(
        clearAll: "Sabitlenenler dahil hepsini sil",
        clearAllConfirm: "Sabitledikleriniz dahil kayıtlı her şey silinir. Bu geri alınamaz.",
        checkInterval: "Panoyu şu sıklıkla denetle",
        checkIntervalCaption: "Geçmişin yeni bir kopyayı ne sıklıkla aradığı. Kısa süre daha çabuk fark eder, uzun süre daha az güç harcar."
    )

    static let ru = ClipboardExtrasStrings(
        clearAll: "Очистить всё, включая закреплённое",
        clearAllConfirm: "Удаляются все сохранённые записи, включая закреплённые. Отменить нельзя.",
        checkInterval: "Проверять буфер обмена каждые",
        checkIntervalCaption: "Как часто история ищет новую копию. Короче — быстрее замечает, длиннее — меньше расходует энергию."
    )

    static let es = ClipboardExtrasStrings(
        clearAll: "Borrar todo, incluidos los fijados",
        clearAllConfirm: "Se borran todas las entradas guardadas, incluidas las fijadas. No se puede deshacer.",
        checkInterval: "Revisar el portapapeles cada",
        checkIntervalCaption: "Con qué frecuencia el historial busca una copia nueva. Más corto avisa antes, más largo gasta menos energía."
    )

    static let sk = ClipboardExtrasStrings(
        clearAll: "Vymazať všetko vrátane pripnutých",
        clearAllConfirm: "Zmažú sa všetky uložené položky vrátane pripnutých. Nedá sa to vrátiť.",
        checkInterval: "Kontrolovať schránku každých",
        checkIntervalCaption: "Ako často história hľadá novú kópiu. Kratšie si všimne skôr, dlhšie spotrebuje menej energie."
    )

    static let de = ClipboardExtrasStrings(
        clearAll: "Alles löschen, auch Angeheftetes",
        clearAllConfirm: "Alle gespeicherten Einträge werden gelöscht, auch angeheftete. Das lässt sich nicht rückgängig machen.",
        checkInterval: "Zwischenablage prüfen alle",
        checkIntervalCaption: "Wie oft der Verlauf nach einer neuen Kopie sucht. Kürzer bemerkt es früher, länger braucht weniger Energie."
    )

    static let fr = ClipboardExtrasStrings(
        clearAll: "Tout effacer, épinglés compris",
        clearAllConfirm: "Toutes les entrées enregistrées disparaissent, y compris celles épinglées. Action irréversible.",
        checkInterval: "Vérifier le presse-papiers toutes les",
        checkIntervalCaption: "Fréquence à laquelle l’historique cherche une nouvelle copie. Plus court remarque plus tôt, plus long consomme moins."
    )

    static let it = ClipboardExtrasStrings(
        clearAll: "Cancella tutto, fissati compresi",
        clearAllConfirm: "Spariscono tutte le voci salvate, comprese quelle fissate. Non si può annullare.",
        checkInterval: "Controlla gli appunti ogni",
        checkIntervalCaption: "Ogni quanto la cronologia cerca una nuova copia. Più corto se ne accorge prima, più lungo consuma meno."
    )

    static let ja = ClipboardExtrasStrings(
        clearAll: "固定したものも含めてすべて消去",
        clearAllConfirm: "固定したものを含め、保存された項目がすべて消えます。元に戻せません。",
        checkInterval: "クリップボードを確認する間隔",
        checkIntervalCaption: "履歴が新しいコピーを探す頻度です。短いほど早く気づき、長いほど電力を節約します。"
    )

    static let ko = ClipboardExtrasStrings(
        clearAll: "고정한 항목까지 모두 지우기",
        clearAllConfirm: "고정한 항목을 포함해 저장된 모든 항목이 사라집니다. 되돌릴 수 없습니다.",
        checkInterval: "클립보드 확인 간격",
        checkIntervalCaption: "기록이 새 복사본을 찾는 빈도입니다. 짧을수록 빨리 알아채고, 길수록 전력을 덜 씁니다."
    )

    static let zhHans = ClipboardExtrasStrings(
        clearAll: "全部清除，包括已固定",
        clearAllConfirm: "所有保存的项目都会消失，包括已固定的项目。无法撤销。",
        checkInterval: "检查剪贴板的间隔",
        checkIntervalCaption: "历史记录查找新拷贝的频率。越短越快发现，越长越省电。"
    )

    static let zhTW = ClipboardExtrasStrings(
        clearAll: "全部清除，包括已固定",
        clearAllConfirm: "所有儲存的項目都會消失，包括已固定的項目。無法復原。",
        checkInterval: "檢查剪貼板的間隔",
        checkIntervalCaption: "歷史記錄尋找新拷貝的頻率。越短越快發現，越長越省電。"
    )

    static let zhHK = ClipboardExtrasStrings(
        clearAll: "全部清除，包括已固定",
        clearAllConfirm: "所有儲存的項目都會消失，包括已固定的項目。無法復原。",
        checkInterval: "檢查剪貼板的間隔",
        checkIntervalCaption: "歷史記錄尋找新拷貝的頻率。越短越快發現，越長越省電。"
    )

    static let uk = ClipboardExtrasStrings(
        clearAll: "Очистити все, включно із закріпленим",
        clearAllConfirm: "Видаляються всі збережені записи, включно із закріпленими. Скасувати не можна.",
        checkInterval: "Перевіряти буфер обміну кожні",
        checkIntervalCaption: "Як часто історія шукає нову копію. Коротше — швидше помічає, довше — менше витрачає енергії."
    )
}
