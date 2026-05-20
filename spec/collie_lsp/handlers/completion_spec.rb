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
          expect(args[:result].size).to be >= 4
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

  describe '.completions_for_context' do
    let(:source) do
      <<~GRAMMAR
        %token <node> IDENTIFIER
        %%
        expr: IDENTIFIER[name] { $$ = $name; };
      GRAMMAR
    end
    let(:index) { CollieLsp::SymbolIndex.build(CollieLsp::CollieWrapper.new.parse(source), source) }

    it 'suppresses completions inside comments' do
      completions = described_class.completions_for_context('// %', { line: 0, character: 4 }, index)

      expect(completions).to be_empty
    end

    it 'returns type tag completions inside type tags' do
      completions = described_class.completions_for_context('%type <n', { line: 0, character: 8 }, index)

      expect(completions).to include(hash_including(label: 'node'))
    end

    it 'returns action reference completions after dollar triggers' do
      completions = described_class.completions_for_context('$', { line: 0, character: 1 }, index)

      expect(completions).to include(hash_including(label: '$name'))
    end
  end
end
