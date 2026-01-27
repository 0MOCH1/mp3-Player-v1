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
10. Visual Requirement: EdgeFade（端のグラデーション消失）  
11. Animation Requirement  
12. Acceptance Criteria（受入条件）

---

## 1. 目的と前提
1.1 本仕様は、別画面遷移（Push/Modal等）を増やさず **同一画面内の状態切替**で機能（歌詞・キュー）を提供する。  
1.2 **Swift + SwiftUI** 前提。ただし実装パターン／コンポーネント選定／閾値／アニメーション曲線等は **開発者裁量**（受入条件は必須）。  
1.3 **Lyrics と Queue は排他**（同時表示しない）。

---

## 2. デザイン踏襲要件
2.1 **基本的なUIデザイン、見た目、配置、サイズ感は既存プロジェクトを踏襲**すること。実現方法は問わない。  
2.2 **Controls の見た目は全状態で一貫**させること（表示時は常に同一のスタイル）。  
2.3 **CompactTrackInfo の見た目も全状態で一貫**させること（固定表示でもリスト内でも同一スタイルに見える）。  
2.4 **CompactTrackInfo の Artwork サイズは 80pt**（正方形）とする。  
2.5 **FullPlayer（標準再生UI）は現状実装されている画面と同一の見た目・体験**であること。内部構造が大幅に変わるため **作り直し実装でよい**（結果が一致すればOK）。

---

## 3. 用語集（英語統一）
3.1 **FullPlayer**  
- 標準再生UI（現状の「再生画面」そのもの）
- フルスクリーンモーダルとして表示

3.2 **MiniPlayer**  
- TabBar 上に `.tabViewBottomAccessory` として常駐する縮小プレイヤー
- FullPlayer を下方向ドラッグで dismiss すると MiniPlayer に戻る

3.3 **Controls**  
- 音量バー、再生/停止、スキップ、戻る、シークバー（経過/残り）、LyricsButton、QueueButton、AirPlayButton 等を含む「操作UI一式」

3.4 **CompactTrackInfo**  
- FullPlayer 内の Lyrics/Queue モードで表示される「縮小楽曲情報」コンポーネント（Artwork + Title の横並び）  
- **Artwork は 80pt**固定（正方形）

3.5 **ContentPanel**  
- FullPlayer 内で Mode に応じて切り替わる主要コンテンツ領域（LyricsPanel / QueuePanel などが入る）

3.6 **LyricsPanel / QueuePanel**  
- ContentPanel に表示される具体コンテンツ（歌詞／キュー）

3.7 **ControlsVisibility**  
- **Shown / Hidden** の2状態  
- ContentPanel の表示可能領域（Viewport）を規定するための状態

3.8 **EdgeFade**  
- LyricsPanel / QueuePanel のスクロールコンテンツ端が **グラデーションで消えていく視覚効果**

3.9 **QueueControls**  
- QueuePanel 内のシャッフル／リピート操作部（常時可視）

3.10 **QueueSubstate**  
- QueuePanel における **Browsing / Reordering** のサブ状態

---

## 4. UI Layer Model（FullPlayer 内）
4.1 FullPlayer の UI は概念的に以下の3レイヤで構成する（実装手段は任意だが、この分離を満たすこと）。

4.2 **Layer0: Background & Grip**  
- Artwork 由来の背景グラデーション  
- FullPlayer dismiss のためのドラッグ操作を担う Grip（ヒット領域）

4.3 **Layer1: ContentPanel**  
- Mode に応じて切り替わるコンテンツ（NowPlaying: Artwork+Title, Lyrics: LyricsPanel, Queue: QueuePanel）

4.4 **Layer2: Chrome**  
- Controls（全状態で見た目一貫）  

4.5 **CompactTrackInfo のレイヤ所属ルール**  
- CompactTrackInfo は **表示位置（固定 or リスト内）をモードに応じて変更してよい**。  
- ただし **見た目（レイアウト・余白・フォント・背景・角丸・影・80pt Artwork 等）は必ず一貫**させること。  
- 推奨：  
  - LyricsPanel では CompactTrackInfo を「固定ヘッダ相当」にしてよい  
  - QueuePanel では CompactTrackInfo を「リスト内要素」として扱ってよい

---

## 5. State Model
5.1 状態は次の直交軸で定義する。

5.2 **ScreenForm**  
- **FullPlayer** / **MiniPlayer**

5.3 **Mode**（排他）  
- **NowPlaying** / **Lyrics** / **Queue**

5.4 **ControlsVisibility**  
- **Shown** / **Hidden**

5.5 **QueueSubstate**（Mode=Queue のときのみ）  
- **Browsing** / **Reordering**

---

## 6. FullPlayer（標準再生UI）
6.1 **Entry**  
- MiniPlayer をタップして FullPlayer へ遷移  
- 前提：再生中アイテム必須（未再生は想定しない。読み込み中はプレースホルダー）

6.2 **UI（既存踏襲）**  
- Artwork, Title, Artist  
- SeekBar（elapsed/remaining）  
- Controls（LyricsButton, QueueButton, AirPlayButton, Volume, Play/Pause, Skip, Back 等）  
- FavoriteButton  
- 背景：Artwork 由来グラデーション（生成方法は裁量）

6.3 **Gestures（既存踏襲）**  
- 下方向ドラッグ：FullPlayer → MiniPlayer  
- Artwork の左右スワイプ：Skip/Back

6.4 **Seek & Interaction Constraint**  
- SeekBar は即時シーク  
- Seek 操作中：Volume 以外の再生コントロールは無効  
- Volume：デバイス音量  
- AirPlay：OS標準挙動  
- エラー表示は行わない（必要なら既存踏襲）

---

## 7. MiniPlayer（縮小UI）
7.1 **配置**  
- `.tabViewBottomAccessory` として TabBar 上に常駐
- 既存の MiniPlayer 実装を踏襲（見た目・機能はそのまま）

7.2 **UI（既存踏襲）**  
- Artwork（32x32、角丸6pt）  
- タイトル + アーティスト名  
- 再生/一時停止ボタン  
- 次へボタン（full placement 時のみ）  
- inline / full の2つの placement に対応

7.3 **Entry to FullPlayer**  
- MiniPlayer 全体をタップで FullPlayer（フルスクリーンモーダル）へ遷移
- できれば MiniPlayer ↔ FullPlayer 間で滑らかなアニメーション遷移

7.4 **Exit from FullPlayer**  
- FullPlayer を下ドラッグで dismiss すると MiniPlayer に戻る

---

## 8. Lyrics Mode（歌詞）
8.1 **Toggle**  
- LyricsButton で NowPlaying ↔ Lyrics をトグル（Queueとは排他）

8.2 **ControlsVisibility**  
- 下方向スクロール/フリックで **ControlsVisibility=Hidden**（拡張）  
- 上方向スクロールで **ControlsVisibility=Shown** に復帰  
- 誤作動防止の判定方法・閾値は裁量（ただし誤作動が目立たないこと）

8.3 **Skip/Back 操作**
- Lyrics モード時は Controls 内の再生ボタン群を使用（Artwork スワイプは不可）

8.4 **CompactTrackInfo**  
- 表示は必須  
- 固定表示として扱ってよい（ただし見た目一貫）

8.5 **No Lyrics**  
- 未取得はプレースホルダー

---

## 9. Queue Mode（キュー）
9.1 **Toggle**  
- QueueButton で NowPlaying ↔ Queue をトグル（Lyricsとは排他）

9.2 **Structure（順序固定）**  
1) History（再生済みトラック。HistoryRepository から取得）  
2) CompactTrackInfo（リスト内要素として配置してよい）  
3) QueueControls（Shuffle / Repeat）  
4) CurrentQueue（現在再生中は含めない）

9.3 **Skip/Back 操作**
- Queue モード時は Controls 内の再生ボタン群を使用（Artwork スワイプは不可）

9.4 **ControlsVisibility**
- Queue モードでは Controls は常に Shown
- Reordering 時のみ Hidden になる

9.5 **Initial Position（必須）**  
- Queueへ入るたび、初期位置は **CompactTrackInfo がリスト上端に揃う位置**から開始する（方法は裁量）

9.6 **QueueControls Visibility（必須）**  
- QueueControls は **常時可視（sticky相当）**

9.7 **Scroll Ownership（必須）**  
- QueueControls が上端に到達するまでは外側スクロール  
- 到達後：CurrentQueue が内側スクロールとして進行し、QueueControls は常時見える  
- CurrentQueue が上端で上方向スクロール継続 → 外側へ戻り History へ戻れること

9.8 **History Gate（必須）**  
- History 下端到達後の下方向操作は以下：  
  1) 下端より下（CompactTrackInfo以降）が **覗ける**  
  2) 閾値未満：History下端位置へ戻される  
  3) 閾値超：CompactTrackInfo が上端に揃う位置へスナップ  
- 閾値・判定方法は裁量（意図せず遷移しない／意図すれば遷移できること）

9.9 **QueueSubstate: Reordering（必須）**  
- CurrentQueue は常に並び替え可能（Reorder handle 等）  
- 並び替え開始：QueueSubstate=Reordering + ControlsVisibility=Hidden  
- 並び替え終了：QueueSubstate=Browsing + ControlsVisibility=Shown に必ず戻る（例外なし）

9.10 **Row Actions / Labels**  
- 左スワイプ削除：確認なし  
- ラベルに追加元を明記（具体名まで）例：`Source: Album 1`
- 行表示は TrackListView / TrackRowView を踏襲
- Artwork は Rectangle（角丸なし）

9.11 **Empty State**  
- CurrentQueue が空：`Queue is empty`  
- History が空：空表示（セクション自体は表示してよい）

9.12 **Queue Button Indicators**  
- Shuffle / Repeat の状態を QueueButton に小さなアイコンで表示

---

## 10. Visual Requirement: EdgeFade（端のグラデーション消失）
10.1 LyricsPanel と QueuePanel のスクロールコンテンツ端は、**EdgeFade** によりグラデーションで消えていくようにする。  
10.2 **ControlsVisibility=Shown のときも同様**に EdgeFade を適用する（Controls に隠れる/重なるかどうかに関係なく、端が自然にフェードすること）。  
10.3 フェード量・強さ・範囲は既存の見た目に合わせて調整（数値は裁量、ただし不自然にならないこと）。

---

## 11. Animation Requirement
11.1 再生/停止、Skip/Back、状態遷移はスムーズにアニメーション（duration/easingは裁量）。  
11.2 FullPlayer ↔ MiniPlayer  
- Artwork は滑らかに連結  
- Title は Full→Mini で上フェードアウト、Mini→Full で下フェードイン

---

## 12. Acceptance Criteria（受入条件）
12.1 既存プロジェクトの見た目・配置・サイズ感を踏襲している（実装は再構築でも可）。  
12.2 Controls は全状態で見た目が一貫し、Shown/Hidden の切替でも再表示時に変化しない。  
12.3 CompactTrackInfo は全状態で見た目が一貫し、Artwork は 80pt。  
12.4 FullPlayer は下ドラッグで MiniPlayer に縮小し、MiniPlayer の Artwork タップで FullPlayer に復帰できる。  
12.5 Lyrics と Queue は排他でトグル可能。Lyrics は ControlsVisibility の切替が成立。  
12.6 Queue は初期位置（CompactTrackInfo が上端）、History Gate、QueueControls 常時可視、内側スクロール、Reordering で ControlsHidden が成立。  
12.7 LyricsPanel / QueuePanel は EdgeFade が効いており、Controls が表示されていても端が自然にフェードする。
