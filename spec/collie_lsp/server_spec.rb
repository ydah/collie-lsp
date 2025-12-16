# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CollieLsp::Server do
  let(:input) { StringIO.new }
  let(:output) { StringIO.new }
  let(:server) { described_class.new(input: input, output: output) }

  describe '#initialize' do
    it 'creates a server instance' do
      expect(server).to be_a(described_class)
    end
  end

  describe 'private methods' do
    describe '#extract_workspace_root' do
      it 'extracts workspace root from file URI' do
        request = {
          params: {
            rootUri: 'file:///workspace/path'
          }
        }

        root = server.send(:extract_workspace_root, request)
        expect(root).to eq('/workspace/path')
      end

      it 'returns nil for nil rootUri' do
        request = { params: {} }

        root = server.send(:extract_workspace_root, request)
        expect(root).to be_nil
      end
    end

    describe '#log_error' do
      it 'does not log when COLLIE_LSP_LOG is not set' do
        expect(File).not_to receive(:open)
        server.send(:log_error, 'test error')
      end

      it 'logs to file when COLLIE_LSP_LOG is set' do
        log_file = '/tmp/collie_lsp_test.log'
        ENV['COLLIE_LSP_LOG'] = log_file

        expect(File).to receive(:open).with(log_file, 'a')

        server.send(:log_error, 'test error')

        ENV.delete('COLLIE_LSP_LOG')
      end
    end
  end
end
