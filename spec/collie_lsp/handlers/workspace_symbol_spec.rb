# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'

RSpec.describe CollieLsp::Handlers::WorkspaceSymbol do
  let(:writer) { mock_writer }

  describe '.search_symbols' do
    it 'finds symbols in unopened workspace files' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'grammar.y')
        File.write(path, "%token NUMBER\n%%\nprogram: NUMBER;\n%%\n")
        collie = CollieLsp::CollieWrapper.new(workspace_root: dir)

        symbols = described_class.search_symbols('program', CollieLsp::DocumentStore.new, collie)

        expect(symbols).to include(hash_including(name: 'program'))
      end
    end

    it 'respects Collie exclude patterns' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, '.collie.yml'), <<~YAML)
          exclude:
            - ignored/**/*
        YAML
        FileUtils.mkdir_p(File.join(dir, 'ignored'))
        File.write(File.join(dir, 'ignored', 'grammar.y'), "%token NUMBER\n%%\nskipped: NUMBER;\n%%\n")
        collie = CollieLsp::CollieWrapper.new(workspace_root: dir)

        symbols = described_class.search_symbols('skipped', CollieLsp::DocumentStore.new, collie)

        expect(symbols).to be_empty
      end
    end
  end
end
