# frozen_string_literal: true

require 'rails_helper'
require 'claims_evidence_api/exceptions'

RSpec.describe ClaimsEvidenceApi::Exceptions do
  # coverage spec
  it 'has expected constants' do
    expect(ClaimsEvidenceApi::Exceptions::VefsError::NOT_FOUND).to eq 'VEFSERR40010'
  end
end
