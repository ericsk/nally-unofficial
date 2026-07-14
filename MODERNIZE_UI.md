# Nally Modernize UI Branch (`modernize-ui`)

這個分支的主要目標是將 Nally 專案中舊型的 macOS UI 架構（基於 Nib/XIB、過時的 Objective-C 繪圖 API 與 Cocoa 元件）現代化，逐步改用 **Swift** 與 **SwiftUI** 來重建核心渲染迴圈與使用者介面。

---

## 🎯 核心工作目標

1. **核心資料模型現代化 (Phase 1) - 已完成**
   - 將全域設定及站台設定 (`YLLGlobalConfig`、`YLSite`) 改寫為 Swift，並採用現代的 `@Observable` 設計以簡化資料流與 UI 的連動。
2. **偏好設定與站台管理面板 SwiftUI 改寫 (Phase 2) - 已完成**
   - 以 SwiftUI 重建偏好設定視窗 (`PreferencesView`) 與站台管理員 (`SitesView`)，取代原先複雜的 Cocoa 視窗控制器，提升設定介面的易用度與外觀。
3. **App 進入點與工具列現代化 (Phase 3) - 已完成**
   - 移轉 AppDelegate 進入點，並以程式化委派 (`NallyToolbarDelegate`) 與自訂工具列項目替換 MainMenu 內的 Nib 控制器，提供更具彈性且高整合性的主介面。
4. **終端機渲染核心與 SwiftUI 橋接 (Phase 4) - 已完成**
   - **分頁控制與視圖排版整合**：移除 `MainMenu.xib` 內的終端機視圖與分頁元件，採用 `NSViewRepresentable` 進行 SwiftUI (`MainContentView`) 橋接。
   - **文字與圖形渲染現代化**：將原本 `YLView.mm` 內雙位元組中文字、ANSI 色彩、框線及特殊區塊字元（如三角塊等）的底層 CoreGraphics/CoreText 渲染引擎完全用 Swift (`YLViewDrawing.swift`) 重寫，大幅提升 GPU 加速的效能。
   - **輸入法 Marked Text 現代化**：以 Swift 重寫 IME 文字輸入視圖 `YLMarkedTextView`，提供穩定的 Marked Text 繪製與輸入法高度相容。
   - **圖片預覽 HUD 面板現代化**：用 `URLSession` + SwiftUI HUD 視窗重新實作 `YLImagePreviewer` 與 `ImagePreviewerView`，去除過時的 `NSURLConnection` 與手動 EXIF 剖析。
5. **底層核心邏輯、網路協定與完全 Swift 化 (Phase 5 - 已完成)**
   - **終端機模擬引擎現代化**：將核心解析器 `YLTerminal` 改寫為 Swift，重新實作 VT100 / ANSI 跳脫序列（Escape Sequence）剖析與字元緩衝區管理。
   - **網路通訊與 Socket 核心重構**：使用 Swift Network 框架 (`NWConnection`) 取代舊型 Socket 與 Stream，重寫 `YLConnection`、`YLTelnet` 與 `YLSSH` 連線引擎。
   - **主控制器與外掛載入器現代化**：將主要 App 邏輯控制器 `YLController` 及外掛模組載入器 `YLPluginLoader` 移轉至 Swift。
   - **完全去 Objective-C 化與程式碼大掃除**：
     - 重構 `YLApplication` (App 進入點與事件分派) 為 Swift。
     - 重構 `YLContextualMenuManager` (右鍵快顯功能表管理員) 為 Swift。
     - 重構 `YLRun` / `YLLine` / `YLTextSuite` (貼上文字折行功能) 為 Swift，移除 legacy 的 `YLApplicationKitAddition` Category 宣告。
     - 徹底移除過時或重複的遺留檔案：`YLSimpleDataSource`、`YLDataSourceProtocol`、`YLEmoticon`、重複的頭文件等，乾淨地清理專案結構。

---

## 📈 目前開發進度

目前 **Phase 1 ~ Phase 5 均已全數實作完成**，並通過本機 `xcodebuild` 建置，執行與連線測試皆正常。

### 📌 已完成工作清單
- [x] **資料模型重構**：`YLSite` 與 `YLLGlobalConfig` 改用 Swift 實作 `@Observable`。
- [x] **UI 控制面板改寫**：偏好設定及站台設定改寫為 Swift/SwiftUI。
- [x] **主視窗版面及工具列轉移**：App 進入點、Menu 及 Toolbar 以 Swift 程式化接管。
- [x] **終端機 Swift 渲染**：`YLView` 繪圖迴圈重寫至 `YLViewDrawing.swift`，提升圖形元件的效能。
- [x] **分頁列 (Tab Bar) 與 delegate 接線修正**：預先以程式化建立 `PSMTabBarControl` 並作為純 AppKit 子視圖嵌入主視窗，繞過 `NSViewRepresentable` 對非 Auto Layout 元件的佈局限制與 delegates 的類型檢查。
- [x] **分頁外觀修正**：修正分頁列背景黑條問題，使其與視窗工具列 (Toolbar) 外觀自然融合。
- [x] **預覽視窗修正**：修正 Swift 初始器與 Objective-C 選擇器（Selector）名稱不相符導致點按圖片無預覽之問題。
- [x] **啟動空分頁行為最佳化**：取消啟動時強制建立空分頁，維持無分頁啟動，並在連線後自動新增分頁。
- [x] **重構 `YLTerminal` 模擬引擎**：將終端機文字暫存與 ANSI 分析重寫為 Swift。
- [x] **重構 `YLConnection` 網路層**：以 Swift Network (`NWConnection`) 與 PTY 互動程序重寫 Telnet 與 SSH。
- [x] **重構 `YLController` 主控制器**：以 Swift 重新實作選單事件與分頁動作管理。
- [x] **重構 `YLPluginLoader` 外掛管理**：以 Swift 重寫 Plugin 機制。
- [x] **重構 `YLApplication` / `YLContextualMenuManager`**：改寫為 Swift 版本。
- [x] **重構折行機制與清除 legacy 程式碼**：將 `YLRun`、`YLLine`、`YLTextSuite` 改寫為 Swift，移除大批過時且無引用的舊型 Objective-C/C 檔案。

### 📌 未來優化目標 (Future Scope)
- [ ] **終端機視窗繪圖元件 (`YLView.mm`) 轉換**：雖然 `YLViewDrawing.swift` 已經接管了繪圖邏輯，但 `YLView.mm` 仍為 C++ 混編。未來可規劃將其完全改寫為純 Swift，達成 100% 的純 Swift 專案目標。
- [ ] **外掛 (Plugins) 的 Swift 改寫**：重寫 `HelloNally` 和 `ImagePreviewer` 的外掛程式。

---

## 🛠 測試與驗證

### 1. 自動建置測試
本機端使用以下指令編譯 Release 版本皆可順利完成，無編譯錯誤：
```bash
xcodebuild -scheme Nally -configuration Release SYMROOT=build build
```

### 2. 手動驗證重點
- 啟動時預設不顯示任何分頁。
- 連線至 BBS 站台（例如 PTT）後，系統應能順利自動新增分頁並定位，個別 tab 上的 UI 狀態（包含連線/斷線指標）渲染正確。
- 連線後畫面字元（雙位元組、ANSI 顏色）渲染及特殊繪圖字元顯示均正確。
- 當游標移至圖片網址（如 `.png`, `.jpg`）並點按時，能順利跳出 HUD 樣式的圖片下載進度條與預覽視窗；按 `i` 鍵能開啟 EXIF 中繼資料資訊，滑鼠懸浮在圖片上會浮現「下載儲存」按鈕；點按 `Esc` 能順利關閉預覽。
- 點按右鍵能顯示 Google 搜尋、複製、字典查詢等功能，且功能執行皆正確。
