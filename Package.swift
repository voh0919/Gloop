// swift-tools-version: 5.9

// Gloop is an App Playground: open this folder in Xcode (or Swift Playgrounds)
// and press Run to launch it in the iPhone Simulator.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Gloop",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "Gloop",
            targets: ["AppModule"],
            bundleIdentifier: "app.lockbuddy.prototype",
            teamIdentifier: "",
            displayVersion: "0.1",
            bundleVersion: "1",
            appIcon: .asset("AppIcon"),
            supportedDeviceFamilies: [
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait
            ],
            capabilities: [
                .camera(purposeString: "Gloop uses the camera so you can send a photo or video with a request, like your finished homework."),
                .microphone(purposeString: "Gloop records sound when you send a video with a request.")
            ]
        )
    ],
    dependencies: [
        // Accounts and data live in Supabase (see Services/SupabaseConfig.swift).
        .package(url: "https://github.com/supabase/supabase-swift.git", "2.0.0"..<"3.0.0")
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ],
            path: ".",
            exclude: ["supabase"]
        )
    ]
)
