# frozen_string_literal: true

module CollieLsp
  module Handlers
    # Semantic tokens support for syntax highlighting
    module SemanticTokens
      module_function

      # LSP semantic token types
      TOKEN_TYPES = %w[
        namespace
        type
        class
        enum
        interface
        struct
        typeParameter
        parameter
        variable
        property
        enumMember
        event
        function
        method
        macro
        keyword
        modifier
        comment
        string
        number
        regexp
        operator
      ].freeze

      # LSP semantic token modifiers
      TOKEN_MODIFIERS = %w[
        declaration
        definition
        readonly
        static
        deprecated
        abstract
        async
        modification
        documentation
        defaultLibrary
      ].freeze

      # Handle textDocument/semanticTokens/full request
      # @param request [Hash] LSP request
      # @param document_store [DocumentStore] Document store
      # @param _collie [CollieWrapper] Collie wrapper (unused)
      # @param writer [Object] Response writer
      def handle(request, document_store, _collie, writer)
        uri = request[:params][:textDocument][:uri]
        doc = document_store.get(uri)

        unless doc
          writer.write(id: request[:id], result: { data: [] })
          return
        end

        ast = doc[:ast]
        unless ast
          writer.write(id: request[:id], result: { data: [] })
          return
        end

        # Build semantic tokens
        tokens = build_semantic_tokens(doc[:text], ast)

        writer.write(
          id: request[:id],
          result: { data: tokens }
        )
      end

      # Build semantic tokens array
      # @param text [String] Document text
      # @param ast [Hash] Parsed AST
      # @return [Array<Integer>] Encoded semantic tokens
      def build_semantic_tokens(text, ast)
        tokens = []
        symbol_info = build_symbol_info(ast)

        lines = text.lines
        lines.each_with_index do |line, line_idx|
          tokens.concat(tokenize_line(line, line_idx, symbol_info))
        end

        # Convert to LSP format (delta encoding)
        encode_tokens(tokens)
      end

      # Build symbol information from AST
      # @param ast [Hash] Parsed AST
      # @return [Hash] Symbol information
      def build_symbol_info(ast)
        info = { tokens: {}, nonterminals: {}, keywords: {} }

        # Collect token declarations
        ast[:declarations]&.each do |decl|
          next unless decl[:kind] == :token

          decl[:names]&.each do |name|
            info[:tokens][name] = true
          end
        end

        # Collect nonterminal rules
        ast[:rules]&.each do |rule|
          info[:nonterminals][rule[:name]] = true
        end

        # Grammar keywords
        %w[%token %type %left %right %nonassoc %prec %union %start].each do |kw|
          info[:keywords][kw] = true
        end

        info
      end

      # Tokenize a single line
      # @param line [String] Line text
      # @param line_idx [Integer] Line index
      # @param symbol_info [Hash] Symbol information
      # @return [Array<Hash>] Tokens in this line
      def tokenize_line(line, line_idx, symbol_info)
        tokens = []
        pos = 0

        while pos < line.length
          # Skip whitespace
          if line[pos] =~ /\s/
            pos += 1
            next
          end

          # Check for keywords
          if line[pos] == '%'
            keyword = extract_keyword(line, pos)
            if keyword && symbol_info[:keywords][keyword]
              tokens << create_token(line_idx, pos, keyword.length, :keyword)
              pos += keyword.length
              next
            end
          end

          # Check for comments
          if line[pos..(pos + 1)] == '//'
            # Rest of line is a comment
            tokens << create_token(line_idx, pos, line.length - pos, :comment)
            break
          end

          if line[pos..(pos + 1)] == '/*'
            # Block comment (simplified - doesn't handle multi-line)
            end_pos = line.index('*/', pos + 2)
            if end_pos
              tokens << create_token(line_idx, pos, end_pos + 2 - pos, :comment)
              pos = end_pos + 2
              next
            end
          end

          # Check for strings
          if ['"', "'"].include?(line[pos])
            str_len = extract_string_length(line, pos)
            if str_len
              tokens << create_token(line_idx, pos, str_len, :string)
              pos += str_len
              next
            end
          end

          # Check for identifiers
          if line[pos] =~ /[A-Za-z_]/
            identifier = extract_identifier(line, pos)
            if identifier
              type = classify_identifier(identifier, symbol_info)
              tokens << create_token(line_idx, pos, identifier.length, type)
              pos += identifier.length
              next
            end
          end

          # Check for operators
          if line[pos] =~ /[{}:;|]/
            tokens << create_token(line_idx, pos, 1, :operator)
            pos += 1
            next
          end

          # Skip unrecognized characters
          pos += 1
        end

        tokens
      end

      # Extract keyword from position
      # @param line [String] Line text
      # @param pos [Integer] Starting position
      # @return [String, nil] Keyword or nil
      def extract_keyword(line, pos)
        return nil unless line[pos] == '%'

        match = line[pos..].match(/^%[a-z]+/)
        match&.to_s
      end

      # Extract string length
      # @param line [String] Line text
      # @param pos [Integer] Starting position
      # @return [Integer, nil] String length or nil
      def extract_string_length(line, pos)
        quote = line[pos]
        end_pos = pos + 1

        while end_pos < line.length
          return end_pos - pos + 1 if line[end_pos] == quote && line[end_pos - 1] != '\\'

          end_pos += 1
        end

        nil
      end

      # Extract identifier
      # @param line [String] Line text
      # @param pos [Integer] Starting position
      # @return [String, nil] Identifier or nil
      def extract_identifier(line, pos)
        match = line[pos..].match(/^[A-Za-z_][A-Za-z0-9_]*/)
        match&.to_s
      end

      # Classify identifier type
      # @param identifier [String] Identifier name
      # @param symbol_info [Hash] Symbol information
      # @return [Symbol] Token type
      def classify_identifier(identifier, symbol_info)
        return :enumMember if symbol_info[:tokens][identifier]
        return :function if symbol_info[:nonterminals][identifier]

        :variable
      end

      # Create a token
      # @param line [Integer] Line number
      # @param col [Integer] Column number
      # @param length [Integer] Token length
      # @param type [Symbol] Token type
      # @return [Hash] Token hash
      def create_token(line, col, length, type)
        {
          line: line,
          startChar: col,
          length: length,
          tokenType: token_type_index(type),
          tokenModifiers: 0
        }
      end

      # Get token type index
      # @param type [Symbol] Token type symbol
      # @return [Integer] Token type index
      def token_type_index(type)
        type_str = type.to_s
        index = TOKEN_TYPES.index(type_str)
        index || TOKEN_TYPES.index('variable')
      end

      # Encode tokens in LSP delta format
      # @param tokens [Array<Hash>] Tokens
      # @return [Array<Integer>] Encoded tokens
      def encode_tokens(tokens)
        encoded = []
        prev_line = 0
        prev_char = 0

        tokens.sort_by { |t| [t[:line], t[:startChar]] }.each do |token|
          delta_line = token[:line] - prev_line
          delta_char = delta_line.zero? ? token[:startChar] - prev_char : token[:startChar]

          encoded.push(
            delta_line,
            delta_char,
            token[:length],
            token[:tokenType],
            token[:tokenModifiers]
          )

          prev_line = token[:line]
          prev_char = token[:startChar]
        end

        encoded
      end
    end
  end
end
