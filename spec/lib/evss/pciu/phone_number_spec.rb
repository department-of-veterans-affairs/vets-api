# frozen_string_literal: true

require 'rails_helper'

describe EVSS::PCIU::PhoneNumber do
  it 'should have valid factory' do
    expect(build(:phone_number)).to be_valid
  end

  it 'should require a number', :aggregate_failures do
    expect(build(:phone_number, number: '')).not_to be_valid
    expect(build(:phone_number, number: nil)).not_to be_valid
  end

  it 'should not permit non-numeric characters', :aggregate_failures do
    expect(build(:phone_number, number: '123abc')).not_to be_valid
    expect(build(:phone_number, number: '#123')).not_to be_valid
    expect(build(:phone_number, number: '123-456-7890')).not_to be_valid
    expect(build(:phone_number, number: '(123) 456-7890')).not_to be_valid
  end

  it 'should be valid without a country_code or extension', :aggregate_failures do
    expect(build(:phone_number, country_code: '')).to be_valid
    expect(build(:phone_number, extension: '')).to be_valid
  end
end
