# Adwaitter

[![Ko-fi](https://img.shields.io/badge/Ko--fi-Support%20the%20project-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/carrster)

Cross-platform **GNOME Adwaita UI** widget library and design system for Flutter (`package:flutter/widgets.dart`), built with zero dependency on Material or Cupertino and compatible with Android, iOS, Web, Linux, macOS, and Windows.

## Related Packages
- **[Libadwaitter](https://github.com/CarrsterX/Libadwaitter)**: Full GNOME & Linux Wayland desktop suite (`Adwaitter` + native GTK/Wayland bridges).
- **[Adwaitter_Icons](https://github.com/CarrsterX/Adwaitter_Icons)**: Official GNOME Adwaita symbolic icons packaged for Flutter.

## Quick Start (UI Counter Generator)

Replace Flutter's default Material counter app (`lib/main.dart`) with a pure Adwaita counter starter in one command:

```bash
dart run adwaitter:setup
```

Options:
- `--title <name>`: Custom window and header bar title (defaults to `pubspec.yaml` `name`).
- `--dry-run`: Preview changes without writing files.
- `--no-backup`: Skip creating `lib/main.dart.bak`.

## Android Setup

`Adwaitter` enables Android defaults automatically out of the box—including system/gesture navigation bar safe zones, hidden desktop window controls, modal/nested-navigation `frameworkHandlesBack` sync, automatic gesture-vs-button navigation detection, Android 14+ **Predictive Back** (`android:enableOnBackInvokedCallback="true"` via manifest merger), and Android 12+ Material You dynamic accent color (`AdwaitterPlugin`). No manual changes to `AndroidManifest.xml` or `MainActivity` are required.
