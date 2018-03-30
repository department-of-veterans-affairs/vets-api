# frozen_string_literal: true

require 'rails_helper'

describe EVSS::PCIU::Service do
  it 'should have valid factory' do
    expect(build(:phone_number)).to be_valid
  end

  it 'should require a number', :aggregate_failures do
    expect(build(:phone_number, number: '')).to_not be_valid
    expect(build(:phone_number, number: nil)).to_not be_valid
  end

  it 'should not permit non-numeric characters', :aggregate_failures do
    expect(build(:phone_number, number: '123abc')).to_not be_valid
    expect(build(:phone_number, number: '#123')).to_not be_valid
    expect(build(:phone_number, number: '123-456-7890')).to_not be_valid
    expect(build(:phone_number, number: '(123) 456-7890')).to_not be_valid
  end

  it 'should be valid without a country_code or extension', :aggregate_failures do
    expect(build(:phone_number, country_code: '')).to be_valid
    expect(build(:phone_number, extension: '')).to be_valid
  end
end
