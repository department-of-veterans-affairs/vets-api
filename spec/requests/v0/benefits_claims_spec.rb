# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::BenefitsClaims', type: :request do
  include SchemaMatchers

  let(:user) { create(:user, :loa3, :accountable, :legacy_icn, uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef') }
  let(:user_account) { create(:user_account, id: user.uuid) }
  let(:claim_id) { 600_383_363 } # This is the claim in the vcr cassettes that we are using

  describe 'GET /v0/benefits_claims/failed_upload_evidence_submissions' do
    subject do
      get '/v0/benefits_claims/failed_upload_evidence_submissions'
    end

    context 'when the cst_show_document_upload_status is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(
          :cst_show_document_upload_status,
          instance_of(User)
        ).and_return(true)
      end

      context 'when unsuccessful' do
        context 'when the user is not signed in' do
          it 'returns a status of 401' do
            subject

            expect(response).to have_http_status(:unauthorized)
          end
        end

        context 'when the user is signed in, but does not have valid credentials' do
          let(:invalid_user) { create(:user, :loa3, :accountable, :legacy_icn, participant_id: nil) }

          before do
            sign_in_as(invalid_user)
          end

          it 'returns a status of 403' do
            subject

            expect(response).to have_http_status(:forbidden)
          end
        end

        context 'when the user is signed in and has valid credentials' do
          before do
            sign_in_and_set_access_token(user)
          end

          context 'when the ICN is not found' do
            it 'returns a status of 404' do
              VCR.use_cassette('lighthouse/benefits_claims/index/404_response') do
                subject
              end

              expect(response).to have_http_status(:not_found)
            end
          end

          context 'when there is a gateway timeout' do
            it 'returns a status of 504' do
              VCR.use_cassette('lighthouse/benefits_claims/index/504_response') do
                subject
              end

              expect(response).to have_http_status(:gateway_timeout)
            end
          end

          context 'when Lighthouse takes too long to respond' do
            it 'returns a status of 504' do
              allow_any_instance_of(BenefitsClaims::Configuration).to receive(:get).and_raise(Faraday::TimeoutError)
              subject

              expect(response).to have_http_status(:gateway_timeout)
            end
          end
        end
      end

      context 'when successful' do
        before do
          sign_in_and_set_access_token(user)
          2.times { create(:bd_lh_evidence_submission_failed_type2_error, claim_id:, user_account:) }
        end

        it 'returns an array of failed evidence submissions' do
          VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
            subject
          end

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('failed_evidence_submissions')
        end
      end
    end

    context 'when the cst_show_document_upload_status is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(
          :cst_show_document_upload_status,
          instance_of(User)
        ).and_return(false)
      end

      context 'when unsuccessful' do
        context 'when the user is not signed in' do
          it 'returns a status of 401' do
            subject

            expect(response).to have_http_status(:unauthorized)
          end
        end

        context 'when the user is signed in, but does not have valid credentials' do
          let(:invalid_user) { create(:user, :loa3, :accountable, :legacy_icn, participant_id: nil) }

          before do
            sign_in_as(invalid_user)
          end

          it 'returns a status of 403' do
            subject

            expect(response).to have_http_status(:forbidden)
          end
        end

        context 'when the user is signed in and has valid credentials' do
          before do
            sign_in_and_set_access_token(user)
          end

          it 'returns an empty array' do
            subject

            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq([])
          end
        end
      end

      context 'when successful' do
        before do
          sign_in_and_set_access_token(user)
        end

        it 'returns an empty array' do
          subject

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq([])
        end
      end
    end
  end

  def sign_in_and_set_access_token(user)
    sign_in_as(user)
    token = 'fake_access_token'

    allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token).and_return(token)
  end
end
