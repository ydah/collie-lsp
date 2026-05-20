# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CollieLsp::Position do
  it 'converts UTF-16 characters to Ruby character indexes' do
    expect(described_class.utf16_to_codepoint_index("😀TOKEN\n", 2)).to eq(1)
  end

  it 'converts Ruby character indexes to UTF-16 characters' do
    expect(described_class.codepoint_to_utf16("😀TOKEN\n", 1)).to eq(2)
  end

  it 'builds LSP ranges using UTF-16 characters' do
    range = described_class.location_to_range(
      { line: 1, column: 2, length: 5 },
      text: "😀TOKEN\n"
    )

    expect(range).to eq(
      start: { line: 0, character: 2 },
      end: { line: 0, character: 7 }
    )
  end
end
