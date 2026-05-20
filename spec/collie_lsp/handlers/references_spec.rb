# frozen_string_literal: true

require 'fileutils'
require 'spec_helper'
require 'tmpdir'

RSpec.describe CollieLsp::Handlers::References do
  let(:uri) { 'file:///open.y' }

  describe '.find_workspace_references' do
    it 'finds references in unopened workspace files' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'closed.y'), "%token NUMBER\n%%\nother: NUMBER;\n%%\n")
        collie = CollieLsp::CollieWrapper.new(workspace_root: dir)
        store = test_document_store(
          uri: uri,
          text: "%token NUMBER\n%%\nexpr: NUMBER;\n%%\n",
          ast: CollieLsp::CollieWrapper.new.parse("%token NUMBER\n%%\nexpr: NUMBER;\n%%\n")
        )

        locations = described_class.find_workspace_references(store, collie, 'NUMBER', false)

        expect(locations.map { |location| location[:uri] }).to include(uri, CollieLsp::UriUtils.file_uri(File.join(dir, 'closed.y')))
      end
    end
  end
end
