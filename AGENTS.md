# Popup Bridge iOS — Agent Context

## Overview

Popup Bridge is an iOS library that lets a `WKWebView` open a popup in an external browser and receive the result back, using a JavaScript bridge. The public entry point is `POPPopupBridge`, initialized with a `WKWebView` (and optionally a `returnURLScheme` for app-switch flows such as Venmo). It injects a `WKUserScript` exposing `window.popupBridge` to the page; web content calls `window.popupBridge.open(url)`, which posts a message to the native `WKScriptMessageHandler`. The library opens the URL in an `ASWebAuthenticationSession`; when the session returns via its callback URL scheme, the payload is delivered back to the page via `window.popupBridge.onComplete` (or `onCancel`).

## Commits

- If an AI agent authored or substantially wrote the changes in a commit, end the
  message with a blank line and a trailer naming the model:

      Co-Authored-By: <model name> <vendor email address>

  Use the model you are actually running as, e.g. `Claude Sonnet 5.5`. If your harness
  already has its own co-author rule, follow it instead of this one.
