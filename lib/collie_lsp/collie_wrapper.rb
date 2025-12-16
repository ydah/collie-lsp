# frozen_string_literal: true

require 'collie'
require_relative 'collie_linter'

module CollieLsp
  # Wrapper around the Collie gem for LSP integration
  class CollieWrapper
    # Initialize wrapper
    # @param workspace_root [String, nil] Workspace root directory for config discovery
    def initialize(workspace_root: nil)
      config_path = find_config(workspace_root)
      @collie_config = load_collie_config(config_path)
      @linter = CollieLinter.new(@collie_config)
    end

    # Parse grammar source into AST
    # @param source [String] Grammar source code
    # @param filename [String] Filename for error messages
    # @return [Object, nil] AST or nil on error
    def parse(source, filename: 'grammar.y')
      lexer = Collie::Parser::Lexer.new(source, filename: filename)
      tokens = lexer.tokenize
      parser = Collie::Parser::Parser.new(tokens)
      parser.parse
    rescue StandardError => e
      log_error("Parse error in #{filename}: #{e.message}")
      nil
    end

    # Lint grammar source
    # @param source [String] Grammar source code
    # @param filename [String] Filename for error messages
    # @return [Array<Hash>] Array of offenses
    def lint(source, filename: 'grammar.y')
      ast = parse(source, filename: filename)
      return [] unless ast

      offenses = @linter.lint(ast)

      # Convert Collie::Linter::Offense objects to hashes
      offenses.map do |offense|
        {
          message: offense.message,
          severity: offense.severity,
          rule_name: offense.rule.class.rule_name,
          location: offense.location ? {
            line: offense.location.line,
            column: offense.location.column
          } : { line: 1, column: 1 }
        }
      end
    rescue StandardError => e
      log_error("Lint error in #{filename}: #{e.message}")
      []
    end

    # Format grammar source
    # @param source [String] Grammar source code
    # @param filename [String] Filename for error messages
    # @return [String, nil] Formatted source or nil on error
    def format(source, filename: 'grammar.y')
      ast = parse(source, filename: filename)
      return nil unless ast

      formatter_options = Collie::Formatter::Options.new
      formatter = Collie::Formatter::Formatter.new(formatter_options)
      formatter.format(ast)
    rescue StandardError => e
      log_error("Format error in #{filename}: #{e.message}")
      nil
    end

    # Autocorrect offenses in grammar source
    # @param source [String] Grammar source code
    # @param filename [String] Filename for error messages
    # @return [String] Corrected source
    def autocorrect(source, filename: 'grammar.y')
      # Autocorrect is done via formatting in Collie
      format(source, filename: filename) || source
    rescue StandardError => e
      log_error("Autocorrect error in #{filename}: #{e.message}")
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

    # Load Collie configuration
    # @param config_path [String, nil] Config file path
    # @return [Collie::Config] Collie configuration object
    def load_collie_config(config_path)
      # Only pass config_path if it exists and is readable
      if config_path && File.exist?(config_path) && File.readable?(config_path)
        begin
          Collie::Config.new(config_path: config_path)
        rescue StandardError => e
          log_error("Failed to load config from #{config_path}: #{e.message}")
          Collie::Config.new
        end
      else
        Collie::Config.new
      end
    end


    # Log error message
    # @param message [String] Error message
    def log_error(message)
      return unless ENV['COLLIE_LSP_LOG']

      File.open(ENV.fetch('COLLIE_LSP_LOG', nil), 'a') do |f|
        f.puts "[#{Time.now}] #{message}"
      end
    end
  end
end
