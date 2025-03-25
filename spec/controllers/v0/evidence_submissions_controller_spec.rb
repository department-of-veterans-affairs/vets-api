# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::EvidenceSubmissionsController, type: :controller do
  let!(:user) { create(:user, :loa3, :accountable, icn: '123498767V234859') }
  let(:user_account) { create(:user_account) }
  let(:claim_id) { 600_383_363 } # This is the claim in the vcr cassettes that we are using

  before do
    user.user_account_uuid = user_account.id
    user.save!
    sign_in_as(user)
    token = 'fake_access_token'
    allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token).and_return(token)
  end

  describe '#index' do
    context 'when there is a SUCCESS evidence submission record' do
      before do
        create(:bd_lh_evidence_submission_success, claim_id:, user_account:)
      end

      context 'when a claim is successfully returned' do
        it 'returns a status of 200 with no evidence submission records' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get(:index)
          end
          expect(response).to have_http_status(:ok)
          parsed_body = JSON.parse(response.body)
          expect(parsed_body['data'].size).to eq(0)
        end
      end

      context 'when not authorized' do
        it 'returns a status of 200 and no evidence submission records' do
          VCR.use_cassette('lighthouse/benefits_claims/show/401_response') do
            get(:index)
          end
          expect(response).to have_http_status(:ok)
          parsed_body = JSON.parse(response.body)
          expect(parsed_body['data'].size).to eq(0)
        end
      end

      context 'when ICN not found' do
        it 'returns a status of 200 and no evidence submission records' do
          VCR.use_cassette('lighthouse/benefits_claims/show/404_response') do
            get(:index)
          end
          expect(response).to have_http_status(:ok)
          parsed_body = JSON.parse(response.body)
          expect(parsed_body['data'].size).to eq(0)
        end
      end
    end

    context 'when there is a FAILED evidence submission record' do
      before do
        create(:bd_lh_evidence_submission_failed_type1_error, claim_id:, user_account:)
      end

      context 'when a claim is returned' do
        it 'returns a status of 200 with evidence submission records' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get(:index)
          end
          expect(response).to have_http_status(:ok)
          parsed_body = JSON.parse(response.body)
          expect(parsed_body['data'].size).to eq(1)
        end
      end

      context 'when not authorized' do
        it 'returns a status of 401 and no evidence submission records' do
          VCR.use_cassette('lighthouse/benefits_claims/show/401_response') do
            get(:index)
          end
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'when ICN not found' do
        it 'returns a status of 404' do
          VCR.use_cassette('lighthouse/benefits_claims/show/404_response') do
            get(:index)
          end
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when there is a FAILED evidence submission record with a tracked item id' do
      context 'when a claim with a tracked item is returned' do
        let(:tracked_item_id) { 394_443 }

        before do
          create(:bd_lh_evidence_submission_failed_type1_error, claim_id:, user_account:, tracked_item_id:)
        end

        it 'returns a status of 200 with evidence submission records and tracked item information' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get(:index)
          end
          expect(response).to have_http_status(:ok)
          parsed_body = JSON.parse(response.body)
          data = parsed_body['data']
          expect(data.size).to eq(1)
          expect(data[0]['tracked_item_id']).to eq(tracked_item_id)
          expect(data[0]['tracked_item_display_name']).to eq('Submit buddy statement(s)')
        end
      end

      context 'when a claim without that tracked item is returned' do
        let(:tracked_item_id) { 394_999 }

        before do
          create(:bd_lh_evidence_submission_failed_type1_error, claim_id:, user_account:, tracked_item_id:)
        end

        it 'returns a status of 200 with evidence submission records and tracked item information' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get(:index)
          end
          expect(response).to have_http_status(:ok)
          parsed_body = JSON.parse(response.body)
          data = parsed_body['data']
          expect(data.size).to eq(1)

          expect(data[0]['tracked_item_id']).to eq(tracked_item_id)
          expect(data[0]['tracked_item_display_name']).to be_nil
        end
      end

      context 'when a claim without tracked items is returned' do
        let(:tracked_item_id) { 394_999 }

        before do
          create(:bd_lh_evidence_submission_failed_type1_error, claim_id:, user_account:, tracked_item_id:)
        end

        it 'returns a status of 200 with evidence submission records and tracked item information' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_no_tracked_items_response') do
            get(:index)
          end
          expect(response).to have_http_status(:ok)
          parsed_body = JSON.parse(response.body)
          data = parsed_body['data']
          expect(data.size).to eq(1)

          expect(data[0]['tracked_item_id']).to eq(tracked_item_id)
          expect(data[0]['tracked_item_display_name']).to be_nil
        end
      end
    end

    context 'when there are 2 FAILED evidence submission record' do
      before do
        create(:bd_lh_evidence_submission_failed_type1_error, claim_id:, user_account:)
        create(:bd_lh_evidence_submission_failed_type1_error, claim_id:, user_account:)
      end

      context 'when 1 claim is returned for evidence submission records' do
        it 'returns a status of 200 with evidence submission records' do
          # NOTE: Choosing not to use :allow_playback_repeats option for this cassette because
          # we are utilizing a cache in the controller to store the claims.
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get(:index)
          end
          expect(response).to have_http_status(:ok)
          parsed_body = JSON.parse(response.body)
          expect(parsed_body['data'].size).to eq(2)
        end
      end

      context 'when multiple claims are returned for the evidence submission records' do
        before do
          create(:bd_lh_evidence_submission_failed_type1_error, claim_id: 600_229_972, user_account:)
        end

        it 'returns a status of 200 with evidence submission records' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            VCR.use_cassette('lighthouse/benefits_claims/show/200_death_claim_response') do
              get(:index)
            end
          end
          expect(response).to have_http_status(:ok)
          parsed_body = JSON.parse(response.body)
          expect(parsed_body['data'].size).to eq(3)
        end
      end
    end
  end
end
