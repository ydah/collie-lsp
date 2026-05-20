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

        hover_content = build_hover_content(index, symbol, position: position)

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
        SymbolIndex.symbol_at(text, position)
      end

      # Build hover content for a symbol
      # @param source [SymbolIndex, Object] Parsed symbol source
      # @param symbol [String] Symbol name
      # @return [Hash, nil] LSP markup content or nil
      def build_hover_content(source, symbol, position: nil)
        index = source.is_a?(SymbolIndex) ? source : SymbolIndex.build(source, '')
        entry = position ? index.definition_for_at(symbol, position) : index.definition_for(symbol)
        return nil unless entry

        {
          kind: 'markdown',
          value: hover_value(entry, index)
        }
      end

      def hover_value(entry, index = nil)
        case entry[:kind]
        when :token
          "**Token**: `#{entry[:name]}`\n\nType: `#{entry[:type_tag] || 'none'}`\n\nUses: #{index&.usage_count(entry[:name]) || 0}"
        when :rule
          rule_hover(entry, index)
        when :parameterized_rule
          parameters = Array(entry[:parameters]).join(', ')
          "**Parameterized rule**: `#{entry[:name]}`\n\nParameters: `#{parameters}`\n\n#{production_details(entry, index)}"
        when :inline_rule
          "**Inline rule**: `#{entry[:name]}`"
        when :type
          "**Type**: `#{entry[:name]}`\n\nTag: `#{entry[:type_tag] || 'none'}`"
        when :precedence
          "**Precedence**: `#{entry[:name]}`\n\nAssociativity: `#{entry[:associativity]}`"
        when :named_reference
          "**Named reference**: `#{entry[:name]}`\n\nTarget: `#{entry[:target]}`"
        when :reference_target
          "**Reference target**: `#{entry[:name]}`"
        else
          "**Symbol**: `#{entry[:name]}`"
        end
      end

      def rule_hover(entry, index)
        "**Nonterminal**: `#{entry[:name]}`\n\n#{entry[:detail]}\n\n#{production_details(entry, index)}"
      end

      def production_details(entry, index)
        return 'Uses: 0' unless index

        productions = index.productions_for(entry[:name]).first(5)
        details = []
        details << "Uses: #{index.usage_count(entry[:name])}"
        details << "Nullable: #{index.nullable?(entry[:name]) ? 'yes' : 'no'}"
        first = index.first_set(entry[:name])
        details << "FIRST: `#{first.join('`, `')}`" unless first.empty?
        details << "Productions:\n#{productions.map { |production| "- `#{production}`" }.join("\n")}" unless productions.empty?
        details.join("\n\n")
      end
    end
  end
end
