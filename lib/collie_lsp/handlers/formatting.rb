# frozen_string_literal: true

module CollieLsp
  module Handlers
    # Document formatting support
    module Formatting
      module_function

      # Handle textDocument/formatting request
      # @param request [Hash] LSP request
      # @param document_store [DocumentStore] Document store
      # @param collie [CollieWrapper] Collie wrapper
      # @param writer [Object] Response writer
      def handle(request, document_store, collie, writer)
        uri = request[:params][:textDocument][:uri]
        doc = document_store.get(uri)

        unless doc
          writer.write(id: request[:id], result: nil)
          return
        end

        filename = UriUtils.path_from_uri(uri)
        formatted = collie.format(doc[:text], filename: filename)

        unless formatted
          writer.write(id: request[:id], result: nil)
          return
        end

        # Calculate text edits (replace entire document)
        edits = [{
          range: full_document_range(doc[:text]),
          newText: formatted
        }]

        writer.write(
          id: request[:id],
          result: edits
        )
      end

      # Handle textDocument/rangeFormatting request.
      def handle_range(request, document_store, _collie, writer)
        uri = request[:params][:textDocument][:uri]
        range = request[:params][:range]
        doc = document_store.get(uri)

        unless doc
          writer.write(id: request[:id], result: nil)
          return
        end

        writer.write(id: request[:id], result: trailing_whitespace_edits(doc[:text], range))
      end

      # Handle textDocument/onTypeFormatting request.
      def handle_on_type(request, document_store, _collie, writer)
        uri = request[:params][:textDocument][:uri]
        position = request[:params][:position]
        doc = document_store.get(uri)

        unless doc
          writer.write(id: request[:id], result: nil)
          return
        end

        line_range = {
          start: { line: position[:line], character: 0 },
          end: { line: position[:line], character: line_end_character(doc[:text], position[:line]) }
        }
        writer.write(id: request[:id], result: trailing_whitespace_edits(doc[:text], line_range))
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

      def trailing_whitespace_edits(text, range)
        lines = text.lines
        (range[:start][:line]..range[:end][:line]).filter_map do |line_number|
          line = lines[line_number]
          next unless line

          stripped = line.sub(/[ \t]+(\r?\n)?\z/, '\1')
          next if stripped == line

          start_column = stripped.chomp.length
          end_column = line.chomp.length
          {
            range: {
              start: { line: line_number, character: Position.codepoint_to_utf16(line, start_column) },
              end: { line: line_number, character: Position.codepoint_to_utf16(line, end_column) }
            },
            newText: ''
          }
        end
      end

      def line_end_character(text, line_number)
        line = text.lines[line_number].to_s.chomp
        Position.codepoint_to_utf16(line, line.length)
      end
    end
  end
end
