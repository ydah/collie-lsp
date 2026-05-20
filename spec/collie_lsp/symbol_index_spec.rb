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

  context 'with Lrama extensions' do
    let(:source) do
      <<~'GRAMMAR'
        %token NUMBER
        %rule list(item): item | list(item) item ;
        %inline opt
        %%
        expr: NUMBER[num] { $$ = $num + $1; } ;
        %%
      GRAMMAR
    end

    it 'indexes parameterized and inline rules' do
      expect(index.definition_for('list')).to include(kind: :parameterized_rule)
      expect(index.definition_for('opt')).to include(kind: :inline_rule)
    end

    it 'links action named references back to bracket aliases' do
      action_line = source.lines.find_index { |line| line.include?('$num') }
      action_character = source.lines[action_line].index('$num') + 1
      definition = index.definition_for_at('$num', line: action_line, character: action_character)

      expect(definition).to include(kind: :reference_target)
      expect(definition[:location]).to include(line: 5, column: 14, length: 3)
    end

    it 'links positional action references to production symbols' do
      action_line = source.lines.find_index { |line| line.include?('$1') }
      action_character = source.lines[action_line].index('$1') + 1
      definition = index.definition_for_at('$1', line: action_line, character: action_character)

      expect(definition).to include(kind: :reference_target)
      expect(definition[:location]).to include(line: 5, column: 7, length: 6)
    end

    it 'includes action references when finding named reference occurrences' do
      occurrences = index.all_occurrences('num')

      expect(occurrences.map { |entry| entry[:name] }).to include('num', '$num')
    end
  end
end
