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

        ast = doc[:ast]
        unless ast
          writer.write(id: request[:id], result: [])
          return
        end

        symbols = build_document_symbols(ast)

        writer.write(
          id: request[:id],
          result: symbols
        )
      end

      # Build document symbols from AST
      # @param ast [Hash] Parsed AST
      # @return [Array<Hash>] LSP document symbols
      def build_document_symbols(ast)
        symbols = []

        symbols.concat(build_token_symbols(ast))
        symbols.concat(build_type_symbols(ast))
        symbols.concat(build_precedence_symbols(ast))
        symbols.concat(build_rule_symbols(ast))

        symbols
      end

      # Build token symbols
      # @param ast [Hash] Parsed AST
      # @return [Array<Hash>] Token symbols
      def build_token_symbols(ast)
        symbols = []
        ast[:declarations]&.each do |decl|
          next unless decl[:kind] == :token && decl[:location]

          decl[:names]&.each do |name|
            symbols << create_symbol(
              name: name,
              kind: 14,
              location: decl[:location],
              detail: 'Token'
            )
          end
        end
        symbols
      end

      # Build type symbols
      # @param ast [Hash] Parsed AST
      # @return [Array<Hash>] Type symbols
      def build_type_symbols(ast)
        symbols = []
        ast[:declarations]&.each do |decl|
          next unless decl[:kind] == :type && decl[:location]

          decl[:names]&.each do |name|
            symbols << create_symbol(
              name: name,
              kind: 7,
              location: decl[:location],
              detail: 'Type'
            )
          end
        end
        symbols
      end

      # Build precedence symbols
      # @param ast [Hash] Parsed AST
      # @return [Array<Hash>] Precedence symbols
      def build_precedence_symbols(ast)
        symbols = []
        ast[:declarations]&.each do |decl|
          next unless %i[left right nonassoc].include?(decl[:kind]) && decl[:location]

          assoc_name = decl[:kind].to_s.capitalize
          decl[:tokens]&.each do |token|
            symbols << create_symbol(
              name: token,
              kind: 22,
              location: decl[:location],
              detail: "#{assoc_name} precedence"
            )
          end
        end
        symbols
      end

      # Build rule symbols
      # @param ast [Hash] Parsed AST
      # @return [Array<Hash>] Rule symbols
      def build_rule_symbols(ast)
        symbols = []
        ast[:rules]&.each do |rule|
          next unless rule[:location]

          children = build_rule_children(rule)
          symbols << create_symbol(
            name: rule[:name],
            kind: 12,
            location: rule[:location],
            detail: "Grammar rule (#{rule[:alternatives]&.size || 0} alternatives)",
            children: children
          )
        end
        symbols
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
        line = location[:line] - 1
        column = location[:column] - 1

        symbol = {
          name: name,
          kind: kind,
          range: {
            start: { line: line, character: column },
            end: { line: line, character: column + name.length }
          },
          selectionRange: {
            start: { line: line, character: column },
            end: { line: line, character: column + name.length }
          }
        }

        symbol[:detail] = detail if detail
        symbol[:children] = children if children && !children.empty?

        symbol
      end
    end
  end
end
