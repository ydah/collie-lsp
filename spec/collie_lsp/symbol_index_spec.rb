# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CollieLsp::SymbolIndex do
  let(:source) do
    <<~GRAMMAR
      %token NUMBER PLUS
      %type <node> expr
      %left PLUS
      %start program
      %%
      program: expr ;
      expr: NUMBER | expr PLUS NUMBER ;
      %%
    GRAMMAR
  end
  let(:ast) { CollieLsp::CollieWrapper.new.parse(source, filename: 'test.y') }
  let(:index) { described_class.build(ast, source) }

  it 'indexes declarations and rule definitions from real Collie AST objects' do
    expect(index.definition_for('NUMBER')).to include(kind: :token)
    expect(index.definition_for('program')).to include(kind: :rule)
    expect(index.definition_for('expr')).to include(kind: :rule)
  end

  it 'normalizes declaration locations to the symbol name' do
    location = index.definition_for('NUMBER')[:location]

    expect(location).to include(line: 1, column: 8, length: 6)
  end

  it 'tracks references from rule bodies' do
    references = index.references_for('NUMBER')

    expect(references.size).to eq(2)
    expect(references).to all(include(:location))
  end

  it 'extracts symbols at LSP positions' do
    expect(described_class.symbol_at('%token IDENTIFIER', line: 0, character: 10)).to eq('IDENTIFIER')
  end
end
