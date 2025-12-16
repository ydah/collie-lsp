# frozen_string_literal: true

require_relative 'collie_lsp/version'
require_relative 'collie_lsp/server'
require_relative 'collie_lsp/document_store'
require_relative 'collie_lsp/collie_wrapper'
require_relative 'collie_lsp/protocol/initialize'
require_relative 'collie_lsp/protocol/text_document'
require_relative 'collie_lsp/protocol/shutdown'
require_relative 'collie_lsp/handlers/diagnostics'
require_relative 'collie_lsp/handlers/formatting'
require_relative 'collie_lsp/handlers/code_action'
require_relative 'collie_lsp/handlers/hover'
require_relative 'collie_lsp/handlers/completion'
require_relative 'collie_lsp/handlers/definition'
require_relative 'collie_lsp/handlers/references'
require_relative 'collie_lsp/handlers/document_symbol'
require_relative 'collie_lsp/handlers/rename'
require_relative 'collie_lsp/handlers/semantic_tokens'
require_relative 'collie_lsp/handlers/workspace_symbol'
require_relative 'collie_lsp/handlers/folding_range'

module CollieLsp
  class Error < StandardError; end
end
