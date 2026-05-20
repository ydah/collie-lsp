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

      it 'uses the first workspace folder when present' do
        request = {
          params: {
            workspaceFolders: [
              { uri: 'file:///workspace/one', name: 'one' },
              { uri: 'file:///workspace/two', name: 'two' }
            ],
            rootUri: 'file:///workspace/root'
          }
        }

        root = server.send(:extract_workspace_root, request)
        expect(root).to eq('/workspace/one')
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

    describe '#handle_request lifecycle' do
      let(:writer) { mock_writer }

      before do
        server.instance_variable_set(:@writer, writer)
      end

      it 'rejects normal requests before initialize' do
        expect(writer).to receive(:write).with(
          id: 1,
          error: hash_including(code: CollieLsp::Server::SERVER_NOT_INITIALIZED)
        )

        server.send(:handle_request, id: 1, method: 'textDocument/hover', params: {})
      end

      it 'rejects requests after shutdown' do
        server.instance_variable_set(:@initialized, true)
        server.instance_variable_set(:@shutdown, true)

        expect(writer).to receive(:write).with(
          id: 1,
          error: hash_including(code: CollieLsp::Server::INVALID_REQUEST)
        )

        server.send(:handle_request, id: 1, method: 'textDocument/hover', params: {})
      end

      it 'stores cancelled request ids without responding' do
        expect(writer).not_to receive(:write)

        server.send(:handle_request, method: '$/cancelRequest', params: { id: 99 })

        expect(server.instance_variable_get(:@cancelled_request_ids)).to include(99 => true)
      end

      it 'updates workspace folders when notified' do
        collie = CollieLsp::CollieWrapper.new(workspace_roots: ['/old'])
        server.instance_variable_set(:@initialized, true)
        server.instance_variable_set(:@collie, collie)
        expect(writer).to receive(:write).with(hash_including(method: 'window/logMessage'))

        server.send(
          :handle_request,
          method: 'workspace/didChangeWorkspaceFolders',
          params: {
            event: {
              added: [{ uri: 'file:///new', name: 'new' }],
              removed: [{ uri: 'file:///old', name: 'old' }]
            }
          }
        )

        expect(collie.workspace_roots).to eq(['/new'])
      end

      it 'turns late responses into request-cancelled errors' do
        cancellable_writer = described_class::CancellableWriter.new(writer, server, 99)
        server.send(:handle_cancel_request, params: { id: 99 })

        expect(writer).to receive(:write).with(
          id: 99,
          error: hash_including(code: CollieLsp::Server::REQUEST_CANCELLED)
        )

        cancellable_writer.write(id: 99, result: [])
      end
    end
  end
end
