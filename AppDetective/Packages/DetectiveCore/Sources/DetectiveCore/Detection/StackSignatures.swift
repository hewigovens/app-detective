import Foundation

extension StackSignature {
    public static let catalog: [StackSignature] = [
        // MARK: Native

        StackSignature(.swiftUI, [
            .strong(.linkedLibrary(.contains("/SwiftUI.framework/"))),
        ]),
        StackSignature(.appKit, [
            .strong(.linkedLibrary(.contains("/Cocoa.framework/"))),
            .strong(.linkedLibrary(.suffix("/libswiftAppKit.dylib"))),
        ]),
        StackSignature(.catalyst, [
            .strong(.linkedLibrary(.prefix("/System/iOSSupport/System/Library/Frameworks/UIKit.framework/"))),
        ]),

        // MARK: Web runtimes

        StackSignature(.electron, [
            .strong(.framework(.exact("Electron Framework.framework"))),
            .strong(.linkedLibrary(.contains("/Electron Framework.framework/"))),
            .strong(.resource(.exact("app.asar"))),
            .weak(.linkedLibrary(.contains("libnode"))),
        ]),
        StackSignature(.cef, [
            .strong(.framework(.exact("Chromium Embedded Framework.framework"))),
            .strong(.linkedLibrary(.contains("/Chromium Embedded Framework.framework/"))),
            .strong(.linkedLibrary(.contains("libcef.dylib"))),
        ]),
        StackSignature(.microsoftEdge, [
            .strong(.framework(.exact("Microsoft Edge Framework.framework"))),
        ]),
        StackSignature(.tauri, [
            // Injected into the webview by Tauri v2 / v1.
            .strong(.embeddedString("__TAURI_INTERNALS__")),
            .strong(.embeddedString("__TAURI_IPC__")),
            .weak(.embeddedString("tauri://localhost")),
        ]),

        // MARK: Cross-platform UI toolkits

        StackSignature(.flutter, [
            .strong(.framework(.exact("FlutterMacOS.framework"))),
            .strong(.linkedLibrary(.contains("/FlutterMacOS.framework/"))),
            .strong(.file("Contents/Frameworks/App.framework/Resources/flutter_assets")),
            .weak(.framework(.contains("Flutter"))),
        ]),
        StackSignature(.reactNative, [
            .strong(.resource(.suffix(".jsbundle"))),
            .strong(.framework(.exact("hermes.framework"))),
            .strong(.linkedLibrary(.contains("hermes.framework"))),
            .strong(.linkedLibrary(.contains("libhermes"))),
            .strong(.linkedLibrary(.contains("libjsi"))),
            .weak(.framework(.exact("React.framework"))),
            .weak(.resource(.exact("index.bundle"))),
        ]),
        StackSignature(.qt, [
            .strong(.framework(.regex(#"^Qt[A-Z][A-Za-z0-9]*\.framework$"#))),
            .strong(.linkedLibrary(.regex(#"/Qt(Core|Gui|Widgets)\.framework/|libQt\d?(Core|Gui|Widgets)"#))),
            .weak(.resource(.exact("qt.conf"))),
        ]),
        StackSignature(.wxWidgets, [
            .strong(.linkedLibrary(.contains("libwx_"))),
            .weak(.embeddedString("wx_main")),
            .weak(.embeddedString("wxEvtHandler")),
        ]),
        StackSignature(.gtk, [
            .strong(.linkedLibrary(.contains("libgtk-"))),
            .strong(.linkedLibrary(.contains("libgdk-"))),
        ]),
        StackSignature(.gpui, [
            .strong(.embeddedString("gpui::")),
            .strong(.embeddedString("gpui/src/")),
        ]),
        StackSignature(.iced, [
            .strong(.embeddedString("iced_wgpu")),
            .strong(.embeddedString("iced_winit")),
        ]),

        // MARK: Language runtimes

        StackSignature(.java, [
            .strong(.linkedLibrary(.contains("libjvm"))),
            .strong(.linkedLibrary(.contains("/JavaVM.framework/"))),
            .strong(.linkedLibrary(.contains("JavaNativeFoundation"))),
            .strong(.plugIn(.regex(#"\.(jdk|jre)$"#))),
            .strong(.file("Contents/runtime/Contents/Home")),
            .strong(.file("Contents/Java")),
            // Also present in any binary that uses JNI.
            .weak(.embeddedString("java/lang/")),
        ]),
        StackSignature(.python, [
            .strong(.framework(.exact("Python.framework"))),
            .strong(.linkedLibrary(.contains("/Python.framework/"))),
            .strong(.linkedLibrary(.contains("libpython"))),
            // py2app and PyInstaller bootstrap files.
            .strong(.resource(.exact("__boot__.py"))),
            .strong(.resource(.exact("base_library.zip"))),
            .strong(.framework(.exact("base_library.zip"))),
            .weak(.framework(.regex(#"(?i)python.*\.framework$"#))),
        ]),
        StackSignature(.xamarin, [
            .strong(.file("Contents/MonoBundle")),
            .strong(.linkedLibrary(.contains("libmono"))),
            .strong(.linkedLibrary(.contains("libcoreclr"))),
            .strong(.framework(.contains("Xamarin"))),
            .strong(.framework(.contains("Microsoft.Maui"))),
            .weak(.linkedLibrary(.contains("Microsoft.Maui"))),
        ]),
    ]
}
