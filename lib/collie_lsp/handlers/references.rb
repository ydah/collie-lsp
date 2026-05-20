# frozen_string_literal: true

module CollieLsp
  module Handlers
    # Find all references to a symbol
    module References
      module_function

      # Handle textDocument/references request
      # @param request [Hash] LSP request
      # @param document_store [DocumentStore] Document store
      # @param collie [CollieWrapper] Collie wrapper
      # @param writer [Object] Response writer
      def handle(request, document_store, collie, writer)
        uri = request[:params][:textDocument][:uri]
        position = request[:params][:position]
        include_declaration = request[:params][:context][:includeDeclaration]
        doc = document_store.get(uri)

        unless doc
          writer.write(id: request[:id], result: [])
          return
        end

        index = Support.symbol_index_for(doc)
        unless index
          writer.write(id: request[:id], result: [])
          return
        end

        symbol = Support.symbol_at(doc, position)
        unless symbol
          writer.write(id: request[:id], result: [])
          return
        end

        locations = find_workspace_references(document_store, collie, symbol, include_declaration)

        writer.write(
          id: request[:id],
          result: locations
        )
      end

      # Find symbol at the given position
      # @param text [String] Document text
      # @param position [Hash] LSP position
      # @return [String, nil] Symbol name or nil
      def find_symbol_at_position(text, position)
        SymbolIndex.symbol_at(text, position)
      end

      # Find all references to a symbol
      # @param source [SymbolIndex, Object] Parsed symbol source
      # @param symbol [String] Symbol name
      # @param uri [String] Document URI
      # @param include_declaration [Boolean] Include declaration in results
      # @return [Array<Hash>] LSP locations
      def find_references(source, symbol, uri, include_declaration, text: nil)
        index = source.is_a?(SymbolIndex) ? source : SymbolIndex.build(source, '')
        index.references_for(symbol, include_declaration: include_declaration).map do |entry|
          Support.location_to_lsp(uri, entry[:location], text: text)
        end
      end

      def find_workspace_references(document_store, collie, symbol, include_declaration)
        locations = []
        WorkspaceIndex.each(document_store, collie) do |uri, text, index|
          locations.concat(find_references(index, symbol, uri, include_declaration, text: text))
        end
        locations
      end

      # Find declaration location for a symbol
      # @param ast [Hash] Parsed AST
      # @param symbol [String] Symbol name
      # @return [Hash, nil] Location hash or nil
      def find_declaration(ast, symbol)
        SymbolIndex.build(ast, '').definition_for(symbol)&.dig(:location)
      end

      # Estimate symbol location in text
      # @param text [String] Document text
      # @param rule [Hash] Rule containing the symbol
      # @param _alt_index [Integer] Alternative index (unused)
      # @param _sym_index [Integer] Symbol index (unused)
      # @param symbol [String] Symbol name
      # @return [Hash, nil] Location hash or nil
      def estimate_symbol_location(text, rule, _alt_index, _sym_index, symbol)
        # This is a simplified implementation that searches for the symbol
        # In a real implementation, positions would be tracked during parsing
        return nil unless rule[:location]

        search_symbol_from_line(text.lines, rule[:location][:line] - 1, symbol)
      end

      # Search for symbol starting from a specific line
      # @param lines [Array<String>] Document lines
      # @param start_line [Integer] Starting line number
      # @param symbol [String] Symbol to search for
      # @return [Hash, nil] Location hash or nil
      def search_symbol_from_line(lines, start_line, symbol)
        lines[start_line..].each_with_index do |line, offset|
          col = line.index(symbol)
          next unless col

          return {
            line: start_line + offset + 1,
            column: col + 1
          }
        end

        nil
      end

      # Create LSP location from position
      # @param uri [String] Document URI
      # @param location [Hash] Location hash with :line and :column
      # @param symbol [String] Symbol name
      # @return [Hash] LSP location
      def create_location(uri, location, symbol)
        line = location[:line] - 1
        column = location[:column] - 1

        {
          uri: uri,
          range: {
            start: { line: line, character: column },
            end: { line: line, character: column + symbol.length }
          }
        }
      end
    end
  end
end
