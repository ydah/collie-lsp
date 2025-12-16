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

        location = find_definition_location(ast, symbol, uri)

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

      # Find definition location for a symbol
      # @param ast [Hash] Parsed AST
      # @param symbol [String] Symbol name
      # @param uri [String] Document URI
      # @return [Hash, nil] LSP location or nil
      def find_definition_location(ast, symbol, uri)
        # Check if it's a token declaration
        ast[:declarations]&.each do |decl|
          next unless decl[:kind] == :token

          if decl[:names]&.include?(symbol) && decl[:location]
            return {
              uri: uri,
              range: {
                start: {
                  line: decl[:location][:line] - 1,
                  character: decl[:location][:column] - 1
                },
                end: {
                  line: decl[:location][:line] - 1,
                  character: decl[:location][:column] + symbol.length - 1
                }
              }
            }
          end
        end

        # Check if it's a nonterminal rule
        rule = ast[:rules]&.find { |r| r[:name] == symbol }
        if rule && rule[:location]
          return {
            uri: uri,
            range: {
              start: {
                line: rule[:location][:line] - 1,
                character: rule[:location][:column] - 1
              },
              end: {
                line: rule[:location][:line] - 1,
                character: rule[:location][:column] + symbol.length - 1
              }
            }
          }
        end

        nil
      end
    end
  end
end
