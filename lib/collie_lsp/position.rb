# frozen_string_literal: true

module CollieLsp
  # Converts between Ruby character indexes and LSP UTF-16 positions.
  module Position
    module_function

    def utf16_to_codepoint_index(line, utf16_character)
      units = 0
      line.each_char.with_index do |char, index|
        next_units = units + utf16_units(char)
        return index if next_units > utf16_character

        units = next_units
      end

      line.length
    end

    def codepoint_to_utf16(line, codepoint_index)
      line.each_char.take(codepoint_index).sum { |char| utf16_units(char) }
    end

    def codepoint_length_to_utf16(text)
      text.each_char.sum { |char| utf16_units(char) }
    end

    def location_to_range(location, text: nil, fallback_length: 1)
      line_number = location[:line] - 1
      column = location[:column] - 1
      length = location[:length].to_i.positive? ? location[:length].to_i : fallback_length
      line_text = text&.lines&.[](line_number)

      start_character = line_text ? codepoint_to_utf16(line_text, column) : column
      token_text = line_text ? line_text[column, length].to_s : ''
      utf16_length = line_text ? codepoint_length_to_utf16(token_text) : length

      {
        start: { line: line_number, character: start_character },
        end: { line: line_number, character: start_character + utf16_length }
      }
    end

    def position_to_offset(text, position)
      line = position[:line]
      character = position[:character]
      offset = 0

      text.lines.each_with_index do |line_text, index|
        if index == line
          codepoint_index = utf16_to_codepoint_index(line_text, character)
          return offset + codepoint_index
        end

        offset += line_text.length
      end

      offset
    end

    def range_to_offsets(text, range)
      [
        position_to_offset(text, range[:start]),
        position_to_offset(text, range[:end])
      ]
    end

    def text_for_range(text, range)
      start_offset, end_offset = range_to_offsets(text, range)
      text[start_offset...end_offset].to_s
    end

    def contains?(range, position)
      starts_before =
        range[:start][:line] < position[:line] ||
        (range[:start][:line] == position[:line] && range[:start][:character] <= position[:character])
      ends_after =
        range[:end][:line] > position[:line] ||
        (range[:end][:line] == position[:line] && range[:end][:character] >= position[:character])

      starts_before && ends_after
    end

    def utf16_units(char)
      char.ord > 0xFFFF ? 2 : 1
    end
  end
end
