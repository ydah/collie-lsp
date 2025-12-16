# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CollieLsp::Handlers::Hover do
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

    context 'when document exists' do
      let(:text) { '%token IDENTIFIER NUMBER' }
      let(:ast) do
        mock_ast(tokens: %w[IDENTIFIER NUMBER])
      end
      let(:document_store) { test_document_store(uri: uri, text: text, ast: ast) }

      it 'returns hover information for token' do
        expect(writer).to receive(:write).with(
          hash_including(
            id: 1,
            result: hash_including(
              contents: hash_including(
                kind: 'markdown',
                value: match(/Token.*IDENTIFIER/)
              )
            )
          )
        )

        described_class.handle(request, document_store, nil, writer)
      end
    end

    context 'when document does not exist' do
      let(:document_store) { CollieLsp::DocumentStore.new }

      it 'returns nil' do
        expect(writer).to receive(:write).with(id: 1, result: nil)
        described_class.handle(request, document_store, nil, writer)
      end
    end
  end

  describe '.find_symbol_at_position' do
    it 'extracts symbol at position' do
      text = '%token IDENTIFIER'
      position = { line: 0, character: 10 }

      symbol = described_class.find_symbol_at_position(text, position)
      expect(symbol).to eq('IDENTIFIER')
    end

    it 'returns nil for invalid position' do
      text = '%token IDENTIFIER'
      position = { line: 10, character: 0 }

      symbol = described_class.find_symbol_at_position(text, position)
      expect(symbol).to be_nil
    end
  end

  describe '.build_hover_content' do
    let(:ast) do
      mock_ast(
        tokens: ['IDENTIFIER'],
        rules: ['expr']
      )
    end

    it 'builds hover for token' do
      content = described_class.build_hover_content(ast, 'IDENTIFIER')

      expect(content).to include(
        kind: 'markdown',
        value: match(/Token.*IDENTIFIER/)
      )
    end

    it 'builds hover for nonterminal' do
      content = described_class.build_hover_content(ast, 'expr')

      expect(content).to include(
        kind: 'markdown',
        value: match(/Nonterminal.*expr/)
      )
    end

    it 'returns nil for unknown symbol' do
      content = described_class.build_hover_content(ast, 'unknown')
      expect(content).to be_nil
    end
  end
end
