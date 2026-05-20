# frozen_string_literal: true

module CollieLsp
  module Handlers
    # Workspace-wide symbol search
    module WorkspaceSymbol
      module_function

      # Handle workspace/symbol request
      # @param request [Hash] LSP request
      # @param document_store [DocumentStore] Document store
      # @param collie [CollieWrapper] Collie wrapper
      # @param writer [Object] Response writer
      def handle(request, document_store, collie, writer)
        query = request[:params][:query] || ''
        symbols = search_symbols(query, document_store, collie)

        writer.write(
          id: request[:id],
          result: symbols
        )
      end

      # Search for symbols across all open documents
      # @param query [String] Search query
      # @param document_store [DocumentStore] Document store
      # @return [Array<Hash>] Matching symbols
      def search_symbols(query, document_store, collie = nil)
        symbols = []
        open_uris = []

        document_store.each_document do |uri, doc|
          index = Support.symbol_index_for(doc)
          next unless index

          open_uris << uri
          symbols.concat(search_in_document(query, uri, index))
        end

        symbols.concat(search_workspace_files(query, collie, open_uris)) if collie

        # Sort by relevance (exact matches first, then contains)
        symbols.sort_by { |s| symbol_relevance(s[:name], query) }
      end

      def search_workspace_files(query, collie, open_uris)
        collie.workspace_grammar_files.flat_map do |path|
          uri = UriUtils.file_uri(path)
          next [] if open_uris.include?(uri)

          result = collie.parse_file(path)
          next [] unless result.ast

          text = File.read(path)
          search_in_document(query, uri, SymbolIndex.build(result.ast, text))
        rescue StandardError
          []
        end
      end

      # Search for symbols in a single document
      # @param query [String] Search query
      # @param uri [String] Document URI
      # @param source [SymbolIndex, Object] Parsed symbol source
      # @return [Array<Hash>] Matching symbols
      def search_in_document(query, uri, source)
        index = source.is_a?(SymbolIndex) ? source : SymbolIndex.build(source, '')
        index.all_symbols.filter_map do |entry|
          next unless matches_query?(entry[:name], query)

          create_symbol_info(
            name: entry[:name],
            kind: symbol_kind(entry[:kind]),
            uri: uri,
            location: entry[:location],
            container_name: container_name(entry[:kind])
          )
        end
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
        lsp_location = Support.location_to_lsp(uri, location)

        info = {
          name: name,
          kind: kind,
          location: lsp_location
        }

        info[:containerName] = container_name if container_name

        info
      end

      def symbol_kind(kind)
        case kind
        when :token then 14
        when :type then 7
        when :precedence then 22
        when :rule, :parameterized_rule, :inline_rule then 12
        when :start then 13
        when :union then 5
        else 13
        end
      end

      def container_name(kind)
        case kind
        when :token then 'Tokens'
        when :type then 'Types'
        when :precedence then 'Precedence'
        when :rule, :parameterized_rule then 'Rules'
        when :inline_rule then 'Lrama Extensions'
        else 'Declarations'
        end
      end
    end
  end
end
