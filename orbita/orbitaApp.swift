//
//  orbitaApp.swift
//  orbita
//
//  Created by Joel Maldonado on 5/10/26.
//

import SwiftUI

@main
struct orbitaApp: App {
    @State private var model = AppModel(env: .make())

    init() {
        FontLoader.registerManrope()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
    }
}
