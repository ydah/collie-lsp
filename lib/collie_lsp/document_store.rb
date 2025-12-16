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
        ast: nil,
        diagnostics: []
      }
    end

    # Update document content
    # @param uri [String] Document URI
    # @param text [String] New document text
    # @param version [Integer] New document version
    def change(uri, text, version)
      return unless @documents[uri]

      @documents[uri][:text] = text
      @documents[uri][:version] = version
      @documents[uri][:ast] = nil # Invalidate AST cache
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

    # Update cached AST for a document
    # @param uri [String] Document URI
    # @param ast [Object] Parsed AST
    def update_ast(uri, ast)
      return unless @documents[uri]

      @documents[uri][:ast] = ast
    end

    # Update diagnostics for a document
    # @param uri [String] Document URI
    # @param diagnostics [Array<Hash>] LSP diagnostics
    def update_diagnostics(uri, diagnostics)
      return unless @documents[uri]

      @documents[uri][:diagnostics] = diagnostics
    end
  end
end
