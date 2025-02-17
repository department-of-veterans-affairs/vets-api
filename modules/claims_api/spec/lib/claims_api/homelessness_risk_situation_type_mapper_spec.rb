# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/homelessness_risk_situation_type_mapper'

describe ClaimsApi::HomelessnessRiskSituationTypeMapper do
  [
    { name: 'losingHousing', code: 'HOUSING_WILL_BE_LOST_IN_30_DAYS' },
    { name: 'leavingShelter', code: 'LEAVING_PUBLICLY_FUNDED_SYSTEM_OF_CARE' },
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
    { name: 'losingHousing', code: 'HOUSING_WILL_BE_LOST_IN_30_DAYS' },
    { name: 'leavingShelter', code: 'LEAVING_PUBLICLY_FUNDED_SYSTEM_OF_CARE' },
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
