# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MockedAuthentication do
  it 'has a version number' do
    expect(MockedAuthentication::VERSION).not_to be_nil
  end
end
