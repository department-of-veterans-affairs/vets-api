# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Veteran Identifier Endpoint', type: :request do
  let(:path) { '/services/benefits/v2/veteran-id:find' }
  let(:data) do
    {
      ssn: '796130115',
      firstName: 'Tamara',
      lastName: 'Ellis',
      birthdate: '1967-06-19'
    }
  end
  let(:scopes) { %w[claim.read] }
  let(:test_user_icn) { '1012667145V762142' }
  let(:veteran) { ClaimsApi::Veteran.new }
  let(:veteran_mpi_data) { MPIData.new }

  describe 'Veteran Identifier' do
    context 'when auth header and body params are present' do
      context 'when veteran icn is found' do
        it 'returns an id' do
          expect(ClaimsApi::Veteran).to receive(:new).and_return(veteran)
          allow(veteran).to receive(:mpi).and_return(veteran_mpi_data)
          allow(veteran_mpi_data).to receive(:icn).and_return(test_user_icn)
          with_okta_user(scopes) do |auth_header|
            post path, params: data, headers: auth_header
            icn = JSON.parse(response.body)['id']

            expect(icn).to eq(test_user_icn)
            expect(response.status).to eq(200)
          end
        end
      end
    end

    context 'when body params are not present' do
      let(:data) { nil }

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

    context 'when custom verb is invalid' do
      let(:path) { '/services/benefits/v2/veteran-id:search' }

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
