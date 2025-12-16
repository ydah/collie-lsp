# frozen_string_literal: true

module CollieLsp
  module Handlers
    # Quick fixes for autocorrectable offenses
    module CodeAction
      module_function

      # Handle textDocument/codeAction request
      # @param request [Hash] LSP request
      # @param document_store [DocumentStore] Document store
      # @param collie [CollieWrapper] Collie wrapper
      # @param writer [Object] Response writer
      def handle(request, document_store, collie, writer)
        uri = request[:params][:textDocument][:uri]
        range = request[:params][:range]
        doc = document_store.get(uri)

        unless doc
          writer.write(id: request[:id], result: [])
          return
        end

        # Get diagnostics in range
        diagnostics = doc[:diagnostics].select do |diag|
          in_range?(diag, range)
        end

        code_actions = []

        # Add "Fix all" action if there are any diagnostics
        if diagnostics.any?
          filename = uri.gsub(%r{^file://}, '')
          corrected = collie.autocorrect(doc[:text], filename: filename)

          code_actions << {
            title: 'Fix all auto-correctable offenses',
            kind: 'source.fixAll',
            edit: {
              changes: {
                uri => [{
                  range: full_document_range(doc[:text]),
                  newText: corrected
                }]
              }
            }
          }
        end

        writer.write(
          id: request[:id],
          result: code_actions
        )
      end

      # Check if a diagnostic is within the given range
      # @param diagnostic [Hash] LSP diagnostic
      # @param range [Hash] LSP range
      # @return [Boolean]
      def in_range?(diagnostic, range)
        diagnostic[:range][:start][:line] >= range[:start][:line] &&
          diagnostic[:range][:end][:line] <= range[:end][:line]
      end

      # Get the range covering the entire document
      # @param text [String] Document text
      # @return [Hash] LSP range
      def full_document_range(text)
        lines = text.lines.count
        {
          start: { line: 0, character: 0 },
          end: { line: lines, character: 0 }
        }
      end
    end
  end
end
