# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/special_issue_mapper'

describe ClaimsApi::SpecialIssueMapper do
  it 'returns correct code for name' do
    expect(ClaimsApi::SpecialIssueMapper.new.code_from_name('Character of Discharge')).to eq('CD')
  end

  it 'returns correct name for code' do
    expect(ClaimsApi::SpecialIssueMapper.new.name_from_code('RDN')).to eq('Radiation')
  end
end
