# frozen_string_literal: true

module CollieLsp
  module Handlers
    # Workspace-wide symbol search
    module WorkspaceSymbol
      module_function

      # Handle workspace/symbol request
      # @param request [Hash] LSP request
      # @param document_store [DocumentStore] Document store
      # @param _collie [CollieWrapper] Collie wrapper (unused)
      # @param writer [Object] Response writer
      def handle(request, document_store, _collie, writer)
        query = request[:params][:query] || ''
        symbols = search_symbols(query, document_store)

        writer.write(
          id: request[:id],
          result: symbols
        )
      end

      # Search for symbols across all open documents
      # @param query [String] Search query
      # @param document_store [DocumentStore] Document store
      # @return [Array<Hash>] Matching symbols
      def search_symbols(query, document_store)
        symbols = []

        # Search in all open documents
        document_store.instance_variable_get(:@documents).each do |uri, doc|
          next unless doc[:ast]

          symbols.concat(search_in_document(query, uri, doc[:ast]))
        end

        # Sort by relevance (exact matches first, then contains)
        symbols.sort_by { |s| symbol_relevance(s[:name], query) }
      end

      # Search for symbols in a single document
      # @param query [String] Search query
      # @param uri [String] Document URI
      # @param ast [Hash] Parsed AST
      # @return [Array<Hash>] Matching symbols
      def search_in_document(query, uri, ast)
        symbols = []

        # Search token declarations
        ast[:declarations]&.each do |decl|
          next unless decl[:kind] == :token && decl[:location]

          decl[:names]&.each do |name|
            next unless matches_query?(name, query)

            symbols << create_symbol_info(
              name: name,
              kind: 14, # Constant
              uri: uri,
              location: decl[:location],
              container_name: 'Tokens'
            )
          end

          # Search type declarations
          next unless decl[:kind] == :type && decl[:location]

          decl[:names]&.each do |name|
            next unless matches_query?(name, query)

            symbols << create_symbol_info(
              name: name,
              kind: 7, # Class
              uri: uri,
              location: decl[:location],
              container_name: 'Types'
            )
          end
        end

        # Search nonterminal rules
        ast[:rules]&.each do |rule|
          next unless rule[:location] && matches_query?(rule[:name], query)

          symbols << create_symbol_info(
            name: rule[:name],
            kind: 12, # Function
            uri: uri,
            location: rule[:location],
            container_name: 'Rules'
          )
        end

        symbols
      end

      # Check if a symbol name matches the query
      # @param name [String] Symbol name
      # @param query [String] Search query
      # @return [Boolean] True if matches
      def matches_query?(name, query)
        return true if query.empty?

        # Case-insensitive substring match
        name.downcase.include?(query.downcase)
      end

      # Calculate symbol relevance score
      # @param name [String] Symbol name
      # @param query [String] Search query
      # @return [Integer] Relevance score (lower is better)
      def symbol_relevance(name, query)
        return 0 if query.empty?

        name_lower = name.downcase
        query_lower = query.downcase

        # Exact match
        return 1 if name_lower == query_lower

        # Starts with query
        return 2 if name_lower.start_with?(query_lower)

        # Contains query
        return 3 if name_lower.include?(query_lower)

        # No match
        4
      end

      # Create a symbol information object
      # @param name [String] Symbol name
      # @param kind [Integer] LSP symbol kind
      # @param uri [String] Document URI
      # @param location [Hash] Symbol location
      # @param container_name [String] Container name
      # @return [Hash] LSP symbol information
      def create_symbol_info(name:, kind:, uri:, location:, container_name: nil)
        line = location[:line] - 1
        column = location[:column] - 1

        info = {
          name: name,
          kind: kind,
          location: {
            uri: uri,
            range: {
              start: { line: line, character: column },
              end: { line: line, character: column + name.length }
            }
          }
        }

        info[:containerName] = container_name if container_name

        info
      end
    end
  end
end
