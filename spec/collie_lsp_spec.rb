# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CollieLsp do
  it 'has a version number' do
    expect(CollieLsp::VERSION).not_to be_nil
    expect(CollieLsp::VERSION).to match(/^\d+\.\d+\.\d+$/)
  end

  it 'defines an Error class' do
    expect(CollieLsp::Error).to be < StandardError
  end
end
