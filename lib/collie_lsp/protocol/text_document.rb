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

        document_store.open(uri, text, version)
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

        # For full document sync (change: 1)
        return unless params[:contentChanges]&.first&.dig(:text)

        text = params[:contentChanges].first[:text]
        document_store.change(uri, text, version)
        publish_diagnostics(uri, text, document_store, collie, writer)
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
      def handle_did_close(request, document_store, _collie, _writer)
        uri = request[:params][:textDocument][:uri]
        document_store.close(uri)
      end

      # Publish diagnostics for a document
      # @param uri [String] Document URI
      # @param text [String] Document text
      # @param document_store [DocumentStore] Document store
      # @param collie [CollieWrapper] Collie wrapper
      # @param writer [Object] Response writer
      def publish_diagnostics(uri, text, document_store, collie, writer)
        filename = uri.gsub(%r{^file://}, '')
        offenses = collie.lint(text, filename: filename)

        Handlers::Diagnostics.publish(uri, offenses, document_store, writer)
      end
    end
  end
end
