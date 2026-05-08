# training_data_erasure（Flutter アプリ本体）

[`docs/spec.md`](../docs/spec.md) / [`implementation_plan.md`](../docs/implementation_plan.md) に沿った **Phase A〜B の足場**。オンデバイス inpainting ONNX は未同梱（`assets/models/README.txt`）。

## セットアップ

1. Flutter SDK（stable、**3.24+** 推奨）と Xcode / Android Studio を用意する。
2. 初回のみ、既存ソースを維持したままプラットフォーム一式を生成する。

```bash
cd app
flutter create . --platforms=android,ios --project-name training_data_erasure
flutter pub get
```

3. ONNX を PoC する場合のみ `assets/models/inpainting.onnx` を配置し、`pubspec.yaml` の `flutter.assets` にそのパスを追加する。サイズ・ライセンスは `spec.md` §4.1 の表で管理すること。

## 実行

```bash
flutter run
```

## 開発コマンド

```bash
dart format lib test
flutter analyze
flutter test
```

## ONNX ランタイムのパッケージ名について

Pub には **`onnxruntime`** が掲載されており、リポジトリ名は onnxruntime\_flutter と一致しない。コードはこのパブリッシュ名に合わせています。

## ONNX 無し環境での挙動

`main.dart` は `StubInpaintingEngine` で起動する。bundle モデルがある場合のみ `OnnxInpaintingEngine` と差し替え可能（tensor I/O は Phase C で固定）。
