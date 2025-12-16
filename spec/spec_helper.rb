# frozen_string_literal: true

require 'collie_lsp'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Filter to run specific examples
  config.filter_run_when_matching :focus

  # Print the 10 slowest examples
  config.profile_examples = 10 if ENV['PROFILE']

  # Use color in STDOUT
  config.color = true

  # Use documentation format
  config.default_formatter = 'doc' if config.files_to_run.one?
end

# Helper method to create a mock writer
def mock_writer
  writer = instance_double('LanguageServer::Protocol::Transport::Io::Writer')
  allow(writer).to receive(:write)
  writer
end

# Helper method to create a mock AST
def mock_ast(tokens: [], types: [], rules: [])
  {
    declarations: [
      *tokens.map { |name| { kind: :token, names: [name], location: { line: 1, column: 1 } } },
      *types.map { |name| { kind: :type, names: [name], location: { line: 1, column: 1 } } }
    ],
    rules: rules.map do |name|
      {
        name: name,
        location: { line: 10, column: 1 },
        alternatives: [{ symbols: [], action: nil }]
      }
    end
  }
end

# Helper method to create a document store with test data
def test_document_store(uri: 'file:///test.y', text: '', ast: nil)
  store = CollieLsp::DocumentStore.new
  store.open(uri, text, 1)
  store.update_ast(uri, ast) if ast
  store
end
