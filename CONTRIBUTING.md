# 開発への参加

## 製品方針

Mac版は、好きな曲を開いて弾くための静かな道具です。
自動で練習課題を提案したり、演奏を採点したりする画面は追加しません。
譜面の視認性、少ない操作、コード図の使いやすさを優先します。

## 変更と検証

- macOSのUIは`macOS/Sources/GuitarToolsMacApp`、音楽処理は`GuitarToolsCore`にあります。
- Macは`swift test --package-path macOS`と`swift build --package-path macOS`で確認します。
- パッケージは`macOS/scripts/package-app.sh`で生成し、署名、Info.plist、アイコンを確認します。
- AndroidはJDK 17、Gradle 9.3.1を使い、`gradle :app:testDebugUnitTest :app:assembleDebug`で確認します。
- UIの変更では狭い幅、明暗、文字の読みやすさを実画面で確認してください。ビルド成功だけを操作確認とは扱いません。
- 外部連携では、モックテストと実サイトでの確認を区別して報告してください。
- 譜面の不具合には曲名、元ページURL、再生位置、表示設定を添えてください。歌詞全文や無許諾の音源は添付しないでください。

## 紹介画像とアイコン

`macOS/AppResources/AppIcon.png`がアイコンの原画で、`macOS/scripts/generate-app-icon.sh`でICNSを生成します。
アイコンの原画はAI生成です。
紹介画像は第三者の曲を転載せず、自作デモ譜面を使います。
Debugビルドの`--showcase`でデモを表示できます。この入口はReleaseビルドには含まれません。
