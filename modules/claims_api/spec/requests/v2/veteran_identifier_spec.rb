# frozen_string_literal: true

require 'rails_helper'
require 'token_validation/v2/client'
require_relative '../../rails_helper'

RSpec.describe 'ClaimsApi::V2::VeteranIdentifier', openapi_spec: Rswag::TextHelpers.new.claims_api_docs,
                                                   skip: 'Disabling tests for deactivated veteran-id:find endpoint',
                                                   type: :request do
  let(:path) { '/services/claims/v2/veteran-id:find' }
  let(:data) do
    {
      ssn: '796130115',
      firstName: 'Tamara',
      lastName: 'Ellis',
      birthdate: '1967-06-19'
    }
  end
  let(:scopes) { %w[system/claim.write] }
  let(:test_user_icn) { '1012667145V762142' }
  let(:veteran) { ClaimsApi::Veteran.new }
  let(:veteran_mpi_data) { MPIData.new }

  describe 'Veteran Identifier' do
    context 'when auth header and body params are present' do
      context 'when veteran icn is found' do
        context 'when user is a Veteran representative' do
          it 'returns an id' do
            mock_ccg(scopes) do |auth_header|
              expect(ClaimsApi::Veteran).to receive(:new).and_return(veteran)
              allow(veteran).to receive(:mpi).and_return(veteran_mpi_data)
              allow(veteran_mpi_data).to receive(:icn).and_return(test_user_icn)
              post path, params: data, headers: auth_header
              icn = JSON.parse(response.body)['id']

              expect(icn).to eq(test_user_icn)
              expect(response).to have_http_status(:created)
            end
          end
        end

        context 'when user is also the Veteran that was found' do
          okta_user_info = {
            first_name: 'abraham',
            last_name: 'lincoln',
            ssn: '796111863',
            va_profile: ClaimsApi::Veteran.build_profile('1809-02-12')
          }
          let(:veteran) do
            ClaimsApi::Veteran.new(
              first_name: okta_user_info[:first_name],
              last_name: okta_user_info[:last_name],
              ssn: okta_user_info[:ssn],
              va_profile: okta_user_info[:va_profile]
            )
          end

          it 'returns an id' do
            expect(ClaimsApi::Veteran).to receive(:new).and_return(veteran)
            allow(veteran).to receive(:mpi).and_return(veteran_mpi_data)
            allow(veteran_mpi_data).to receive(:icn).and_return(test_user_icn)
            mock_ccg(scopes) do |auth_header|
              post path, params: data, headers: auth_header
              icn = JSON.parse(response.body)['id']

              expect(icn).to eq(test_user_icn)
              expect(response).to have_http_status(:created)
            end
          end
        end
      end
    end

    context 'CCG (Client Credentials Grant) flow' do
      let(:ccg_token) { OpenStruct.new(client_credentials_token?: true, payload: { 'scp' => [] }) }

      context 'when provided' do
        context 'when valid' do
          it 'returns a 201' do
            mock_ccg(scopes) do |auth_header|
              post path, params: data, headers: auth_header

              expect(response).to have_http_status(:created)
            end
          end
        end

        context 'when not valid' do
          it 'returns a 401' do
            mock_ccg(scopes) do |auth_header|
              allow_any_instance_of(ClaimsApi::ValidatedToken).to receive(:validated_token_data).and_return(nil)
              post path, params: data, headers: auth_header
              expect(response).to have_http_status(:unauthorized)
            end
          end
        end
      end
    end

    context 'when body params are not present' do
      let(:data) { {} }

      it 'returns a 400 error code' do
        mock_ccg(scopes) do |auth_header|
          post path, params: data, headers: auth_header
          expect(response).to have_http_status(:bad_request)
        end
      end
    end

    context 'when auth header is not present' do
      it 'returns a 401 error code' do
        post path, params: data
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when veteran icn cannot be found' do
      it 'returns a 404' do
        expect(ClaimsApi::Veteran).to receive(:new).and_return(veteran)
        allow(veteran).to receive(:mpi).and_return(veteran_mpi_data)
        allow(veteran_mpi_data).to receive(:icn).and_return(nil)
        mock_ccg(scopes) do |auth_header|
          post path, params: data, headers: auth_header
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when ssn is invalid' do
      context 'when ssn is too long' do
        it 'returns a 400 error code' do
          mock_ccg(scopes) do |auth_header|
            invalid_data = data
            invalid_data[:ssn] = '7961301159'

            post path, params: invalid_data, headers: auth_header
            expect(response).to have_http_status(:bad_request)
          end
        end
      end

      context 'when ssn is too short' do
        it 'returns a 400 error code' do
          mock_ccg(scopes) do |auth_header|
            invalid_data = data
            invalid_data[:ssn] = '79613011'

            post path, params: invalid_data, headers: auth_header
            expect(response).to have_http_status(:bad_request)
          end
        end
      end

      context 'when ssn has non-digit characters' do
        it 'returns a 400 error code' do
          mock_ccg(scopes) do |auth_header|
            invalid_data = data
            invalid_data[:ssn] = '796130 .A!'

            post path, params: invalid_data, headers: auth_header
            expect(response).to have_http_status(:bad_request)
          end
        end
      end

      context 'when ssn is blank' do
        it 'returns a 400 error code' do
          mock_ccg(scopes) do |auth_header|
            invalid_data = data
            invalid_data[:ssn] = ''

            post path, params: invalid_data, headers: auth_header
            expect(response).to have_http_status(:bad_request)
          end
        end
      end
    end

    context 'when birthdate is invalid' do
      context 'when birthdate is an invalid date' do
        it 'returns a 400 error code' do
          mock_ccg(scopes) do |auth_header|
            invalid_data = data
            invalid_data[:birthdate] = '1234'

            post path, params: invalid_data, headers: auth_header
            expect(response).to have_http_status(:bad_request)
          end
        end
      end

      context 'when birthdate is in the future' do
        it 'returns a 400 error code' do
          mock_ccg(scopes) do |auth_header|
            invalid_data = data
            invalid_data[:birthdate] = (Time.zone.today + 1.year).to_s

            post path, params: invalid_data, headers: auth_header
            expect(response).to have_http_status(:bad_request)
          end
        end
      end
    end

    context 'when custom verb is invalid' do
      let(:path) { '/services/claims/v2/veteran-id:search' }

      describe 'veteran identifier' do
        it 'returns a 404 error code' do
          mock_ccg(scopes) do |auth_header|
            post path, params: data, headers: auth_header
            expect(response).to have_http_status(:not_found)
          end
        end
      end
    end
  end
end
