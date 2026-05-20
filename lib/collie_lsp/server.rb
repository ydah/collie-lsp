# frozen_string_literal: true

require 'language_server-protocol'

module CollieLsp
  # Main LSP server implementation
  class Server
    SERVER_NOT_INITIALIZED = -32_002
    INVALID_REQUEST = -32_600
    METHOD_NOT_FOUND = -32_601
    INTERNAL_ERROR = -32_603

    INITIALIZATION_METHODS = %w[initialize exit].freeze
    POST_SHUTDOWN_METHODS = %w[exit].freeze
    NOTIFICATION_METHODS = %w[
      initialized
      textDocument/didOpen
      textDocument/didChange
      textDocument/didSave
      textDocument/didClose
      workspace/didChangeConfiguration
      workspace/didChangeWatchedFiles
      $/cancelRequest
      exit
    ].freeze

    # Initialize server
    # @param input [IO] Input stream (default: stdin)
    # @param output [IO] Output stream (default: stdout)
    def initialize(input: $stdin, output: $stdout)
      @reader = LanguageServer::Protocol::Transport::Io::Reader.new(input)
      @writer = LanguageServer::Protocol::Transport::Io::Writer.new(output)
      @document_store = DocumentStore.new
      @collie = nil
      @workspace_root = nil
      @workspace_roots = []
      @initialized = false
      @shutdown = false
      @cancelled_request_ids = {}
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
      return handle_cancel_request(request) if request[:method] == '$/cancelRequest'
      return reject_uninitialized(request) unless initialized_request_allowed?(request)
      return reject_after_shutdown(request) unless post_shutdown_request_allowed?(request)

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
      when 'textDocument/rangeFormatting'
        Handlers::Formatting.handle_range(request, @document_store, @collie, @writer)
      when 'textDocument/onTypeFormatting'
        Handlers::Formatting.handle_on_type(request, @document_store, @collie, @writer)
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
      when 'textDocument/prepareRename'
        Handlers::Rename.prepare(request, @document_store, @collie, @writer)
      when 'textDocument/semanticTokens/full'
        Handlers::SemanticTokens.handle(request, @document_store, @collie, @writer)
      when 'textDocument/semanticTokens/full/delta'
        Handlers::SemanticTokens.handle_delta(request, @document_store, @collie, @writer)
      when 'workspace/didChangeConfiguration'
        handle_configuration_change
      when 'workspace/didChangeWatchedFiles'
        handle_watched_files_change(request)
      when 'workspace/symbol'
        Handlers::WorkspaceSymbol.handle(request, @document_store, @collie, @writer)
      when 'textDocument/foldingRange'
        Handlers::FoldingRange.handle(request, @document_store, @collie, @writer)
      when 'shutdown'
        @shutdown = true
        Protocol::Shutdown.handle(request, @writer)
      when 'exit'
        Protocol::Shutdown.handle_exit(shutdown: @shutdown)
      else
        write_error(request, METHOD_NOT_FOUND, "Method not found: #{request[:method]}") if request[:id]
      end
    rescue StandardError => e
      log_error("Error handling request: #{e.message}\n#{e.backtrace.join("\n")}")
      write_error(request, INTERNAL_ERROR, e.message) if request[:id]
    end

    # Handle initialize request and set up workspace
    # @param request [Hash] LSP initialize request
    def handle_initialize(request)
      @workspace_roots = extract_workspace_roots(request)
      @workspace_root = @workspace_roots.first
      @collie = CollieWrapper.new(workspace_root: @workspace_root, workspace_roots: @workspace_roots)
      @initialized = true
      Protocol::Initialize.handle(request, @writer)
    end

    def handle_configuration_change
      reload_configuration
      log_message('info', 'collie-lsp configuration reloaded')
    end

    def handle_watched_files_change(request)
      changes = Array(request.dig(:params, :changes))
      return unless changes.any? { |change| watched_config?(change[:uri]) || watched_grammar?(change[:uri]) }

      reload_configuration if changes.any? { |change| watched_config?(change[:uri]) }
      republish_open_document_diagnostics if changes.any? { |change| watched_config?(change[:uri]) }
    end

    # Extract workspace root from initialize request
    # @param request [Hash] LSP initialize request
    # @return [String, nil] Workspace root path or nil
    def extract_workspace_root(request)
      extract_workspace_roots(request).first
    end

    def extract_workspace_roots(request)
      params = request[:params] || {}
      workspace_folders = Array(params[:workspaceFolders])
      roots = workspace_folders.filter_map do |folder|
        uri = folder[:uri] || folder['uri']
        UriUtils.path_from_uri(uri) if uri
      end
      return roots.uniq unless roots.empty?

      root_uri = params[:rootUri]
      return [] unless root_uri

      [UriUtils.path_from_uri(root_uri)]
    end

    def initialized_request_allowed?(request)
      @initialized || INITIALIZATION_METHODS.include?(request[:method])
    end

    def post_shutdown_request_allowed?(request)
      !@shutdown || POST_SHUTDOWN_METHODS.include?(request[:method])
    end

    def reject_uninitialized(request)
      write_error(request, SERVER_NOT_INITIALIZED, 'Server has not been initialized') if request[:id]
    end

    def reject_after_shutdown(request)
      write_error(request, INVALID_REQUEST, 'Server has been shut down') if request[:id]
    end

    def handle_cancel_request(request)
      id = request.dig(:params, :id)
      @cancelled_request_ids[id] = true if id
    end

    def reload_configuration
      @collie&.reload_config!
    end

    def republish_open_document_diagnostics
      return unless @collie

      @document_store.each_document do |uri, doc|
        Protocol::TextDocument.publish_diagnostics(uri, doc[:text], @document_store, @collie, @writer)
      end
    end

    def watched_config?(uri)
      return false unless uri

      File.basename(UriUtils.path_from_uri(uri)) == '.collie.yml'
    end

    def watched_grammar?(uri)
      return false unless uri

      File.extname(UriUtils.path_from_uri(uri)) == '.y'
    end

    def log_message(level, message)
      type = {
        error: 1,
        warning: 2,
        info: 3,
        log: 4
      }.fetch(level.to_sym, 4)

      @writer.write(
        method: 'window/logMessage',
        params: {
          type: type,
          message: message
        }
      )
    end

    # Log error message
    # @param message [String] Error message
    def log_error(message)
      return unless ENV['COLLIE_LSP_LOG']

      File.open(ENV.fetch('COLLIE_LSP_LOG', nil), 'a') do |f|
        f.puts "[#{Time.now}] ERROR: #{message}"
      end
    end

    def write_error(request, code, message)
      return unless request[:id]

      @writer.write(
        id: request[:id],
        error: {
          code: code,
          message: message
        }
      )
    end
  end
end
