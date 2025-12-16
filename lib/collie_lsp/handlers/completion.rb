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

        ast = doc[:ast]
        unless ast
          writer.write(id: request[:id], result: [])
          return
        end

        completions = build_completions(ast)

        writer.write(
          id: request[:id],
          result: completions
        )
      end

      # Build completion items from AST
      # @param ast [Hash] Parsed AST
      # @return [Array<Hash>] LSP completion items
      def build_completions(ast)
        completions = []

        # Add all declared tokens
        ast[:declarations]&.each do |decl|
          next unless decl[:kind] == :token

          decl[:names]&.each do |name|
            completions << {
              label: name,
              kind: 14, # Keyword
              detail: "Token: #{name}",
              documentation: 'Declared token'
            }
          end
        end

        # Add all nonterminals
        ast[:rules]&.each do |rule|
          completions << {
            label: rule[:name],
            kind: 7, # Class (nonterminal)
            detail: "Nonterminal: #{rule[:name]}",
            documentation: 'Grammar rule'
          }
        end

        completions
      end
    end
  end
end
