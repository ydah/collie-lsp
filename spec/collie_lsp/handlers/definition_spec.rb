# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CollieLsp::Handlers::Definition do
  let(:writer) { mock_writer }
  let(:uri) { 'file:///test.y' }

  describe '.handle' do
    let(:request) do
      {
        id: 1,
        params: {
          textDocument: { uri: uri },
          position: { line: 0, character: 10 }
        }
      }
    end

    context 'when symbol is found' do
      let(:text) { '%token IDENTIFIER' }
      let(:ast) do
        {
          declarations: [{
            kind: :token,
            names: ['IDENTIFIER'],
            location: { line: 1, column: 8 }
          }],
          rules: []
        }
      end
      let(:document_store) { test_document_store(uri: uri, text: text, ast: ast) }

      it 'returns definition location' do
        expect(writer).to receive(:write) do |args|
          expect(args[:id]).to eq(1)
          expect(args[:result]).to include(
            uri: uri,
            range: hash_including(
              start: { line: 0, character: 7 }
            )
          )
        end

        described_class.handle(request, document_store, nil, writer)
      end
    end

    context 'when symbol is not found' do
      let(:text) { '' }
      let(:ast) { mock_ast }
      let(:document_store) { test_document_store(uri: uri, text: text, ast: ast) }

      it 'returns nil' do
        expect(writer).to receive(:write).with(id: 1, result: nil)
        described_class.handle(request, document_store, nil, writer)
      end
    end
  end

  describe '.find_symbol_at_position' do
    it 'extracts symbol name at position' do
      text = '%token IDENTIFIER NUMBER'
      position = { line: 0, character: 10 }

      symbol = described_class.find_symbol_at_position(text, position)
      expect(symbol).to eq('IDENTIFIER')
    end
  end

  describe '.find_definition_location' do
    let(:ast) do
      {
        declarations: [{
          kind: :token,
          names: ['TEST'],
          location: { line: 5, column: 10 }
        }],
        rules: [{
          name: 'rule_name',
          location: { line: 15, column: 1 }
        }]
      }
    end

    it 'finds token declaration location' do
      location = described_class.find_definition_location(ast, 'TEST', uri)

      expect(location).to include(
        uri: uri,
        range: hash_including(
          start: { line: 4, character: 9 }
        )
      )
    end

    it 'finds nonterminal declaration location' do
      location = described_class.find_definition_location(ast, 'rule_name', uri)

      expect(location).to include(
        uri: uri,
        range: hash_including(
          start: { line: 14, character: 0 }
        )
      )
    end

    it 'returns nil for unknown symbol' do
      location = described_class.find_definition_location(ast, 'unknown', uri)
      expect(location).to be_nil
    end
  end
end
