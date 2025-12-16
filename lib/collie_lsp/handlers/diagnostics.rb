# frozen_string_literal: true

module CollieLsp
  module Handlers
    # Converts Collie offenses to LSP diagnostics
    module Diagnostics
      module_function

      # Publish diagnostics for a document
      # @param uri [String] Document URI
      # @param offenses [Array<Hash>] Collie offenses
      # @param document_store [DocumentStore] Document store
      # @param writer [Object] Response writer
      def publish(uri, offenses, document_store, writer)
        diagnostics = offenses.map do |offense|
          offense_to_diagnostic(offense)
        end

        document_store.update_diagnostics(uri, diagnostics)

        writer.write(
          method: 'textDocument/publishDiagnostics',
          params: {
            uri: uri,
            diagnostics: diagnostics
          }
        )
      end

      # Convert a Collie offense to an LSP diagnostic
      # @param offense [Hash] Collie offense
      # @return [Hash] LSP diagnostic
      def offense_to_diagnostic(offense)
        location = offense[:location] || { line: 1, column: 1 }
        line = location[:line] - 1 # LSP is 0-indexed
        column = location[:column] - 1

        {
          range: {
            start: { line: line, character: column },
            end: { line: line, character: column + 10 } # Approximate
          },
          severity: severity_to_lsp(offense[:severity]),
          code: offense[:rule_name] || 'unknown',
          source: 'collie',
          message: offense[:message] || 'Unknown error'
        }
      end

      # Convert Collie severity to LSP severity
      # @param severity [Symbol] Collie severity (:error, :warning, :convention, :info)
      # @return [Integer] LSP severity (1-4)
      def severity_to_lsp(severity)
        case severity
        when :error then 1    # Error
        when :warning then 2  # Warning
        when :convention then 3 # Information
        when :info then 4 # Hint
        else 3
        end
      end
    end
  end
end
