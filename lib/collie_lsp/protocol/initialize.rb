# frozen_string_literal: true

module CollieLsp
  module Protocol
    # Handles initialize and initialized LSP messages
    module Initialize
      module_function

      # Handle initialize request
      # @param request [Hash] LSP request
      # @param writer [Object] Response writer
      def handle(request, writer)
        writer.write(
          id: request[:id],
          result: {
            capabilities: {
              textDocumentSync: {
                openClose: true,
                change: 2, # Incremental
                save: { includeText: true }
              },
              documentFormattingProvider: true,
              codeActionProvider: true,
              hoverProvider: true,
              completionProvider: {
                triggerCharacters: ['%', '$']
              },
              definitionProvider: true,
              referencesProvider: true,
              documentSymbolProvider: true,
              renameProvider: true,
              semanticTokensProvider: {
                legend: {
                  tokenTypes: Handlers::SemanticTokens::TOKEN_TYPES,
                  tokenModifiers: Handlers::SemanticTokens::TOKEN_MODIFIERS
                },
                full: true
              },
              workspaceSymbolProvider: true,
              foldingRangeProvider: true
            },
            serverInfo: {
              name: 'collie-lsp',
              version: CollieLsp::VERSION
            }
          }
        )
      end

      # Handle initialized notification
      # @param _request [Hash] LSP request
      # @param _writer [Object] Response writer
      def handle_initialized(_request, _writer)
        # Nothing to do for initialized notification
      end
    end
  end
end
