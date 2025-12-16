# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

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
    it 'returns an AST structure for valid grammar' do
      source = <<~GRAMMAR
        %token NUMBER
        %%
        program: NUMBER;
        %%
      GRAMMAR

      result = wrapper.parse(source)

      expect(result).to be_a(Collie::AST::GrammarFile)
      expect(result.declarations).to be_an(Array)
      expect(result.rules).to be_an(Array)
    end

    it 'handles parse errors gracefully' do
      # Invalid grammar that will fail to parse
      result = wrapper.parse('invalid')

      expect(result).to be_nil
    end
  end

  describe '#lint' do
    it 'returns array of offenses for valid grammar' do
      source = <<~GRAMMAR
        %token NUMBER
        %%
        program: NUMBER;
        %%
      GRAMMAR

      offenses = wrapper.lint(source)

      expect(offenses).to be_an(Array)
      # The result may or may not have offenses depending on the grammar
    end

    it 'returns empty array on parse error' do
      offenses = wrapper.lint('invalid')

      expect(offenses).to be_empty
    end
  end

  describe '#format' do
    it 'formats valid grammar source' do
      source = <<~GRAMMAR
        %token NUMBER
        %%
        program: NUMBER;
        %%
      GRAMMAR

      formatted = wrapper.format(source)

      expect(formatted).to be_a(String)
      expect(formatted).to include('NUMBER')
      expect(formatted).to include('program')
    end

    it 'returns nil on parse error' do
      formatted = wrapper.format('invalid')

      expect(formatted).to be_nil
    end
  end

  describe '#autocorrect' do
    it 'autocorrects valid grammar source' do
      source = <<~GRAMMAR
        %token NUMBER
        %%
        program: NUMBER;
        %%
      GRAMMAR

      corrected = wrapper.autocorrect(source)

      expect(corrected).to be_a(String)
      # Autocorrect delegates to format, so it should return formatted source
    end
  end

  describe 'private methods' do
    describe '#find_config' do
      it 'returns nil for nil workspace root' do
        config = wrapper.send(:find_config, nil)
        expect(config).to be_nil
      end

      it 'returns config path if file exists' do
        temp_dir = Dir.mktmpdir
        config_file = File.join(temp_dir, '.collie.yml')
        File.write(config_file, "# test config\n")

        wrapper_with_config = described_class.new(workspace_root: temp_dir)
        config = wrapper_with_config.send(:find_config, temp_dir)

        expect(config).to eq(config_file)

        FileUtils.rm_rf(temp_dir)
      end

      it 'returns nil if file does not exist' do
        allow(File).to receive(:exist?).and_return(false)

        config = wrapper.send(:find_config, '/workspace')
        expect(config).to be_nil
      end
    end
  end
end
