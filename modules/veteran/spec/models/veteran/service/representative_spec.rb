# frozen_string_literal: true

require 'rails_helper'

describe Veteran::Service::Representative, vcr: true do
  it 'is valid with valid attributes' do
    expect(Veteran::Service::Representative.new(poa: '000')).to be_valid
  end

  it 'is not valid without a poa' do
    representative = Veteran::Service::Representative.new(poa: nil)
    expect(representative).to_not be_valid
  end

  it 'should reload data from pulldown' do
    Veteran::Service::Representative.reload!
    expect(Veteran::Service::Representative.count).to eq 9338
    expect(Veteran::Service::Organization.count).to eq 92
  end
end
