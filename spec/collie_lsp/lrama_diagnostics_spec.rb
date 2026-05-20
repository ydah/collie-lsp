# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CollieLsp::LramaDiagnostics do
  def parse(source)
    CollieLsp::CollieWrapper.new.parse(source, filename: 'test.y')
  end

  it 'reports parameterized rule arity mismatches' do
    ast = parse(<<~GRAMMAR)
      %token NUMBER
      %rule list(item): item ;
      %%
      expr: list(NUMBER, NUMBER) ;
      %%
    GRAMMAR

    diagnostics = described_class.analyze(ast)

    expect(diagnostics).to include(hash_including(rule_name: 'ParameterizedRuleArity', length: 4))
  end

  it 'reports invalid named and positional action references' do
    ast = parse(<<~GRAMMAR)
      %token NUMBER PLUS
      %%
      expr: NUMBER[item] PLUS[item] { $$ = $missing + $3; } ;
      %%
    GRAMMAR

    diagnostics = described_class.analyze(ast)

    expect(diagnostics).to include(
      hash_including(rule_name: 'DuplicateNamedReference'),
      hash_including(rule_name: 'UndefinedNamedReference'),
      hash_including(rule_name: 'InvalidActionReference')
    )
  end
end
