# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::ClaimSubmissionsController, type: :request do
  before do
    login_as(representative_user)
    allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_access_token')

    # This removes: SHRINE WARNING: Error occurred when attempting to extract image dimensions:
    # #<FastImage::UnknownImageType: FastImage::UnknownImageType>
    allow(FastImage).to receive(:size).and_wrap_original do |original, file|
      if file.respond_to?(:path) && file.path.end_with?('.pdf')
        nil
      else
        original.call(file)
      end
    end
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

    # Default two that should be visible to the rep.
    # Make them older so the sorting test can deterministically place newer records on page 1.
    let!(:saved_claim_claimant_representative_a) do
      create(:saved_claim_claimant_representative, created_at: 10.days.ago)
    end
    let!(:saved_claim_claimant_representative_b) do
      create(:saved_claim_claimant_representative, created_at: 9.days.ago)
    end

    # different PoA code → should be filtered out
    let!(:saved_claim_claimant_representative_c) do
      create(:saved_claim_claimant_representative, power_of_attorney_holder_poa_code: '002')
    end
    # different registration number → should be filtered out
    let!(:saved_claim_claimant_representative_d) do
      create(:saved_claim_claimant_representative, accredited_individual_registration_number: '987675')
    end

    around do |example|
      VCR.use_cassette('lighthouse/benefits_claims/power_of_attorney/200_response') do
        example.run
      end
    end

    describe 'GET /accredited_representative_portal/v0/claims_submissions' do
      it 'returns only claims submissions that the rep is allowed to view' do
        get '/accredited_representative_portal/v0/claim_submissions'
        expect(response).to have_http_status(:ok)

        expect(parsed_response).to eq(
          {
            'data' => [
              {
                'submittedDate' => saved_claim_claimant_representative_a.created_at.to_date.iso8601,
                'firstName' => 'John',
                'lastName' => 'Doe',
                'benefitType' => nil,
                'formType' => '21-686c',
                'packet' => false,
                'confirmationNumber' =>
                  saved_claim_claimant_representative_a.saved_claim.latest_submission_attempt.benefits_intake_uuid,
                'vbmsStatus' => 'awaiting_receipt',
                'vbmsReceivedDate' => nil,
                'id' => saved_claim_claimant_representative_a.id
              },
              {
                'submittedDate' => saved_claim_claimant_representative_b.created_at.to_date.iso8601,
                'firstName' => 'John',
                'lastName' => 'Doe',
                'formType' => '21-686c',
                'benefitType' => nil,
                'packet' => false,
                'confirmationNumber' =>
                  saved_claim_claimant_representative_b.saved_claim.latest_submission_attempt.benefits_intake_uuid,
                'vbmsStatus' => 'awaiting_receipt',
                'vbmsReceivedDate' => nil,
                'id' => saved_claim_claimant_representative_b.id
              }
            ],
            'meta' => {
              'page' => {
                'number' => 1,
                'size' => 10,
                'total' => 2,
                'totalPages' => 1
              }
            }
          }
        )
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

    describe 'sorting and pagination plumbing' do
      let!(:older)  { create(:saved_claim_claimant_representative, created_at: 3.days.ago) }
      let!(:newest) { create(:saved_claim_claimant_representative, created_at: 1.day.ago) }

      before do
        allow(AccreditedRepresentativePortal::SubmissionsService::ParamsSchema)
          .to receive(:validate_and_normalize!)
          .and_return({
                        sort: { by: 'created_at', order: 'desc' },
                        page: { number: 1, size: 2 }
                      })
      end

      it 'returns results ordered by submittedDate desc and paginates' do
        get '/accredited_representative_portal/v0/claim_submissions'
        expect(response).to have_http_status(:ok)

        body = parsed_response
        expect(body.dig('meta', 'page', 'number')).to eq(1)
        expect(body.dig('meta', 'page', 'size')).to eq(2)
        expect(body['data'].size).to eq(2)

        dates = body['data'].map { |h| Date.iso8601(h['submittedDate']) }
        expect(dates).to eq(dates.sort.reverse) # sorted desc
        expect(dates).to include(newest.created_at.to_date) # newest included on page 1
      end
    end

    describe 'invalid params' do
      before do
        allow(AccreditedRepresentativePortal::SubmissionsService::ParamsSchema)
          .to receive(:validate_and_normalize!)
          .and_raise(Common::Exceptions::ParameterMissing.new('page.size'))
      end

      it 'returns 400 (or 422) when params schema validation fails' do
        get '/accredited_representative_portal/v0/claim_submissions', params: { page: { size: 'not-a-number' } }
        expect(response.status).to be_in([400, 422])
      end
    end

    describe 'authorization wiring' do
      it 'calls controller#authorize with the correct policy_class' do
        expect_any_instance_of(AccreditedRepresentativePortal::V0::ClaimSubmissionsController)
          .to receive(:authorize)
          .with(nil, policy_class: AccreditedRepresentativePortal::SavedClaimClaimantRepresentativePolicy)
          .and_call_original

        get '/accredited_representative_portal/v0/claim_submissions'
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'defaults (no sort/page params)' do
      before do
        allow(AccreditedRepresentativePortal::SubmissionsService::ParamsSchema)
          .to receive(:validate_and_normalize!)
          .and_return({})
      end

      it 'uses default pagination and does not error' do
        get '/accredited_representative_portal/v0/claim_submissions'
        expect(response).to have_http_status(:ok)

        meta_page = parsed_response.dig('meta', 'page')
        expect(meta_page['number']).to eq(1)
        expect(meta_page['size']).to eq(30)
      end
    end
  end
end
