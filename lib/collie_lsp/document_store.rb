# frozen_string_literal: true

module CollieLsp
  # Manages open documents in memory
  class DocumentStore
    def initialize
      @documents = {}
    end

    # Open a new document
    # @param uri [String] Document URI
    # @param text [String] Document text content
    # @param version [Integer] Document version
    def open(uri, text, version)
      @documents[uri] = {
        text: text,
        version: version,
        language_id: nil,
        ast: nil,
        parse_error: nil,
        symbol_index: nil,
        semantic_tokens: nil,
        diagnostics: []
      }
    end

    # Update document content
    # @param uri [String] Document URI
    # @param text [String] New document text
    # @param version [Integer] New document version
    def change(uri, text_or_changes, version)
      return unless @documents[uri]

      @documents[uri][:text] = if text_or_changes.is_a?(Array)
                                 apply_content_changes(@documents[uri][:text], text_or_changes)
                               else
                                 text_or_changes
                               end
      @documents[uri][:version] = version
      invalidate_cache(uri)
    end

    # Get document data
    # @param uri [String] Document URI
    # @return [Hash, nil] Document data or nil if not found
    def get(uri)
      @documents[uri]
    end

    # Close a document
    # @param uri [String] Document URI
    def close(uri)
      @documents.delete(uri)
    end

    # Iterate over open documents.
    # @yieldparam uri [String] Document URI
    # @yieldparam doc [Hash] Document data
    def each_document(&)
      @documents.each(&)
    end

    # Update cached AST for a document
    # @param uri [String] Document URI
    # @param ast [Object] Parsed AST
    def update_ast(uri, ast)
      return unless @documents[uri]

      @documents[uri][:ast] = ast
    end

    # Update parse error for a document.
    # @param uri [String] Document URI
    # @param error [Hash, nil] Parse error metadata
    def update_parse_error(uri, error)
      return unless @documents[uri]

      @documents[uri][:parse_error] = error
    end

    # Update cached symbol index for a document.
    # @param uri [String] Document URI
    # @param symbol_index [Object, nil] Symbol index
    def update_symbol_index(uri, symbol_index)
      return unless @documents[uri]

      @documents[uri][:symbol_index] = symbol_index
    end

    # Update language id for a document.
    # @param uri [String] Document URI
    # @param language_id [String, nil] LSP language id
    def update_language_id(uri, language_id)
      return unless @documents[uri]

      @documents[uri][:language_id] = language_id
    end

    # Update cached semantic tokens for a document.
    # @param uri [String] Document URI
    # @param cache [Hash, nil] Semantic token cache
    def update_semantic_tokens(uri, cache)
      return unless @documents[uri]

      @documents[uri][:semantic_tokens] = cache
    end

    # Update diagnostics for a document
    # @param uri [String] Document URI
    # @param diagnostics [Array<Hash>] LSP diagnostics
    def update_diagnostics(uri, diagnostics)
      return unless @documents[uri]

      @documents[uri][:diagnostics] = diagnostics
    end

    private

    def invalidate_cache(uri)
      @documents[uri][:ast] = nil
      @documents[uri][:parse_error] = nil
      @documents[uri][:symbol_index] = nil
      @documents[uri][:semantic_tokens] = nil
    end

    def apply_content_changes(text, changes)
      changes.reduce(text) do |current_text, change|
        next change[:text] unless change[:range]

        apply_range_change(current_text, change[:range], change[:text])
      end
    end

    def apply_range_change(text, range, replacement)
      start_offset = position_to_offset(text, range[:start])
      end_offset = position_to_offset(text, range[:end])
      text.dup.tap { |changed| changed[start_offset...end_offset] = replacement }
    end

    def position_to_offset(text, position)
      line = position[:line]
      character = position[:character]
      offset = 0

      text.lines.each_with_index do |line_text, index|
        return offset + [character, line_text.length].min if index == line

        offset += line_text.length
      end

      offset
    end
  end
end
