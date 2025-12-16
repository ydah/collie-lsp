import * as path from 'path';
import { workspace, ExtensionContext } from 'vscode';
import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
  TransportKind
} from 'vscode-languageclient/node';

let client: LanguageClient;

export function activate(context: ExtensionContext) {
  // Get server path from configuration
  const config = workspace.getConfiguration('collie-lsp');
  const serverPath = config.get<string>('serverPath') || 'collie-lsp';

  // Server options
  const serverOptions: ServerOptions = {
    command: serverPath,
    args: ['--stdio'],
    transport: TransportKind.stdio
  };

  // Client options
  const clientOptions: LanguageClientOptions = {
    documentSelector: [{ scheme: 'file', language: 'yacc' }],
    synchronize: {
      fileEvents: workspace.createFileSystemWatcher('**/.y')
    }
  };

  // Create and start the client
  client = new LanguageClient(
    'collie-lsp',
    'Collie LSP',
    serverOptions,
    clientOptions
  );

  client.start();
}

export function deactivate(): Thenable<void> | undefined {
  if (!client) {
    return undefined;
  }
  return client.stop();
}
