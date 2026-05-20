# frozen_string_literal: true

module CollieLsp
  module Handlers
    # Auto-completion for tokens and nonterminals
    module Completion
      module_function

      # Handle textDocument/completion request
      # @param request [Hash] LSP request
      # @param document_store [DocumentStore] Document store
      # @param _collie [CollieWrapper] Collie wrapper (unused)
      # @param writer [Object] Response writer
      def handle(request, document_store, _collie, writer)
        uri = request[:params][:textDocument][:uri]
        _position = request[:params][:position]
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

        completions = build_completions(index)

        writer.write(
          id: request[:id],
          result: completions
        )
      end

      # Build completion items from symbol index or AST.
      # @param source [SymbolIndex, Object] Parsed symbol source
      # @return [Array<Hash>] LSP completion items
      def build_completions(source)
        index = source.is_a?(SymbolIndex) ? source : SymbolIndex.build(source, '')
        directives + index.all_symbols.filter_map { |entry| completion_for(entry) }
      end

      def directives
        %w[%token %type %left %right %nonassoc %start %union %prec %rule %inline].map do |directive|
          {
            label: directive,
            kind: 14,
            detail: 'Grammar directive'
          }
        end
      end

      def completion_for(entry)
        case entry[:kind]
        when :token
          completion_item(entry, kind: 14, detail: "Token: #{entry[:name]}", documentation: 'Declared token')
        when :rule
          completion_item(entry, kind: 7, detail: "Nonterminal: #{entry[:name]}", documentation: 'Grammar rule')
        when :parameterized_rule
          completion_item(entry, kind: 3, detail: "Parameterized rule: #{entry[:name]}", documentation: 'Lrama parameterized rule')
        when :inline_rule
          completion_item(entry, kind: 3, detail: "Inline rule: #{entry[:name]}", documentation: 'Lrama inline rule')
        when :type
          completion_item(entry, kind: 7, detail: "Type: #{entry[:name]}", documentation: 'Typed nonterminal')
        else
          nil
        end
      end

      def completion_item(entry, kind:, detail:, documentation:)
        {
          label: entry[:name],
          kind: kind,
          detail: detail,
          documentation: documentation
        }
      end
    end
  end
end
