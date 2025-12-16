# frozen_string_literal: true

module CollieLsp
  # Wrapper around the Collie gem for LSP integration
  class CollieWrapper
    # Initialize wrapper
    # @param workspace_root [String, nil] Workspace root directory for config discovery
    def initialize(workspace_root: nil)
      config_path = find_config(workspace_root)
      @config = load_config(config_path)
      load_rules
    end

    # Parse grammar source into AST
    # @param source [String] Grammar source code
    # @param filename [String] Filename for error messages
    # @return [Object, Hash] AST or error hash
    def parse(_source, filename: 'grammar.y')
      # For now, return a mock AST structure
      # This will be replaced with actual Collie parser when available
      {
        declarations: [],
        rules: [],
        prologue: nil,
        epilogue: nil
      }
    rescue StandardError => e
      { error: e.message, location: { line: 1, column: 1 } }
    end

    # Lint grammar source
    # @param source [String] Grammar source code
    # @param filename [String] Filename for error messages
    # @return [Array<Hash>] Array of offenses
    def lint(source, filename: 'grammar.y')
      ast = parse(source, filename: filename)
      return [] if ast.is_a?(Hash) && ast[:error]

      # For now, return empty offenses
      # This will be replaced with actual Collie linter when available
      []
    end

    # Format grammar source
    # @param source [String] Grammar source code
    # @param filename [String] Filename for error messages
    # @return [String, nil] Formatted source or nil on error
    def format(source, filename: 'grammar.y')
      ast = parse(source, filename: filename)
      return nil if ast.is_a?(Hash) && ast[:error]

      # For now, return the source as-is
      # This will be replaced with actual Collie formatter when available
      source
    end

    # Autocorrect offenses in grammar source
    # @param source [String] Grammar source code
    # @param filename [String] Filename for error messages
    # @return [String] Corrected source
    def autocorrect(source, filename: 'grammar.y')
      # For now, return the source as-is
      # This will be replaced with actual Collie autocorrect when available
      source
    end

    private

    # Find configuration file
    # @param root [String, nil] Workspace root directory
    # @return [String, nil] Config file path or nil
    def find_config(root)
      return nil unless root

      config_file = File.join(root, '.collie.yml')
      File.exist?(config_file) ? config_file : nil
    end

    # Load configuration
    # @param config_path [String, nil] Config file path
    # @return [Hash] Configuration hash
    def load_config(config_path)
      if config_path && File.exist?(config_path)
        require 'yaml'
        YAML.load_file(config_path)
      else
        {}
      end
    end

    # Load linter rules
    def load_rules
      # This will be replaced with actual Collie rule loading when available
      # Collie::Linter::Registry.load_rules
    end
  end
end
