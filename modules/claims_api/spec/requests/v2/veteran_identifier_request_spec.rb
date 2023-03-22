# frozen_string_literal: true

require 'rails_helper'
require 'token_validation/v2/client'

RSpec.describe 'Veteran Identifier Endpoint', type: :request,
                                              swagger_doc: Rswag::TextHelpers.new.claims_api_docs do
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
            expect(ClaimsApi::Veteran).to receive(:new).and_return(veteran)
            allow(veteran).to receive(:mpi).and_return(veteran_mpi_data)
            allow(veteran_mpi_data).to receive(:icn).and_return(test_user_icn)
            expect(::Veteran::Service::Representative).to receive(:find_by).and_return(true)
            with_okta_user(scopes) do |auth_header|
              post path, params: data, headers: auth_header
              icn = JSON.parse(response.body)['id']

              expect(icn).to eq(test_user_icn)
              expect(response.status).to eq(201)
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
            with_okta_user(scopes) do |auth_header|
              post path, params: data, headers: auth_header
              icn = JSON.parse(response.body)['id']

              expect(icn).to eq(test_user_icn)
              expect(response.status).to eq(201)
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
            allow(JWT).to receive(:decode).and_return(nil)
            allow(Token).to receive(:new).and_return(ccg_token)
            allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(true)
            expect(ClaimsApi::Veteran).to receive(:new).and_return(veteran)
            allow(veteran).to receive(:mpi).and_return(veteran_mpi_data)
            allow(veteran_mpi_data).to receive(:icn).and_return(test_user_icn)

            post path, params: data, headers: { 'Authorization' => 'Bearer HelloWorld' }

            expect(response.status).to eq(201)
          end
        end

        context 'when not valid' do
          it 'returns a 403' do
            allow(JWT).to receive(:decode).and_return(nil)
            allow(Token).to receive(:new).and_return(ccg_token)
            allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(false)

            post path, params: data, headers: { 'Authorization' => 'Bearer HelloWorld' }

            expect(response.status).to eq(403)
          end
        end
      end
    end

    context 'when body params are not present' do
      let(:data) { {} }

      it 'returns a 400 error code' do
        with_okta_user(scopes) do |auth_header|
          post path, params: data, headers: auth_header
          expect(response.status).to eq(400)
        end
      end
    end

    context 'when auth header is not present' do
      it 'returns a 401 error code' do
        post path, params: data
        expect(response.status).to eq(401)
      end
    end

    context 'when veteran icn cannot be found' do
      it 'returns a 404' do
        expect(ClaimsApi::Veteran).to receive(:new).and_return(veteran)
        allow(veteran).to receive(:mpi).and_return(veteran_mpi_data)
        allow(veteran_mpi_data).to receive(:icn).and_return(nil)
        with_okta_user(scopes) do |auth_header|
          post path, params: data, headers: auth_header
          expect(response.status).to eq(404)
        end
      end
    end

    context 'when ssn is invalid' do
      context 'when ssn is too long' do
        it 'returns a 400 error code' do
          with_okta_user(scopes) do |auth_header|
            invalid_data = data
            invalid_data[:ssn] = '7961301159'

            post path, params: invalid_data, headers: auth_header
            expect(response.status).to eq(400)
          end
        end
      end

      context 'when ssn is too short' do
        it 'returns a 400 error code' do
          with_okta_user(scopes) do |auth_header|
            invalid_data = data
            invalid_data[:ssn] = '79613011'

            post path, params: invalid_data, headers: auth_header
            expect(response.status).to eq(400)
          end
        end
      end

      context 'when ssn has non-digit characters' do
        it 'returns a 400 error code' do
          with_okta_user(scopes) do |auth_header|
            invalid_data = data
            invalid_data[:ssn] = '796130 .A!'

            post path, params: invalid_data, headers: auth_header
            expect(response.status).to eq(400)
          end
        end
      end

      context 'when ssn is blank' do
        it 'returns a 400 error code' do
          with_okta_user(scopes) do |auth_header|
            invalid_data = data
            invalid_data[:ssn] = ''

            post path, params: invalid_data, headers: auth_header
            expect(response.status).to eq(400)
          end
        end
      end
    end

    context 'when birthdate is invalid' do
      context 'when birthdate is an invalid date' do
        it 'returns a 400 error code' do
          with_okta_user(scopes) do |auth_header|
            invalid_data = data
            invalid_data[:birthdate] = '1234'

            post path, params: invalid_data, headers: auth_header
            expect(response.status).to eq(400)
          end
        end
      end

      context 'when birthdate is in the future' do
        it 'returns a 400 error code' do
          with_okta_user(scopes) do |auth_header|
            invalid_data = data
            invalid_data[:birthdate] = (Time.zone.today + 1.year).to_s

            post path, params: invalid_data, headers: auth_header
            expect(response.status).to eq(400)
          end
        end
      end
    end

    context 'when request is forbidden' do
      context 'when user is not a Veteran representative, nor the matching Veteran' do
        it 'returns a 403 forbidden response' do
          expect(ClaimsApi::Veteran).to receive(:new).and_return(veteran)
          allow(veteran).to receive(:mpi).and_return(veteran_mpi_data)
          allow(veteran_mpi_data).to receive(:icn).and_return(test_user_icn)
          expect(::Veteran::Service::Representative).to receive(:find_by).and_return(nil)
          with_okta_user(scopes) do |auth_header|
            post path, params: data, headers: auth_header

            expect(response.status).to eq(403)
          end
        end
      end
    end

    context 'when custom verb is invalid' do
      let(:path) { '/services/claims/v2/veteran-id:search' }

      describe 'veteran identifier' do
        it 'returns a 404 error code' do
          with_okta_user(scopes) do |auth_header|
            post path, params: data, headers: auth_header
            expect(response.status).to eq(404)
          end
        end
      end
    end
  end
end
