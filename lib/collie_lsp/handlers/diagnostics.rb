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
        doc = document_store.get(uri)
        diagnostics = offenses.map do |offense|
          offense_to_diagnostic(offense, text: doc&.dig(:text))
        end
        document_store.update_diagnostics(uri, diagnostics)

        params = {
          uri: uri,
          diagnostics: diagnostics
        }
        params[:version] = doc[:version] if doc&.key?(:version)

        writer.write(method: 'textDocument/publishDiagnostics', params: params)
      end

      # Convert a Collie offense to an LSP diagnostic
      # @param offense [Hash] Collie offense
      # @return [Hash] LSP diagnostic
      def offense_to_diagnostic(offense = nil, text: nil, **keywords)
        offense ||= keywords
        location = offense[:location] || { line: 1, column: 1 }
        length = offense[:length].to_i.positive? ? offense[:length].to_i : 1

        {
          range: Position.location_to_range(location.merge(length: length), text: text),
          severity: severity_to_lsp(offense[:severity]),
          code: offense[:rule_name] || 'unknown',
          source: 'collie',
          message: offense[:message] || 'Unknown error',
          data: {
            rule_name: offense[:rule_name] || 'unknown',
            autocorrect: autocorrectable?(offense[:rule_name])
          }
        }
      end

      def autocorrectable?(rule_name)
        %w[TrailingWhitespace TokenNaming NonterminalNaming UndefinedSymbol MissingStartSymbol].include?(rule_name)
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
