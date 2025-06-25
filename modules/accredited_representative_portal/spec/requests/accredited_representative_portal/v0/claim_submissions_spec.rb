# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::ClaimSubmissionsController, type: :request do
  before do
    login_as(representative_user)
    allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_access_token')
  end

  describe 'GET /accredited_representative_portal/v0/claim_submissions' do
    let!(:poa_code) { '067' }
    let(:representative_user) do
      create(:representative_user, email: 'test@va.gov', icn: '123498767V234859', all_emails: ['test@va.gov'])
    end
    let!(:representative) do
      create(:representative,
             :vso,
             email: representative_user.email,
             representative_id: '357458',
             poa_codes: [poa_code])
    end
    let!(:vso) { create(:organization, poa: poa_code, can_accept_digital_poa_requests: false) }
    let!(:saved_claim_claimant_representative) { create(:saved_claim_claimant_representative) }
    let!(:saved_claim_claimant_representative2) { create(:saved_claim_claimant_representative) }
    # different PoA code
    let!(:saved_claim_claimant_representative3) do
      create(:saved_claim_claimant_representative, power_of_attorney_holder_poa_code: '002')
    end
    # different registration number
    let!(:saved_claim_claimant_representative4) do
      create(:saved_claim_claimant_representative, accredited_individual_registration_number: '987675')
    end

    around do |example|
      VCR.use_cassette('lighthouse/benefits_claims/power_of_attorney/200_response') do
        example.run
      end
    end

    describe 'GET /accredited_representative_portal/v0/claims_submissions' do
      let(:expected_meta) do
        { 'page' => { 'number' => 1, 'size' => 10, 'total' => 2, 'totalPages' => 1 } }
      end

      it 'returns only claims submissions that the rep is allowed to view' do
        get '/accredited_representative_portal/v0/claim_submissions'
        expect(response).to have_http_status(:ok)
        saved_claim_ids = [
          saved_claim_claimant_representative.id,
          saved_claim_claimant_representative2.id
        ]
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['data'].map { |obj| obj['id'] }).to eq saved_claim_ids
        expect(parsed_response['meta']).to eq expected_meta
      end

      context 'rep does not have any valid PoA codes' do
        let!(:representative) do
          create(:representative,
                 :vso,
                 email: representative_user.email,
                 representative_id: '357458',
                 poa_codes: ['11'])
        end

        it 'returns 403' do
          get '/accredited_representative_portal/v0/claim_submissions'
          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end
end
