# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CollieLsp::Handlers::Formatting do
  let(:writer) { mock_writer }
  let(:uri) { 'file:///test.y' }

  describe '.handle_range' do
    it 'removes trailing whitespace in the requested range' do
      store = test_document_store(uri: uri, text: "%token NUMBER  \n%%\n")
      request = {
        id: 1,
        params: {
          textDocument: { uri: uri },
          range: {
            start: { line: 0, character: 0 },
            end: { line: 0, character: 15 }
          }
        }
      }

      expect(writer).to receive(:write) do |message|
        expect(message[:result]).to contain_exactly(
          hash_including(newText: '')
        )
      end

      described_class.handle_range(request, store, nil, writer)
    end
  end
end
