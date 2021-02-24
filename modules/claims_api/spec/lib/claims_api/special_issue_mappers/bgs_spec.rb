# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/special_issue_mappers/bgs'

describe ClaimsApi::SpecialIssueMappers::Bgs do
  [
    { name: 'Character of Discharge', code: 'CD' },
    { name: 'PTSD/1', code: 'PTSD/1' }
  ].each do |special_issue|
    it "returns correct code for name: #{special_issue[:name]}" do
      expect(ClaimsApi::SpecialIssueMappers::Bgs.new.code_from_name!(special_issue[:name])).to eq(special_issue[:code])
    end
  end

  [
    { name: 'Radiation', code: 'RDN' },
    { name: 'PTSD/3', code: 'PTSD/3' }
  ].each do |special_issue|
    it "returns correct name for code: #{special_issue[:code]}" do
      expect(ClaimsApi::SpecialIssueMappers::Bgs.new.name_from_code!(special_issue[:code])).to eq(special_issue[:name])
    end
  end
end
