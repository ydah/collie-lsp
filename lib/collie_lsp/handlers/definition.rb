# frozen_string_literal: true

module CollieLsp
  module Handlers
    # Go to definition support
    module Definition
      module_function

      # Handle textDocument/definition request
      # @param request [Hash] LSP request
      # @param document_store [DocumentStore] Document store
      # @param _collie [CollieWrapper] Collie wrapper (unused)
      # @param writer [Object] Response writer
      def handle(request, document_store, _collie, writer)
        uri = request[:params][:textDocument][:uri]
        position = request[:params][:position]
        doc = document_store.get(uri)

        unless doc
          writer.write(id: request[:id], result: nil)
          return
        end

        index = Support.symbol_index_for(doc)
        unless index
          writer.write(id: request[:id], result: nil)
          return
        end

        symbol = Support.symbol_at(doc, position)
        unless symbol
          writer.write(id: request[:id], result: nil)
          return
        end

        location = find_definition_location(index, symbol, uri)

        if location
          writer.write(id: request[:id], result: location)
        else
          writer.write(id: request[:id], result: nil)
        end
      end

      # Find symbol at the given position
      # @param text [String] Document text
      # @param position [Hash] LSP position
      # @return [String, nil] Symbol name or nil
      def find_symbol_at_position(text, position)
        SymbolIndex.symbol_at(text, position)
      end

      # Find definition location for a symbol
      # @param source [SymbolIndex, Object] Parsed symbol source
      # @param symbol [String] Symbol name
      # @param uri [String] Document URI
      # @return [Hash, nil] LSP location or nil
      def find_definition_location(source, symbol, uri)
        index = source.is_a?(SymbolIndex) ? source : SymbolIndex.build(source, '')
        entry = index.definition_for(symbol)
        return nil unless entry

        Support.location_to_lsp(uri, entry[:location])
      end
    end
  end
end
