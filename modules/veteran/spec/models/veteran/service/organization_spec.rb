# frozen_string_literal: true

require 'rails_helper'

describe Veteran::Service::Organization do
  it 'is valid with valid attributes' do
    expect(Veteran::Service::Organization.new).to be_valid
  end
end
