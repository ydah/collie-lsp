# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CollieLsp::Handlers::FoldingRange do
  describe '.build_folding_ranges' do
    it 'uses the actual rule semicolon instead of a fixed offset' do
      source = <<~GRAMMAR
        %token NUMBER
        %%
        expr:
          NUMBER
        | expr NUMBER
        ;
        %%
      GRAMMAR
      ast = CollieLsp::CollieWrapper.new.parse(source, filename: 'test.y')

      ranges = described_class.build_folding_ranges(source, ast)

      expect(ranges).to include(hash_including(startLine: 2, endLine: 5))
    end
  end
end
