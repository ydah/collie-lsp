# frozen_string_literal: true

module CollieLsp
  module Handlers
    # Show information on hover
    module Hover
      module_function

      # Handle textDocument/hover request
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

        ast = doc[:ast]
        unless ast
          writer.write(id: request[:id], result: nil)
          return
        end

        # Find symbol at position
        symbol = find_symbol_at_position(doc[:text], position)
        unless symbol
          writer.write(id: request[:id], result: nil)
          return
        end

        hover_content = build_hover_content(ast, symbol)

        if hover_content
          writer.write(
            id: request[:id],
            result: {
              contents: hover_content
            }
          )
        else
          writer.write(id: request[:id], result: nil)
        end
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

      # Build hover content for a symbol
      # @param ast [Hash] Parsed AST
      # @param symbol [String] Symbol name
      # @return [Hash, nil] LSP markup content or nil
      def build_hover_content(ast, symbol)
        # Check if it's a token
        ast[:declarations]&.each do |decl|
          next unless decl[:kind] == :token

          if decl[:names]&.include?(symbol)
            return {
              kind: 'markdown',
              value: "**Token**: `#{symbol}`\n\nType: `#{decl[:type_tag] || 'none'}`"
            }
          end
        end

        # Check if it's a nonterminal
        rule = ast[:rules]&.find { |r| r[:name] == symbol }
        if rule
          alt_count = rule[:alternatives]&.size || 0
          return {
            kind: 'markdown',
            value: "**Nonterminal**: `#{symbol}`\n\n#{alt_count} alternative(s)"
          }
        end

        nil
      end
    end
  end
end
