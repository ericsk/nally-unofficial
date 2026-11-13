# Nally Unofficial

現代化的開源 macOS Telnet / SSH BBS 終端機用戶端（原生支援 Apple Silicon `arm64` 與 macOS 14+）。

本專案將經典的 Nally 全面重構為 **100% 純 Swift + SwiftUI 視窗生命週期 + CoreGraphics / CoreText 硬體加速渲染** 架構，兼具傳統 BBS 雙色字、區塊圖形（`◢◣◤◥█`）精準繪製與現代 macOS 原生體驗。

## 功能特色

* **通訊協定與安全防護**：原生支援 `Telnet`（`Network.framework`）與 `SSH`（POSIX PTY + 讀寫獨立 FD 佇列 + IPv6 + `--` 參數注入防護）。
* **完整字元編碼**：支援 **Big5**、**GBK** 與串流式 **UTF-8**（完美相容 `ssh://bbsu@ptt.cc` 與現代 SSH 主機）。
* **極速終端機渲染**：採用列級別 Dirty 追蹤、雙位元組原子配對重繪、CoreText 零動態配置與獨立 `CALayer` / `CAShapeLayer` 游標及選取圖層。
* **書籤與憑證安全**：採用 `SwiftData` 管理站台書籤，密碼以 `@Transient` 隔離並安全儲存於 macOS **Keychain**，支援自動登入與頂部選單列 **MenuBarExtra** 快速連線。
* **內建圖片預覽與短網址**：支援點擊與 **按住 `Cmd` 懸停（Cmd + Hover）** 即時圖片預覽（Popover 氣泡或獨立 HUD 視窗）、手勢縮放、Quick Look、EXIF 檢視，以及 `http://` 短網址自動系統瀏覽器 Fallback。
* **BBS 專屬互動增強**：支援 PTT 文章代碼（`#AID`）右鍵一鍵跳轉、ANSI 彩色複製／貼上、避頭尾點自動斷行貼上（Paste Wrap）、觸控板／滑鼠滾輪捲動、以及可自訂秒數的 **防閒置掛站（Anti-Idle）**。

## 建置與測試

需要 macOS 14.0+ 與 Xcode 16+（Apple Silicon）：

```bash
# 建置 Release 版本 Nally.app
make

# 執行完整 Swift Testing 自動化單元測試集
make test

# 安裝至 /Applications
make install

# 打包散佈壓縮檔與 SHA-256 校驗碼（輸出至 build/dist/）
make release
```

## 常用快捷鍵

| 快捷鍵 | 功能說明 |
| :--- | :--- |
| `Cmd + T` / `Cmd + L` | 新增分頁／聚焦網址列快速連線 |
| `Cmd + B` / `Cmd + N` | 開啟站台書籤管理器 |
| `Cmd + W` | 關閉目前分頁 |
| `Cmd + D` / `Cmd + R` | 中斷目前連線（保留畫面）／重新連線 |
| `Cmd + Shift + V` | 自動斷行貼上（Paste Wrap） |
| `Cmd + Option + V` | ANSI 彩色貼上（Paste Color） |
| `Cmd + =` / `Cmd + -` / `Cmd + 0` | 動態放大／縮小／重設終端機字型與視窗比例 |
| `Cmd + 左鍵點擊` | 智慧計算雙位元組寬度並將 BBS 游標移至點擊處 |
| `Cmd + 游標懸停網址` | 即時彈出圖片預覽氣泡 |

---

## 歷史版本紀錄 (Legacy History)

### 1.4.9
* 修正短網址打不開的 regression，加入自動短網址服務選擇（`ppt.cc`、`0rz.tw`、`tinyurl.com`、`pixiv`、`niconico`）。
* 修正 `Opt + Click` URL 在背景開啟瀏覽器的問題。

### 1.4.8
* 修正 10.8 下藍色框的問題。
* 加入 `Cmd + 上下鍵` 對應到 `PageUp / PageDown`。

### 1.4.7
* 支援設定是否優先使用內建 Image Previewer，並可同時開啟多個 URL。

### 1.4.6
* 修正 Paste Wrap 遇到過長英文會卡住的問題，並加入避頭尾點功能。
