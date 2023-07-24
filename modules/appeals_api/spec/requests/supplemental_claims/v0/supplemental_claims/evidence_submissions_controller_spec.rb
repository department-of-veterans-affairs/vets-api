# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::SupplementalClaims::V0::SupplementalClaims::EvidenceSubmissionsController, type: :request do
  include FixtureHelpers
  let(:supplemental_claim) { create(:supplemental_claim_v0) }
  let(:evidence_submissions) { create_list(:evidence_submission_v0, 3, supportable: supplemental_claim) }
  let(:path) { '/services/appeals/supplemental-claims/v0/evidence-submissions' }
  let(:parsed) { JSON.parse(response.body) }

  def stub_upload_location(expected_location = 'http://some.fakesite.com/path/uuid')
    allow_any_instance_of(VBADocuments::UploadSubmission).to receive(:get_location).and_return(expected_location)
  end

  describe '#create' do
    let(:params) { { sc_uuid: supplemental_claim.id } }

    before { stub_upload_location }

    it_behaves_like(
      'an endpoint with OpenID auth',
      scopes: described_class::OAUTH_SCOPES[:POST],
      success_status: :accepted
    ) do
      def make_request(auth_header)
        post(path,
             params:, # TODO: read SSN from body instead:
             headers: auth_header.merge({ 'X-VA-SSN' => supplemental_claim.veteran.ssn }))
      end
    end
  end

  describe '#show' do
    before { stub_upload_location }

    it_behaves_like('an endpoint with OpenID auth', scopes: described_class::OAUTH_SCOPES[:GET]) do
      def make_request(auth_header)
        get("#{path}/#{evidence_submissions.sample.guid}", headers: auth_header)
      end
    end
  end
end
