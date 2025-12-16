# frozen_string_literal: true

module CollieLsp
  module Handlers
    # Code folding support
    module FoldingRange
      module_function

      # Handle textDocument/foldingRange request
      # @param request [Hash] LSP request
      # @param document_store [DocumentStore] Document store
      # @param _collie [CollieWrapper] Collie wrapper (unused)
      # @param writer [Object] Response writer
      def handle(request, document_store, _collie, writer)
        uri = request[:params][:textDocument][:uri]
        doc = document_store.get(uri)

        unless doc
          writer.write(id: request[:id], result: [])
          return
        end

        ranges = build_folding_ranges(doc[:text], doc[:ast])

        writer.write(
          id: request[:id],
          result: ranges
        )
      end

      # Build folding ranges from document
      # @param text [String] Document text
      # @param ast [Hash, nil] Parsed AST (may be nil)
      # @return [Array<Hash>] LSP folding ranges
      def build_folding_ranges(text, ast)
        ranges = []

        # Add ranges from AST if available
        ranges.concat(build_ast_folding_ranges(ast)) if ast

        # Add ranges from text structure
        ranges.concat(build_text_folding_ranges(text))

        # Sort and remove overlaps
        ranges.sort_by { |r| [r[:startLine], r[:endLine]] }
      end

      # Build folding ranges from AST
      # @param ast [Hash] Parsed AST
      # @return [Array<Hash>] Folding ranges
      def build_ast_folding_ranges(ast)
        ranges = []

        # Fold grammar rules with multiple alternatives
        ast[:rules]&.each do |rule|
          next unless rule[:location] && rule[:alternatives]
          next if rule[:alternatives].size < 2

          # Find the end of the rule (look for semicolon)
          start_line = rule[:location][:line] - 1
          end_line = find_rule_end_line(rule, ast)

          # Only create a range if the rule spans multiple lines
          ranges << create_folding_range(start_line, end_line, 'region') if end_line && end_line > start_line
        end

        ranges
      end

      # Build folding ranges from text structure
      # @param text [String] Document text
      # @return [Array<Hash>] Folding ranges
      def build_text_folding_ranges(text)
        ranges = []
        lines = text.lines

        # Fold block comments
        ranges.concat(find_comment_blocks(lines))

        # Fold C code blocks (%{ ... %})
        ranges.concat(find_c_code_blocks(lines))

        # Fold action blocks ({ ... })
        ranges.concat(find_action_blocks(lines))

        ranges
      end

      # Find the end line of a rule
      # @param rule [Hash] Rule
      # @param ast [Hash] AST (for context)
      # @return [Integer, nil] End line number or nil
      def find_rule_end_line(rule, ast)
        # Find the next rule's start line
        rule_index = ast[:rules].index(rule)
        return nil unless rule_index

        if rule_index < ast[:rules].size - 1
          next_rule = ast[:rules][rule_index + 1]
          return next_rule[:location][:line] - 2 if next_rule[:location]
        end

        # Last rule - use a default offset
        rule[:location][:line] + 10
      end

      # Find block comment ranges
      # @param lines [Array<String>] Document lines
      # @return [Array<Hash>] Folding ranges
      def find_comment_blocks(lines)
        ranges = []
        in_comment = false
        comment_start = nil

        lines.each_with_index do |line, idx|
          if !in_comment && line.include?('/*')
            in_comment = true
            comment_start = idx
          elsif in_comment && line.include?('*/')
            in_comment = false
            ranges << create_folding_range(comment_start, idx, 'comment') if comment_start && idx > comment_start
            comment_start = nil
          end
        end

        ranges
      end

      # Find C code block ranges
      # @param lines [Array<String>] Document lines
      # @return [Array<Hash>] Folding ranges
      def find_c_code_blocks(lines)
        ranges = []
        in_block = false
        block_start = nil

        lines.each_with_index do |line, idx|
          if !in_block && line.strip == '%{'
            in_block = true
            block_start = idx
          elsif in_block && line.strip == '%}'
            in_block = false
            ranges << create_folding_range(block_start, idx, 'region') if block_start && idx > block_start
            block_start = nil
          end
        end

        ranges
      end

      # Find action block ranges (multi-line only)
      # @param lines [Array<String>] Document lines
      # @return [Array<Hash>] Folding ranges
      def find_action_blocks(lines)
        ranges = []

        lines.each_with_index do |line, idx|
          # Look for opening brace
          brace_pos = line.index('{')
          next unless brace_pos

          # Find matching closing brace
          end_line = find_matching_brace(lines, idx, brace_pos)
          next unless end_line && end_line > idx

          ranges << create_folding_range(idx, end_line, 'region')
        end

        ranges
      end

      # Find matching closing brace
      # @param lines [Array<String>] Document lines
      # @param start_line [Integer] Line with opening brace
      # @param start_pos [Integer] Position of opening brace
      # @return [Integer, nil] Line with closing brace or nil
      def find_matching_brace(lines, start_line, start_pos)
        depth = 1
        pos = start_pos + 1

        (start_line...lines.length).each do |line_idx|
          line = lines[line_idx]
          start = line_idx == start_line ? pos : 0

          (start...line.length).each do |char_idx|
            char = line[char_idx]
            depth += 1 if char == '{'
            depth -= 1 if char == '}'

            return line_idx if depth.zero?
          end
        end

        nil
      end

      # Create a folding range
      # @param start_line [Integer] Start line (0-indexed)
      # @param end_line [Integer] End line (0-indexed)
      # @param kind [String] Folding range kind
      # @return [Hash] LSP folding range
      def create_folding_range(start_line, end_line, kind)
        {
          startLine: start_line,
          endLine: end_line,
          kind: kind
        }
      end
    end
  end
end
