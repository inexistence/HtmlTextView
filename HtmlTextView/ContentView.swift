//
//  ContentView.swift
//  HtmlTextView
//
//  Created by 黄建斌 on 2024/6/16.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ScrollView {
            HtmlTextView(PreviewData.delevoper3).padding()
        }
    }
}

#Preview {
    ContentView()
}
