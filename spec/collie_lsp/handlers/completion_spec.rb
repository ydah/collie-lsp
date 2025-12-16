# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CollieLsp::Handlers::Completion do
  let(:writer) { mock_writer }
  let(:uri) { 'file:///test.y' }

  describe '.handle' do
    let(:request) do
      {
        id: 1,
        params: {
          textDocument: { uri: uri },
          position: { line: 0, character: 0 }
        }
      }
    end

    context 'when document exists with AST' do
      let(:ast) do
        mock_ast(
          tokens: %w[IDENTIFIER NUMBER],
          rules: %w[expr term]
        )
      end
      let(:document_store) { test_document_store(uri: uri, ast: ast) }

      it 'returns completion items' do
        expect(writer).to receive(:write) do |args|
          expect(args[:id]).to eq(1)
          expect(args[:result]).to be_an(Array)
          expect(args[:result].size).to eq(4) # 2 tokens + 2 rules
        end

        described_class.handle(request, document_store, nil, writer)
      end
    end

    context 'when document does not exist' do
      let(:document_store) { CollieLsp::DocumentStore.new }

      it 'returns empty array' do
        expect(writer).to receive(:write).with(id: 1, result: [])
        described_class.handle(request, document_store, nil, writer)
      end
    end
  end

  describe '.build_completions' do
    let(:ast) do
      mock_ast(
        tokens: ['IDENTIFIER'],
        rules: ['expr']
      )
    end

    it 'builds completion items from AST' do
      completions = described_class.build_completions(ast)

      expect(completions).to include(
        hash_including(
          label: 'IDENTIFIER',
          kind: 14,
          detail: 'Token: IDENTIFIER'
        )
      )

      expect(completions).to include(
        hash_including(
          label: 'expr',
          kind: 7,
          detail: 'Nonterminal: expr'
        )
      )
    end
  end
end
