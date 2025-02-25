# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/special_issue_mappers/evss'

describe ClaimsApi::SpecialIssueMappers::Evss do
  [
    { name: 'Amyotrophic Lateral Sclerosis (ALS)', code: 'ALS' },
    { name: 'PTSD/1', code: 'PTSD_1' }
  ].each do |special_issue|
    it "returns correct code for name: #{special_issue[:name]}" do
      expect(subject.code_from_name!(special_issue[:name])).to eq(special_issue[:code])
    end
  end

  it 'returns nil for invalid name' do
    expect(subject.code_from_name('invalid-name')).to be_nil
  end

  it 'raises exception for invalid name' do
    expect { subject.code_from_name!('invalid-name') }.to raise_error(Common::Exceptions::InvalidFieldValue)
  end

  [
    { name: 'PTSD/3', code: 'PTSD_3' }
  ].each do |special_issue|
    it "returns correct name for code: #{special_issue[:code]}" do
      expect(subject.name_from_code!(special_issue[:code])).to eq(special_issue[:name])
    end
  end

  it 'returns nil for invalid code' do
    expect(subject.name_from_code('invalid-code')).to be_nil
  end

  it 'raises exception for invalid code' do
    expect { subject.name_from_code!('invalid-code') }.to raise_error(Common::Exceptions::InvalidFieldValue)
  end
end
