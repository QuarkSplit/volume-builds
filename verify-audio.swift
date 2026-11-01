import Cocoa
import WebKit

final class AudioResult: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let result = String(describing: message.body)
        print("WebKit audio: \(result)")
        exit(result == "playing" ? 0 : 1)
    }
}

let audio = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let handler = AudioResult()
let configuration = WKWebViewConfiguration()
configuration.mediaTypesRequiringUserActionForPlayback = []
configuration.userContentController.add(handler, name: "result")
let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 320, height: 240), configuration: configuration)
let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
window.contentView = view
window.makeKeyAndOrderFront(nil)
view.loadHTMLString("""
<!doctype html><script>
const report = text => window.webkit.messageHandlers.result.postMessage(text);
const bytes = Uint8Array.from(atob('\(audio.base64EncodedString())'), c => c.charCodeAt(0));
const a = new Audio(); a.muted = true;
a.ontimeupdate = () => { if (a.currentTime > 0.05) report('playing'); };
a.onerror = () => report('decode error ' + a.error?.code);
a.src = URL.createObjectURL(new Blob([bytes], {type:'audio/ogg'}));
a.play().catch(e => report(e.message));
</script>
""", baseURL: nil)
DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
    print("WebKit audio did not advance")
    exit(1)
}
NSApplication.shared.run()
