# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require 'spec_helper'

RSpec.describe 'collie-lsp executable' do
  it 'documents stdio and socket transports' do
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, 'exe/collie-lsp', '--help')

    expect(status).to be_success
    expect(stderr).to be_empty
    expect(stdout).to include('--stdio', '--socket')
  end
end
