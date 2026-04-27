# WearOrder Clothing Classifier

This document defines the first custom on-device clothing classification model for WearOrder.

The app is already wired to look for a bundled Core ML model named:

```text
WearOrderClothingClassifier.mlmodel
```

If the model is present in the Xcode target, the app uses it first. If it is missing or cannot run, the app falls back to Apple's built-in Vision image classification.

## Labels

Use exactly these folder and model label names for the first version:

| Label | App category | Chinese name |
|---|---|---|
| `top` | `WardrobeCategory.top` | 上装 |
| `outerwear` | `WardrobeCategory.outerwear` | 外套 |
| `bottom` | `WardrobeCategory.bottom` | 下装 |
| `skirt` | `WardrobeCategory.skirt` | 裙装 |
| `shoes` | `WardrobeCategory.shoes` | 鞋履 |
| `bag` | `WardrobeCategory.bag` | 包袋 |
| `accessory` | `WardrobeCategory.accessory` | 配饰 |
| `hat` | `WardrobeCategory.hat` | 帽子 |

Do not rename labels casually. The app maps these exact labels to its wardrobe categories.

## Dataset Structure

Create a local dataset folder outside the Xcode project:

```text
WearOrderClothingDataset/
  training/
    top/
    outerwear/
    bottom/
    skirt/
    shoes/
    bag/
    accessory/
    hat/
  validation/
    top/
    outerwear/
    bottom/
    skirt/
    shoes/
    bag/
    accessory/
    hat/
```

Recommended image counts:

| Stage | Images per class |
|---|---:|
| Smoke test | 50-100 |
| Usable beta | 300-800 |
| Commercial quality | 1000+ |

Keep validation images separate from training images. Do not duplicate the same photo across both sets.

## Photo Rules

Use realistic clothing photos similar to what users will import:

- Single item photos on plain backgrounds.
- Real closet photos with imperfect lighting.
- Multiple colors per category.
- Folded, hanging, and worn examples where appropriate.
- Different camera angles and crop sizes.
- Avoid using the same product catalog image repeatedly.

Avoid confusing label choices:

- Dresses should go into `skirt` for the current app taxonomy.
- Hoodies can go into `outerwear` if used as an outer layer, otherwise `top`.
- Scarves, belts, jewelry, watches, and sunglasses go into `accessory`.
- Caps, beanies, berets, and sun hats go into `hat`.

## Copyright And Privacy

Only train with images you have the right to use.

Recommended sources:

- Photos you take yourself.
- Photos explicitly licensed for commercial machine-learning use.
- User-submitted photos only after clear consent and privacy-policy updates.

Do not use scraped images from Xiaohongshu, Taobao, brand stores, Pinterest, Instagram, or other platforms unless the license explicitly allows commercial model training.

If user photos are collected later, update:

- App privacy policy.
- App Store privacy labels.
- In-app consent copy.
- Data deletion workflow.

## Create ML Training

1. Open Apple's Create ML app.
2. Create an Image Classification project.
3. Add `WearOrderClothingDataset/training`.
4. Add `WearOrderClothingDataset/validation` as validation data.
5. Train the model.
6. Review validation accuracy and the confusion matrix.
7. Export the model as:

```text
WearOrderClothingClassifier.mlmodel
```

## Acceptance Targets

For the first TestFlight version:

| Metric | Target |
|---|---:|
| Overall validation accuracy | 85%+ |
| Each class recall | 75%+ |
| Shoes / bag / hat precision | 85%+ |
| Top vs outerwear confusion | Review manually |
| Bottom vs skirt confusion | Review manually |

If one class performs badly, add more diverse photos for that class before changing app code.

## Xcode Integration

1. Drag `WearOrderClothingClassifier.mlmodel` into the `衣橱存储` target.
2. Make sure target membership is enabled for the app target.
3. Build the app once. Xcode compiles the model into `WearOrderClothingClassifier.mlmodelc`.
4. Run the app.
5. Add or edit a clothing item and import a photo.
6. The app should show a category suggestion from the custom model.

The current code path is:

```text
ClothingEditorForm
  -> ClothingImageAnalyzer.suggestCategory(from:)
  -> WearOrderClothingClassifier.mlmodel, if bundled
  -> Apple Vision fallback, if no custom model is bundled
```

## Versioning

Keep exported model files with versioned copies outside Xcode:

```text
models/
  WearOrderClothingClassifier-v0.1.mlmodel
  WearOrderClothingClassifier-v0.2.mlmodel
```

Only the active model copied into Xcode should be named:

```text
WearOrderClothingClassifier.mlmodel
```

Record each model's dataset date, class counts, validation accuracy, known weaknesses, and release date.
