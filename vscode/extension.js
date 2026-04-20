const vscode = require('vscode');
const fs = require('fs');
const path = require('path');
const os = require('os');

const log = vscode.window.createOutputChannel('Majorelle');

const ATTENTION_FILE = path.join(os.homedir(), '.claude', 'attention.json');

function openUrl(url) {
  log.appendLine('Opening URL: ' + url);
  vscode.commands.executeCommand('simpleBrowser.show', url);
}

function readAttentionState() {
  try {
    const raw = fs.readFileSync(ATTENTION_FILE, 'utf8');
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
  } catch (e) {
    return {};
  }
}

function writeAttentionState(state) {
  try {
    fs.mkdirSync(path.dirname(ATTENTION_FILE), { recursive: true });
    const tmp = ATTENTION_FILE + '.tmp-' + process.pid;
    fs.writeFileSync(tmp, JSON.stringify(state, null, 2));
    fs.renameSync(tmp, ATTENTION_FILE);
  } catch (e) {
    log.appendLine('attention: write failed: ' + e.message);
  }
}

function isInsideWorkspace(cwd) {
  const folders = vscode.workspace.workspaceFolders || [];
  if (!folders.length || !cwd) return false;
  const normalized = path.resolve(cwd);
  return folders.some(folder => {
    const root = path.resolve(folder.uri.fsPath);
    return normalized === root || normalized.startsWith(root + path.sep);
  });
}

function formatAge(seconds) {
  const s = Math.max(0, Math.floor(seconds));
  if (s < 60) return `${s}s ago`;
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  return `${Math.floor(s / 86400)}d ago`;
}

class AttentionProvider {
  constructor() {
    this._emitter = new vscode.EventEmitter();
    this.onDidChangeTreeData = this._emitter.event;
    this.entries = [];
  }

  refresh() {
    const state = readAttentionState();
    this.entries = Object.values(state)
      .filter(e => e && e.session_id && isInsideWorkspace(e.cwd))
      .sort((a, b) => (b.ts || 0) - (a.ts || 0));
    this._emitter.fire();
  }

  getTreeItem(entry) {
    const folder = (entry.cwd && path.basename(entry.cwd)) || '';
    const snippet = (entry.last_text || '').trim().replace(/\n/g, ' ');
    const age = formatAge(Date.now() / 1000 - (entry.ts || 0));

    const label = snippet
      ? (snippet.length > 60 ? snippet.slice(0, 60) + '…' : snippet)
      : (folder || entry.session_id.slice(0, 8));
    const description = folder ? `${age} · ${folder}` : age;

    const item = new vscode.TreeItem(label, vscode.TreeItemCollapsibleState.None);
    item.description = description;
    item.tooltip = new vscode.MarkdownString(
      [
        snippet ? `> ${snippet}` : '_(no message yet)_',
        `**cwd:** \`${entry.cwd || '(none)'}\``,
        `**session:** \`${entry.session_id}\``,
        `**shell pid:** \`${entry.shell_pid}\``,
      ].join('\n\n')
    );
    item.iconPath = new vscode.ThemeIcon(
      entry.kind === 'notification' ? 'warning'
      : entry.kind === 'running' ? 'play'
      : 'bell-dot'
    );
    item.contextValue = 'majorelleAttentionEntry';
    item.command = {
      command: 'majorelle.attention.focus',
      title: 'Focus Terminal',
      arguments: [entry],
    };
    return item;
  }

  getChildren() {
    return this.entries;
  }

  count() {
    return this.entries.length;
  }
}

async function focusTerminal(entry) {
  if (!entry || !entry.shell_pid) return;
  for (const terminal of vscode.window.terminals) {
    const pid = await terminal.processId;
    if (pid === entry.shell_pid) {
      terminal.show(false);
      return;
    }
  }
  vscode.window.showInformationMessage(
    `Majorelle: no terminal matches session ${entry.session_id.slice(0, 8)} (pid ${entry.shell_pid}). It may have been closed.`
  );
}

function clearEntry(entry) {
  const sid = entry && entry.session_id;
  if (!sid) return;
  const state = readAttentionState();
  if (state[sid]) {
    delete state[sid];
    writeAttentionState(state);
  }
}

function clearAll(provider) {
  // Only clear entries that belong to this workspace so other windows keep theirs.
  const state = readAttentionState();
  let changed = false;
  for (const [sid, entry] of Object.entries(state)) {
    if (isInsideWorkspace(entry && entry.cwd)) {
      delete state[sid];
      changed = true;
    }
  }
  if (changed) writeAttentionState(state);
  provider.refresh();
}

function activate(context) {
  log.appendLine('Majorelle activated');

  context.subscriptions.push(
    vscode.window.registerUriHandler({
      handleUri(uri) {
        log.appendLine('URI received - full: ' + uri.toString());
        const raw = uri.toString();
        const match = raw.match(/majorelle\/(.+)$/);
        const url = match ? decodeURIComponent(match[1]) : null;
        if (url) openUrl(url);
      },
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
        if (input) openUrl(input);
      });
    })
  );

  const provider = new AttentionProvider();
  const tree = vscode.window.createTreeView('majorelle.attention', {
    treeDataProvider: provider,
    showCollapseAll: false,
  });
  context.subscriptions.push(tree);

  const syncView = () => {
    provider.refresh();
    const n = provider.count();
    tree.badge = n > 0 ? { value: n, tooltip: `${n} Claude session${n === 1 ? '' : 's'} need attention` } : undefined;
    tree.title = n > 0 ? `Claude · Attention (${n})` : 'Claude · Attention';
  };
  syncView();

  // Ensure the state dir exists so fs.watch has something to watch.
  try {
    fs.mkdirSync(path.dirname(ATTENTION_FILE), { recursive: true });
  } catch (e) {
    log.appendLine('attention: mkdir failed: ' + e.message);
  }

  let watcher;
  try {
    watcher = fs.watch(path.dirname(ATTENTION_FILE), (eventType, filename) => {
      if (filename === path.basename(ATTENTION_FILE)) syncView();
    });
  } catch (e) {
    log.appendLine('attention: watch failed: ' + e.message);
  }
  if (watcher) context.subscriptions.push({ dispose: () => watcher.close() });

  context.subscriptions.push(
    vscode.workspace.onDidChangeWorkspaceFolders(syncView),
    tree.onDidChangeVisibility(e => { if (e.visible) syncView(); })
  );

  // Polling safety net — keeps "Xm ago" descriptions current.
  const interval = setInterval(syncView, 5_000);
  context.subscriptions.push({ dispose: () => clearInterval(interval) });

  context.subscriptions.push(
    vscode.commands.registerCommand('majorelle.attention.focus', focusTerminal)
  );
  context.subscriptions.push(
    vscode.commands.registerCommand('majorelle.attention.clear', (entry) => {
      clearEntry(entry);
      syncView();
    })
  );
  context.subscriptions.push(
    vscode.commands.registerCommand('majorelle.attention.clearAll', () => clearAll(provider))
  );
  context.subscriptions.push(
    vscode.commands.registerCommand('majorelle.attention.refresh', syncView)
  );
}

function deactivate() {}

module.exports = { activate, deactivate };
