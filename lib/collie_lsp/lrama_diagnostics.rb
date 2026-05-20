# frozen_string_literal: true

module CollieLsp
  # LSP-side diagnostics for Lrama constructs that Collie 0.1.0 does not expose as rules.
  module LramaDiagnostics
    module_function

    def analyze(ast)
      return [] unless ast

      parameterized_rules = parameterized_rule_definitions(ast)
      rule_like_nodes(ast).flat_map do |rule|
        Array(value(rule, :alternatives)).flat_map do |alternative|
          diagnostics_for_alternative(alternative, parameterized_rules)
        end
      end
    end

    def diagnostics_for_alternative(alternative, parameterized_rules)
      symbols = Array(value(alternative, :symbols))
      diagnostics = parameterized_rule_arity_diagnostics(symbols, parameterized_rules)
      diagnostics.concat(named_reference_diagnostics(alternative, symbols))
      diagnostics
    end

    def parameterized_rule_arity_diagnostics(symbols, parameterized_rules)
      symbols.filter_map do |symbol|
        arguments = value(symbol, :arguments)
        next unless arguments

        name = value(symbol, :name)
        expected = parameterized_rules[name]
        next unless expected && expected.size != arguments.size

        diagnostic(
          rule_name: 'ParameterizedRuleArity',
          message: "Parameterized rule `#{name}` expects #{expected.size} argument(s), got #{arguments.size}",
          location: value(symbol, :location),
          length: name.to_s.length
        )
      end
    end

    def named_reference_diagnostics(alternative, symbols)
      aliases = {}
      diagnostics = []

      symbols.each do |symbol|
        alias_name = value(symbol, :alias_name)
        next unless alias_name

        if aliases.key?(alias_name)
          diagnostics << diagnostic(
            rule_name: 'DuplicateNamedReference',
            message: "Named reference `#{alias_name}` is already defined in this alternative",
            location: value(symbol, :location),
            length: alias_name.length,
            severity: :warning
          )
        end
        aliases[alias_name] = true
      end

      diagnostics.concat(action_reference_diagnostics(alternative, symbols, aliases))
    end

    def action_reference_diagnostics(alternative, symbols, aliases)
      action = value(alternative, :action)
      code = value(action, :code)
      action_location = value(action, :location)
      return [] unless code && action_location

      diagnostics = []
      code.to_enum(:scan, /\$[A-Za-z_][A-Za-z0-9_]*|\$\d+/).each do
        match = Regexp.last_match
        reference = match.to_s

        if invalid_action_reference?(reference, symbols, aliases)
          diagnostics << invalid_action_reference(reference, symbols, action_location, code, match.begin(0))
        end
      end
      diagnostics.compact
    end

    def invalid_action_reference?(reference, symbols, aliases)
      if reference.match?(/\A\$\d+\z/)
        index = reference[1..].to_i
        index.zero? || index > symbols.size
      else
        !aliases.key?(reference.delete_prefix('$'))
      end
    end

    def invalid_action_reference(reference, _symbols, action_location, code, offset)
      diagnostic(
        rule_name: reference.match?(/\A\$\d+\z/) ? 'InvalidActionReference' : 'UndefinedNamedReference',
        message: "Action reference `#{reference}` does not match a production symbol",
        location: location_from_offset(action_location, code, offset, reference.length),
        length: reference.length
      )
    end

    def parameterized_rule_definitions(ast)
      rule_like_nodes(ast).each_with_object({}) do |rule, definitions|
        parameters = Array(value(rule, :parameters))
        definitions[value(rule, :name)] = parameters unless parameters.empty?
      end
    end

    def rule_like_nodes(ast)
      Array(value(ast, :declarations)) + Array(value(ast, :rules)).flat_map do |rule|
        inline_rule?(rule) ? value(rule, :rule) : rule
      end
    end

    def inline_rule?(rule)
      !rule.is_a?(String) && rule.class.name.end_with?('InlineRule')
    end

    def diagnostic(rule_name:, message:, location:, length:, severity: :error)
      {
        rule_name: rule_name,
        message: message,
        severity: severity,
        location: normalize_location(location),
        length: length
      }
    end

    def location_from_offset(base_location, source, offset, length)
      location = normalize_location(base_location)
      return location unless location

      lines = source[0...offset].split("\n", -1)
      if lines.size == 1
        location.merge(column: location[:column] + offset, length: length)
      else
        { line: location[:line] + lines.size - 1, column: lines.last.length + 1, length: length }
      end
    end

    def normalize_location(location)
      return { line: 1, column: 1 } unless location
      return { line: location[:line] || location['line'], column: location[:column] || location['column'] } if location.is_a?(Hash)

      { line: location.line, column: location.column }
    end

    def value(object, key)
      return nil unless object
      return object[key] || object[key.to_s] if object.is_a?(Hash)
      return object.public_send(key) if object.respond_to?(key)

      nil
    end
  end
end
