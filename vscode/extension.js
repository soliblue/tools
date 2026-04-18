const vscode = require('vscode');

const log = vscode.window.createOutputChannel('Majorelle');

function openUrl(url) {
  log.appendLine('Opening URL: ' + url);
  vscode.commands.executeCommand('simpleBrowser.show', url);
}

function activate(context) {
  log.appendLine('Majorelle activated');

  context.subscriptions.push(
    vscode.window.registerUriHandler({
      handleUri(uri) {
        log.appendLine('URI received - full: ' + uri.toString());
        log.appendLine('URI path: ' + uri.path);
        log.appendLine('URI query: ' + uri.query);
        log.appendLine('URI fragment: ' + uri.fragment);

        const raw = uri.toString();
        const match = raw.match(/majorelle\/(.+)$/);
        const url = match ? decodeURIComponent(match[1]) : null;

        log.appendLine('Extracted URL: ' + url);
        if (url) {
          openUrl(url);
        }
      }
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('majorelle.openInBrowser', (url) => {
      if (url) {
        openUrl(url);
        return;
      }
      const editor = vscode.window.activeTextEditor;
      const selection = editor?.document.getText(editor.selection);
      if (selection && (selection.startsWith('http://') || selection.startsWith('https://'))) {
        openUrl(selection.trim());
        return;
      }
      vscode.window.showInputBox({ prompt: 'URL to open', placeHolder: 'https://' }).then(input => {
        if (input) {
          openUrl(input);
        }
      });
    })
  );
}

function deactivate() {}

module.exports = { activate, deactivate };
