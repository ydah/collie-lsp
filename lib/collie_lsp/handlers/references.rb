# frozen_string_literal: true

module CollieLsp
  module Handlers
    # Find all references to a symbol
    module References
      module_function

      # Handle textDocument/references request
      # @param request [Hash] LSP request
      # @param document_store [DocumentStore] Document store
      # @param _collie [CollieWrapper] Collie wrapper (unused)
      # @param writer [Object] Response writer
      def handle(request, document_store, _collie, writer)
        uri = request[:params][:textDocument][:uri]
        position = request[:params][:position]
        include_declaration = request[:params][:context][:includeDeclaration]
        doc = document_store.get(uri)

        unless doc
          writer.write(id: request[:id], result: [])
          return
        end

        ast = doc[:ast]
        unless ast
          writer.write(id: request[:id], result: [])
          return
        end

        # Find symbol at position
        symbol = find_symbol_at_position(doc[:text], position)
        unless symbol
          writer.write(id: request[:id], result: [])
          return
        end

        locations = find_references(ast, symbol, uri, doc[:text], include_declaration)

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
        lines = text.lines
        line = lines[position[:line]]
        return nil unless line

        # Extract word at character position
        char = position[:character]
        start_pos = char
        end_pos = char

        # Move backwards to find word start
        start_pos -= 1 while start_pos.positive? && line[start_pos - 1] =~ /[A-Za-z0-9_]/
        # Move forwards to find word end
        end_pos += 1 while end_pos < line.length && line[end_pos] =~ /[A-Za-z0-9_]/

        line[start_pos...end_pos]
      end

      # Find all references to a symbol
      # @param ast [Hash] Parsed AST
      # @param symbol [String] Symbol name
      # @param uri [String] Document URI
      # @param text [String] Document text
      # @param include_declaration [Boolean] Include declaration in results
      # @return [Array<Hash>] LSP locations
      def find_references(ast, symbol, uri, text, include_declaration)
        locations = []

        # Find declaration location
        declaration_loc = find_declaration(ast, symbol)

        # Add declaration if requested
        locations << create_location(uri, declaration_loc, symbol) if include_declaration && declaration_loc

        # Find all usages in rules
        locations.concat(find_usage_in_rules(ast, symbol, uri, text))

        locations
      end

      # Find symbol usage in grammar rules
      # @param ast [Hash] Parsed AST
      # @param symbol [String] Symbol name
      # @param uri [String] Document URI
      # @param text [String] Document text
      # @return [Array<Hash>] LSP locations
      def find_usage_in_rules(ast, symbol, uri, text)
        locations = []

        ast[:rules]&.each do |rule|
          rule[:alternatives]&.each_with_index do |alt, alt_index|
            alt[:symbols]&.each_with_index do |sym, sym_index|
              next unless sym[:name] == symbol

              loc = estimate_symbol_location(text, rule, alt_index, sym_index, symbol)
              locations << create_location(uri, loc, symbol) if loc
            end
          end
        end

        locations
      end

      # Find declaration location for a symbol
      # @param ast [Hash] Parsed AST
      # @param symbol [String] Symbol name
      # @return [Hash, nil] Location hash or nil
      def find_declaration(ast, symbol)
        # Check token declarations
        ast[:declarations]&.each do |decl|
          next unless decl[:kind] == :token

          return decl[:location] if decl[:names]&.include?(symbol) && decl[:location]
        end

        # Check nonterminal rules
        rule = ast[:rules]&.find { |r| r[:name] == symbol }
        return rule[:location] if rule && rule[:location]

        nil
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
