# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../rails_helper'
require 'token_validation/v2/client'
require 'bgs_service/local_bgs'
require 'bgs/power_of_attorney_verifier'

RSpec.describe 'ClaimsApi::V1::PowerOfAttorney::PowerOfAttorney', type: :request do
  let(:veteran_id) { '1013062086V794840' }
  let(:get_poa_path) { "/services/claims/v2/veterans/#{veteran_id}/power-of-attorney" }
  let(:scopes) { %w[system/claim.write system/claim.read] }
  let(:invalid_post_scopes) { %w[system/claim.read] }
  let(:individual_poa_code) { 'A1H' }
  let(:organization_poa_code) { '083' }
  let(:bgs_poa) { { person_org_name: "#{individual_poa_code} name-here" } }
  let(:local_bgs) { ClaimsApi::LocalBGS }

  describe 'PowerOfAttorney' do
    before do
      create(:veteran_representative, representative_id: '12345', poa_codes: [individual_poa_code],
                                      first_name: 'Abraham', last_name: 'Lincoln')
      create(:veteran_representative, representative_id: '67890', poa_codes: [organization_poa_code],
                                      first_name: 'George', last_name: 'Washington')
      create(:veteran_organization, poa: organization_poa_code,
                                    name: "#{organization_poa_code} - DISABLED AMERICAN VETERANS")
    end

    describe 'show' do
      context 'CCG (Client Credentials Grant) flow' do
        context 'when provided' do
          context 'when valid' do
            context 'when BGS does not return a POA code' do
              it 'returns a 200' do
                mock_ccg(scopes) do |auth_header|
                  allow(BGS::PowerOfAttorneyVerifier).to receive(:new).and_return(OpenStruct.new(current_poa_code: nil))

                  get get_poa_path, headers: auth_header

                  expect(response).to have_http_status(:ok)
                end
              end
            end

            context 'when the current poa is not associated with an organization' do
              context 'when there is one unique representative_id' do
                before do
                  create(:veteran_representative, representative_id: '12345', first_name: 'Robert', last_name: 'Lawlaw',
                                                  poa_codes: ['ABC'], phone: '321-654-0987', created_at: Time.zone.now)
                end

                it 'returns the most recently created representative' do
                  mock_ccg(scopes) do |auth_header|
                    allow(BGS::PowerOfAttorneyVerifier)
                      .to receive(:new)
                      .and_return(OpenStruct.new(current_poa_code: 'ABC'))

                    expected_response = {
                      'data' => {
                        'type' => 'individual',
                        'attributes' => {
                          'code' => 'ABC',
                          'name' => 'Robert Lawlaw',
                          'phoneNumber' => '321-654-0987'
                        }
                      }
                    }

                    get get_poa_path, headers: auth_header

                    response_body = JSON.parse(response.body)

                    expect(response).to have_http_status(:ok)
                    expect(response_body).to eq(expected_response)
                  end
                end

                context 'when there are multiple unique representative_ids' do
                  before do
                    create(:veteran_representative, representative_id: '67890', poa_codes: ['EDF'])
                    create(:veteran_representative, representative_id: '54321', poa_codes: ['EDF'])
                  end

                  it 'returns a meaningful 422' do
                    mock_ccg(scopes) do |auth_header|
                      allow(BGS::PowerOfAttorneyVerifier)
                        .to receive(:new)
                        .and_return(OpenStruct.new(current_poa_code: 'EDF'))

                      detail = 'Could not retrieve Power of Attorney due to multiple representatives with code: EDF'

                      get get_poa_path, headers: auth_header

                      response_body = JSON.parse(response.body)['errors'][0]

                      expect(response).to have_http_status(:unprocessable_entity)
                      expect(response_body['title']).to eq('Unprocessable entity')
                      expect(response_body['status']).to eq('422')
                      expect(response_body['detail']).to eq(detail)
                    end
                  end
                end
              end
            end
          end

          context 'when not valid' do
            it 'returns a 401' do
              get get_poa_path, headers: { 'Authorization' => 'Bearer HelloWorld' }

              expect(response).to have_http_status(:unauthorized)
            end
          end
        end
      end
    end

    describe 'status' do
      it 'returns the status of a POA' do
        mock_ccg(scopes) do |auth_header|
          poa = create(:power_of_attorney, :submitted, auth_headers: auth_header)

          get "#{get_poa_path}/#{poa.id}", params: nil, headers: auth_header
          json = JSON.parse(response.body)

          expect(json['data']['type']).to eq('claimsApiPowerOfAttorneys')
          expect(json['data']['attributes']['status']).to eq('submitted')
        end
      end

      it 'returns 404 when given an unknown id' do
        mock_ccg(scopes) do |auth_header|
          get "#{get_poa_path}/123456", params: nil, headers: auth_header

          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
