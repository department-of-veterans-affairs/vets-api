# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Claims', type: :request do
  let(:veteran_id) { '1013062086V794840' }
  let(:claim_id) { '600131328' }
  let(:all_claims_path) { "/services/benefits/v2/veterans/#{veteran_id}/claims" }
  let(:claim_by_id_path) { "/services/benefits/v2/veterans/#{veteran_id}/claims/#{claim_id}" }
  let(:scopes) { %w[claim.read] }

  describe 'Claims' do
    context 'auth header' do
      context 'when provided' do
        it 'returns a 200' do
          with_okta_user(scopes) do |auth_header|
            expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
              .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(
                benefit_claims_dto: {
                  benefit_claim: []
                }
              )
            expect(ClaimsApi::AutoEstablishedClaim)
              .to receive(:where).and_return([])

            get all_claims_path, headers: auth_header
            expect(response.status).to eq(200)
          end
        end
      end

      context 'when not provided' do
        it 'returns a 401 error code' do
          with_okta_user(scopes) do
            get all_claims_path
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

              get all_claims_path, headers: auth_header
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
            get all_claims_path, headers: auth_header
            expect(response.status).to eq(404)
          end
        end
      end

      context 'when known veteran_id is provided' do
        it 'returns a 200' do
          with_okta_user(scopes) do |auth_header|
            expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
              .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(
                benefit_claims_dto: {
                  benefit_claim: []
                }
              )
            expect(ClaimsApi::AutoEstablishedClaim)
              .to receive(:where).and_return([])

            get all_claims_path, headers: auth_header
            expect(response.status).to eq(200)
          end
        end
      end

      context 'when unknown veteran_id is provided' do
        let(:veteran) { OpenStruct.new(mpi: nil, participant_id: nil) }

        it 'returns a 403 error code' do
          with_okta_user(scopes) do |auth_header|
            expect(ClaimsApi::Veteran).to receive(:new).and_return(veteran)

            get all_claims_path, headers: auth_header
            expect(response.status).to eq(403)
          end
        end
      end
    end

    context 'for a single claim' do
      context 'when no auth header provided' do
        it 'returns a 401 error code' do
          with_okta_user(scopes) do
            get claim_by_id_path
            expect(response.status).to eq(401)
          end
        end
      end

      context 'when current user is not the target veteran' do
        context 'when current user is not a representative of the target veteran' do
          it 'returns a 403' do
            with_okta_user(scopes) do |auth_header|
              expect_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:user_is_target_veteran?).and_return(false)
              expect_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:user_represents_veteran?).and_return(false)

              get claim_by_id_path, headers: auth_header
              expect(response.status).to eq(403)
            end
          end
        end
      end

      context 'when a known claimId is provided' do
        it 'returns a 200' do
          with_okta_user(scopes) do |auth_header|
            expect(ClaimsApi::AutoEstablishedClaim)
              .to receive(:get_by_id_or_evss_id).and_return(
                OpenStruct.new(id: '1111', claim_type: 'Appeals Control', evss_id: '1', status: 'completed')
              )
            expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
              .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(nil)

            get claim_by_id_path, headers: auth_header
            expect(response.status).to eq(200)
          end
        end
      end

      context 'when a known BGS claimId is provided' do
        it 'returns a 200' do
          with_okta_user(scopes) do |auth_header|
            expect(ClaimsApi::AutoEstablishedClaim).to receive(:get_by_id_or_evss_id).and_return(nil)
            expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
              .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(
                benefit_claim_details_dto: {
                  benefit_claim_id: '1',
                  claim_status_type: 'Compensation'
                }
              )

            get claim_by_id_path, headers: auth_header
            expect(response.status).to eq(200)
          end
        end
      end

      context 'when an unknown claim_id is provided' do
        it 'returns a 404' do
          with_okta_user(scopes) do |auth_header|
            expect(ClaimsApi::AutoEstablishedClaim).to receive(:get_by_id_or_evss_id).and_return(nil)
            expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
              .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(nil)

            get claim_by_id_path, headers: auth_header

            expect(response.status).to eq(404)
          end
        end
      end
    end
  end
end
