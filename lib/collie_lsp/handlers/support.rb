# frozen_string_literal: true

module CollieLsp
  module Handlers
    # Shared handler helpers.
    module Support
      module_function

      def symbol_index_for(doc)
        return doc[:symbol_index] if doc[:symbol_index]
        return nil unless doc[:ast]

        SymbolIndex.build(doc[:ast], doc[:text])
      end

      def symbol_at(doc, position)
        SymbolIndex.symbol_at(doc[:text], position)
      end

      def location_to_lsp(uri, location)
        line = location[:line] - 1
        column = location[:column] - 1
        length = location[:length].to_i.positive? ? location[:length].to_i : 1

        {
          uri: uri,
          range: {
            start: { line: line, character: column },
            end: { line: line, character: column + length }
          }
        }
      end

      def document_symbol_range(location, name)
        line = location[:line] - 1
        column = location[:column] - 1
        length = location[:length].to_i.positive? ? location[:length].to_i : name.length

        {
          start: { line: line, character: column },
          end: { line: line, character: column + length }
        }
      end
    end
  end
end
