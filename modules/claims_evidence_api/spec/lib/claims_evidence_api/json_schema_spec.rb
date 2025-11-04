# frozen_string_literal: true

require 'rails_helper'
require 'claims_evidence_api/json_schema'

RSpec.describe ClaimsEvidenceApi::JsonSchema do
  it 'has expected constants' do
    expect(ClaimsEvidenceApi::JsonSchema::SCHEMA).to be_present
    expect(ClaimsEvidenceApi::JsonSchema::UPLOAD_PAYLOAD).to be_present
    expect(ClaimsEvidenceApi::JsonSchema::PROVIDER_DATA).to be_present
    expect(ClaimsEvidenceApi::JsonSchema::SEARCH_FILE_REQUEST).to be_present
    expect(ClaimsEvidenceApi::JsonSchema::SEARCH_FILE_FILTERS).to be_present
    expect(ClaimsEvidenceApi::JsonSchema::SEARCH_FILE_SORT).to be_present

    expect(ClaimsEvidenceApi::JsonSchema::PROPERTIES).to be_present
  end

  it 'has same number of properties as files in schema/properties' do
    props = "#{ClaimsEvidenceApi::JsonSchema::SCHEMA}/properties"
    props = Dir.children(props).map { |f| "#{props}/#{f}" }.select { |f| File.file?(f) }
    expect(ClaimsEvidenceApi::JsonSchema::PROPERTIES.length).to eq props.length
  end
end
