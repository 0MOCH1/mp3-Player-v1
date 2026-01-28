# NowPlaying Screen Specification v7

## 変更履歴
- v7: 商用品質に向けた全面的な仕様見直し・明確化

---

## 目次
1. 目的と前提
2. デザイン踏襲要件
3. 用語集（英語統一）
4. UI Layer Model（FullPlayer 内）
5. State Model
6. FullPlayer（標準再生UI）
7. MiniPlayer（縮小UI）
8. Lyrics Mode（歌詞）
9. Queue Mode（キュー）
10. Visual Requirement: EdgeFade
11. Animation Requirement
12. Layout & Spacing
13. Acceptance Criteria

---

## 1. 目的と前提
1.1 本仕様は、別画面遷移（Push/Modal等）を増やさず **同一画面内の状態切替**で機能（歌詞・キュー）を提供する。

1.2 **Swift + SwiftUI** 前提。ただし実装パターン／コンポーネント選定／閾値／アニメーション曲線等は **開発者裁量**（受入条件は必須）。

1.3 **Lyrics と Queue は排他**（同時表示しない）。

1.4 **商用リリース品質**を目指す。UXは滑らかで一貫性があり、不自然な動作・表示は許容しない。

---

## 2. デザイン踏襲要件
2.1 **基本的なUIデザイン、見た目、配置、サイズ感は既存プロジェクトを踏襲**すること。

2.2 **Controls の見た目は全状態で一貫**させること（表示時は常に同一のスタイル）。

2.3 **CompactTrackInfo の見た目も全状態で一貫**させること（固定表示でもリスト内でも同一スタイルに見える）。

2.4 **CompactTrackInfo の Artwork サイズは 80pt**（正方形）とする。

2.5 **FullPlayer（標準再生UI）は現状実装されている画面と同一の見た目・体験**であること。

---

## 3. 用語集（英語統一）

### 3.1 FullPlayer
- 標準再生UI（現状の「再生画面」そのもの）
- フルスクリーンモーダルとして表示

### 3.2 MiniPlayer
- TabBar 上に `.tabViewBottomAccessory` として常駐する縮小プレイヤー
- FullPlayer を下方向ドラッグで dismiss すると MiniPlayer に戻る

### 3.3 Controls
- 音量バー、再生/停止、スキップ、戻る、シークバー（経過/残り）、LyricsButton、QueueButton、AirPlayButton 等を含む「操作UI一式」
- **TrackInfoは含まない**（TrackInfoはControlsとは別コンポーネント）

### 3.4 TrackInfo
- NowPlayingモード時にのみ表示される楽曲タイトル・アーティスト名
- シークバーの30pt上に配置
- Lyrics/Queueモード時は非表示

### 3.5 CompactTrackInfo
- FullPlayer 内の Lyrics/Queue モードで表示される「縮小楽曲情報」コンポーネント（Artwork + Title の横並び）
- **Artwork は 80pt**固定（正方形）

### 3.6 ContentPanel
- FullPlayer 内で Mode に応じて切り替わる主要コンテンツ領域

### 3.7 LyricsPanel / QueuePanel
- ContentPanel に表示される具体コンテンツ（歌詞／キュー）

### 3.8 ControlsVisibility
- **Shown / Hidden** の2状態
- ContentPanel の表示可能領域（Viewport）を規定するための状態

### 3.9 EdgeFade
- LyricsPanel / QueuePanel のスクロールコンテンツ端が **グラデーションで消えていく視覚効果**

### 3.10 QueueControls
- QueuePanel 内のシャッフル／リピート操作部
- **EdgeFadeの外側（影響を受けない位置）に配置**
- **背景なし、透明**

### 3.11 QueueSubstate
- QueuePanel における **Browsing / Reordering** のサブ状態

---

## 4. UI Layer Model（FullPlayer 内）

### 4.1 レイヤ構成
FullPlayer の UI は概念的に以下の3レイヤで構成する。

### 4.2 Layer0: Background & Grip
- Artwork 由来の背景グラデーション
- FullPlayer dismiss のためのドラッグ操作を担う Grip（ヒット領域）

### 4.3 Layer1: ContentPanel
- Mode に応じて切り替わるコンテンツ
  - **NowPlaying**: Artwork のみ（TrackInfoはLayer2）
  - **Lyrics**: LyricsPanel（CompactTrackInfo + 歌詞スクロール）
  - **Queue**: QueuePanel（History + CompactTrackInfo + QueueControls + CurrentQueue）

### 4.4 Layer2: Chrome
- **TrackInfo**（NowPlayingモード時のみ）
- **Controls**（全状態で見た目一貫）

### 4.5 コンテンツとControlsの重なり禁止（重要）
- **ControlsVisibility=Shown時**: ContentPanelの下端はシークバー上端に一致
- **ControlsVisibility=Hidden時**: ContentPanelは画面下端まで拡張
- コンテンツがControlsを透けて見えることは許容しない

---

## 5. State Model

### 5.1 ScreenForm
- **FullPlayer** / **MiniPlayer**

### 5.2 Mode（排他）
- **NowPlaying** / **Lyrics** / **Queue**

### 5.3 ControlsVisibility
- **Shown** / **Hidden**

### 5.4 QueueSubstate（Mode=Queue のときのみ）
- **Browsing** / **Reordering**

---

## 6. FullPlayer（標準再生UI）

### 6.1 Entry
- MiniPlayer をタップして FullPlayer へ遷移

### 6.2 UI（既存踏襲）
- Artwork, Title, Artist
- SeekBar（elapsed/remaining）
- Controls（LyricsButton, QueueButton, AirPlayButton, Volume, Play/Pause, Skip, Back 等）
- FavoriteButton
- 背景：Artwork 由来グラデーション

### 6.3 Gestures（既存踏襲）
- 下方向ドラッグ：FullPlayer → MiniPlayer
- Artwork の左右スワイプ：Skip/Back

### 6.4 TrackInfo配置
- シークバーの30pt上に配置
- NowPlayingモード時のみ表示

---

## 7. MiniPlayer（縮小UI）

### 7.1 配置
- `.tabViewBottomAccessory` として TabBar 上に常駐
- 既存の MiniPlayer 実装を踏襲

### 7.2 UI（既存踏襲）
- Artwork（32x32、角丸6pt）
- タイトル + アーティスト名
- 再生/一時停止ボタン
- 次へボタン（full placement 時のみ）

### 7.3 Entry to FullPlayer
- MiniPlayer 全体をタップで FullPlayer へ遷移

---

## 8. Lyrics Mode（歌詞）

### 8.1 Toggle
- LyricsButton で NowPlaying ↔ Lyrics をトグル（Queueとは排他）

### 8.2 ControlsVisibility
- 下方向スクロール/フリックで **ControlsVisibility=Hidden**
- 上方向スクロールで **ControlsVisibility=Shown** に復帰

### 8.3 Skip/Back 操作
- Lyrics モード時は Controls 内の再生ボタン群を使用

### 8.4 CompactTrackInfo
- 表示は必須
- 固定ヘッダとして配置

### 8.5 コンテンツ領域
- ControlsVisibility=Shown時: 下端はシークバー上端まで
- ControlsVisibility=Hidden時: 下端は画面下端まで

---

## 9. Queue Mode（キュー）

### 9.1 Toggle
- QueueButton で NowPlaying ↔ Queue をトグル（Lyricsとは排他）

### 9.2 Structure（順序固定）
1. History（再生済みトラック）
2. CompactTrackInfo（リスト内要素として配置）
3. QueueControls（Shuffle / Repeat）- **EdgeFadeの外側に配置**
4. CurrentQueue（現在再生中は含めない）

### 9.3 Skip/Back 操作
- Queue モード時は Controls 内の再生ボタン群を使用

### 9.4 ControlsVisibility
- Queue モードでは Controls は **常に Shown**
- Reordering 時のみ Hidden になる

### 9.5 Initial Position（必須）
- Queueへ入るたび、初期位置は **CompactTrackInfo がリスト上端に揃う位置**から開始
- アニメーションなしで即座にその位置に配置

### 9.6 QueueControls 仕様
- **スクロールに追従する**（sticky ではない）
- **EdgeFadeの外側に配置**（フェードに巻き込まれない）
- **背景なし**（透明）
- **ボタンサイズ**: 縦方向+5pt、横方向+20pt 拡大
- **Capsuleスタイル、center alignment**
- 有効時: 白背景 + 黒テキスト
- 無効時: 半透明白背景 + 白テキスト

### 9.7 QueueSubstate: Reordering
- CurrentQueue は常に並び替え可能（Reorder handle）
- 並び替え開始：QueueSubstate=Reordering + ControlsVisibility=Hidden
- 並び替え終了：QueueSubstate=Browsing + ControlsVisibility=Shown に必ず戻る

### 9.8 Row Actions / Labels
- 左スワイプ削除：確認なし
- ソースラベルはセクションラベルとして表示（"Playing from {source}"）
- 行表示は TrackListView / TrackRowView を踏襲
- **Artwork は RoundedRectangle（角丸あり、cornerRadius: 4）**

### 9.9 Empty State
- CurrentQueue が空：`Queue is empty`
- History が空：空表示

### 9.10 コンテンツ領域
- ControlsVisibility=Shown時: 下端はシークバー上端まで
- ControlsVisibility=Hidden時: 下端は画面下端まで

---

## 10. Visual Requirement: EdgeFade

### 10.1 適用範囲
- LyricsPanel と QueuePanel のスクロールコンテンツ端に適用

### 10.2 QueueControls除外
- **QueueControlsはEdgeFadeの影響を受けない位置に配置**
- QueueControlsは常に完全に表示される

### 10.3 フェード量
- フェード量・強さ・範囲は既存の見た目に合わせて調整

---

## 11. Animation Requirement

### 11.1 基本方針
- **「複数の画面を切り替える」ではなく「画面は一つで、状態によってパーツが動く」**
- アニメーションは**高速**（duration: 0.2秒程度）
- 同じコンポーネントはスムーズに状態間で動く

### 11.2 共通パーツのアニメーション定義

#### Artwork（共通）
- **すべてのMode間でmatchedGeometryEffectを使用**
- NowPlayingの大Artwork ↔ CompactTrackInfoの小Artwork
- スケール + 位置移動を同時に行う

#### TrackInfo（NowPlayingのみ表示）
- **表示時**: 下からスライドしながらフェードイン
- **非表示時**: 上へスライドしながらフェードアウト

#### CompactTrackInfo内のtrackInfo
- **表示時**: 下からスライドしながらフェードイン
- **非表示時**: 上へスライドしながらフェードアウト

#### ContentPanel（Layer1）
- **Mode切り替え時**: asymmetric scale + opacity transition
- **入り**: scale(1.0) + opacity(1)
- **出**: scale(0.95) + opacity(0)
- **両方向（入/出）に適用**

### 11.3 具体的なトランジション例

#### NowPlaying → Lyrics/Queue
- Artwork: 大→小にスケール縮小しながらCompactTrackInfo位置へ移動
- TrackInfo: 上方向へスライドしながらフェードアウト
- CompactTrackInfoのtrackInfo: 下からスライドしながらフェードイン
- ContentPanel: 入りアニメーション適用

#### Lyrics/Queue → NowPlaying
- Artwork: 小→大にスケール拡大しながらNowPlaying位置へ移動
- TrackInfo: 下からスライドしながらフェードイン
- CompactTrackInfoのtrackInfo: 上へスライドしながらフェードアウト
- ContentPanel: 出アニメーション適用

#### Lyrics ↔ Queue
- Artwork: CompactTrackInfo位置を維持（ControlsVisibility=Shown時）
- ContentPanel: asymmetric scale + opacityで切り替え
- QueueがスクロールされていてLyricsへ戻る場合: CompactTrackInfoがLyrics位置へスライド

### 11.4 アニメーション速度
- **標準duration: 0.2秒**
- easing: .easeInOut または .spring(response: 0.3)

---

## 12. Layout & Spacing（レイアウト・余白）

### 12.1 Controls余白（下から順）
| 間隔 | 値 |
|------|-----|
| 画面下端 → Footer | safeArea.bottom + 3pt |
| Footer → Volume | 10pt |
| Volume → PlayerButtons | 30pt |
| PlayerButtons → SeekBar | 30pt |
| SeekBar → TrackInfo | 30pt |

### 12.2 Grip寸法
- 幅: 64pt（80ptから20%短縮）
- 高さ: 5pt

### 12.3 CompactTrackInfo位置
- LyricsPanel / QueuePanel 共通: 現行位置から10pt上へ

### 12.4 AirPlayボタン
- **他のボタンと同じ色（palette.opaque）を使用**
- blendMode: .overlay

---

## 13. Acceptance Criteria（受入条件）

### 13.1 基本要件
- [ ] 既存プロジェクトの見た目・配置・サイズ感を踏襲している
- [ ] Controls は全状態で見た目が一貫している
- [ ] CompactTrackInfo は全状態で見た目が一貫し、Artwork は 80pt

### 13.2 FullPlayer/MiniPlayer
- [ ] FullPlayer は下ドラッグで MiniPlayer に縮小できる
- [ ] MiniPlayer の Artwork タップで FullPlayer に復帰できる

### 13.3 Lyrics Mode
- [ ] LyricsButton でトグル可能
- [ ] ControlsVisibility の切替が成立
- [ ] CompactTrackInfo が表示される

### 13.4 Queue Mode
- [ ] QueueButton でトグル可能
- [ ] 初期位置がCompactTrackInfo（即座に、アニメーションなし）
- [ ] QueueControls がEdgeFadeに巻き込まれない
- [ ] QueueControls の背景がない
- [ ] Reorder handle で並び替え可能
- [ ] スワイプ削除が機能する
- [ ] アートワークがRoundedRectangle

### 13.5 コンテンツとControlsの関係
- [ ] ControlsVisibility=Shown時、コンテンツ下端はシークバー上端まで（重なりなし）
- [ ] ControlsVisibility=Hidden時、コンテンツは画面下端まで拡張

### 13.6 TrackInfo
- [ ] NowPlayingモード時のみ表示
- [ ] シークバーの30pt上に配置

### 13.7 アニメーション
- [ ] ArtworkはmatchedGeometryEffectでスムーズに遷移
- [ ] TrackInfoはスライド+フェードで遷移
- [ ] ContentPanelはasymmetric scale + opacity（入/出両方）
- [ ] アニメーション速度は0.2秒程度（遅すぎない）

### 13.8 その他
- [ ] AirPlayボタンが機能し、他のボタンと同じ色
- [ ] EdgeFade が効いている
- [ ] Shuffle/Repeat ボタンがCapsuleスタイルで正しいサイズ

---

## 付録: v6からの主な変更点

1. **TrackInfo配置の明確化**: シークバーの30pt上に配置（NowPlayingモード時のみ）
2. **コンテンツとControlsの重なり禁止**: 明確に仕様化
3. **ControlsVisibility=Hidden時のコンテンツ拡張**: 動的な仕組みを明記
4. **QueueControls仕様の詳細化**: EdgeFade外、背景なし、サイズ拡大
5. **アニメーション速度**: 0.2秒を標準とし「遅すぎない」ことを明記
6. **asymmetric transition**: 入/出両方に適用することを明記
7. **AirPlayボタンの色**: 他のボタンと同じ色を使用
8. **キューアートワーク**: RoundedRectangle（角丸あり）
9. **QueuePanel初期位置**: アニメーションなしで即座にCompactTrackInfo位置
10. **トランジション一般化**: 特定のMode間だけでなく、共通パーツのアニメーションとして定義
