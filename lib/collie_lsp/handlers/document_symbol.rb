# frozen_string_literal: true

module CollieLsp
  module Handlers
    # Document symbol support for outline view
    module DocumentSymbol
      module_function

      # Handle textDocument/documentSymbol request
      # @param request [Hash] LSP request
      # @param document_store [DocumentStore] Document store
      # @param _collie [CollieWrapper] Collie wrapper (unused)
      # @param writer [Object] Response writer
      def handle(request, document_store, _collie, writer)
        uri = request[:params][:textDocument][:uri]
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

        symbols = build_document_symbols(index, doc[:text])

        writer.write(
          id: request[:id],
          result: symbols
        )
      end

      # Build document symbols from symbol index or AST.
      # @param source [SymbolIndex, Object] Parsed symbol source
      # @return [Array<Hash>] LSP document symbols
      def build_document_symbols(source, text = nil)
        index = source.is_a?(SymbolIndex) ? source : SymbolIndex.build(source, '')
        index.all_symbols.map { |entry| create_symbol_from_entry(entry, text: text) }
      end

      # Build token symbols
      # @param ast [Hash] Parsed AST
      # @return [Array<Hash>] Token symbols
      def build_token_symbols(ast)
        SymbolIndex.build(ast, '').entries_by_kind(:token).map { |entry| create_symbol_from_entry(entry) }
      end

      # Build type symbols
      # @param ast [Hash] Parsed AST
      # @return [Array<Hash>] Type symbols
      def build_type_symbols(ast)
        SymbolIndex.build(ast, '').entries_by_kind(:type).map { |entry| create_symbol_from_entry(entry) }
      end

      # Build precedence symbols
      # @param ast [Hash] Parsed AST
      # @return [Array<Hash>] Precedence symbols
      def build_precedence_symbols(ast)
        SymbolIndex.build(ast, '').entries_by_kind(:precedence).map { |entry| create_symbol_from_entry(entry) }
      end

      # Build rule symbols
      # @param ast [Hash] Parsed AST
      # @return [Array<Hash>] Rule symbols
      def build_rule_symbols(ast)
        SymbolIndex.build(ast, '').entries_by_kind(:rule, :parameterized_rule).map { |entry| create_symbol_from_entry(entry) }
      end

      # Build children symbols for a rule (alternatives)
      # @param rule [Hash] Grammar rule
      # @return [Array<Hash>] Child symbols
      def build_rule_children(rule)
        children = []

        rule[:alternatives]&.each_with_index do |alt, index|
          next unless alt[:location]

          # Create a symbol for each alternative
          symbols_str = alt[:symbols]&.map { |s| s[:name] }&.join(' ') || 'ε'
          children << create_symbol(
            name: "Alternative #{index + 1}",
            kind: 6, # Property
            location: alt[:location],
            detail: symbols_str
          )
        end

        children
      end

      # Create a document symbol
      # @param name [String] Symbol name
      # @param kind [Integer] LSP symbol kind
      # @param location [Hash] Location hash with :line and :column
      # @param detail [String] Symbol detail
      # @param children [Array<Hash>] Child symbols
      # @return [Hash] LSP document symbol
      def create_symbol(name:, kind:, location:, detail: nil, children: nil)
        range = Support.document_symbol_range(location, name)

        symbol = {
          name: name,
          kind: kind,
          range: range,
          selectionRange: range
        }

        symbol[:detail] = detail if detail
        symbol[:children] = children if children && !children.empty?

        symbol
      end

      def create_symbol_from_entry(entry, text: nil)
        range = Support.document_symbol_range(entry[:location], entry[:name], text: text)
        symbol = create_symbol(
          name: entry[:name],
          kind: symbol_kind(entry[:kind]),
          location: entry[:location],
          detail: entry[:detail]
        )
        symbol[:range] = range
        symbol[:selectionRange] = range
        symbol
      end

      def symbol_kind(kind)
        case kind
        when :token then 14
        when :type then 7
        when :precedence then 22
        when :rule, :parameterized_rule, :inline_rule then 12
        when :union then 5
        else 13
        end
      end
    end
  end
end
