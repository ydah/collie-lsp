# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CollieLsp::Handlers::Rename do
  let(:writer) { mock_writer }
  let(:uri) { 'file:///test.y' }

  describe '.handle' do
    let(:request) do
      {
        id: 1,
        params: {
          textDocument: { uri: uri },
          position: { line: 0, character: 10 },
          newName: 'NEW_NAME'
        }
      }
    end

    context 'when rename is valid' do
      let(:text) { "%token OLD_NAME\n\nexpr: OLD_NAME ;" }
      let(:ast) do
        {
          declarations: [{
            kind: :token,
            names: ['OLD_NAME'],
            location: { line: 1, column: 8 }
          }],
          rules: []
        }
      end
      let(:document_store) { test_document_store(uri: uri, text: text, ast: ast) }

      it 'returns workspace edit' do
        expect(writer).to receive(:write) do |args|
          expect(args[:id]).to eq(1)
          expect(args[:result]).to include(
            changes: hash_including(uri => kind_of(Array))
          )
        end

        described_class.handle(request, document_store, nil, writer)
      end
    end

    context 'when new name is invalid' do
      let(:request) do
        {
          id: 1,
          params: {
            textDocument: { uri: uri },
            position: { line: 0, character: 10 },
            newName: 'invalid_name' # lowercase for token
          }
        }
      end
      let(:text) { '%token TOKEN_NAME' }
      let(:ast) { mock_ast(tokens: ['TOKEN_NAME']) }
      let(:document_store) { test_document_store(uri: uri, text: text, ast: ast) }

      it 'returns nil' do
        expect(writer).to receive(:write).with(id: 1, result: nil)
        described_class.handle(request, document_store, nil, writer)
      end
    end
  end

  describe '.valid_name?' do
    let(:ast) { mock_ast(tokens: ['TOKEN'], rules: ['rule']) }

    it 'validates token naming convention' do
      expect(described_class.valid_name?('TOKEN', 'NEW_TOKEN', ast)).to be true
      expect(described_class.valid_name?('TOKEN', 'invalid', ast)).to be false
    end

    it 'validates nonterminal naming convention' do
      expect(described_class.valid_name?('rule', 'new_rule', ast)).to be true
      expect(described_class.valid_name?('rule', 'INVALID', ast)).to be false
    end

    it 'rejects empty names' do
      expect(described_class.valid_name?('TOKEN', '', ast)).to be false
    end
  end

  describe '.find_all_occurrences' do
    let(:text) { "%token TEST\n\nexpr: TEST ;" }
    let(:ast) do
      {
        declarations: [{
          kind: :token,
          names: ['TEST'],
          location: { line: 1, column: 8 }
        }],
        rules: [{
          name: 'expr',
          location: { line: 3, column: 1 },
          alternatives: []
        }]
      }
    end

    it 'finds all occurrences of a symbol' do
      locations = described_class.find_all_occurrences(text, 'TEST', ast)

      expect(locations.size).to be >= 1
      expect(locations).to all(include(:line, :column))
    end
  end
end
