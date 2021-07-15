# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Claims', type: :request do
  let(:veteran_id) { '1013062086V794840' }
  let(:path) { "/services/benefits/v2/veterans/#{veteran_id}/claims" }
  let(:scopes) { %w[claim.read] }

  describe 'Claims' do
    context 'auth header' do
      context 'when provided' do
        it 'returns a 200' do
          with_okta_user(scopes) do |auth_header|
            expect_any_instance_of(BGS::BenefitClaimWebServiceV1)
              .to receive(:find_claims_details_by_participant_id).and_return({ bnft_claim_detail: [] })
            expect(ClaimsApi::AutoEstablishedClaim)
              .to receive(:where).and_return([])

            get path, headers: auth_header
            expect(response.status).to eq(200)
          end
        end
      end

      context 'when not provided' do
        it 'returns a 401 error code' do
          with_okta_user(scopes) do
            get path
            expect(response.status).to eq(401)
          end
        end
      end
    end

    context 'forbidden access' do
      context 'when current user is not the target veteran' do
        context 'when current user is not a representative of the target veteran' do
          it 'returns a 403' do
            with_okta_user(scopes) do |auth_header|
              expect_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:user_is_target_veteran?).and_return(false)
              expect_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:user_represents_veteran?).and_return(false)

              get path, headers: auth_header
              expect(response.status).to eq(403)
            end
          end
        end
      end
    end

    context 'veteran_id param' do
      context 'when not provided' do
        let(:veteran_id) { nil }

        it 'returns a 404 error code' do
          with_okta_user(scopes) do |auth_header|
            get path, headers: auth_header
            expect(response.status).to eq(404)
          end
        end
      end

      context 'when known veteran_id is provided' do
        it 'returns a 200' do
          with_okta_user(scopes) do |auth_header|
            expect_any_instance_of(BGS::BenefitClaimWebServiceV1)
              .to receive(:find_claims_details_by_participant_id).and_return({ bnft_claim_detail: [] })
            expect(ClaimsApi::AutoEstablishedClaim)
              .to receive(:where).and_return([])

            get path, headers: auth_header
            expect(response.status).to eq(200)
          end
        end
      end

      context 'when unknown veteran_id is provided' do
        let(:veteran) { OpenStruct.new(mpi: nil, participant_id: nil) }

        it 'returns a 403 error code' do
          with_okta_user(scopes) do |auth_header|
            expect(ClaimsApi::Veteran).to receive(:new).and_return(veteran)

            get path, headers: auth_header
            expect(response.status).to eq(403)
          end
        end
      end
    end
  end
end
