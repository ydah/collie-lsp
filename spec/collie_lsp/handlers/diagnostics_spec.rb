# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CollieLsp::Handlers::Diagnostics do
  let(:writer) { mock_writer }
  let(:document_store) { CollieLsp::DocumentStore.new }
  let(:uri) { 'file:///test.y' }

  describe '.publish' do
    it 'publishes diagnostics to writer' do
      offenses = [
        {
          location: { line: 5, column: 10 },
          severity: :error,
          rule_name: 'TestRule',
          message: 'Test error'
        }
      ]

      document_store.open(uri, '', 1)

      expect(writer).to receive(:write).with(
        hash_including(
          method: 'textDocument/publishDiagnostics',
          params: hash_including(
            uri: uri,
            diagnostics: array_including(
              hash_including(
                message: 'Test error',
                severity: 1
              )
            )
          )
        )
      )

      described_class.publish(uri, offenses, document_store, writer)
    end

    it 'converts offense to diagnostic correctly' do
      offense = {
        location: { line: 10, column: 5 },
        severity: :warning,
        rule_name: 'WarningRule',
        message: 'Warning message'
      }

      diagnostic = described_class.offense_to_diagnostic(offense)

      expect(diagnostic).to include(
        range: {
          start: { line: 9, character: 4 },
          end: { line: 9, character: 5 }
        },
        severity: 2,
        code: 'WarningRule',
        source: 'collie',
        message: 'Warning message'
      )
    end
  end

  describe '.offense_to_diagnostic' do
    it 'uses offense length when present' do
      diagnostic = described_class.offense_to_diagnostic(
        location: { line: 2, column: 3 },
        severity: :error,
        rule_name: 'ParseError',
        message: 'parse failed',
        length: 4
      )

      expect(diagnostic[:range]).to eq(
        start: { line: 1, character: 2 },
        end: { line: 1, character: 6 }
      )
    end
  end

  describe '.severity_to_lsp' do
    it 'converts error severity' do
      expect(described_class.severity_to_lsp(:error)).to eq(1)
    end

    it 'converts warning severity' do
      expect(described_class.severity_to_lsp(:warning)).to eq(2)
    end

    it 'converts convention severity' do
      expect(described_class.severity_to_lsp(:convention)).to eq(3)
    end

    it 'converts info severity' do
      expect(described_class.severity_to_lsp(:info)).to eq(4)
    end

    it 'defaults to info for unknown severity' do
      expect(described_class.severity_to_lsp(:unknown)).to eq(3)
    end
  end
end
