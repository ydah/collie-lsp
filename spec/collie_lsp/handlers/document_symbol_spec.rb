# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CollieLsp::Handlers::DocumentSymbol do
  let(:uri) { 'file:///test.y' }
  let(:writer) { mock_writer }

  describe '.handle' do
    it 'returns an empty list for unknown documents' do
      expect(writer).to receive(:write).with(id: 1, result: [])

      described_class.handle(
        { id: 1, params: { textDocument: { uri: uri } } },
        CollieLsp::DocumentStore.new,
        nil,
        writer
      )
    end

    it 'returns symbols from the cached symbol index' do
      text = <<~GRAMMAR
        %token NUMBER
        %%
        expr: NUMBER ;
        %%
      GRAMMAR
      ast = CollieLsp::CollieWrapper.new.parse(text, filename: 'test.y')
      store = test_document_store(uri: uri, text: text, ast: ast)
      store.update_symbol_index(uri, CollieLsp::SymbolIndex.build(ast, text))

      expect(writer).to receive(:write) do |message|
        expect(message[:result]).to include(
          hash_including(name: 'NUMBER', kind: 14),
          hash_including(name: 'expr', kind: 12)
        )
      end

      described_class.handle(
        { id: 1, params: { textDocument: { uri: uri } } },
        store,
        nil,
        writer
      )
    end
  end

  describe '.build_rule_children' do
    it 'builds alternative children for legacy rule hashes' do
      children = described_class.build_rule_children(
        {
          alternatives: [
            {
              location: { line: 3, column: 1 },
              symbols: [{ name: 'NUMBER' }]
            }
          ]
        }
      )

      expect(children).to contain_exactly(hash_including(name: 'Alternative 1', detail: 'NUMBER'))
    end
  end
end
