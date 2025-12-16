# frozen_string_literal: true

require 'language_server-protocol'

module CollieLsp
  # Main LSP server implementation
  class Server
    # Initialize server
    # @param input [IO] Input stream (default: stdin)
    # @param output [IO] Output stream (default: stdout)
    def initialize(input: $stdin, output: $stdout)
      @reader = LanguageServer::Protocol::Transport::Io::Reader.new(input)
      @writer = LanguageServer::Protocol::Transport::Io::Writer.new(output)
      @document_store = DocumentStore.new
      @collie = nil
      @workspace_root = nil
    end

    # Start the server
    def start
      @reader.read do |request|
        handle_request(request)
      end
    end

    private

    # Handle an LSP request
    # @param request [Hash] LSP request message
    def handle_request(request)
      case request[:method]
      when 'initialize'
        handle_initialize(request)
      when 'initialized'
        Protocol::Initialize.handle_initialized(request, @writer)
      when 'textDocument/didOpen'
        Protocol::TextDocument.handle_did_open(request, @document_store, @collie, @writer)
      when 'textDocument/didChange'
        Protocol::TextDocument.handle_did_change(request, @document_store, @collie, @writer)
      when 'textDocument/didSave'
        Protocol::TextDocument.handle_did_save(request, @document_store, @collie, @writer)
      when 'textDocument/didClose'
        Protocol::TextDocument.handle_did_close(request, @document_store, @collie, @writer)
      when 'textDocument/formatting'
        Handlers::Formatting.handle(request, @document_store, @collie, @writer)
      when 'textDocument/codeAction'
        Handlers::CodeAction.handle(request, @document_store, @collie, @writer)
      when 'textDocument/hover'
        Handlers::Hover.handle(request, @document_store, @collie, @writer)
      when 'textDocument/completion'
        Handlers::Completion.handle(request, @document_store, @collie, @writer)
      when 'textDocument/definition'
        Handlers::Definition.handle(request, @document_store, @collie, @writer)
      when 'textDocument/references'
        Handlers::References.handle(request, @document_store, @collie, @writer)
      when 'textDocument/documentSymbol'
        Handlers::DocumentSymbol.handle(request, @document_store, @collie, @writer)
      when 'textDocument/rename'
        Handlers::Rename.handle(request, @document_store, @collie, @writer)
      when 'textDocument/semanticTokens/full'
        Handlers::SemanticTokens.handle(request, @document_store, @collie, @writer)
      when 'workspace/symbol'
        Handlers::WorkspaceSymbol.handle(request, @document_store, @collie, @writer)
      when 'textDocument/foldingRange'
        Handlers::FoldingRange.handle(request, @document_store, @collie, @writer)
      when 'shutdown'
        Protocol::Shutdown.handle(request, @writer)
      when 'exit'
        Protocol::Shutdown.handle_exit
      end
    rescue StandardError => e
      log_error("Error handling request: #{e.message}\n#{e.backtrace.join("\n")}")
    end

    # Handle initialize request and set up workspace
    # @param request [Hash] LSP initialize request
    def handle_initialize(request)
      @workspace_root = extract_workspace_root(request)
      @collie = CollieWrapper.new(workspace_root: @workspace_root)
      Protocol::Initialize.handle(request, @writer)
    end

    # Extract workspace root from initialize request
    # @param request [Hash] LSP initialize request
    # @return [String, nil] Workspace root path or nil
    def extract_workspace_root(request)
      params = request[:params]
      root_uri = params[:rootUri]
      return nil unless root_uri

      root_uri.gsub(%r{^file://}, '')
    end

    # Log error message
    # @param message [String] Error message
    def log_error(message)
      return unless ENV['COLLIE_LSP_LOG']

      File.open(ENV.fetch('COLLIE_LSP_LOG', nil), 'a') do |f|
        f.puts "[#{Time.now}] ERROR: #{message}"
      end
    end
  end
end
