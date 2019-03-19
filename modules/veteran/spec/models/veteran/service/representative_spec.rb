# frozen_string_literal: true

require 'rails_helper'

describe Veteran::Service::Representative do
  it 'is valid with valid attributes' do
    expect(Veteran::Service::Representative.new(poa: '000')).to be_valid
  end

  it 'is not valid without a poa' do
    representative = Veteran::Service::Representative.new(poa: nil)
    expect(representative).to_not be_valid
  end
end
