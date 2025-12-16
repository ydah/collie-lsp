# frozen_string_literal: true

require_relative 'lib/collie_lsp/version'

Gem::Specification.new do |spec|
  spec.name = 'collie-lsp'
  spec.version = CollieLsp::VERSION
  spec.authors = ['Yudai Takada']
  spec.email = ['t.yudai92@gmail.com']

  spec.summary = 'Language Server Protocol implementation for Lrama Style BNF grammar files'
  spec.description = 'collie-lsp provides real-time linting, formatting, and code intelligence ' \
                     'features for .y grammar files in any LSP-compatible editor'
  spec.homepage = 'https://github.com/ydah/collie-lsp'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri'] = "#{spec.homepage}/issues"
  spec.metadata['documentation_uri'] = "#{spec.homepage}/blob/main/README.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'collie', '~> 0.1.0'
  spec.add_dependency 'language_server-protocol', '~> 3.17.0'
end
