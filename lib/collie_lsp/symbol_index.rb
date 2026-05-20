# frozen_string_literal: true

module CollieLsp
  # Normalized symbol view over Collie AST objects and legacy hash fixtures.
  class SymbolIndex
    DECLARATION_KINDS = %i[token type precedence start union rule parameterized_rule inline_rule].freeze
    RULE_KINDS = %i[rule parameterized_rule].freeze

    attr_reader :entries

    def self.build(ast, text = '')
      new(ast, text)
    end

    def self.symbol_at(text, position)
      line = text.lines[position[:line]]
      return nil unless line

      character = Position.utf16_to_codepoint_index(line, position[:character])
      action_ref_at(line, character) || identifier_at(line, character)
    end

    def self.action_ref_at(line, character)
      start = [character, line.length - 1].min
      start -= 1 while start.positive? && line[start] =~ /[A-Za-z0-9_]/
      start -= 1 if start.positive? && line[start - 1] == '$'
      return nil unless line[start] == '$'

      if line[start + 1] == '$'
        '$$'
      else
        match = line[start..].match(/\A\$[A-Za-z_][A-Za-z0-9_]*|\A\$\d+/)
        match&.to_s
      end
    end

    def self.identifier_at(line, character)
      start = [character, line.length - 1].min
      start -= 1 if start.positive? && line[start] !~ /[A-Za-z0-9_]/ && line[start - 1] =~ /[A-Za-z0-9_]/
      return nil unless line[start] =~ /[A-Za-z_]/

      finish = start
      start -= 1 while start.positive? && line[start - 1] =~ /[A-Za-z0-9_]/
      finish += 1 while finish < line.length && line[finish] =~ /[A-Za-z0-9_]/

      line[start...finish]
    end

    def initialize(ast, text)
      @ast = ast
      @text = text
      @entries = []
      @definitions_by_name = Hash.new { |hash, key| hash[key] = [] }
      @references_by_name = Hash.new { |hash, key| hash[key] = [] }

      build
    end

    def definitions_for(name)
      @definitions_by_name[name] || []
    end

    def definition_for(name)
      candidates = definitions_for(name)
      candidates = definitions_for(name.delete_prefix('$')) if candidates.empty? && named_action_reference?(name)
      return nil if candidates.empty?

      candidates.min_by { |entry| definition_priority(entry[:kind]) }
    end

    def definition_for_at(name, position)
      reference = reference_at(name, position)
      return reference_target(reference) if reference

      definition_for(name)
    end

    def references_for(name, include_declaration: false)
      references = references_matching(name)
      references.concat(definitions_matching(name)) if include_declaration
      unique_by_location(references)
    end

    def all_occurrences(name)
      unique_by_location(definitions_matching(name) + references_matching(name))
    end

    def entries_by_kind(*kinds)
      @entries.select { |entry| kinds.include?(entry[:kind]) }
    end

    def all_symbols
      @entries.select { |entry| DECLARATION_KINDS.include?(entry[:kind]) }
    end

    def tokens
      entries_by_kind(:token)
    end

    def rules
      entries_by_kind(*RULE_KINDS)
    end

    def type_tags
      @entries.filter_map { |entry| entry[:type_tag] }.uniq
    end

    private

    def build
      return unless @ast

      declarations.each { |declaration| add_declaration(declaration) }
      rules_from_ast.each { |rule| add_rule(rule) }
    end

    def declarations
      Array(value(@ast, :declarations))
    end

    def rules_from_ast
      Array(value(@ast, :rules))
    end

    def add_declaration(declaration)
      case declaration_kind(declaration)
      when :token
        add_token_declaration(declaration)
      when :type
        add_type_declaration(declaration)
      when :precedence
        add_precedence_declaration(declaration)
      when :start
        add_start_declaration(declaration)
      when :union
        add_union_declaration(declaration)
      when :parameterized_rule
        add_rule(declaration, kind: :parameterized_rule)
      when :inline_rule
        add_inline_rule(declaration)
      end
    end

    def add_token_declaration(declaration)
      Array(value(declaration, :names)).each do |name|
        add_definition(
          name: name,
          kind: :token,
          location: location_for_name(value(declaration, :location), name),
          detail: 'Token',
          type_tag: value(declaration, :type_tag)
        )
      end
    end

    def add_type_declaration(declaration)
      Array(value(declaration, :names)).each do |name|
        add_definition(
          name: name,
          kind: :type,
          location: location_for_name(value(declaration, :location), name),
          detail: 'Type',
          type_tag: value(declaration, :type_tag)
        )
      end
    end

    def add_precedence_declaration(declaration)
      associativity = value(declaration, :associativity) || value(declaration, :kind)
      Array(value(declaration, :tokens)).each do |token|
        add_definition(
          name: token,
          kind: :precedence,
          location: location_for_name(value(declaration, :location), token),
          detail: "#{associativity} precedence",
          associativity: associativity
        )
      end
    end

    def add_start_declaration(declaration)
      symbol = value(declaration, :symbol)
      return unless symbol

      add_definition(
        name: symbol,
        kind: :start,
        location: location_for_name(value(declaration, :location), symbol),
        detail: 'Start symbol'
      )
    end

    def add_union_declaration(declaration)
      add_definition(
        name: '%union',
        kind: :union,
        location: normalize_location(value(declaration, :location), length: 6),
        detail: 'Union declaration'
      )
    end

    def add_inline_rule(declaration)
      rule_name = value(declaration, :rule)
      return unless rule_name

      add_definition(
        name: rule_name,
        kind: :inline_rule,
        location: location_for_name(value(declaration, :location), rule_name),
        detail: 'Inline rule'
      )
    end

    def add_rule(rule, kind: nil)
      name = value(rule, :name)
      return unless name

      rule_kind = kind || (Array(value(rule, :parameters)).empty? ? :rule : :parameterized_rule)
      add_definition(
        name: name,
        kind: rule_kind,
        location: location_for_name(value(rule, :location), name),
        detail: rule_detail(rule_kind, rule),
        parameters: Array(value(rule, :parameters))
      )

      Array(value(rule, :alternatives)).each do |alternative|
        add_alternative_references(alternative)
      end
    end

    def add_alternative_references(alternative)
      symbols = Array(value(alternative, :symbols))
      named_references = {}

      symbols.each do |symbol|
        name = value(symbol, :name)
        next unless name

        add_reference(
          name: name,
          kind: value(symbol, :kind),
          location: normalize_location(value(symbol, :location), length: name.length)
        )

        alias_name = value(symbol, :alias_name)
        if alias_name
          entry = add_named_reference(symbol, alias_name)
          named_references[alias_name] = entry
        end

        Array(value(symbol, :arguments)).each do |argument|
          argument_name = value(argument, :name)
          next unless argument_name

          add_reference(
            name: argument_name,
            kind: value(argument, :kind),
            location: normalize_location(value(argument, :location), length: argument_name.length)
          )
        end
      end

      prec = value(alternative, :prec)
      add_reference(name: prec, kind: :precedence, location: find_first_location(prec)) if prec

      add_action_references(alternative, symbols, named_references)
    end

    def add_named_reference(symbol, alias_name)
      entry = compact_entry(
        name: alias_name,
        kind: :named_reference,
        location: location_for_alias(symbol, alias_name),
        detail: "Named reference for #{value(symbol, :name)}",
        target: value(symbol, :name)
      )
      @entries << entry
      @definitions_by_name[alias_name] << entry
      @definitions_by_name["$#{alias_name}"] << entry
      entry
    end

    def add_action_references(alternative, symbols, named_references)
      action = value(alternative, :action)
      code = value(action, :code)
      action_location = value(action, :location)
      return unless code && action_location

      code.to_enum(:scan, /\$\$|\$[A-Za-z_][A-Za-z0-9_]*|\$\d+/).each do
        match = Regexp.last_match
        reference = match.to_s
        target_location = action_reference_target(reference, symbols, named_references)

        add_reference(
          name: reference,
          kind: :action_reference,
          location: location_from_offset(action_location, code, match.begin(0), reference.length),
          target_location: target_location
        )
      end
    end

    def action_reference_target(reference, symbols, named_references)
      return nil if reference == '$$'

      if reference.match?(/\A\$\d+\z/)
        symbol = symbols[reference[1..].to_i - 1]
        return normalize_location(value(symbol, :location), length: value(symbol, :name).to_s.length) if symbol
      end

      alias_name = reference.delete_prefix('$')
      named_references[alias_name]&.dig(:location)
    end

    def add_definition(attributes)
      entry = compact_entry(attributes)
      @entries << entry
      @definitions_by_name[entry[:name]] << entry
    end

    def add_reference(attributes)
      entry = compact_entry(attributes)
      @references_by_name[entry[:name]] << entry
    end

    def compact_entry(attributes)
      attributes.compact.tap do |entry|
        entry[:location] ||= find_first_location(entry[:name])
        entry[:location] ||= { line: 1, column: 1, length: entry[:name].length }
      end
    end

    def references_matching(name)
      unless named_action_reference?(name)
        references = @references_by_name[name].dup
        references.concat(@references_by_name["$#{name}"]) if definitions_for("$#{name}").any?
        return references
      end

      bare_name = name.delete_prefix('$')
      @references_by_name[bare_name].dup + @references_by_name["$#{bare_name}"].dup
    end

    def definitions_matching(name)
      unless named_action_reference?(name)
        definitions = definitions_for(name).dup
        definitions.concat(definitions_for("$#{name}")) if definitions_for("$#{name}").any?
        return definitions
      end

      bare_name = name.delete_prefix('$')
      definitions_for(bare_name).dup + definitions_for("$#{bare_name}").dup
    end

    def named_action_reference?(name)
      name.start_with?('$') && name.match?(/\A\$[A-Za-z_][A-Za-z0-9_]*\z/)
    end

    def reference_at(name, position)
      references_matching(name).find do |entry|
        location_contains_position?(entry[:location], position)
      end
    end

    def reference_target(reference)
      target_location = reference[:target_location]
      return nil unless target_location

      {
        name: reference[:name],
        kind: :reference_target,
        location: target_location,
        detail: 'Reference target'
      }
    end

    def declaration_kind(declaration)
      return normalized_hash_kind(value(declaration, :kind), declaration) if declaration.is_a?(Hash)

      class_name = declaration.class.name
      return :token if class_name.end_with?('TokenDeclaration')
      return :type if class_name.end_with?('TypeDeclaration')
      return :precedence if class_name.end_with?('PrecedenceDeclaration')
      return :start if class_name.end_with?('StartDeclaration')
      return :union if class_name.end_with?('UnionDeclaration')
      return :parameterized_rule if class_name.end_with?('ParameterizedRule')
      return :inline_rule if class_name.end_with?('InlineRule')

      nil
    end

    def normalized_hash_kind(kind, declaration)
      return :precedence if %i[left right nonassoc].include?(kind)
      return :inline_rule if kind == :inline
      return :parameterized_rule if kind == :rule && !Array(value(declaration, :parameters)).empty?

      kind
    end

    def rule_detail(kind, rule)
      parameters = Array(value(rule, :parameters))
      return "Parameterized rule (#{parameters.join(', ')})" if kind == :parameterized_rule

      "Grammar rule (#{Array(value(rule, :alternatives)).size} alternatives)"
    end

    def value(object, key)
      return nil unless object
      return object[key] || object[key.to_s] if object.is_a?(Hash)
      return object.public_send(key) if object.respond_to?(key)

      nil
    end

    def location_for_name(base_location, name)
      location = normalize_location(base_location, length: name.length) || find_first_location(name)
      return nil unless location

      line_text = @text.lines[location[:line] - 1]
      return location unless line_text

      candidates = [name, "'#{name}'", "\"#{name}\""]
      start_column = [location[:column] - 1, 0].max
      match_column = candidates.filter_map { |candidate| line_text.index(candidate, start_column) }.min
      match_column ||= candidates.filter_map { |candidate| line_text.index(candidate) }.min

      return location unless match_column

      {
        line: location[:line],
        column: match_column + 1,
        length: name.length
      }
    end

    def location_for_alias(symbol, alias_name)
      location = normalize_location(value(symbol, :location), length: alias_name.length)
      return find_first_location(alias_name) unless location

      line_text = @text.lines[location[:line] - 1]
      return location unless line_text

      bracket = "[#{alias_name}]"
      match_column = line_text.index(bracket, [location[:column] - 1, 0].max)
      return location unless match_column

      {
        line: location[:line],
        column: match_column + 2,
        length: alias_name.length
      }
    end

    def location_from_offset(base_location, source, offset, length)
      location = normalize_location(base_location, length: length)
      return nil unless location

      prefix = source[0...offset]
      lines = prefix.split("\n", -1)

      if lines.size == 1
        {
          line: location[:line],
          column: location[:column] + offset,
          length: length
        }
      else
        {
          line: location[:line] + lines.size - 1,
          column: lines.last.length + 1,
          length: length
        }
      end
    end

    def find_first_location(name)
      return nil unless name

      @text.lines.each_with_index do |line, index|
        column = whole_word_index(line, name)
        return { line: index + 1, column: column + 1, length: name.length } if column
      end

      nil
    end

    def whole_word_index(line, name)
      escaped = Regexp.escape(name)
      match = line.match(/(?<![A-Za-z0-9_])#{escaped}(?![A-Za-z0-9_])/)
      match&.begin(0)
    end

    def normalize_location(location, length: nil)
      return nil unless location

      if location.is_a?(Hash)
        {
          line: location[:line] || location['line'],
          column: location[:column] || location['column'],
          length: length || location[:length] || location['length']
        }.compact
      else
        {
          line: location.line,
          column: location.column,
          length: length || location.length
        }
      end
    end

    def definition_priority(kind)
      {
        token: 0,
        rule: 1,
        parameterized_rule: 1,
        inline_rule: 2,
        type: 3,
        precedence: 4,
        start: 5,
        union: 6
      }.fetch(kind, 10)
    end

    def unique_by_location(entries)
      entries.uniq do |entry|
        location = entry[:location]
        [entry[:name], entry[:kind], location[:line], location[:column]]
      end
    end

    def location_contains_position?(location, position)
      return false unless location

      line = location[:line] - 1
      start_character = location[:column] - 1
      length = location[:length].to_i.positive? ? location[:length].to_i : 1

      position[:line] == line &&
        position[:character] >= start_character &&
        position[:character] <= start_character + length
    end
  end
end
