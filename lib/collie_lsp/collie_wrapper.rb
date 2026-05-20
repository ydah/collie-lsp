# frozen_string_literal: true

require 'collie'
require 'pathname'
require_relative 'collie_linter'

module CollieLsp
  # Wrapper around the Collie gem for LSP integration
  class CollieWrapper
    ParseResult = Struct.new(:ast, :error, keyword_init: true)

    # Initialize wrapper
    # @param workspace_root [String, nil] Workspace root directory for config discovery
    # @param workspace_roots [Array<String>, nil] Workspace roots for multi-root workspaces
    def initialize(workspace_root: nil, workspace_roots: nil)
      @workspace_roots = Array(workspace_roots || workspace_root).compact.uniq
      reload_config!
    end

    attr_reader :workspace_roots

    # Parse grammar source into AST
    # @param source [String] Grammar source code
    # @param filename [String] Filename for error messages
    # @return [Object, nil] AST or nil on error
    def parse(source, filename: 'grammar.y')
      parse_result(source, filename: filename).ast
    end

    # Parse grammar source and keep parse error metadata.
    # @param source [String] Grammar source code
    # @param filename [String] Filename for error messages
    # @return [ParseResult] AST and parse error metadata
    def parse_result(source, filename: 'grammar.y')
      lexer = Collie::Parser::Lexer.new(source, filename: filename)
      tokens = lexer.tokenize
      parser = Collie::Parser::Parser.new(tokens)
      ParseResult.new(ast: parser.parse, error: nil)
    rescue StandardError => e
      log_error("Parse error in #{filename}: #{e.message}")
      ParseResult.new(ast: nil, error: parse_error_hash(e, filename))
    end

    # Lint grammar source
    # @param source [String] Grammar source code
    # @param filename [String] Filename for error messages
    # @return [Array<Hash>] Array of offenses
    def lint(source, filename: 'grammar.y')
      ast = parse_result(source, filename: filename).ast
      return [] unless ast

      lint_ast(ast, filename: filename)
    rescue StandardError => e
      log_error("Lint error in #{filename}: #{e.message}")
      []
    end

    # Lint an already parsed grammar AST.
    # @param ast [Collie::AST::GrammarFile] Parsed AST
    # @return [Array<Hash>] Array of offenses
    def lint_ast(ast, filename: nil)
      offenses = linter_for(filename).lint(ast)

      offenses.map do |offense|
        offense_to_hash(offense)
      end
    end

    # Format grammar source
    # @param source [String] Grammar source code
    # @param filename [String] Filename for error messages
    # @return [String, nil] Formatted source or nil on error
    def format(source, filename: 'grammar.y')
      ast = parse(source, filename: filename)
      return nil unless ast

      formatter_options = Collie::Formatter::Options.new(symbolize_keys(config_for(filename).formatter_options))
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

    # Reload `.collie.yml` for all workspace roots.
    def reload_config!
      @configs_by_root = {}
      @linters_by_root = {}

      workspace_roots.each do |root|
        config = load_collie_config(find_config(root))
        @configs_by_root[root] = config
        @linters_by_root[root] = CollieLinter.new(config)
      end

      @collie_config = @configs_by_root.values.first || Collie::Config.new
      @linter = @linters_by_root.values.first || CollieLinter.new(@collie_config)
    end

    # Return workspace .y files respecting Collie include/exclude settings.
    # @return [Array<String>] Absolute file paths
    def workspace_grammar_files
      workspace_roots.flat_map do |root|
        Dir.glob(File.join(root, '**', '*')).select do |path|
          File.file?(path) && included_file?(path)
        end
      end.uniq
    end

    # Parse a file from disk.
    # @param path [String] File path
    # @return [ParseResult]
    def parse_file(path)
      parse_result(File.read(path), filename: path)
    rescue StandardError => e
      log_error("Failed to read #{path}: #{e.message}")
      ParseResult.new(ast: nil, error: parse_error_hash(e, path))
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

    def included_file?(path)
      root = workspace_root_for(path)
      return File.extname(path) == '.y' unless root

      relative = relative_path(path, root)
      config = config_for(path)
      included = config.included_patterns.any? { |pattern| File.fnmatch?(pattern, relative, File::FNM_PATHNAME) }
      excluded = config.excluded_patterns.any? { |pattern| File.fnmatch?(pattern, relative, File::FNM_PATHNAME) }

      included && !excluded
    end

    def linter_for(filename)
      root = workspace_root_for(filename)
      return @linter unless root

      @linters_by_root[root] || @linter
    end

    def config_for(filename)
      root = workspace_root_for(filename)
      return @collie_config unless root

      @configs_by_root[root] || @collie_config
    end

    def workspace_root_for(path)
      return nil unless path

      expanded_path = File.expand_path(path)
      workspace_roots.select { |root| expanded_path.start_with?(File.expand_path(root)) }.max_by(&:length)
    end

    def relative_path(path, root)
      Pathname.new(File.expand_path(path)).relative_path_from(Pathname.new(File.expand_path(root))).to_s
    rescue ArgumentError
      path
    end

    # Load Collie configuration
    # @param config_path [String, nil] Config file path
    # @return [Collie::Config] Collie configuration object
    def load_collie_config(config_path)
      # Only pass config_path if it exists and is readable
      if config_path && File.exist?(config_path) && File.readable?(config_path)
        begin
          Collie::Config.new(config_path)
        rescue StandardError => e
          log_error("Failed to load config from #{config_path}: #{e.message}")
          Collie::Config.new
        end
      else
        Collie::Config.new
      end
    end

    def offense_to_hash(offense)
      {
        message: offense.message,
        severity: offense.severity,
        rule_name: offense.rule.class.rule_name,
        location: location_to_hash(offense.location),
        length: offense.location&.length
      }
    end

    def parse_error_hash(error, filename)
      {
        message: error.message,
        severity: :error,
        rule_name: 'ParseError',
        location: error_location(error.message, filename),
        length: 1
      }
    end

    def error_location(message, filename)
      match = message.match(/#{Regexp.escape(filename)}:(\d+):(\d+)/)
      return { line: match[1].to_i, column: match[2].to_i } if match

      { line: 1, column: 1 }
    end

    def location_to_hash(location)
      return { line: 1, column: 1 } unless location

      {
        line: location.line,
        column: location.column
      }
    end

    def symbolize_keys(hash)
      hash.to_h.transform_keys(&:to_sym)
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
