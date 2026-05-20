# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CollieLsp::DocumentStore do
  let(:store) { described_class.new }
  let(:uri) { 'file:///test.y' }
  let(:text) { 'test content' }
  let(:version) { 1 }

  describe '#open' do
    it 'stores a new document' do
      store.open(uri, text, version)
      doc = store.get(uri)

      expect(doc).not_to be_nil
      expect(doc[:text]).to eq(text)
      expect(doc[:version]).to eq(version)
      expect(doc[:ast]).to be_nil
      expect(doc[:diagnostics]).to eq([])
    end
  end

  describe '#change' do
    before do
      store.open(uri, text, version)
    end

    it 'updates document content' do
      new_text = 'new content'
      new_version = 2

      store.change(uri, new_text, new_version)
      doc = store.get(uri)

      expect(doc[:text]).to eq(new_text)
      expect(doc[:version]).to eq(new_version)
    end

    it 'invalidates AST cache' do
      ast = { rules: [] }
      store.update_ast(uri, ast)

      store.change(uri, 'changed', 2)
      doc = store.get(uri)

      expect(doc[:ast]).to be_nil
    end

    it 'does nothing for unknown document' do
      expect { store.change('unknown', 'text', 1) }.not_to raise_error
    end
  end

  describe '#get' do
    it 'returns document data' do
      store.open(uri, text, version)
      doc = store.get(uri)

      expect(doc).to be_a(Hash)
      expect(doc.keys).to include(:text, :version, :language_id, :ast,
                                  :parse_error, :symbol_index, :semantic_tokens,
                                  :diagnostics)
    end

    it 'returns nil for unknown document' do
      expect(store.get('unknown')).to be_nil
    end
  end

  describe '#close' do
    before do
      store.open(uri, text, version)
    end

    it 'removes document from store' do
      store.close(uri)
      expect(store.get(uri)).to be_nil
    end
  end

  describe '#update_ast' do
    before do
      store.open(uri, text, version)
    end

    it 'updates AST for document' do
      ast = { rules: [{ name: 'test' }] }
      store.update_ast(uri, ast)

      doc = store.get(uri)
      expect(doc[:ast]).to eq(ast)
    end

    it 'does nothing for unknown document' do
      expect { store.update_ast('unknown', {}) }.not_to raise_error
    end
  end

  describe '#update_diagnostics' do
    before do
      store.open(uri, text, version)
    end

    it 'updates diagnostics for document' do
      diagnostics = [{ message: 'error' }]
      store.update_diagnostics(uri, diagnostics)

      doc = store.get(uri)
      expect(doc[:diagnostics]).to eq(diagnostics)
    end

    it 'does nothing for unknown document' do
      expect { store.update_diagnostics('unknown', []) }.not_to raise_error
    end
  end

  describe '#change with incremental edits' do
    before do
      store.open(uri, "first\nsecond\n", version)
    end

    it 'applies range changes' do
      store.change(
        uri,
        [{
          range: {
            start: { line: 1, character: 0 },
            end: { line: 1, character: 6 }
          },
          text: 'changed'
        }],
        2
      )

      expect(store.get(uri)[:text]).to eq("first\nchanged\n")
    end

    it 'applies UTF-16 range changes' do
      store.change(uri, "😀TOKEN\n", 2)

      store.change(
        uri,
        [{
          range: {
            start: { line: 0, character: 2 },
            end: { line: 0, character: 7 }
          },
          text: 'VALUE'
        }],
        3
      )

      expect(store.get(uri)[:text]).to eq("😀VALUE\n")
    end
  end
end
