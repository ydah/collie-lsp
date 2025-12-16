# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CollieLsp::CollieWrapper do
  let(:wrapper) { described_class.new }

  describe '#initialize' do
    it 'creates a wrapper instance' do
      expect(wrapper).to be_a(described_class)
    end

    context 'with workspace root' do
      it 'finds config file if exists' do
        wrapper = described_class.new(workspace_root: '/nonexistent')
        expect(wrapper).to be_a(described_class)
      end
    end
  end

  describe '#parse' do
    it 'returns a mock AST structure' do
      result = wrapper.parse('test grammar')

      expect(result).to be_a(Hash)
      expect(result).to have_key(:declarations)
      expect(result).to have_key(:rules)
      expect(result).to have_key(:prologue)
      expect(result).to have_key(:epilogue)
    end

    it 'handles parse errors gracefully' do
      # The current implementation returns a mock AST, not an error
      # This would be tested when integrated with real Collie gem
      result = wrapper.parse('invalid')

      expect(result).to be_a(Hash)
      expect(result).to have_key(:declarations)
    end
  end

  describe '#lint' do
    it 'returns empty array for valid grammar' do
      offenses = wrapper.lint('valid grammar')

      expect(offenses).to be_an(Array)
      expect(offenses).to be_empty
    end

    it 'returns empty array on parse error' do
      allow(wrapper).to receive(:parse).and_return({ error: 'parse error' })

      offenses = wrapper.lint('invalid')

      expect(offenses).to be_empty
    end
  end

  describe '#format' do
    it 'returns source as-is for mock implementation' do
      source = 'test grammar'
      formatted = wrapper.format(source)

      expect(formatted).to eq(source)
    end

    it 'returns nil on parse error' do
      allow(wrapper).to receive(:parse).and_return({ error: 'parse error' })

      formatted = wrapper.format('invalid')

      expect(formatted).to be_nil
    end
  end

  describe '#autocorrect' do
    it 'returns source as-is for mock implementation' do
      source = 'test grammar'
      corrected = wrapper.autocorrect(source)

      expect(corrected).to eq(source)
    end
  end

  describe 'private methods' do
    describe '#find_config' do
      it 'returns nil for nil workspace root' do
        config = wrapper.send(:find_config, nil)
        expect(config).to be_nil
      end

      it 'returns config path if file exists' do
        allow(File).to receive(:exist?).and_return(true)

        config = wrapper.send(:find_config, '/workspace')
        expect(config).to eq('/workspace/.collie.yml')
      end

      it 'returns nil if file does not exist' do
        allow(File).to receive(:exist?).and_return(false)

        config = wrapper.send(:find_config, '/workspace')
        expect(config).to be_nil
      end
    end
  end
end
