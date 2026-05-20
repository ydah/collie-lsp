# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CollieLsp::Handlers::CodeAction do
  let(:uri) { 'file:///test.y' }

  describe '.quickfix_actions' do
    it 'creates a trailing whitespace quickfix' do
      diagnostic = {
        code: 'TrailingWhitespace',
        range: {
          start: { line: 0, character: 13 },
          end: { line: 0, character: 15 }
        },
        data: { autocorrect: true }
      }
      doc = { text: "%token NUMBER  \n" }

      actions = described_class.quickfix_actions(uri, doc, diagnostic)

      expect(actions).to include(hash_including(title: 'Remove trailing whitespace', kind: 'quickfix'))
    end

    it 'creates an undefined token declaration quickfix' do
      diagnostic = {
        code: 'UndefinedSymbol',
        range: {
          start: { line: 2, character: 6 },
          end: { line: 2, character: 13 }
        },
        data: { autocorrect: true }
      }
      doc = { text: "%token NUMBER\n%%\nexpr: MISSING;\n%%\n" }

      actions = described_class.quickfix_actions(uri, doc, diagnostic)

      expect(actions.first[:edit][:changes][uri].first[:newText]).to eq("%token MISSING\n")
    end
  end
end
