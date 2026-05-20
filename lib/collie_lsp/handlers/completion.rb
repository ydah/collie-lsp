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
        position = request[:params][:position]
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

        completions = completions_for_context(doc[:text], position, index)

        writer.write(
          id: request[:id],
          result: completions
        )
      end

      # Handle completionItem/resolve request.
      def resolve(request, _document_store, _collie, writer)
        item = request[:params]
        item[:documentation] ||= {
          kind: 'markdown',
          value: completion_documentation(item)
        }
        writer.write(id: request[:id], result: item)
      end

      # Build completion items from symbol index or AST.
      # @param source [SymbolIndex, Object] Parsed symbol source
      # @return [Array<Hash>] LSP completion items
      def build_completions(source)
        index = source.is_a?(SymbolIndex) ? source : SymbolIndex.build(source, '')
        directives +
          index.all_symbols.filter_map { |entry| completion_for(entry) } +
          type_tag_completions(index) +
          positional_reference_completions(index) +
          action_reference_completions(index)
      end

      def completions_for_context(text, position, index)
        return [] if suppressed_context?(text, position)

        line = text.lines[position[:line]].to_s
        prefix = line[0...Position.utf16_to_codepoint_index(line, position[:character])]
        completions = context_completions(prefix, index)
        filter_by_prefix(completions, completion_prefix(prefix))
      end

      def suppressed_context?(text, position)
        line = text.lines[position[:line]].to_s
        offset = Position.utf16_to_codepoint_index(line, position[:character])
        prefix = line[0...offset]
        return true if prefix.include?('//')

        quote_count = prefix.scan(/(?<!\\)["']/).size
        quote_count.odd?
      end

      def context_completions(prefix, index)
        return type_tag_completions(index) if prefix.match?(/%type\s+<[^>]*\z|%token\s+<[^>]*\z/)
        return precedence_completions(index) if prefix.match?(/%prec\s+\S*\z/)
        return action_reference_completions(index) + positional_reference_completions(index) if prefix.include?('$')
        return named_reference_completions(index) if prefix.match?(/\[[A-Za-z_0-9]*\z/)

        build_completions(index)
      end

      def completion_prefix(prefix)
        prefix[/[%$]?[A-Za-z_0-9]*\z/] || ''
      end

      def filter_by_prefix(completions, prefix)
        return completions if prefix.empty?

        completions.select { |item| item[:label].downcase.start_with?(prefix.downcase) }
      end

      def directives
        %w[%token %type %left %right %nonassoc %start %union %prec %rule %inline].map do |directive|
          {
            label: directive,
            kind: 14,
            detail: 'Grammar directive',
            insertTextFormat: 2,
            insertText: directive_snippet(directive)
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

      def action_reference_completions(index)
        named_references = index.entries_by_kind(:named_reference).map do |entry|
          {
            label: "$#{entry[:name]}",
            kind: 6,
            detail: "Named reference: #{entry[:name]}",
            documentation: 'Lrama action named reference'
          }
        end

        named_references << {
          label: '$$',
          kind: 6,
          detail: 'Current semantic value',
          documentation: 'Lrama action result value'
        }
      end

      def type_tag_completions(index)
        index.type_tags.map do |tag|
          {
            label: tag,
            kind: 25,
            detail: "Type tag: #{tag}",
            documentation: 'Type tag from declarations'
          }
        end
      end

      def precedence_completions(index)
        index.entries_by_kind(:precedence, :token).map do |entry|
          {
            label: entry[:name],
            kind: 14,
            detail: "Precedence token: #{entry[:name]}",
            documentation: 'Token usable after %prec'
          }
        end
      end

      def positional_reference_completions(index)
        (1..[index.entries_by_kind(:terminal, :nonterminal).size, 9].max).map do |number|
          {
            label: "$#{number}",
            kind: 6,
            detail: "Positional reference #{number}",
            documentation: 'Lrama action positional reference'
          }
        end
      end

      def named_reference_completions(index)
        index.entries_by_kind(:named_reference).map do |entry|
          {
            label: entry[:name],
            kind: 6,
            detail: "Named reference: #{entry[:name]}",
            documentation: 'Named reference alias'
          }
        end
      end

      def directive_snippet(directive)
        case directive
        when '%token' then '%token ${1:NAME}'
        when '%type' then '%type <${1:type}> ${2:symbol}'
        when '%start' then '%start ${1:symbol}'
        when '%rule' then "%rule ${1:name}:\n  ${2:/* empty */}\n;"
        when '%inline' then '%inline ${1:name}'
        else
          directive
        end
      end

      def completion_documentation(item)
        detail = item[:detail] || item['detail'] || item[:label] || item['label']
        detail.to_s
      end
    end
  end
end
