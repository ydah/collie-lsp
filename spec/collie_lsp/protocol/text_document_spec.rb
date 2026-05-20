# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CollieLsp::Protocol::TextDocument do
  let(:writer) { mock_writer }
  let(:document_store) { CollieLsp::DocumentStore.new }
  let(:collie) { CollieLsp::CollieWrapper.new }
  let(:uri) { 'file:///test.y' }

  describe '.handle_did_open' do
    it 'caches the parsed AST and publishes diagnostics' do
      request = {
        params: {
          textDocument: {
            uri: uri,
            languageId: 'yacc',
            version: 1,
            text: "%token NUMBER\n%%\nprogram: NUMBER;\n%%\n"
          }
        }
      }

      expect(writer).to receive(:write).with(hash_including(method: 'textDocument/publishDiagnostics'))

      described_class.handle_did_open(request, document_store, collie, writer)

      doc = document_store.get(uri)
      expect(doc[:ast]).to be_a(Collie::AST::GrammarFile)
      expect(doc[:parse_error]).to be_nil
      expect(doc[:language_id]).to eq('yacc')
    end

    it 'publishes parse errors as diagnostics' do
      request = {
        params: {
          textDocument: {
            uri: uri,
            languageId: 'yacc',
            version: 1,
            text: 'invalid'
          }
        }
      }

      expect(writer).to receive(:write) do |message|
        diagnostic = message.dig(:params, :diagnostics)&.first
        expect(diagnostic).to include(code: 'ParseError', severity: 1)
      end

      described_class.handle_did_open(request, document_store, collie, writer)

      expect(document_store.get(uri)[:ast]).to be_nil
      expect(document_store.get(uri)[:parse_error]).to include(rule_name: 'ParseError')
    end
  end
end
