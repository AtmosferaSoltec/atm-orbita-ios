//
//  orbitaApp.swift
//  orbita
//
//  Created by Joel Maldonado on 5/10/26.
//

import SwiftUI

@main
struct orbitaApp: App {
    init() {
        FontLoader.registerManrope()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
