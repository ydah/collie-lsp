# frozen_string_literal: true

require 'digest'

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

        # Build semantic tokens
        tokens = build_semantic_tokens(doc[:text], Support.symbol_index_for(doc))
        result_id = result_id_for(doc, tokens)
        document_store.update_semantic_tokens(uri, result_id: result_id, data: tokens)

        writer.write(
          id: request[:id],
          result: { resultId: result_id, data: tokens }
        )
      end

      # Handle textDocument/semanticTokens/full/delta request.
      # @param request [Hash] LSP request
      # @param document_store [DocumentStore] Document store
      # @param _collie [CollieWrapper] Collie wrapper (unused)
      # @param writer [Object] Response writer
      def handle_delta(request, document_store, _collie, writer)
        uri = request[:params][:textDocument][:uri]
        previous_result_id = request[:params][:previousResultId]
        doc = document_store.get(uri)

        unless doc
          writer.write(id: request[:id], result: { edits: [] })
          return
        end

        tokens = build_semantic_tokens(doc[:text], Support.symbol_index_for(doc))
        result_id = result_id_for(doc, tokens)
        previous = doc[:semantic_tokens]
        document_store.update_semantic_tokens(uri, result_id: result_id, data: tokens)

        edits = semantic_token_edits(previous, previous_result_id, tokens)

        writer.write(id: request[:id], result: { resultId: result_id, edits: edits })
      end

      # Handle textDocument/semanticTokens/range request.
      def handle_range(request, document_store, _collie, writer)
        uri = request[:params][:textDocument][:uri]
        range = request[:params][:range]
        doc = document_store.get(uri)

        unless doc
          writer.write(id: request[:id], result: { data: [] })
          return
        end

        tokens = build_semantic_tokens(doc[:text], Support.symbol_index_for(doc), range: range)
        writer.write(id: request[:id], result: { data: tokens })
      end

      # Build semantic tokens array
      # @param text [String] Document text
      # @param source [SymbolIndex, Object, nil] Parsed symbol source
      # @return [Array<Integer>] Encoded semantic tokens
      def build_semantic_tokens(text, source, range: nil)
        tokens = []
        symbol_info = build_symbol_info(source)

        lines = text.lines
        in_block_comment = false
        lines.each_with_index do |line, line_idx|
          next if range && (line_idx < range[:start][:line] || line_idx > range[:end][:line])

          line_tokens, in_block_comment = tokenize_line(line, line_idx, symbol_info, in_block_comment: in_block_comment)
          tokens.concat(line_tokens)
        end

        # Convert to LSP format (delta encoding)
        encode_tokens(tokens.map { |token| encode_token_position(token, lines[token[:line]]) })
      end

      # Build symbol information from AST
      # @param source [SymbolIndex, Object, nil] Parsed symbol source
      # @return [Hash] Symbol information
      def build_symbol_info(source)
        index = source.is_a?(SymbolIndex) ? source : (SymbolIndex.build(source, '') if source)
        info = { tokens: {}, nonterminals: {}, keywords: {} }

        if index
          index.tokens.each { |entry| info[:tokens][entry[:name]] = true }
          index.rules.each { |entry| info[:nonterminals][entry[:name]] = true }
        end

        # Grammar keywords
        %w[%token %type %left %right %nonassoc %prec %union %start %rule %inline].each do |kw|
          info[:keywords][kw] = true
        end

        info
      end

      # Tokenize a single line
      # @param line [String] Line text
      # @param line_idx [Integer] Line index
      # @param symbol_info [Hash] Symbol information
      # @return [Array<Hash>] Tokens in this line
      def tokenize_line(line, line_idx, symbol_info, in_block_comment: false)
        tokens = []
        pos = 0

        while pos < line.length
          if in_block_comment
            end_pos = line.index('*/', pos)
            length = end_pos ? end_pos + 2 - pos : line.length - pos
            tokens << create_token(line_idx, pos, length, :comment)
            return [tokens, true] unless end_pos

            pos = end_pos + 2
            in_block_comment = false
            next
          end

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
            end_pos = line.index('*/', pos + 2)
            if end_pos
              tokens << create_token(line_idx, pos, end_pos + 2 - pos, :comment)
              pos = end_pos + 2
              next
            end

            tokens << create_token(line_idx, pos, line.length - pos, :comment)
            return [tokens, true]
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

          # Check for Lrama action references
          if line[pos] == '$'
            reference = line[pos..].match(/\A\$\$|\A\$[A-Za-z_][A-Za-z0-9_]*|\A\$\d+/)&.to_s
            if reference
              tokens << create_token(line_idx, pos, reference.length, :parameter)
              pos += reference.length
              next
            end
          end

          # Check for named references
          if line[pos] == '['
            match = line[pos..].match(/\A\[([A-Za-z_][A-Za-z0-9_]*)\]/)
            if match
              tokens << create_token(line_idx, pos + 1, match[1].length, :parameter)
              pos += match[0].length
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

        [tokens, in_block_comment]
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

      def encode_token_position(token, line)
        start_char = Position.codepoint_to_utf16(line, token[:startChar])
        token_text = line[token[:startChar], token[:length]].to_s

        token.merge(
          startChar: start_char,
          length: Position.codepoint_length_to_utf16(token_text)
        )
      end

      def result_id_for(doc, tokens)
        digest = Digest::SHA256.hexdigest(tokens.join(','))
        "#{doc[:version]}-#{digest[0, 12]}"
      end

      def semantic_token_edits(previous, previous_result_id, tokens)
        return full_semantic_token_edit(previous, tokens) unless previous && previous[:result_id] == previous_result_id
        return [] if previous[:data] == tokens

        minimal_semantic_token_edit(previous[:data], tokens)
      end

      def full_semantic_token_edit(previous, tokens)
        [{
          start: 0,
          deleteCount: previous&.dig(:data)&.size || 0,
          data: tokens
        }]
      end

      def minimal_semantic_token_edit(old_data, new_data)
        prefix = common_prefix_length(old_data, new_data)
        suffix = common_suffix_length(old_data, new_data, prefix)
        delete_count = old_data.length - prefix - suffix
        data = new_data[prefix...(new_data.length - suffix)]

        [{
          start: prefix,
          deleteCount: delete_count,
          data: data || []
        }]
      end

      def common_prefix_length(left, right)
        max = [left.length, right.length].min
        index = 0
        index += 1 while index < max && left[index] == right[index]
        index
      end

      def common_suffix_length(left, right, prefix)
        max = [left.length, right.length].min - prefix
        index = 0
        index += 1 while index < max && left[-index - 1] == right[-index - 1]
        index
      end
    end
  end
end
