# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/homelessness_situation_type_mapper'

describe ClaimsApi::HomelessnessSituationTypeMapper do
  [
    { name: 'fleeing', code: 'FLEEING_CURRENT_RESIDENCE' },
    { name: 'shelter', code: 'LIVING_IN_A_HOMELESS_SHELTER' },
    { name: 'notShelter', code: 'NOT_CURRENTLY_IN_A_SHELTERED_ENVIRONMENT' },
    { name: 'anotherPerson', code: 'STAYING_WITH_ANOTHER_PERSON' },
    { name: 'other', code: 'OTHER' }
  ].each do |situation_type|
    it "returns correct code for name: #{situation_type[:name]}" do
      expect(subject.code_from_name!(situation_type[:name])).to eq(situation_type[:code])
    end
  end

  it 'returns nil for invalid name' do
    expect(subject.code_from_name('invalid-name')).to be_nil
  end

  it 'raises exception for invalid name' do
    expect { subject.code_from_name!('invalid-name') }.to raise_error(Common::Exceptions::InvalidFieldValue)
  end

  [
    { name: 'fleeing', code: 'FLEEING_CURRENT_RESIDENCE' },
    { name: 'shelter', code: 'LIVING_IN_A_HOMELESS_SHELTER' },
    { name: 'notShelter', code: 'NOT_CURRENTLY_IN_A_SHELTERED_ENVIRONMENT' },
    { name: 'anotherPerson', code: 'STAYING_WITH_ANOTHER_PERSON' },
    { name: 'other', code: 'OTHER' }
  ].each do |situation_type|
    it "returns correct name for code: #{situation_type[:code]}" do
      expect(subject.name_from_code!(situation_type[:code])).to eq(situation_type[:name])
    end
  end

  it 'returns nil for invalid code' do
    expect(subject.name_from_code('invalid-code')).to be_nil
  end

  it 'raises exception for invalid code' do
    expect { subject.name_from_code!('invalid-code') }.to raise_error(Common::Exceptions::InvalidFieldValue)
  end
end
