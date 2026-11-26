// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The placement picker in Clipboard settings. One label and one line per
/// choice, so a person can tell "next to the pointer" from "bottom of the
/// screen" without opening the window to find out.
struct ClipboardPlacementStrings {
    let title: String
    let nearCursor: String
    let nearCursorCaption: String
    let remembered: String
    let rememberedCaption: String
    let bottomOfScreen: String
    let bottomOfScreenCaption: String
    let topCenter: String
    let topCenterCaption: String
    let island: String
    let islandCaption: String
    /// The line under the picker while the cards layout is selected: that
    /// layout places itself, so the choice in hand is not what opens.
    let cardsCaption: String

    func label(for placement: ClipboardSurfacePlacement) -> String {
        switch placement {
        case .nearCursor: return nearCursor
        case .remembered: return remembered
        case .bottomOfScreen: return bottomOfScreen
        case .topCenter: return topCenter
        case .dynamicIsland: return island
        }
    }

    /// The line under the picker for the choice in hand, not for every choice
    /// at once: the explanation has to describe what the window will actually
    /// do next time it opens.
    func caption(for placement: ClipboardSurfacePlacement) -> String {
        switch placement {
        case .nearCursor: return nearCursorCaption
        case .remembered: return rememberedCaption
        case .bottomOfScreen: return bottomOfScreenCaption
        case .topCenter: return topCenterCaption
        case .dynamicIsland: return islandCaption
        }
    }

    /// The line under the picker. A layout that places the window itself
    /// takes the caption away from the choice, because the choice is not what
    /// the next opening will do.
    func caption(for placement: ClipboardSurfacePlacement, cardsLayout: Bool) -> String {
        guard !Self.placementIsFixed(cardsLayout: cardsLayout, placement: placement) else {
            return cardsCaption
        }
        return self.caption(for: placement)
    }

    /// Whether the picker has nothing to offer in this layout. The cards shelf
    /// places itself along the bottom, so a window placement cannot apply
    /// there; the island is not a place on a display, so choosing it still
    /// means something in either layout.
    static func placementIsFixed(cardsLayout: Bool,
                                placement: ClipboardSurfacePlacement) -> Bool {
        cardsLayout && placement != .dynamicIsland
    }
}

extension FeatureStrings {
    static func clipboardPlacement(_ language: AppLanguage) -> ClipboardPlacementStrings {
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

extension ClipboardPlacementStrings {
    static let enUS = ClipboardPlacementStrings(
        title: "Placement",
        nearCursor: "Next to the pointer",
        nearCursorCaption: "Opens beside the pointer, on the display it is on.",
        remembered: "Wherever it was last",
        rememberedCaption: "Keeps the place you left the window in. With the island’s clipboard on, it opens there instead.",
        bottomOfScreen: "Bottom of the screen",
        bottomOfScreenCaption: "Sits along the bottom edge of the display the pointer is on.",
        topCenter: "Top center",
        topCenterCaption: "Opens centered under the menu bar of the display the pointer is on.",
        island: "Dynamic Island",
        islandCaption: "Uses the island’s clipboard page. Needs the island on and showing Clipboard.",
        cardsCaption: "The Cards layout sits along the bottom of the screen, so a placement is not used. Choose List to pick a place."
    )

    static let ptBR = ClipboardPlacementStrings(
        title: "Posição",
        nearCursor: "Perto do ponteiro",
        nearCursorCaption: "Abre ao lado do ponteiro, na tela em que ele está.",
        remembered: "Onde estava por último",
        rememberedCaption: "Mantém o lugar onde você deixou a janela. Com a área de transferência da ilha ativa, abre lá.",
        bottomOfScreen: "Parte inferior da tela",
        bottomOfScreenCaption: "Fica na borda inferior da tela em que o ponteiro está.",
        topCenter: "Centro superior",
        topCenterCaption: "Abre centralizada sob a barra de menus da tela em que o ponteiro está.",
        island: "Dynamic Island",
        islandCaption: "Usa a página de área de transferência da ilha. Exige a ilha ativa e o módulo Área de transferência.",
        cardsCaption: "O layout Cartões fica na parte inferior da tela, então a posição não é usada. Escolha Lista para escolher um lugar."
    )

    static let tr = ClipboardPlacementStrings(
        title: "Konum",
        nearCursor: "İmlecin yanında",
        nearCursorCaption: "İmlecin bulunduğu ekranda, imlecin yanında açılır.",
        remembered: "Son kaldığı yer",
        rememberedCaption: "Pencereyi bıraktığınız yeri korur. Dynamic Island panosu açıksa orada açılır.",
        bottomOfScreen: "Ekranın altı",
        bottomOfScreenCaption: "İmlecin bulunduğu ekranın alt kenarına yerleşir.",
        topCenter: "Üst orta",
        topCenterCaption: "İmlecin bulunduğu ekranın menü çubuğunun altında ortalanır.",
        island: "Dynamic Island",
        islandCaption: "Dynamic Island’ın pano sayfasını kullanır. Dynamic Island açık ve Pano modülü görünür olmalı.",
        cardsCaption: "Kartlar düzeni ekranın alt kısmında durur, bu yüzden konum kullanılmaz. Bir yer seçmek için Liste’yi seçin."
    )

    static let ru = ClipboardPlacementStrings(
        title: "Размещение",
        nearCursor: "Рядом с указателем",
        nearCursorCaption: "Открывается рядом с указателем на том экране, где он находится.",
        remembered: "Там, где было",
        rememberedCaption: "Сохраняет место, где вы оставили окно. Если буфер обмена в острове включён, окно открывается там.",
        bottomOfScreen: "Низ экрана",
        bottomOfScreenCaption: "Располагается у нижнего края экрана, на котором находится указатель.",
        topCenter: "Сверху по центру",
        topCenterCaption: "Открывается по центру под строкой меню экрана, на котором находится указатель.",
        island: "Dynamic Island",
        islandCaption: "Использует страницу буфера обмена в острове. Нужно включить остров и модуль «Буфер обмена».",
        cardsCaption: "Макет «Карточки» расположен у нижнего края экрана, поэтому размещение не используется. Выберите «Список», чтобы задать место."
    )

    static let es = ClipboardPlacementStrings(
        title: "Ubicación",
        nearCursor: "Junto al puntero",
        nearCursorCaption: "Se abre junto al puntero, en la pantalla donde está.",
        remembered: "Donde estaba la última vez",
        rememberedCaption: "Mantiene el lugar donde dejaste la ventana. Con el portapapeles de la isla activo, se abre allí.",
        bottomOfScreen: "Parte inferior de la pantalla",
        bottomOfScreenCaption: "Se sitúa en el borde inferior de la pantalla donde está el puntero.",
        topCenter: "Centro superior",
        topCenterCaption: "Se abre centrada bajo la barra de menús de la pantalla donde está el puntero.",
        island: "Dynamic Island",
        islandCaption: "Usa la página de portapapeles de la isla. Requiere la isla activa y el módulo Portapapeles.",
        cardsCaption: "La vista Tarjetas se coloca en la parte inferior, así que la posición no se usa. Elige Lista para elegir un lugar."
    )

    static let sk = ClipboardPlacementStrings(
        title: "Umiestnenie",
        nearCursor: "Pri ukazovateli",
        nearCursorCaption: "Otvorí sa vedľa ukazovateľa na obrazovke, na ktorej je.",
        remembered: "Tam, kde bolo naposledy",
        rememberedCaption: "Zachová miesto, v ktorom ste okno nechali. Keď je schránka v ostrove zapnutá, otvorí sa tam.",
        bottomOfScreen: "Spodok obrazovky",
        bottomOfScreenCaption: "Usadí sa pri spodnom okraji obrazovky, na ktorej je ukazovateľ.",
        topCenter: "Hore v strede",
        topCenterCaption: "Otvorí sa vycentrované pod lištou ponuky obrazovky, na ktorej je ukazovateľ.",
        island: "Dynamic Island",
        islandCaption: "Použije stránku schránky v ostrove. Vyžaduje zapnutý ostrov s modulom Schránka.",
        cardsCaption: "Rozloženie Karty je naspodku obrazovky, preto sa poloha nepoužije. Miesto vyberiete v rozložení Zoznam."
    )

    static let de = ClipboardPlacementStrings(
        title: "Platzierung",
        nearCursor: "Neben dem Zeiger",
        nearCursorCaption: "Öffnet neben dem Zeiger auf dem Bildschirm, auf dem er sich befindet.",
        remembered: "Wo es zuletzt war",
        rememberedCaption: "Behält die Stelle, an der du das Fenster gelassen hast. Ist die Zwischenablage der Insel an, öffnet es dort.",
        bottomOfScreen: "Unten am Bildschirm",
        bottomOfScreenCaption: "Liegt am unteren Rand des Bildschirms, auf dem der Zeiger ist.",
        topCenter: "Oben mittig",
        topCenterCaption: "Öffnet mittig unter der Menüleiste des Bildschirms, auf dem der Zeiger ist.",
        island: "Dynamic Island",
        islandCaption: "Nutzt die Zwischenablage-Seite der Insel. Die Insel muss an sein und Zwischenablage zeigen.",
        cardsCaption: "Die Ansicht „Karten“ sitzt unten am Bildschirm, deshalb wird die Platzierung nicht verwendet. Wähle „Liste“ für einen Platz."
    )

    static let fr = ClipboardPlacementStrings(
        title: "Emplacement",
        nearCursor: "Près du pointeur",
        nearCursorCaption: "S’ouvre à côté du pointeur, sur l’écran où il se trouve.",
        remembered: "Là où il était",
        rememberedCaption: "Conserve l’endroit où vous avez laissé la fenêtre. Si le presse-papiers de l’îlot est actif, elle s’ouvre là.",
        bottomOfScreen: "Bas de l’écran",
        bottomOfScreenCaption: "Se place au bord inférieur de l’écran où se trouve le pointeur.",
        topCenter: "Haut centré",
        topCenterCaption: "S’ouvre centré sous la barre des menus de l’écran où se trouve le pointeur.",
        island: "Dynamic Island",
        islandCaption: "Utilise la page presse-papiers de l’îlot. Nécessite l’îlot actif avec le module Presse-papiers.",
        cardsCaption: "La vue Cartes se place en bas de l’écran, la position n’y est donc pas utilisée. Choisissez Liste pour un emplacement."
    )

    static let it = ClipboardPlacementStrings(
        title: "Posizione",
        nearCursor: "Accanto al puntatore",
        nearCursorCaption: "Si apre accanto al puntatore, sullo schermo in cui si trova.",
        remembered: "Dove era l’ultima volta",
        rememberedCaption: "Mantiene il punto in cui hai lasciato la finestra. Con gli appunti dell’isola attivi, si apre lì.",
        bottomOfScreen: "In fondo allo schermo",
        bottomOfScreenCaption: "Si colloca sul bordo inferiore dello schermo in cui si trova il puntatore.",
        topCenter: "In alto al centro",
        topCenterCaption: "Si apre centrata sotto la barra dei menu dello schermo in cui si trova il puntatore.",
        island: "Dynamic Island",
        islandCaption: "Usa la pagina appunti dell’isola. Richiede l’isola attiva con il modulo Appunti.",
        cardsCaption: "La vista Schede sta in fondo allo schermo, quindi la posizione non viene usata. Scegli Elenco per scegliere un punto."
    )

    static let ja = ClipboardPlacementStrings(
        title: "表示位置",
        nearCursor: "ポインタの近く",
        nearCursorCaption: "ポインタがある画面で、ポインタの隣に開きます。",
        remembered: "前回の位置",
        rememberedCaption: "ウィンドウを置いた場所を保ちます。アイランドのクリップボードがオンのときは、そちらで開きます。",
        bottomOfScreen: "画面の下部",
        bottomOfScreenCaption: "ポインタがある画面の下端に沿って表示します。",
        topCenter: "上部中央",
        topCenterCaption: "ポインタがある画面のメニューバーの下、中央に開きます。",
        island: "Dynamic Island",
        islandCaption: "アイランドのクリップボードページを使います。アイランドがオンで、クリップボードを表示している必要があります。",
        cardsCaption: "カード表示は画面下部に固定されるため、配置は使われません。場所を選ぶにはリストに切り替えてください。"
    )

    static let ko = ClipboardPlacementStrings(
        title: "위치",
        nearCursor: "포인터 근처",
        nearCursorCaption: "포인터가 있는 화면에서 포인터 옆에 열립니다.",
        remembered: "마지막 위치",
        rememberedCaption: "창을 두었던 자리를 유지합니다. 아일랜드 클립보드가 켜져 있으면 그곳에서 열립니다.",
        bottomOfScreen: "화면 아래",
        bottomOfScreenCaption: "포인터가 있는 화면의 아래쪽 가장자리에 놓입니다.",
        topCenter: "상단 중앙",
        topCenterCaption: "포인터가 있는 화면의 메뉴 막대 아래 중앙에 열립니다.",
        island: "Dynamic Island",
        islandCaption: "아일랜드의 클립보드 페이지를 사용합니다. 아일랜드가 켜져 있고 클립보드를 표시해야 합니다.",
        cardsCaption: "카드 보기는 화면 아래쪽에 고정되므로 배치가 사용되지 않습니다. 위치를 선택하려면 목록으로 전환하세요."
    )

    static let zhHans = ClipboardPlacementStrings(
        title: "位置",
        nearCursor: "指针附近",
        nearCursorCaption: "在指针所在的屏幕上，紧靠指针打开。",
        remembered: "上次的位置",
        rememberedCaption: "保留你上次放置窗口的位置。开启岛屿剪贴板时，改为在岛屿中打开。",
        bottomOfScreen: "屏幕底部",
        bottomOfScreenCaption: "沿指针所在屏幕的下边缘显示。",
        topCenter: "顶部居中",
        topCenterCaption: "在指针所在屏幕的菜单栏下方居中打开。",
        island: "Dynamic Island",
        islandCaption: "使用岛屿的剪贴板页面。需要开启岛屿并显示剪贴板。",
        cardsCaption: "卡片视图固定在屏幕底部，因此不会使用所选位置。要选择位置，请切换到列表。"
    )

    static let zhTW = ClipboardPlacementStrings(
        title: "位置",
        nearCursor: "指標附近",
        nearCursorCaption: "在指標所在的螢幕上，緊鄰指標開啟。",
        remembered: "上次的位置",
        rememberedCaption: "保留你上次放置視窗的位置。開啟島嶼剪貼簿時，改在島嶼中開啟。",
        bottomOfScreen: "螢幕底部",
        bottomOfScreenCaption: "沿指標所在螢幕的下緣顯示。",
        topCenter: "頂部置中",
        topCenterCaption: "在指標所在螢幕的選單列下置中開啟。",
        island: "Dynamic Island",
        islandCaption: "使用島嶼的剪貼簿頁面。需要開啟島嶼並顯示剪貼簿。",
        cardsCaption: "卡片檢視固定在螢幕底部，因此不會使用所選位置。要選擇位置，請切換到列表。"
    )

    static let zhHK = ClipboardPlacementStrings(
        title: "位置",
        nearCursor: "指標附近",
        nearCursorCaption: "喺指標所在嘅螢幕上，貼近指標開啟。",
        remembered: "上次嘅位置",
        rememberedCaption: "保留你上次放置視窗嘅位置。開啟島嶼剪貼簿時，改為喺島嶼開啟。",
        bottomOfScreen: "螢幕底部",
        bottomOfScreenCaption: "沿指標所在螢幕嘅下緣顯示。",
        topCenter: "頂部置中",
        topCenterCaption: "喺指標所在螢幕嘅選單列下置中開啟。",
        island: "Dynamic Island",
        islandCaption: "使用島嶼嘅剪貼簿頁面。需要開啟島嶼並顯示剪貼簿。",
        cardsCaption: "卡片檢視固定在螢幕底部，因此不會使用所選位置。要選擇位置，請切換到列表。"
    )

    static let uk = ClipboardPlacementStrings(
        title: "Розміщення",
        nearCursor: "Біля вказівника",
        nearCursorCaption: "Відкривається поруч із вказівником на тому екрані, де він перебуває.",
        remembered: "Там, де було",
        rememberedCaption: "Зберігає місце, де ви залишили вікно. Якщо буфер обміну в острові ввімкнено, вікно відкривається там.",
        bottomOfScreen: "Низ екрана",
        bottomOfScreenCaption: "Розміщується біля нижнього краю екрана, на якому перебуває вказівник.",
        topCenter: "Угорі по центру",
        topCenterCaption: "Відкривається по центру під рядком меню екрана, на якому перебуває вказівник.",
        island: "Dynamic Island",
        islandCaption: "Використовує сторінку буфера обміну в острові. Потрібно ввімкнути острів і модуль «Буфер обміну».",
        cardsCaption: "Макет «Картки» розташований унизу екрана, тому розміщення не використовується. Виберіть «Список», щоб задати місце."
    )
}
