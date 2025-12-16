# frozen_string_literal: true

module CollieLsp
  module Handlers
    # Document formatting support
    module Formatting
      module_function

      # Handle textDocument/formatting request
      # @param request [Hash] LSP request
      # @param document_store [DocumentStore] Document store
      # @param collie [CollieWrapper] Collie wrapper
      # @param writer [Object] Response writer
      def handle(request, document_store, collie, writer)
        uri = request[:params][:textDocument][:uri]
        doc = document_store.get(uri)

        unless doc
          writer.write(id: request[:id], result: nil)
          return
        end

        filename = uri.gsub(%r{^file://}, '')
        formatted = collie.format(doc[:text], filename: filename)

        unless formatted
          writer.write(id: request[:id], result: nil)
          return
        end

        # Calculate text edits (replace entire document)
        edits = [{
          range: full_document_range(doc[:text]),
          newText: formatted
        }]

        writer.write(
          id: request[:id],
          result: edits
        )
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
