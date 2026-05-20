# frozen_string_literal: true

module CollieLsp
  module Handlers
    # Rename symbol support
    module Rename
      module_function

      # Handle textDocument/rename request
      # @param request [Hash] LSP request
      # @param document_store [DocumentStore] Document store
      # @param _collie [CollieWrapper] Collie wrapper (unused)
      # @param writer [Object] Response writer
      def handle(request, document_store, _collie, writer)
        uri = request[:params][:textDocument][:uri]
        position = request[:params][:position]
        new_name = request[:params][:newName]
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

        # Validate new name
        unless valid_name?(symbol, new_name, index)
          writer.write(id: request[:id], result: nil)
          return
        end

        # Build workspace edit with all occurrences
        workspace_edit = build_workspace_edit(uri, symbol, new_name, doc[:text], index)

        writer.write(
          id: request[:id],
          result: workspace_edit
        )
      end

      # Find symbol at the given position
      # @param text [String] Document text
      # @param position [Hash] LSP position
      # @return [String, nil] Symbol name or nil
      def find_symbol_at_position(text, position)
        SymbolIndex.symbol_at(text, position)
      end

      # Validate the new name based on symbol type
      # @param old_name [String] Old symbol name
      # @param new_name [String] New symbol name
      # @param ast [Hash] Parsed AST
      # @return [Boolean] True if valid
      def valid_name?(old_name, new_name, ast)
        return false if new_name.empty?
        return false if old_name.match?(/\A\$\d+\z/) || old_name == '$$'

        index = ast.is_a?(SymbolIndex) ? ast : SymbolIndex.build(ast, '')
        entry = index.definition_for(old_name)
        old_name = old_name.delete_prefix('$') if old_name.start_with?('$')

        # Check if old symbol is a token (should be UPPER_CASE)
        is_token = entry&.dig(:kind) == :token

        pattern = if is_token
                    # Token names should be uppercase
                    /^[A-Z][A-Z0-9_]*$/
                  else
                    # Nonterminal names should be lowercase
                    /^[a-z][a-z0-9_]*$/
                  end

        !!(new_name =~ pattern)
      end

      # Build workspace edit with all rename changes
      # @param uri [String] Document URI
      # @param old_name [String] Old symbol name
      # @param new_name [String] New symbol name
      # @param text [String] Document text
      # @param ast [Hash] Parsed AST
      # @return [Hash] LSP workspace edit
      def build_workspace_edit(uri, old_name, new_name, text, ast)
        # Find all occurrences of the symbol
        index = ast.is_a?(SymbolIndex) ? ast : SymbolIndex.build(ast, text)
        occurrences = index.all_occurrences(old_name)

        edits = occurrences.map do |entry|
          loc = entry[:location]
          length = loc[:length].to_i.positive? ? loc[:length].to_i : entry[:name].length
          {
            range: {
              start: {
                line: loc[:line] - 1,
                character: loc[:column] - 1
              },
              end: {
                line: loc[:line] - 1,
                character: loc[:column] + length - 1
              }
            },
            newText: rename_text(entry, new_name)
          }
        end

        {
          changes: {
            uri => edits
          }
        }
      end

      def rename_text(entry, new_name)
        entry[:name].start_with?('$') ? "$#{new_name.delete_prefix('$')}" : new_name.delete_prefix('$')
      end

      # Find all occurrences of a symbol in the document
      # @param text [String] Document text
      # @param symbol [String] Symbol to find
      # @param ast [Hash] Parsed AST
      # @return [Array<Hash>] Array of locations
      def find_all_occurrences(text, symbol, ast)
        index = ast.is_a?(SymbolIndex) ? ast : SymbolIndex.build(ast, text)
        index.all_occurrences(symbol).map { |entry| entry[:location] }
      end

      # Find declaration location
      # @param ast [Hash] Parsed AST
      # @param symbol [String] Symbol name
      # @return [Hash, nil] Location or nil
      def find_declaration_location(ast, symbol)
        SymbolIndex.build(ast, '').definition_for(symbol)&.dig(:location)
      end

      # Find all usage locations in rules
      # @param text [String] Document text
      # @param symbol [String] Symbol to find
      # @param ast [Hash] Parsed AST
      # @return [Array<Hash>] Array of locations
      def find_usage_locations(text, symbol, ast)
        locations = []
        lines = text.lines

        ast[:rules]&.each do |rule|
          next unless rule[:location]

          # Search from rule location onwards
          start_line = rule[:location][:line] - 1
          search_end = find_rule_end(lines, start_line)

          (start_line..search_end).each do |line_idx|
            line = lines[line_idx]
            next unless line

            # Find all occurrences in this line
            col = 0
            while (pos = line.index(symbol, col))
              # Verify it's a whole word (not part of another identifier)
              before_char = pos.positive? ? line[pos - 1] : ' '
              after_char = line[pos + symbol.length] || ' '

              if before_char !~ /[A-Za-z0-9_]/ && after_char !~ /[A-Za-z0-9_]/
                locations << {
                  line: line_idx + 1,
                  column: pos + 1
                }
              end

              col = pos + 1
            end
          end
        end

        locations
      end

      # Find the end line of a rule
      # @param lines [Array<String>] Document lines
      # @param start_line [Integer] Rule start line
      # @return [Integer] End line index
      def find_rule_end(lines, start_line)
        # Look for the semicolon that ends the rule
        (start_line...lines.length).each do |idx|
          return idx if lines[idx]&.include?(';')
        end

        lines.length - 1
      end
    end
  end
end
