# frozen_string_literal: true

module CollieLsp
  # Enumerates open and on-disk grammar documents with symbol indexes.
  module WorkspaceIndex
    module_function

    def each(document_store, collie)
      yielded = {}

      document_store.each_document do |uri, doc|
        index = Handlers::Support.symbol_index_for(doc)
        next unless index

        yielded[uri] = true
        yield uri, doc[:text], index
      end

      return unless collie

      collie.workspace_grammar_files.each do |path|
        uri = UriUtils.file_uri(path)
        next if yielded[uri]

        text = File.read(path)
        result = collie.parse_result(text, filename: path)
        next unless result.ast

        yield uri, text, SymbolIndex.build(result.ast, text)
      rescue StandardError
        next
      end
    end
  end
end
