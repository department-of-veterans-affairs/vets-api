# frozen_string_literal: true

require 'rails_helper'
require 'token_validation/v2/client'
require 'bgs_service/local_bgs'

RSpec.describe 'Power Of Attorney', type: :request do
  let(:veteran_id) { '1013062086V794840' }
  let(:get_poa_path) { "/services/claims/v2/veterans/#{veteran_id}/power-of-attorney" }
  let(:appoint_individual_path) { "/services/claims/v2/veterans/#{veteran_id}/power-of-attorney:appoint-individual" }
  let(:appoint_organization_path) do
    "/services/claims/v2/veterans/#{veteran_id}/power-of-attorney:appoint-organization"
  end
  let(:scopes) { %w[system/claim.write] }
  let(:individual_poa_code) { 'A1H' }
  let(:organization_poa_code) { '083' }
  let(:bgs_poa) { { person_org_name: "#{individual_poa_code} name-here" } }
  let(:local_bgs) { ClaimsApi::LocalBGS }

  describe 'PowerOfAttorney' do
    before do
      Veteran::Service::Representative.new(representative_id: '12345', poa_codes: [individual_poa_code],
                                           first_name: 'Abraham', last_name: 'Lincoln').save!
      Veteran::Service::Representative.new(representative_id: '67890', poa_codes: [organization_poa_code],
                                           first_name: 'George', last_name: 'Washington').save!
      Veteran::Service::Organization.create(poa: organization_poa_code,
                                            name: "#{organization_poa_code} - DISABLED AMERICAN VETERANS")
    end

    describe 'show' do
      context 'CCG (Client Credentials Grant) flow' do
        let(:ccg_token) { OpenStruct.new(client_credentials_token?: true, payload: { 'scp' => [] }) }

        context 'when provided' do
          context 'when valid' do
            context 'when current poa code does not exist' do
              it 'returns a 204' do
                allow(JWT).to receive(:decode).and_return(nil)
                allow(Token).to receive(:new).and_return(ccg_token)
                allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(true)
                allow(BGS::PowerOfAttorneyVerifier).to receive(:new).and_return(OpenStruct.new(current_poa_code: nil))

                get get_poa_path, headers: { 'Authorization' => 'Bearer HelloWorld' }

                expect(response.status).to eq(204)
              end
            end
          end

          context 'when not valid' do
            it 'returns a 403' do
              allow(JWT).to receive(:decode).and_return(nil)
              allow(Token).to receive(:new).and_return(ccg_token)
              allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(false)

              get get_poa_path, headers: { 'Authorization' => 'Bearer HelloWorld' }

              expect(response.status).to eq(403)
            end
          end
        end
      end
    end

    describe 'appoint_individual' do
      b64_image = File.read('modules/claims_api/spec/fixtures/signature_b64.txt')
      let(:data) do
        {
          serviceOrganization: {
            poaCode: individual_poa_code.to_s
          },
          signatures: {
            veteran: b64_image,
            representative: b64_image
          }
        }
      end

      describe 'auth header' do
        context 'when provided' do
          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              expect_any_instance_of(local_bgs).to receive(:find_poa_by_participant_id)
                .and_return(bgs_poa)
              allow_any_instance_of(local_bgs).to receive(:find_poa_history_by_ptcpnt_id)
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

      context 'when a POA code isn\'t provided' do
        it 'returns a 400 error code' do
          with_okta_user(scopes) do |auth_header|
            data[:serviceOrganization] = nil

            put appoint_individual_path, params: data, headers: auth_header
            expect(response.status).to eq(400)
          end
        end
      end

      context 'when no signatures are provided' do
        it 'returns a 400 error code' do
          with_okta_user(scopes) do |auth_header|
            data[:signatures] = nil

            put appoint_individual_path, params: data, headers: auth_header
            expect(response.status).to eq(400)
          end
        end
      end

      context 'when a veteran signature isn\'t provided' do
        it 'returns a 400 error code' do
          with_okta_user(scopes) do |auth_header|
            data[:signatures][:veteran] = nil

            put appoint_individual_path, params: data, headers: auth_header
            expect(response.status).to eq(400)
          end
        end
      end

      context 'when a representative signature isn\'t provided' do
        it 'returns a 400 error code' do
          with_okta_user(scopes) do |auth_header|
            data[:signatures][:representative] = nil

            put appoint_individual_path, params: data, headers: auth_header
            expect(response.status).to eq(400)
          end
        end
      end

      context 'when the POA code is for an organization instead of an individual' do
        it 'returns a 422 error code' do
          with_okta_user(scopes) do |auth_header|
            data[:serviceOrganization][:poaCode] = organization_poa_code.to_s

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

      context 'CCG (Client Credentials Grant) flow' do
        let(:ccg_token) { OpenStruct.new(client_credentials_token?: true, payload: { 'scp' => [] }) }

        context 'when provided' do
          context 'when valid' do
            it 'returns a 200' do
              allow(JWT).to receive(:decode).and_return(nil)
              allow(Token).to receive(:new).and_return(ccg_token)
              allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(true)
              expect_any_instance_of(local_bgs).to receive(:find_poa_by_participant_id)
                .and_return(bgs_poa)
              allow_any_instance_of(local_bgs).to receive(:find_poa_history_by_ptcpnt_id)
                .and_return({ person_poa_history: nil })

              put appoint_individual_path, params: data, headers: { 'Authorization' => 'Bearer HelloWorld' }

              expect(response.status).to eq(200)
            end
          end

          context 'when not valid' do
            it 'returns a 403' do
              allow(JWT).to receive(:decode).and_return(nil)
              allow(Token).to receive(:new).and_return(ccg_token)
              allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(false)

              put appoint_individual_path, params: data, headers: { 'Authorization' => 'Bearer HelloWorld' }

              expect(response.status).to eq(403)
            end
          end
        end
      end
    end

    describe 'appoint_organization' do
      b64_image = File.read('modules/claims_api/spec/fixtures/signature_b64.txt')
      let(:data) do
        {
          serviceOrganization: {
            poaCode: organization_poa_code.to_s
          },
          signatures: {
            veteran: b64_image,
            representative: b64_image
          }
        }
      end

      describe 'auth header' do
        context 'when provided' do
          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              expect_any_instance_of(local_bgs).to receive(:find_poa_by_participant_id)
                .and_return(bgs_poa)
              allow_any_instance_of(local_bgs).to receive(:find_poa_history_by_ptcpnt_id)
                .and_return({ person_poa_history: nil })

              put appoint_organization_path, params: data, headers: auth_header
              expect(response.status).to eq(200)
            end
          end
        end

        context 'when not provided' do
          it 'returns a 401 error code' do
            with_okta_user(scopes) do
              put appoint_organization_path, params: data
              expect(response.status).to eq(401)
            end
          end
        end

        context 'when the POA code is for an individual instead of an organization' do
          it 'returns a 422 error code' do
            with_okta_user(scopes) do |auth_header|
              data[:serviceOrganization][:poaCode] = individual_poa_code.to_s

              put appoint_organization_path, params: data, headers: auth_header
              expect(response.status).to eq(422)
            end
          end
        end
      end

      context 'CCG (Client Credentials Grant) flow' do
        let(:ccg_token) { OpenStruct.new(client_credentials_token?: true, payload: { 'scp' => [] }) }

        context 'when provided' do
          context 'when valid' do
            it 'returns a 200' do
              allow(JWT).to receive(:decode).and_return(nil)
              allow(Token).to receive(:new).and_return(ccg_token)
              allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(true)
              expect_any_instance_of(local_bgs).to receive(:find_poa_by_participant_id)
                .and_return(bgs_poa)
              allow_any_instance_of(local_bgs).to receive(:find_poa_history_by_ptcpnt_id)
                .and_return({ person_poa_history: nil })

              put appoint_organization_path, params: data, headers: { 'Authorization' => 'Bearer HelloWorld' }

              expect(response.status).to eq(200)
            end
          end

          context 'when not valid' do
            it 'returns a 403' do
              allow(JWT).to receive(:decode).and_return(nil)
              allow(Token).to receive(:new).and_return(ccg_token)
              allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(false)

              put appoint_organization_path, params: data, headers: { 'Authorization' => 'Bearer HelloWorld' }

              expect(response.status).to eq(403)
            end
          end
        end
      end
    end
  end
end
