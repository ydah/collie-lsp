# frozen_string_literal: true

module CollieLsp
  module Protocol
    # Handles textDocument/* LSP messages
    module TextDocument
      module_function

      # Handle textDocument/didOpen notification
      # @param request [Hash] LSP request
      # @param document_store [DocumentStore] Document store
      # @param collie [CollieWrapper] Collie wrapper
      # @param writer [Object] Response writer
      def handle_did_open(request, document_store, collie, writer)
        params = request[:params]
        uri = params[:textDocument][:uri]
        text = params[:textDocument][:text]
        version = params[:textDocument][:version]
        language_id = params[:textDocument][:languageId]

        document_store.open(uri, text, version)
        document_store.update_language_id(uri, language_id)
        publish_diagnostics(uri, text, document_store, collie, writer)
      end

      # Handle textDocument/didChange notification
      # @param request [Hash] LSP request
      # @param document_store [DocumentStore] Document store
      # @param collie [CollieWrapper] Collie wrapper
      # @param writer [Object] Response writer
      def handle_did_change(request, document_store, collie, writer)
        params = request[:params]
        uri = params[:textDocument][:uri]
        version = params[:textDocument][:version]

        changes = params[:contentChanges]
        return unless changes&.any?

        document_store.change(uri, changes, version)
        doc = document_store.get(uri)
        publish_diagnostics(uri, doc[:text], document_store, collie, writer) if doc
      end

      # Handle textDocument/didSave notification
      # @param request [Hash] LSP request
      # @param document_store [DocumentStore] Document store
      # @param collie [CollieWrapper] Collie wrapper
      # @param writer [Object] Response writer
      def handle_did_save(request, document_store, collie, writer)
        params = request[:params]
        uri = params[:textDocument][:uri]
        doc = document_store.get(uri)

        return unless doc

        publish_diagnostics(uri, doc[:text], document_store, collie, writer)
      end

      # Handle textDocument/didClose notification
      # @param request [Hash] LSP request
      # @param document_store [DocumentStore] Document store
      # @param _collie [CollieWrapper] Collie wrapper (unused)
      # @param _writer [Object] Response writer (unused)
      def handle_did_close(request, document_store, _collie, writer)
        uri = request[:params][:textDocument][:uri]
        document_store.close(uri)

        Handlers::Diagnostics.publish(uri, [], document_store, writer)
      end

      # Publish diagnostics for a document
      # @param uri [String] Document URI
      # @param text [String] Document text
      # @param document_store [DocumentStore] Document store
      # @param collie [CollieWrapper] Collie wrapper
      # @param writer [Object] Response writer
      def publish_diagnostics(uri, text, document_store, collie, writer)
        filename = UriUtils.path_from_uri(uri)
        parse_result = collie.parse_result(text, filename: filename)
        document_store.update_ast(uri, parse_result.ast)
        document_store.update_parse_error(uri, parse_result.error)
        document_store.update_symbol_index(
          uri,
          parse_result.ast ? SymbolIndex.build(parse_result.ast, text) : nil
        )

        offenses = if parse_result.error
                     [parse_result.error]
                   else
                     collie.lint_ast(parse_result.ast)
                   end

        Handlers::Diagnostics.publish(uri, offenses, document_store, writer)
      end
    end
  end
end
