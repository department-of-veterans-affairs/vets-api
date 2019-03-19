# frozen_string_literal: true

require 'rails_helper'

describe Veteran::Service::Representative do
  it 'is valid with valid attributes' do
    expect(Veteran::Service::Representative.new).to be_valid
  end
end
