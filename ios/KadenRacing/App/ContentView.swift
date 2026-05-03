import SwiftUI
import WebKit

struct ContentView: View {
    var body: some View {
        KadenGameWebView()
            .ignoresSafeArea()
    }
}

struct KadenGameWebView: UIViewRepresentable {
    private let gameURL = URL(string: "https://kaden-car-championships.vercel.app/")!

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = true
        webView.scrollView.alwaysBounceVertical = true
        webView.scrollView.delaysContentTouches = false
        webView.scrollView.canCancelContentTouches = true
        webView.scrollView.keyboardDismissMode = .interactive
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = false
        webView.load(URLRequest(url: gameURL, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 30))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url == nil {
            webView.load(URLRequest(url: gameURL, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 30))
        }
    }
}
