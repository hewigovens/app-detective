import Foundation

extension TraitSignature {
    public static let catalog: [TraitSignature] = [
        // MARK: Native

        TraitSignature(.swiftUI, [
            .strong(.linkedLibrary(.contains("/SwiftUI.framework/"))),
        ]),
        TraitSignature(.appKit, [
            .strong(.linkedLibrary(.contains("/Cocoa.framework/"))),
            .strong(.linkedLibrary(.suffix("/libswiftAppKit.dylib"))),
        ]),
        TraitSignature(.uiKit, [
            // macOS has no UIKit at this path; only iOS binaries link it.
            .strong(.linkedLibrary(.prefix("/System/Library/Frameworks/UIKit.framework/"))),
        ]),
        TraitSignature(.catalyst, [
            .strong(.linkedLibrary(.prefix("/System/iOSSupport/System/Library/Frameworks/UIKit.framework/"))),
        ]),
        TraitSignature(.swift, [
            .strong(.linkedLibrary(.suffix("/libswiftCore.dylib"))),
            // Apps deploying before macOS 10.14.4 bundle the Swift runtime.
            .strong(.framework(.exact("libswiftCore.dylib"))),
        ]),

        // MARK: Web runtimes

        TraitSignature(.electron, [
            .strong(.framework(.exact("Electron Framework.framework"))),
            .strong(.linkedLibrary(.contains("/Electron Framework.framework/"))),
            .strong(.resource(.exact("app.asar"))),
            .weak(.linkedLibrary(.contains("libnode"))),
        ]),
        TraitSignature(.cef, [
            .strong(.framework(.exact("Chromium Embedded Framework.framework"))),
            .strong(.linkedLibrary(.contains("/Chromium Embedded Framework.framework/"))),
            .strong(.linkedLibrary(.contains("libcef.dylib"))),
        ]),
        TraitSignature(.microsoftEdge, [
            .strong(.framework(.exact("Microsoft Edge Framework.framework"))),
        ]),
        TraitSignature(.tauri, [
            // Injected into the webview by Tauri v2 / v1.
            .strong(.embeddedString("__TAURI_INTERNALS__")),
            .strong(.embeddedString("__TAURI_IPC__")),
            .weak(.embeddedString("tauri://localhost")),
        ]),

        // MARK: Cross-platform UI toolkits

        TraitSignature(.flutter, [
            .strong(.framework(.exact("FlutterMacOS.framework"))),
            .strong(.linkedLibrary(.contains("/FlutterMacOS.framework/"))),
            .strong(.file("Contents/Frameworks/App.framework/Resources/flutter_assets")),
            .weak(.framework(.contains("Flutter"))),
        ]),
        TraitSignature(.reactNative, [
            .strong(.resource(.suffix(".jsbundle"))),
            .strong(.framework(.exact("hermes.framework"))),
            .strong(.linkedLibrary(.contains("hermes.framework"))),
            .strong(.linkedLibrary(.contains("libhermes"))),
            .strong(.linkedLibrary(.contains("libjsi"))),
            .weak(.framework(.exact("React.framework"))),
            .weak(.resource(.exact("index.bundle"))),
        ]),
        TraitSignature(.qt, [
            .strong(.framework(.regex(#"^Qt[A-Z][A-Za-z0-9]*\.framework$"#))),
            .strong(.linkedLibrary(.regex(#"/Qt(Core|Gui|Widgets)\.framework/|libQt\d?(Core|Gui|Widgets)"#))),
            .weak(.resource(.exact("qt.conf"))),
        ]),
        TraitSignature(.wxWidgets, [
            .strong(.linkedLibrary(.contains("libwx_"))),
            .weak(.embeddedString("wx_main")),
            .weak(.embeddedString("wxEvtHandler")),
        ]),
        TraitSignature(.gtk, [
            .strong(.linkedLibrary(.contains("libgtk-"))),
            .strong(.linkedLibrary(.contains("libgdk-"))),
        ]),
        TraitSignature(.gpui, [
            .strong(.embeddedString("gpui::")),
            .strong(.embeddedString("gpui/src/")),
        ]),
        TraitSignature(.iced, [
            .strong(.embeddedString("iced_wgpu")),
            .strong(.embeddedString("iced_winit")),
        ]),
        TraitSignature(.egui, [
            // Cargo registry paths, kept in panic messages.
            .strong(.embeddedString("/eframe-")),
            .strong(.embeddedString("/egui-")),
        ]),
        TraitSignature(.slint, [
            .strong(.embeddedString("/slint-")),
        ]),
        TraitSignature(.wgpu, [
            // Log targets and panic locations, so also present in apps built on Iced or egui.
            .strong(.embeddedString("wgpu_core::")),
            .strong(.embeddedString("wgpu_hal::")),
        ]),
        TraitSignature(.wails, [
            // Go module paths from the binary's build info.
            .strong(.embeddedString("github.com/wailsapp/wails")),
        ]),
        TraitSignature(.fyne, [
            .strong(.embeddedString("fyne.io/fyne")),
        ]),
        TraitSignature(.compose, [
            // jpackage puts the Skia bindings next to the app's jars.
            .strong(.entry(in: "Contents/app", .prefix("libskiko"))),
            .strong(.entry(in: "Contents/app", .prefix("skiko-awt"))),
        ]),
        TraitSignature(.avalonia, [
            .strong(.entry(in: "Contents/MacOS", .exact("libAvaloniaNative.dylib"))),
        ]),
        TraitSignature(.xojo, [
            .strong(.framework(.exact("XojoFramework.framework"))),
        ]),

        // MARK: Game engines

        TraitSignature(.unity, [
            .strong(.framework(.exact("UnityPlayer.dylib"))),
            .strong(.linkedLibrary(.contains("UnityPlayer"))),
            .weak(.resource(.exact("Data"))),
        ]),
        TraitSignature(.unreal, [
            .strong(.file("Contents/UE4")),
            .strong(.file("Contents/UE")),
        ]),

        // MARK: Updaters

        TraitSignature(.appStore, [
            .strong(.file("Contents/_MASReceipt")),
            // iOS apps on Apple silicon keep their store metadata next to the wrapped app.
            .strong(.file("Wrapper/iTunesMetadata.plist")),
        ]),
        TraitSignature(.sparkle, [
            .strong(.framework(.exact("Sparkle.framework"))),
        ]),
        TraitSignature(.squirrel, [
            // Electron's autoUpdater.
            .strong(.framework(.exact("Squirrel.framework"))),
        ]),
        TraitSignature(.tauriUpdater, [
            .strong(.codeString("tauri_plugin_updater")),
        ]),

        // MARK: Language runtimes

        TraitSignature(.java, [
            .strong(.linkedLibrary(.contains("libjvm"))),
            .strong(.linkedLibrary(.contains("/JavaVM.framework/"))),
            .strong(.linkedLibrary(.contains("JavaNativeFoundation"))),
            .strong(.plugIn(.regex(#"\.(jdk|jre)$"#))),
            .strong(.file("Contents/runtime/Contents/Home")),
            .strong(.file("Contents/Java")),
            // Also present in any binary that uses JNI.
            .weak(.embeddedString("java/lang/")),
        ]),
        TraitSignature(.rust, [
            // Panic locations in the standard library and its unwrap message.
            .strong(.codeString("/library/std/src/")),
            .strong(.codeString("called `Result::unwrap()` on an `Err` value")),
        ]),
        TraitSignature(.go, [
            // The module build info header and a runtime function name, both kept in stripped binaries.
            .strong(.codeString("Go buildinf:")),
            .strong(.codeString("runtime.gopanic")),
        ]),
        TraitSignature(.python, [
            .strong(.framework(.exact("Python.framework"))),
            .strong(.linkedLibrary(.contains("/Python.framework/"))),
            .strong(.linkedLibrary(.contains("libpython"))),
            // py2app and PyInstaller bootstrap files.
            .strong(.resource(.exact("__boot__.py"))),
            .strong(.resource(.exact("base_library.zip"))),
            .strong(.framework(.exact("base_library.zip"))),
            .weak(.framework(.regex(#"(?i)python.*\.framework$"#))),
        ]),
        TraitSignature(.xamarin, [
            .strong(.file("Contents/MonoBundle")),
            .strong(.linkedLibrary(.contains("libmono"))),
            .strong(.linkedLibrary(.contains("libcoreclr"))),
            .strong(.framework(.contains("Xamarin"))),
            .strong(.framework(.contains("Microsoft.Maui"))),
            .weak(.linkedLibrary(.contains("Microsoft.Maui"))),
        ]),
    ]
}
