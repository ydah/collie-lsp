# collie-lsp

[![Gem Version](https://badge.fury.io/rb/collie-lsp.svg)](https://badge.fury.io/rb/collie-lsp)
[![Build Status](https://github.com/ydah/collie-lsp/workflows/CI/badge.svg)](https://github.com/ydah/collie-lsp/actions)

Language Server Protocol (LSP) implementation for Lrama Style BNF grammar files (.y files).

## Features

- Real-time diagnostics and linting
- Document formatting
- Code actions and quick fixes
- Hover information and auto-completion
- Go to definition and find references
- Symbol renaming and workspace search
- Semantic highlighting and code folding

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'collie-lsp'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install collie-lsp
```

## Usage

### Starting the Server

The LSP server can be started in stdio mode (the default for most LSP clients):

```bash
collie-lsp --stdio
```

Or in socket mode:

```bash
collie-lsp --socket=7658
```

### Editor Configuration

#### VS Code

Install the collie-lsp extension from the VS Code marketplace, or configure manually:

```json
{
  "collie-lsp.serverPath": "collie-lsp",
  "collie-lsp.trace.server": "verbose"
}
```

#### Neovim (with nvim-lspconfig)

```lua
require'lspconfig'.collie_lsp.setup{
  cmd = { "collie-lsp", "--stdio" },
  filetypes = { "yacc" },
  root_dir = function(fname)
    return vim.fn.getcwd()
  end,
}
```

#### Emacs (with lsp-mode)

```elisp
(add-to-list 'lsp-language-id-configuration '(yacc-mode . "yacc"))

(lsp-register-client
 (make-lsp-client :new-connection (lsp-stdio-connection "collie-lsp")
                  :major-modes '(yacc-mode)
                  :server-id 'collie-lsp))
```

#### Vim (with vim-lsp)

```vim
if executable('collie-lsp')
  au User lsp_setup call lsp#register_server({
    \ 'name': 'collie-lsp',
    \ 'cmd': {server_info->['collie-lsp', '--stdio']},
    \ 'whitelist': ['yacc'],
    \ })
endif
```

### Configuration

Create a `.collie.yml` file in your project root:

```yaml
# Linter rules
rules:
  DuplicateToken:
    enabled: true
    severity: error

  TokenNaming:
    enabled: true
    severity: convention
    pattern: '^[A-Z][A-Z0-9_]*$'

  NonterminalNaming:
    enabled: true
    severity: convention
    pattern: '^[a-z][a-z0-9_]*$'

# Formatter options
formatter:
  indent_size: 4
  align_tokens: true
  align_alternatives: true
  max_line_length: 120

# File patterns
include:
  - '**/*.y'
exclude:
  - 'vendor/**/*'
  - 'tmp/**/*'
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Or use rake
bundle exec rake
```

## Architecture

```
lib/collie_lsp/
├── server.rb                  # Main LSP server
├── document_store.rb          # Document management
├── collie_wrapper.rb          # Collie gem integration
├── protocol/                  # LSP protocol handlers
│   ├── initialize.rb
│   ├── text_document.rb
│   └── shutdown.rb
└── handlers/                  # Feature handlers
    ├── diagnostics.rb         # Lint diagnostics
    ├── formatting.rb          # Document formatting
    ├── code_action.rb         # Quick fixes
    ├── hover.rb               # Hover information
    ├── completion.rb          # Auto-completion
    ├── definition.rb          # Go to definition
    ├── references.rb          # Find references
    ├── document_symbol.rb     # Document outline
    ├── rename.rb              # Symbol renaming
    ├── semantic_tokens.rb     # Semantic highlighting
    ├── workspace_symbol.rb    # Workspace search
    └── folding_range.rb       # Code folding
```

## Testing

Run the test suite:

```bash
bundle exec rspec
```

Run specific tests:

```bash
bundle exec rspec spec/collie_lsp/handlers/hover_spec.rb
```

Run with coverage:

```bash
COVERAGE=true bundle exec rspec
```

## Logging

Enable logging for debugging:

```bash
COLLIE_LSP_LOG=/tmp/collie-lsp.log collie-lsp --stdio
```

Then tail the log file:

```bash
tail -f /tmp/collie-lsp.log
```

## LSP Capabilities

### textDocument/publishDiagnostics
Real-time linting as you type, showing errors, warnings, and style violations.

### textDocument/formatting
Format the entire document according to your style preferences.

### textDocument/codeAction
Quick fixes for autocorrectable offenses. Access via your editor's "Quick Fix" command.

### textDocument/hover
Hover over a symbol to see its type and documentation.

### textDocument/completion
Intelligent auto-completion for:
- Declared tokens
- Defined nonterminals
- Grammar keywords

### textDocument/definition
Jump to the definition of any token or nonterminal.

### textDocument/references
Find all references to a symbol across the file.

### textDocument/documentSymbol
View document outline in your editor's symbol browser.

### textDocument/rename
Rename symbols with validation and automatic updates throughout the file.

### textDocument/semanticTokens/full
Enhanced syntax highlighting for:
- Keywords (`%token`, `%type`, etc.)
- Tokens (uppercase identifiers)
- Nonterminals (lowercase identifiers)
- Comments and strings

### workspace/symbol
Search for symbols across all open documents.

### textDocument/foldingRange
Fold code sections:
- Grammar rules
- Block comments
- C code blocks (`%{ ... %}`)
- Action blocks (`{ ... }`)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ydah/collie-lsp.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Related Projects

- [collie](https://github.com/ydah/collie) - The core linter and formatter (coming soon)
- [lrama](https://github.com/ruby/lrama) - LALR parser generator
