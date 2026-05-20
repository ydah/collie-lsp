import { workspace, window, ExtensionContext } from 'vscode';
import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions
} from 'vscode-languageclient/node';

let client: LanguageClient | undefined;

export function activate(context: ExtensionContext) {
  startClient();

  context.subscriptions.push(
    workspace.onDidChangeConfiguration(async (event) => {
      if (
        event.affectsConfiguration('collie-lsp.serverPath') ||
        event.affectsConfiguration('collie-lsp.trace.server')
      ) {
        await restartClient();
      }
    })
  );
}

export function deactivate(): Thenable<void> | undefined {
  if (!client) {
    return undefined;
  }

  return client.stop();
}

function startClient(): void {
  const serverOptions = createServerOptions();
  const clientOptions = createClientOptions();

  client = new LanguageClient('collie-lsp', 'Collie LSP', serverOptions, clientOptions);

  void client.start().catch((error: unknown) => {
    const message = error instanceof Error ? error.message : String(error);
    void window.showErrorMessage(`Failed to start collie-lsp: ${message}`);
  });
}

async function restartClient(): Promise<void> {
  if (client) {
    await client.stop();
    client = undefined;
  }

  startClient();
}

function createServerOptions(): ServerOptions {
  const config = workspace.getConfiguration('collie-lsp');
  const serverPath = config.get<string>('serverPath') || 'collie-lsp';

  return {
    command: serverPath,
    args: ['--stdio']
  };
}

function createClientOptions(): LanguageClientOptions {
  return {
    documentSelector: [{ scheme: 'file', language: 'yacc' }],
    synchronize: {
      fileEvents: workspace.createFileSystemWatcher('**/*.y')
    }
  };
}
