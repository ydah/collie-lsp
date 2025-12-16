# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CollieLsp::Handlers::SemanticTokens do
  let(:writer) { mock_writer }
  let(:uri) { 'file:///test.y' }

  describe '.handle' do
    let(:request) do
      {
        id: 1,
        params: {
          textDocument: { uri: uri }
        }
      }
    end

    context 'when document exists' do
      let(:text) { '%token IDENTIFIER' }
      let(:ast) { mock_ast(tokens: ['IDENTIFIER']) }
      let(:document_store) { test_document_store(uri: uri, text: text, ast: ast) }

      it 'returns semantic tokens' do
        expect(writer).to receive(:write) do |args|
          expect(args[:id]).to eq(1)
          expect(args[:result]).to include(data: kind_of(Array))
        end

        described_class.handle(request, document_store, nil, writer)
      end
    end

    context 'when document does not exist' do
      let(:document_store) { CollieLsp::DocumentStore.new }

      it 'returns empty data' do
        expect(writer).to receive(:write).with(id: 1, result: { data: [] })
        described_class.handle(request, document_store, nil, writer)
      end
    end
  end

  describe '.build_symbol_info' do
    let(:ast) { mock_ast(tokens: ['TOKEN'], rules: ['rule']) }

    it 'builds symbol information from AST' do
      info = described_class.build_symbol_info(ast)

      expect(info[:tokens]).to include('TOKEN' => true)
      expect(info[:nonterminals]).to include('rule' => true)
      expect(info[:keywords]).to include('%token' => true)
    end
  end

  describe '.encode_tokens' do
    it 'encodes tokens in delta format' do
      tokens = [
        { line: 0, startChar: 0, length: 5, tokenType: 0, tokenModifiers: 0 },
        { line: 0, startChar: 6, length: 4, tokenType: 1, tokenModifiers: 0 },
        { line: 1, startChar: 0, length: 3, tokenType: 2, tokenModifiers: 0 }
      ]

      encoded = described_class.encode_tokens(tokens)

      expect(encoded).to be_an(Array)
      expect(encoded.size).to eq(15) # 3 tokens × 5 values
      expect(encoded[0]).to eq(0) # delta line for first token
    end
  end

  describe 'TOKEN_TYPES and TOKEN_MODIFIERS' do
    it 'defines token types' do
      expect(described_class::TOKEN_TYPES).to be_an(Array)
      expect(described_class::TOKEN_TYPES).to include('keyword', 'string', 'comment')
    end

    it 'defines token modifiers' do
      expect(described_class::TOKEN_MODIFIERS).to be_an(Array)
      expect(described_class::TOKEN_MODIFIERS).to include('declaration', 'definition')
    end
  end
end
