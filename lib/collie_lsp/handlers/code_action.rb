# frozen_string_literal: true

module CollieLsp
  module Handlers
    # Quick fixes for autocorrectable offenses
    module CodeAction
      module_function

      # Handle textDocument/codeAction request
      # @param request [Hash] LSP request
      # @param document_store [DocumentStore] Document store
      # @param collie [CollieWrapper] Collie wrapper
      # @param writer [Object] Response writer
      def handle(request, document_store, collie, writer)
        uri = request[:params][:textDocument][:uri]
        range = request[:params][:range]
        only = Array(request.dig(:params, :context, :only))
        doc = document_store.get(uri)

        unless doc
          writer.write(id: request[:id], result: [])
          return
        end

        # Get diagnostics in range
        diagnostics = doc[:diagnostics].select do |diag|
          in_range?(diag, range)
        end

        code_actions = diagnostics.flat_map do |diagnostic|
          quickfix_actions(uri, doc, diagnostic)
        end

        # Add "Fix all" action if there are any diagnostics
        if diagnostics.any? && allows_kind?(only, 'source.fixAll')
          filename = UriUtils.path_from_uri(uri)
          corrected = collie.autocorrect(doc[:text], filename: filename)

          code_actions << {
            title: 'Fix all auto-correctable offenses',
            kind: 'source.fixAll',
            edit: {
              changes: {
                uri => [{
                  range: full_document_range(doc[:text]),
                  newText: corrected
                }]
              }
            }
          }
        end
        code_actions.select! { |action| only.empty? || only.any? { |kind| action[:kind].start_with?(kind) } }

        writer.write(
          id: request[:id],
          result: code_actions
        )
      end

      # Check if a diagnostic is within the given range
      # @param diagnostic [Hash] LSP diagnostic
      # @param range [Hash] LSP range
      # @return [Boolean]
      def in_range?(diagnostic, range)
        diagnostic[:range][:start][:line] >= range[:start][:line] &&
          diagnostic[:range][:end][:line] <= range[:end][:line]
      end

      def quickfix_actions(uri, doc, diagnostic)
        return [] unless allows_quickfix?(diagnostic)

        case diagnostic[:code]
        when 'TrailingWhitespace'
          [simple_replacement(uri, diagnostic, 'Remove trailing whitespace', '')]
        when 'TokenNaming'
          [rename_symbol_action(uri, doc, diagnostic, 'Convert token to upper case', &:upcase)]
        when 'NonterminalNaming'
          [rename_symbol_action(uri, doc, diagnostic, 'Convert nonterminal to snake case') { |symbol| snake_case(symbol) }]
        when 'UndefinedSymbol'
          undefined_symbol_actions(uri, doc, diagnostic)
        when 'MissingStartSymbol'
          missing_start_action(uri, doc, diagnostic)
        else
          []
        end.compact
      end

      def allows_kind?(only, kind)
        only.empty? || only.any? { |requested| kind.start_with?(requested) }
      end

      def allows_quickfix?(diagnostic)
        diagnostic.dig(:data, :autocorrect) != false
      end

      def simple_replacement(uri, diagnostic, title, new_text)
        {
          title: title,
          kind: 'quickfix',
          diagnostics: [diagnostic],
          edit: {
            changes: {
              uri => [{
                range: diagnostic[:range],
                newText: new_text
              }]
            }
          }
        }
      end

      def rename_symbol_action(uri, doc, diagnostic, title)
        symbol = Position.text_for_range(doc[:text], diagnostic[:range])
        return nil if symbol.empty?

        simple_replacement(uri, diagnostic, title, yield(symbol))
      end

      def undefined_symbol_actions(uri, doc, diagnostic)
        symbol = Position.text_for_range(doc[:text], diagnostic[:range])
        return [] if symbol.empty?

        if symbol.match?(/\A[A-Z]/)
          [insert_at_start(uri, diagnostic, "Declare token #{symbol}", "%token #{symbol}\n")]
        else
          [append_rule_skeleton(uri, doc, diagnostic, symbol)]
        end
      end

      def missing_start_action(uri, doc, diagnostic)
        index = Support.symbol_index_for(doc)
        rule = index&.rules&.first
        return nil unless rule

        insert_at_start(uri, diagnostic, "Add %start #{rule[:name]}", "%start #{rule[:name]}\n")
      end

      def insert_at_start(uri, diagnostic, title, text)
        {
          title: title,
          kind: 'quickfix',
          diagnostics: [diagnostic],
          edit: {
            changes: {
              uri => [{
                range: {
                  start: { line: 0, character: 0 },
                  end: { line: 0, character: 0 }
                },
                newText: text
              }]
            }
          }
        }
      end

      def append_rule_skeleton(uri, doc, diagnostic, symbol)
        {
          title: "Create rule #{symbol}",
          kind: 'quickfix',
          diagnostics: [diagnostic],
          edit: {
            changes: {
              uri => [{
                range: full_document_range(doc[:text]),
                newText: "#{doc[:text].sub(/\s*\z/, "\n")}#{symbol}:\n  /* empty */\n;\n"
              }]
            }
          }
        }
      end

      def snake_case(symbol)
        symbol
          .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
          .gsub(/([a-z\d])([A-Z])/, '\1_\2')
          .tr('-', '_')
          .downcase
      end

      # Get the range covering the entire document
      # @param text [String] Document text
      # @return [Hash] LSP range
      def full_document_range(text)
        lines = text.lines.count
        {
          start: { line: 0, character: 0 },
          end: { line: lines, character: 0 }
        }
      end
    end
  end
end
