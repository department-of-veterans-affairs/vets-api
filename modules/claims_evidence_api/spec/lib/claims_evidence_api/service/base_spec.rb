# frozen_string_literal: true

require 'rails_helper'

require 'claims_evidence_api/service/base'

require_relative '../../../support/claims_evidence_api/shared_examples/service'

RSpec.describe ClaimsEvidenceApi::Service::Base do
  let(:service) { described_class.new }

  it_behaves_like 'a ClaimsEvidenceApi::Service class'
end
