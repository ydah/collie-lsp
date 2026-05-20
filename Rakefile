# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'json'
require 'rubocop/rake_task'
require 'rspec/core/rake_task'
require_relative 'lib/collie_lsp/version'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new(:rubocop)

namespace :release do
  desc 'Validate release metadata before tagging'
  task :check do
    package = JSON.parse(File.read('vscode-extension/package.json'))
    unless package.fetch('version') == CollieLsp::VERSION
      abort "VS Code extension version #{package.fetch('version')} does not match gem version #{CollieLsp::VERSION}"
    end

    changelog = File.read('CHANGELOG.md')
    abort "CHANGELOG.md is missing #{CollieLsp::VERSION}" unless changelog.include?("## #{CollieLsp::VERSION}")
  end
end

task default: %i[spec rubocop]
