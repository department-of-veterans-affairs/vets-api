# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Power Of Attorney', type: :request do
  let(:veteran_id) { '1013062086V794840' }
  let(:data) do
    {
      serviceOrganization: {
        poaCode: '074'
      }
    }
  end
  let(:appoint_individual_path) { "/services/benefits/v2/veterans/#{veteran_id}/power-of-attorney:appointIndividual" }
  let(:scopes) { %w[claim.write] }
  let(:individual_poa_code) { '074' }
  let(:organization_poa_code) { '083' }
  let(:bgs_poa) { { person_org_name: "#{individual_poa_code} name-here" } }

  describe 'PowerOfAttorney' do
    describe 'AppointIndividual' do
      before do
        Veteran::Service::Representative.new(representative_id: '12345', poa_codes: [individual_poa_code],
                                             first_name: 'Abraham', last_name: 'Lincoln').save!
        Veteran::Service::Representative.new(representative_id: '67890', poa_codes: [organization_poa_code],
                                             first_name: 'George', last_name: 'Washington',
                                             user_types: ['veteran_service_officer']).save!
        Veteran::Service::Organization.create(poa: organization_poa_code,
                                              name: "#{organization_poa_code} - DISABLED AMERICAN VETERANS")
      end

      describe 'auth header' do
        context 'when provided' do
          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              expect_any_instance_of(BGS::ClaimantWebService).to receive(:find_poa_by_participant_id)
                .and_return(bgs_poa)
              allow_any_instance_of(BGS::OrgWebService).to receive(:find_poa_history_by_ptcpnt_id)
                .and_return({ person_poa_history: nil })

              put appoint_individual_path, params: data, headers: auth_header
              expect(response.status).to eq(200)
            end
          end
        end

        context 'when not provided' do
          it 'returns a 401 error code' do
            with_okta_user(scopes) do
              put appoint_individual_path, params: data
              expect(response.status).to eq(401)
            end
          end
        end
      end

      context 'when the POA code is for an organization instead of an individual' do
        it 'returns a 422 error code' do
          with_okta_user(scopes) do |auth_header|
            data[:serviceOrganization][:poaCode] = '083'

            put appoint_individual_path, params: data, headers: auth_header
            expect(response.status).to eq(422)
          end
        end
      end

      context 'when there are multiple representatives with the same POA code' do
        it 'returns a 500 error code' do
          Veteran::Service::Representative.new(representative_id: '12345', poa_codes: [individual_poa_code],
                                               first_name: 'Thomas', last_name: 'Jefferson').save!

          with_okta_user(scopes) do |auth_header|
            put appoint_individual_path, params: data, headers: auth_header
            expect(response.status).to eq(500)
          end
        end
      end
    end
  end
end
