# frozen_string_literal: true

require 'collie'

module CollieLsp
  # Wrapper class for Collie linting functionality
  # This class provides a unified interface to run all enabled linter rules
  class CollieLinter
    # @param config [Collie::Config] Configuration object
    def initialize(config = nil)
      @config = config || Collie::Config.new
      Collie::Linter::Registry.load_rules
    end

    # Run linting on the AST
    # @param ast [Collie::AST::GrammarFile] The parsed grammar AST
    # @return [Array<Collie::Linter::Offense>] Array of offenses
    def lint(ast)
      return [] unless ast

      enabled_rules = Collie::Linter::Registry.enabled_rules(@config)
      all_offenses = []

      enabled_rules.each do |rule_class|
        linter = rule_class.new
        linter.check(ast)
        # Use send to access protected method
        all_offenses.concat(linter.send(:offenses))
      end

      all_offenses
    end
  end
end
