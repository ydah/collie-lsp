# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'generated grammar smoke coverage' do
  let(:wrapper) { CollieLsp::CollieWrapper.new }

  def generated_grammar(seed)
    token = "TOKEN_#{seed}"
    other = "OTHER_#{seed}"
    rule = "rule_#{seed}"

    <<~GRAMMAR
      %token #{token} #{other}
      %start #{rule}
      %%
      #{rule}: #{token}[item] { $$ = $item; }
        | #{other}
        ;
      %%
    GRAMMAR
  end

  it 'does not crash core LSP handlers for deterministic random grammar fragments' do
    Random.new(12_345).then { |rng| Array.new(8) { rng.rand(10_000) } }.each_with_index do |seed, index|
      uri = "file:///generated_#{index}.y"
      text = generated_grammar(seed)
      ast = wrapper.parse(text, filename: "generated_#{index}.y")
      expect(ast).not_to be_nil

      store = test_document_store(uri: uri, text: text, ast: ast)
      store.update_symbol_index(uri, CollieLsp::SymbolIndex.build(ast, text))
      writer = mock_writer
      text_document = { uri: uri }

      expect do
        CollieLsp::Handlers::DocumentSymbol.handle({ id: 1, params: { textDocument: text_document } }, store, wrapper, writer)
        CollieLsp::Handlers::FoldingRange.handle({ id: 2, params: { textDocument: text_document } }, store, wrapper, writer)
        CollieLsp::Handlers::SemanticTokens.handle({ id: 3, params: { textDocument: text_document } }, store, wrapper, writer)
        CollieLsp::Handlers::SemanticTokens.handle_delta(
          { id: 4, params: { textDocument: text_document, previousResultId: 'stale' } },
          store,
          wrapper,
          writer
        )
        CollieLsp::Handlers::Completion.handle(
          { id: 5, params: { textDocument: text_document, position: { line: 3, character: 10 } } },
          store,
          wrapper,
          writer
        )
        CollieLsp::Handlers::Hover.handle(
          { id: 6, params: { textDocument: text_document, position: { line: 3, character: 10 } } },
          store,
          wrapper,
          writer
        )
        CollieLsp::Handlers::Definition.handle(
          { id: 7, params: { textDocument: text_document, position: { line: 3, character: 10 } } },
          store,
          wrapper,
          writer
        )
        CollieLsp::Handlers::References.handle(
          {
            id: 8,
            params: {
              textDocument: text_document,
              position: { line: 3, character: 10 },
              context: { includeDeclaration: true }
            }
          },
          store,
          wrapper,
          writer
        )
      end.not_to raise_error
    end
  end
end
