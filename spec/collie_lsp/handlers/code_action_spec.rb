# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CollieLsp::Handlers::CodeAction do
  let(:uri) { 'file:///test.y' }
  let(:writer) { mock_writer }

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

  describe '.handle' do
    it 'returns unresolved fix-all actions for codeAction/resolve' do
      store = test_document_store(uri: uri, text: "%token NUMBER  \n")
      store.update_diagnostics(
        uri,
        [{
          code: 'TrailingWhitespace',
          range: {
            start: { line: 0, character: 13 },
            end: { line: 0, character: 15 }
          },
          data: { autocorrect: true }
        }]
      )

      expect(writer).to receive(:write) do |message|
        action = message[:result].find { |item| item[:kind] == 'source.fixAll' }
        expect(action).to include(data: include(resolve: 'fixAll', uri: uri))
        expect(action).not_to include(:edit)
      end

      described_class.handle(
        {
          id: 1,
          params: {
            textDocument: { uri: uri },
            range: {
              start: { line: 0, character: 0 },
              end: { line: 0, character: 20 }
            },
            context: { only: ['source.fixAll'] }
          }
        },
        store,
        CollieLsp::CollieWrapper.new,
        writer
      )
    end
  end

  describe '.resolve' do
    it 'materializes fix-all edits lazily' do
      store = test_document_store(uri: uri, text: "%token NUMBER  \n%%\nexpr: NUMBER;\n%%\n")
      collie = instance_double(CollieLsp::CollieWrapper)
      allow(collie).to receive(:autocorrect).and_return("%token NUMBER\n%%\nexpr: NUMBER;\n%%\n")

      expect(writer).to receive(:write) do |message|
        edit = message.dig(:result, :edit, :changes, uri)&.first
        expect(edit).to include(newText: "%token NUMBER\n%%\nexpr: NUMBER;\n%%\n")
      end

      described_class.resolve(
        {
          id: 2,
          params: {
            title: 'Fix all auto-correctable offenses',
            kind: 'source.fixAll',
            data: { resolve: 'fixAll', uri: uri }
          }
        },
        store,
        collie,
        writer
      )
    end
  end
end
