// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The AI page's OpenCode Go key surface: adding, removing and reading the
/// health of the keys the notch accounts per provider request. Product names
/// stay untranslated, as elsewhere in the agents section.
struct AgentKeyStrings {
    let title: String
    let explanation: String
    let labelPlaceholder: String
    let secretPlaceholder: String
    let add: String
    let remove: String
    let reset: String
    let emptyHint: String
    let secretTooShort: String
    let saveFailed: String
    /// Tokens and requests for one key; both arguments are already formatted.
    let usageFormat: String
    let healthReady: String
    let healthRateLimited: String
    let healthInvalid: String
    let healthExhausted: String

    func usage(tokens: String, requests: String) -> String {
        String(format: usageFormat, tokens, requests)
    }

    func health(_ health: AgentKeyHealth) -> String {
        switch health {
        case .ready: return healthReady
        case .rateLimited: return healthRateLimited
        case .invalid: return healthInvalid
        case .exhausted: return healthExhausted
        }
    }

    func message(_ error: AgentKeyProvisioningError) -> String {
        switch error {
        case .secretTooShort: return secretTooShort
        case .saveFailed: return saveFailed
        }
    }
}

extension FeatureStrings {
    static func agentKeys(_ language: AppLanguage) -> AgentKeyStrings {
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
        case .uk: return .uk
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        }
    }
}

extension AgentKeyStrings {
    static let enUS = AgentKeyStrings(
        title: "OpenCode Go keys",
        explanation: "Keys are kept in your login keychain, never on disk, and only their last four characters are ever shown. The AI page lists each key with its health and usage.",
        labelPlaceholder: "Name (optional)",
        secretPlaceholder: "Paste a key",
        add: "Add key",
        remove: "Remove this key",
        reset: "Allow again",
        emptyHint: "No key saved yet.",
        secretTooShort: "That key is too short to be an OpenCode Go key.",
        saveFailed: "The keychain could not save this key.",
        usageFormat: "%1$@ tokens · %2$@ requests",
        healthReady: "Ready",
        healthRateLimited: "Rate limited",
        healthInvalid: "Rejected",
        healthExhausted: "Out of credit")

    static let ptBR = AgentKeyStrings(
        title: "Chaves do OpenCode Go",
        explanation: "As chaves ficam no seu chaveiro de login, nunca no disco, e apenas os últimos quatro caracteres aparecem. A página dos agentes lista cada chave com sua saúde e uso.",
        labelPlaceholder: "Nome (opcional)",
        secretPlaceholder: "Cole uma chave",
        add: "Adicionar chave",
        remove: "Remover esta chave",
        reset: "Permitir de novo",
        emptyHint: "Nenhuma chave salva ainda.",
        secretTooShort: "Essa chave é curta demais para ser uma chave do OpenCode Go.",
        saveFailed: "O chaveiro não conseguiu salvar esta chave.",
        usageFormat: "%1$@ tokens · %2$@ solicitações",
        healthReady: "Pronta",
        healthRateLimited: "Limitada",
        healthInvalid: "Rejeitada",
        healthExhausted: "Sem crédito")

    static let tr = AgentKeyStrings(
        title: "OpenCode Go anahtarları",
        explanation: "Anahtarlar diskte değil, oturum açma anahtarlığınızda durur ve yalnızca son dört karakteri görünür. Ajanlar sayfası her anahtarı durumu ve kullanımıyla listeler.",
        labelPlaceholder: "Ad (isteğe bağlı)",
        secretPlaceholder: "Bir anahtar yapıştırın",
        add: "Anahtar ekle",
        remove: "Bu anahtarı kaldır",
        reset: "Yeniden izin ver",
        emptyHint: "Henüz kayıtlı anahtar yok.",
        secretTooShort: "Bu anahtar OpenCode Go anahtarı olamayacak kadar kısa.",
        saveFailed: "Anahtarlık bu anahtarı kaydedemedi.",
        usageFormat: "%1$@ jeton · %2$@ istek",
        healthReady: "Hazır",
        healthRateLimited: "Sınırlandı",
        healthInvalid: "Reddedildi",
        healthExhausted: "Kredi bitti")

    static let ru = AgentKeyStrings(
        title: "Ключи OpenCode Go",
        explanation: "Ключи хранятся в связке ключей входа, а не на диске, и видны только последние четыре символа. Страница агентов перечисляет каждый ключ с его состоянием и расходом.",
        labelPlaceholder: "Название (необязательно)",
        secretPlaceholder: "Вставьте ключ",
        add: "Добавить ключ",
        remove: "Удалить этот ключ",
        reset: "Снова разрешить",
        emptyHint: "Сохранённых ключей пока нет.",
        secretTooShort: "Этот ключ слишком короткий для ключа OpenCode Go.",
        saveFailed: "Связка ключей не смогла сохранить этот ключ.",
        usageFormat: "%1$@ токенов · %2$@ запросов",
        healthReady: "Готов",
        healthRateLimited: "Ограничен",
        healthInvalid: "Отклонён",
        healthExhausted: "Нет кредита")

    static let es = AgentKeyStrings(
        title: "Claves de OpenCode Go",
        explanation: "Las claves se guardan en tu llavero de inicio de sesión, nunca en el disco, y solo se muestran sus últimos cuatro caracteres. La página de agentes muestra cada clave con su estado y uso.",
        labelPlaceholder: "Nombre (opcional)",
        secretPlaceholder: "Pega una clave",
        add: "Añadir clave",
        remove: "Quitar esta clave",
        reset: "Permitir de nuevo",
        emptyHint: "Aún no hay ninguna clave guardada.",
        secretTooShort: "Esa clave es demasiado corta para ser una clave de OpenCode Go.",
        saveFailed: "El llavero no pudo guardar esta clave.",
        usageFormat: "%1$@ tokens · %2$@ solicitudes",
        healthReady: "Lista",
        healthRateLimited: "Limitada",
        healthInvalid: "Rechazada",
        healthExhausted: "Sin crédito")

    static let sk = AgentKeyStrings(
        title: "Kľúče OpenCode Go",
        explanation: "Kľúče sa ukladajú do kľúčenky, nie na disk, a zobrazujú sa iba ich posledné štyri znaky. Stránka agentov uvádza každý kľúč s jeho stavom a spotrebou.",
        labelPlaceholder: "Názov (voliteľné)",
        secretPlaceholder: "Vložte kľúč",
        add: "Pridať kľúč",
        remove: "Odstrániť tento kľúč",
        reset: "Znova povoliť",
        emptyHint: "Zatiaľ nie je uložený žiadny kľúč.",
        secretTooShort: "Tento kľúč je príliš krátky na kľúč OpenCode Go.",
        saveFailed: "Kľúčenka nedokázala uložiť tento kľúč.",
        usageFormat: "%1$@ tokenov · %2$@ požiadaviek",
        healthReady: "Pripravený",
        healthRateLimited: "Obmedzený",
        healthInvalid: "Odmietnutý",
        healthExhausted: "Bez kreditu")

    static let de = AgentKeyStrings(
        title: "OpenCode-Go-Schlüssel",
        explanation: "Schlüssel liegen im Anmeldeschlüsselbund, nicht auf der Festplatte, und nur die letzten vier Zeichen werden angezeigt. Die Agentenseite führt jeden Schlüssel mit Zustand und Verbrauch auf.",
        labelPlaceholder: "Name (optional)",
        secretPlaceholder: "Schlüssel einfügen",
        add: "Schlüssel hinzufügen",
        remove: "Diesen Schlüssel entfernen",
        reset: "Wieder zulassen",
        emptyHint: "Noch kein Schlüssel gespeichert.",
        secretTooShort: "Dieser Schlüssel ist zu kurz für einen OpenCode-Go-Schlüssel.",
        saveFailed: "Der Schlüsselbund konnte diesen Schlüssel nicht sichern.",
        usageFormat: "%1$@ Token · %2$@ Anfragen",
        healthReady: "Bereit",
        healthRateLimited: "Begrenzt",
        healthInvalid: "Abgelehnt",
        healthExhausted: "Kein Guthaben")

    static let fr = AgentKeyStrings(
        title: "Clés OpenCode Go",
        explanation: "Les clés sont conservées dans votre trousseau de connexion, jamais sur le disque, et seuls leurs quatre derniers caractères sont affichés. La page des agents liste chaque clé avec son état et son usage.",
        labelPlaceholder: "Nom (facultatif)",
        secretPlaceholder: "Collez une clé",
        add: "Ajouter une clé",
        remove: "Supprimer cette clé",
        reset: "Autoriser de nouveau",
        emptyHint: "Aucune clé enregistrée pour l’instant.",
        secretTooShort: "Cette clé est trop courte pour être une clé OpenCode Go.",
        saveFailed: "Le trousseau n’a pas pu enregistrer cette clé.",
        usageFormat: "%1$@ jetons · %2$@ requêtes",
        healthReady: "Prête",
        healthRateLimited: "Limitée",
        healthInvalid: "Refusée",
        healthExhausted: "Sans crédit")

    static let it = AgentKeyStrings(
        title: "Chiavi OpenCode Go",
        explanation: "Le chiavi sono conservate nel portachiavi di accesso, mai su disco, e solo gli ultimi quattro caratteri sono visibili. La pagina degli agenti elenca ogni chiave con stato e utilizzo.",
        labelPlaceholder: "Nome (facoltativo)",
        secretPlaceholder: "Incolla una chiave",
        add: "Aggiungi chiave",
        remove: "Rimuovi questa chiave",
        reset: "Consenti di nuovo",
        emptyHint: "Nessuna chiave salvata.",
        secretTooShort: "Questa chiave è troppo corta per essere una chiave OpenCode Go.",
        saveFailed: "Il portachiavi non ha potuto salvare questa chiave.",
        usageFormat: "%1$@ token · %2$@ richieste",
        healthReady: "Pronta",
        healthRateLimited: "Limitata",
        healthInvalid: "Rifiutata",
        healthExhausted: "Senza credito")

    static let ja = AgentKeyStrings(
        title: "OpenCode Go のキー",
        explanation: "キーはディスクではなくログイン用キーチェーンに保存され、末尾4文字だけが表示されます。エージェントページに各キーの状態と使用量が並びます。",
        labelPlaceholder: "名前（任意）",
        secretPlaceholder: "キーを貼り付け",
        add: "キーを追加",
        remove: "このキーを削除",
        reset: "再び許可",
        emptyHint: "保存されたキーはまだありません。",
        secretTooShort: "このキーは OpenCode Go のキーとしては短すぎます。",
        saveFailed: "キーチェーンにこのキーを保存できませんでした。",
        usageFormat: "%1$@ トークン · %2$@ リクエスト",
        healthReady: "使用可能",
        healthRateLimited: "制限中",
        healthInvalid: "拒否",
        healthExhausted: "残高なし")

    static let ko = AgentKeyStrings(
        title: "OpenCode Go 키",
        explanation: "키는 디스크가 아니라 로그인 키체인에 보관되며 마지막 네 글자만 표시됩니다. 에이전트 페이지에 각 키의 상태와 사용량이 나열됩니다.",
        labelPlaceholder: "이름(선택)",
        secretPlaceholder: "키 붙여넣기",
        add: "키 추가",
        remove: "이 키 제거",
        reset: "다시 허용",
        emptyHint: "저장된 키가 없습니다.",
        secretTooShort: "이 키는 OpenCode Go 키로 쓰기에는 너무 짧습니다.",
        saveFailed: "키체인에 이 키를 저장하지 못했습니다.",
        usageFormat: "%1$@ 토큰 · %2$@ 요청",
        healthReady: "준비됨",
        healthRateLimited: "제한됨",
        healthInvalid: "거부됨",
        healthExhausted: "크레딧 없음")

    static let uk = AgentKeyStrings(
        title: "Ключі OpenCode Go",
        explanation: "Ключі зберігаються в ключниці входу, а не на диску, і видно лише останні чотири символи. Сторінка агентів показує кожен ключ, його стан і витрати.",
        labelPlaceholder: "Назва (необов’язково)",
        secretPlaceholder: "Вставте ключ",
        add: "Додати ключ",
        remove: "Вилучити цей ключ",
        reset: "Знову дозволити",
        emptyHint: "Збережених ключів ще немає.",
        secretTooShort: "Цей ключ занадто короткий для ключа OpenCode Go.",
        saveFailed: "Ключниця не змогла зберегти цей ключ.",
        usageFormat: "%1$@ токенів · %2$@ запитів",
        healthReady: "Готовий",
        healthRateLimited: "Обмежений",
        healthInvalid: "Відхилений",
        healthExhausted: "Немає кредиту")

    static let zhHans = AgentKeyStrings(
        title: "OpenCode Go 密钥",
        explanation: "密钥保存在登录钥匙串中，而不是磁盘上，并且只显示最后四个字符。智能体页面会列出每个密钥的状态和用量。",
        labelPlaceholder: "名称（可选）",
        secretPlaceholder: "粘贴密钥",
        add: "添加密钥",
        remove: "移除此密钥",
        reset: "重新允许",
        emptyHint: "尚未保存任何密钥。",
        secretTooShort: "该密钥过短，不能作为 OpenCode Go 密钥。",
        saveFailed: "钥匙串无法保存此密钥。",
        usageFormat: "%1$@ 个令牌 · %2$@ 次请求",
        healthReady: "就绪",
        healthRateLimited: "受限",
        healthInvalid: "已拒绝",
        healthExhausted: "额度用尽")

    static let zhTW = AgentKeyStrings(
        title: "OpenCode Go 金鑰",
        explanation: "金鑰儲存在登入鑰匙圈中，而非磁碟上，且只會顯示最後四個字元。代理程式頁面會列出每個金鑰的狀態與用量。",
        labelPlaceholder: "名稱（選填）",
        secretPlaceholder: "貼上金鑰",
        add: "加入金鑰",
        remove: "移除此金鑰",
        reset: "再次允許",
        emptyHint: "尚未儲存任何金鑰。",
        secretTooShort: "此金鑰太短，無法作為 OpenCode Go 金鑰。",
        saveFailed: "鑰匙圈無法儲存此金鑰。",
        usageFormat: "%1$@ 個權杖 · %2$@ 次要求",
        healthReady: "就緒",
        healthRateLimited: "受限",
        healthInvalid: "已拒絕",
        healthExhausted: "額度用盡")

    static let zhHK = AgentKeyStrings(
        title: "OpenCode Go 金鑰",
        explanation: "金鑰存放於登入鑰匙圈，而非磁碟，只會顯示最後四個字元。代理程式頁面會列出每個金鑰的狀態與用量。",
        labelPlaceholder: "名稱（可選）",
        secretPlaceholder: "貼上金鑰",
        add: "新增金鑰",
        remove: "移除這個金鑰",
        reset: "再次允許",
        emptyHint: "尚未儲存任何金鑰。",
        secretTooShort: "此金鑰太短，不能作為 OpenCode Go 金鑰。",
        saveFailed: "鑰匙圈無法儲存此金鑰。",
        usageFormat: "%1$@ 權杖 · %2$@ 請求",
        healthReady: "就緒",
        healthRateLimited: "受限",
        healthInvalid: "已拒絕",
        healthExhausted: "額度用盡")
}
