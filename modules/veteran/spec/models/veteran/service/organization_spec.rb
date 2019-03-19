# frozen_string_literal: true

require 'rails_helper'

describe Veteran::Service::Organization do
  it 'is valid with valid attributes' do
    expect(Veteran::Service::Organization.new(poa: '000')).to be_valid
  end

  it 'is not valid without a poa' do
    organization = Veteran::Service::Organization.new(poa: nil)
    expect(organization).to_not be_valid
  end
end
