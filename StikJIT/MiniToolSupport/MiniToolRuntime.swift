import Foundation
import UniformTypeIdentifiers
import SwiftUI
import WebKit
import JavaScriptCore

final class MiniToolRuntime: NSObject, ObservableObject {
    let tool: MiniToolBundle
    let toolInfo: ToolInfo
    @Published var logs: [String] = []
    @Published var isReady: Bool = false

    var webView: WKWebView?
    private var context: JSContext?

    private var appXHRTasks: [String: URLSessionDataTask] = [:]

    private let messageHandlerName = "miniToolBridge"
    
    private var ideviceJSBridge : IDeviceJSBridge? = nil

    init(tool: MiniToolBundle, toolInfo: ToolInfo) {
        self.tool = tool
        self.toolInfo = toolInfo
        super.init()
        let configuration = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(source: MiniToolRuntime.frontendBridgeScript,
                                              injectionTime: .atDocumentStart,
                                              forMainFrameOnly: true))
        configuration.userContentController = controller
        let leakAvoider = LeakAvoider(delegate: self)
        configuration.setURLSchemeHandler(leakAvoider, forURLScheme: "app")
        webView = WKWebView(frame: .zero, configuration: configuration)
        controller.add(leakAvoider, name: messageHandlerName)
        webView!.navigationDelegate = self
        webView!.isInspectable = true
    }

    deinit {
        webView!.configuration.userContentController.removeScriptMessageHandler(forName: messageHandlerName)
    }

    func start() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
        loadBackground()
        loadFrontend()
    }

    func reload() {
        start()
    }

    // MARK: - Loading

    private func loadFrontend() {
        guard FileManager.default.fileExists(atPath: tool.indexURL.path) else {
            appendLog("index.html missing for \(tool.name)")
            return
        }
        isReady = false
        webView!.load(URLRequest(url: URL(string: "app://\(tool.getHostName())")!))
    }

    private func loadBackground() {
        context = JSContext()
        ideviceJSBridge = IDeviceJSBridge(context: context, allowedFunctions: toolInfo.requiredIDeviceFunctions ?? [])
        context?.exceptionHandler = { [weak self] _, exception in
            if let message = exception?.toString() {
                self?.appendLog("Background exception: \(message)")
            }
        }

        let sendToFrontend: @convention(block) (Any?) -> Void = { [weak self] payload in
            self?.deliverToFrontend(payload ?? NSNull())
        }
        
        let logFunction: @convention(block) (Any?) -> Void = { [weak self] msg in
            self?.appendLog(msg as? String ?? "Unable to decode log message.")
            
        }
        
        let ideviceFunction: @convention(block) (Any?) -> JSValue = { [weak self] msg in
            return JSValue.init(newPromiseIn: self?.context!) { resolve, reject in
                if let msg = msg as? [String: Any] {
                    if let bridge = self?.ideviceJSBridge {
                        bridge.didReceiveScriptMessage(msg, resolve: resolve, reject: reject);
                    } else {
                        resolve?.call(withArguments: ["Current Runtime is Terminated."])
                    }
                }
            }
        }
        context?.setObject(sendToFrontend, forKeyedSubscript: "__miniToolPostMessage" as NSString)
        context?.setObject(logFunction, forKeyedSubscript: "__miniToolLog" as NSString)
        context?.setObject(ideviceFunction, forKeyedSubscript: "__postIdeviceMessage" as NSString)

        context?.evaluateScript(MiniToolRuntime.backgroundBridgeScript)
        if let ideviceJSURL = Bundle.main.url(forResource: "idevice", withExtension: "js"),
           let ideviceJSText = try? String(contentsOf: ideviceJSURL, encoding: .utf8) {
            context?.evaluateScript(ideviceJSText)
        }

        do {
            let script = try String(contentsOf: tool.backgroundURL)
            context?.evaluateScript(script)
        } catch {
            appendLog("Failed to load background.js: \(error.localizedDescription)")
        }
    }

    private func deliverToBackground(_ payload: Any) {
        guard let receiver = context?.objectForKeyedSubscript("__miniToolReceive"),
              !receiver.isUndefined else {
            appendLog("Background handler is not ready")
            return
        }
        _ = receiver.call(withArguments: [payload])
    }

    private func deliverToFrontend(_ payload: Any) {
        guard let json = MiniToolRuntime.encodePayload(payload) else {
            appendLog("Unable to encode payload for frontend")
            return
        }
        DispatchQueue.main.async {
            let script = "window.miniTool && window.miniTool.__receive(\(json))"
            self.webView!.evaluateJavaScript(script) { _, error in
                if let error {
                    self.appendLog("Frontend dispatch error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func appendLog(_ text: String) {
        DispatchQueue.main.async {
            self.logs.append(text)
        }
    }
}

extension MiniToolRuntime : WKURLSchemeHandler {
    func webView(
        _ webView: WKWebView,
        start urlSchemeTask: WKURLSchemeTask
    ) {
        guard let url = urlSchemeTask.request.url else { return }
        
        guard let host = url.host(), host == tool.getHostName() else {
            urlSchemeTask.didFailWithError(NSError(domain: "Invalid Host Name", code: 404))
            return
        }

        let path = url.path.isEmpty ? "index.html" : url.path

        let fileURL = tool.url
            .appendingPathComponent(path).standardizedFileURL
        
        if fileURL.path().hasPrefix(tool.url.path()) {
            urlSchemeTask.didFailWithError(NSError(domain: "Path traversal is not allowed.", code: -1))
            return
        }
        
        if fileURL.path() == tool.url.appending(path: "check").path() {
            urlSchemeTask.didFailWithError(NSError(domain: "Reading this file is not allowed.", code: -1))
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let mimeType : String
            if let type = UTType(filenameExtension: fileURL.pathExtension), let mimetype = type.preferredMIMEType  {
                mimeType = mimetype
            } else {
                mimeType = UTType.data.preferredMIMEType!
            }

            let response = URLResponse(
                url: url,
                mimeType: mimeType,
                expectedContentLength: data.count,
                textEncodingName: nil
            )

            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        
    }
}

// MARK: - WKScriptMessageHandler

extension MiniToolRuntime: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == messageHandlerName else { return }
        if let dict = message.body as? [String: Any], dict["__appXHR"] as? Bool == true {
            handleAppXHRMessage(dict)
            return
        }
        if let dict = message.body as? [String: Any], let payload = dict["payload"] {
            deliverToBackground(payload)
        } else {
            deliverToBackground(message.body)
        }
    }
}

// MARK: - WKNavigationDelegate

extension MiniToolRuntime: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        // Don't allow loading other contents
        guard let url = navigationAction.request.url else {
            return WKNavigationActionPolicy.cancel
        }
        guard let scheme = url.scheme, scheme == "app" else {
            return WKNavigationActionPolicy.cancel
        }
        guard let host = url.host(), host == tool.getHostName() else {
            return WKNavigationActionPolicy.cancel
        }
        return WKNavigationActionPolicy.allow
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isReady = true
        deliverToBackground(["type": "ui-ready", "tool": tool.name])
        deliverToFrontend(["type": "ready", "tool": tool.name])
    }
    
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }
        
}

extension MiniToolRuntime: WKDownloadDelegate {
    
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String) async -> URL? {
        return MiniToolStore.toolsDataDirectory().appending(path: suggestedFilename, directoryHint: .notDirectory)
    }
}

// MARK: - Scripts & Encoding

extension MiniToolRuntime {
    static let frontendBridgeScript = """
        window.miniTool = window.miniTool || {};
        window.miniTool.__handler = null;
        window.miniTool.onMessage = function(handler) { window.miniTool.__handler = handler; };
        window.miniTool.postMessage = function(payload) {
            window.webkit.messageHandlers.miniToolBridge.postMessage({ payload: payload });
        };
        window.miniTool.__receive = function(payload) {
            try {
                if (typeof window.miniTool.__handler === 'function') {
                    window.miniTool.__handler(payload);
                }
            } catch (err) {
                console.error(err);
            }
        };

        (function() {
            const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.miniToolBridge;
            function safePostMessage(body) {
                if (!handler || !handler.postMessage) {
                    console.error('miniToolBridge unavailable for AppXMLHttpRequest');
                    return;
                }
                handler.postMessage(body);
            }

            function base64ToArrayBuffer(base64) {
                const binaryString = atob(base64);
                const len = binaryString.length;
                const bytes = new Uint8Array(len);
                for (let i = 0; i < len; i++) {
                    bytes[i] = binaryString.charCodeAt(i);
                }
                return bytes.buffer;
            }

            class AppXMLHttpRequest {
                constructor() {
                    this.readyState = 0;
                    this.status = 0;
                    this.statusText = '';
                    this.responseText = '';
                    this.response = null;
                    this.responseType = '';
                    this.onreadystatechange = null;
                    this.onload = null;
                    this.onerror = null;
                    this.onabort = null;
                    this._headers = {};
                    this._method = null;
                    this._url = null;
                    this._async = true;
                    this._aborted = false;
                    this._id = AppXMLHttpRequest.__nextId();
                }

                open(method, url, async = true) {
                    this._method = method;
                    this._url = url;
                    this._async = async !== false;
                    this.readyState = 1; // OPENED
                    this._emitReadyState();
                }

                setRequestHeader(key, value) {
                    this._headers[key] = value;
                }

                send(body = null) {
                    if (!this._method || !this._url) {
                        throw new Error('AppXMLHttpRequest: call open() before send().');
                    }

                    this.readyState = 2; // HEADERS_RECEIVED (simulated)
                    this._emitReadyState();

                    AppXMLHttpRequest.__pending[this._id] = this;

                    let encodedBody = null;
                    let bodyIsBase64 = false;
                    if (typeof body === 'string') {
                        encodedBody = body;
                    } else if (body instanceof ArrayBuffer || ArrayBuffer.isView(body)) {
                        const view = body instanceof ArrayBuffer ? new Uint8Array(body) : new Uint8Array(body.buffer, body.byteOffset || 0, body.byteLength || body.length || 0);
                        let binary = '';
                        for (let i = 0; i < view.length; i++) {
                            binary += String.fromCharCode(view[i]);
                        }
                        encodedBody = btoa(binary);
                        bodyIsBase64 = true;
                    } else if (body != null) {
                        try {
                            encodedBody = JSON.stringify(body);
                        } catch (err) {
                            console.error('AppXMLHttpRequest: unable to serialize body', err);
                        }
                    }

                    safePostMessage({
                        __appXHR: true,
                        action: 'request',
                        id: this._id,
                        method: this._method,
                        url: this._url,
                        async: this._async,
                        headers: this._headers,
                        body: encodedBody,
                        bodyIsBase64: bodyIsBase64,
                        responseType: this.responseType
                    });
                }

                abort() {
                    this._aborted = true;
                    safePostMessage({ __appXHR: true, action: 'abort', id: this._id });
                }

                _complete(payload) {
                    if (this._aborted && !payload.aborted) {
                        return;
                    }

                    this.status = payload.status || 0;
                    this.statusText = payload.statusText || '';
                    this.responseText = payload.responseText || '';
                    const base64 = payload.base64 || null;

                    if (this.responseType === 'json') {
                        try {
                            this.response = this.responseText ? JSON.parse(this.responseText) : null;
                        } catch (err) {
                            console.error('AppXMLHttpRequest: failed to parse JSON response', err);
                            this.response = null;
                        }
                    } else if (this.responseType === 'arraybuffer' && base64) {
                        this.response = base64ToArrayBuffer(base64);
                    } else {
                        this.response = this.responseText;
                    }

                    this.readyState = 4; // DONE
                    this._emitReadyState();

                    if (payload.aborted) {
                        if (typeof this.onabort === 'function') {
                            try { this.onabort(); } catch (err) { console.error(err); }
                        }
                        delete AppXMLHttpRequest.__pending[this._id];
                        return;
                    }

                    if (payload.error) {
                        if (typeof this.onerror === 'function') {
                            try { this.onerror(new Error(payload.error)); } catch (err) { console.error(err); }
                        }
                    } else if (typeof this.onload === 'function') {
                        try { this.onload(); } catch (err) { console.error(err); }
                    }

                    delete AppXMLHttpRequest.__pending[this._id];
                }

                _emitReadyState() {
                    if (typeof this.onreadystatechange === 'function') {
                        try {
                            this.onreadystatechange();
                        } catch (err) {
                            console.error(err);
                        }
                    }
                }

                static __nextId() {
                    AppXMLHttpRequest.__counter += 1;
                    return `app-xhr-${AppXMLHttpRequest.__counter}`;
                }

                static __receive(payload) {
                    const instance = AppXMLHttpRequest.__pending[payload.id];
                    if (instance) {
                        instance._complete(payload);
                    }
                }
            }

            AppXMLHttpRequest.__counter = 0;
            AppXMLHttpRequest.__pending = {};

            window.__XMLHttpRequest = window.XMLHttpRequest;
            window.XMLHttpRequest = AppXMLHttpRequest; // alias with requested casing
        })();
    """

    static let backgroundBridgeScript = """
        var miniTool = this.miniTool || {};
        miniTool.__handler = null;
        miniTool.onMessage = function(handler) { miniTool.__handler = handler; };
        miniTool.postMessage = function(payload) { __miniToolPostMessage(payload); };
        miniTool.log = function(log) { __miniToolLog(log); }
        function __miniToolReceive(payload) {
            try {
                if (typeof miniTool.__handler === 'function') {
                    miniTool.__handler(payload);
                }
            } catch (err) {
                console.log(err);
            }
        }
        this.miniTool = miniTool;
    """

    static func encodePayload(_ payload: Any) -> String? {
        if JSONSerialization.isValidJSONObject(payload) {
            if let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
               let string = String(data: data, encoding: .utf8) {
                return string
            }
        }
        if let string = payload as? String {
            let escaped = string.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        }
        if let number = payload as? NSNumber {
            return number.stringValue
        }
        return nil
    }
}

// MARK: - App-backed XHR

private extension MiniToolRuntime {
    func handleAppXHRMessage(_ payload: [String: Any]) {
        guard let capabilities = toolInfo.capabilities, capabilities.internetAccess ?? false else {
            appendLog("Internet access is disabled! To enable it, enable internetAccess in toolInfo.json")
            return
        }
        
        guard let id = payload["id"] as? String else {
            appendLog("AppXHR missing id")
            return
        }

        let action = payload["action"] as? String ?? "request"

        if action == "abort" {
            if let task = appXHRTasks[id] {
                task.cancel()
                appXHRTasks[id] = nil
            }
            deliverAppXHRResponse(["id": id, "status": 0, "statusText": "aborted", "aborted": true])
            return
        }

        guard let urlString = payload["url"] as? String, let url = URL(string: urlString) else {
            appendLog("AppXHR invalid URL for id \(id)")
            deliverAppXHRResponse(["id": id, "status": 0, "statusText": "invalid-url", "error": "Invalid URL"])
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = (payload["method"] as? String) ?? "GET"

        if let headers = payload["headers"] as? [String: Any] {
            headers.forEach { key, value in
                if let valueString = value as? String ?? (value as? NSNumber)?.stringValue {
                    request.setValue(valueString, forHTTPHeaderField: key)
                }
            }
        }

        if let body = payload["body"] {
            let isBase64 = payload["bodyIsBase64"] as? Bool ?? false
            if let stringBody = body as? String {
                if isBase64, let data = Data(base64Encoded: stringBody) {
                    request.httpBody = data
                } else {
                    request.httpBody = stringBody.data(using: .utf8)
                }
            } else if JSONSerialization.isValidJSONObject(body),
                      let data = try? JSONSerialization.data(withJSONObject: body, options: []) {
                request.httpBody = data
            }
        }

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            var responsePayload: [String: Any] = [
                "id": id,
                "status": 0,
                "statusText": ""
            ]

            if let http = response as? HTTPURLResponse {
                responsePayload["status"] = http.statusCode
                responsePayload["statusText"] = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)

                let headers = http.allHeaderFields.reduce(into: [String: String]()) { partialResult, entry in
                    if let key = entry.key as? String {
                        partialResult[key] = String(describing: entry.value)
                    }
                }
                responsePayload["headers"] = headers
            }

            if let error = error as NSError? {
                if error.code == NSURLErrorCancelled {
                    responsePayload["aborted"] = true
                    responsePayload["statusText"] = "aborted"
                } else {
                    responsePayload["error"] = error.localizedDescription
                }
            }

            if let data = data {
                responsePayload["responseText"] = String(data: data, encoding: .utf8) ?? ""
                responsePayload["base64"] = data.base64EncodedString()
            }

            DispatchQueue.main.async {
                self.appXHRTasks[id] = nil
                self.deliverAppXHRResponse(responsePayload)
            }
        }

        appXHRTasks[id] = task
        task.resume()
    }

    func deliverAppXHRResponse(_ payload: [String: Any]) {
        guard let json = MiniToolRuntime.encodePayload(payload) else {
            appendLog("AppXHR: Unable to encode response for id \(payload["id"] ?? "<unknown>")")
            return
        }

        DispatchQueue.main.async {
            let script = "window.XMLHttpRequest.__receive(\(json))"
            self.webView!.evaluateJavaScript(script) { _, error in
                if let error {
                    self.appendLog("AppXHR deliver error: \(error.localizedDescription)")
                }
            }
        }
    }
}

class LeakAvoider : NSObject, WKURLSchemeHandler, WKScriptMessageHandler, WKDownloadDelegate {
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String) async -> URL? {
        return await self.delegate?.download(download, decideDestinationUsing: response, suggestedFilename: suggestedFilename)
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        self.delegate?.userContentController(userContentController, didReceive: message)
    }
    
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        self.delegate?.webView(webView, start: urlSchemeTask)
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        self.delegate?.webView(webView, stop: urlSchemeTask)
    }
    
    
    
    weak var delegate : (WKURLSchemeHandler & WKScriptMessageHandler & WKDownloadDelegate)?
    init (delegate:WKURLSchemeHandler & WKScriptMessageHandler & WKDownloadDelegate) {
        self.delegate = delegate
        super.init()
    }
    
}
