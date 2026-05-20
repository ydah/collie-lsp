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

      def location_to_lsp(uri, location, text: nil)
        {
          uri: uri,
          range: Position.location_to_range(location, text: text)
        }
      end

      def document_symbol_range(location, name, text: nil)
        Position.location_to_range(location, text: text, fallback_length: name.length)
      end
    end
  end
end
