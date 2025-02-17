# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

require 'va_profile/demographics/service'

RSpec.describe 'Mobile::V0::User::PreferredName', type: :request do
  include SchemaMatchers

  describe 'logingov user' do
    let!(:user) do
      sis_user(
        idme_uuid: nil,
        logingov_uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef',
        authn_context: 'dslogon_loa3'
      )
    end
    let(:csd) { 'LGN' }

    describe 'PUT /mobile/v0/profile/preferred_names' do
      context 'when user does not have demographics access' do
        let!(:user) do
          sis_user(
            idme_uuid: nil,
            logingov_uuid: nil
          )
        end

        it 'returns forbidden' do
          preferred_name = VAProfile::Models::PreferredName.new(text: 'Pat')
          put('/mobile/v0/user/preferred_name', params: preferred_name.to_h, headers: sis_headers)

          expect(response).to have_http_status(:forbidden)
        end
      end

      context 'when user does not have mpi access' do
        let!(:user) do
          sis_user(
            icn: nil,
            first_name: nil,
            last_name: nil,
            birth_date: nil,
            ssn: nil,
            gender: nil
          )
        end

        it 'returns forbidden' do
          preferred_name = VAProfile::Models::PreferredName.new(text: 'Pat')
          put('/mobile/v0/user/preferred_name', params: preferred_name.to_h, headers: sis_headers)

          expect(response).to have_http_status(:forbidden)
        end
      end

      context 'when text is valid' do
        it 'returns 204', :aggregate_failures do
          preferred_name = VAProfile::Models::PreferredName.new(text: 'Pat')
          VCR.use_cassette('mobile/va_profile/post_preferred_name_success', erb: { csd: }) do
            VCR.use_cassette('mobile/demographics/logingov') do
              put('/mobile/v0/user/preferred_name', params: preferred_name.to_h, headers: sis_headers)
              expect(response).to have_http_status(:no_content)
            end
          end
        end

        it 'invalidates the cache for the mpi-profile-response', :aggregate_failures do
          preferred_name = VAProfile::Models::PreferredName.new(text: 'Pat')
          VCR.use_cassette('mobile/va_profile/post_preferred_name_success', erb: { csd: }) do
            VCR.use_cassette('mobile/demographics/logingov') do
              expect_any_instance_of(User).to receive(:invalidate_mpi_cache)
              put('/mobile/v0/user/preferred_name', params: preferred_name.to_h, headers: sis_headers)

              expect(response).to have_http_status(:no_content)
            end
          end
        end
      end

      context 'when text is blank' do
        it 'matches the errors schema', :aggregate_failures do
          preferred_name = VAProfile::Models::PreferredName.new(text: nil)

          put('/mobile/v0/user/preferred_name', params: preferred_name.to_h, headers: sis_headers)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('errors')
          expect(errors_for(response)).to include "text - can't be blank"
        end
      end

      context 'when text is too long' do
        it 'matches the errors schema', :aggregate_failures do
          preferred_name = VAProfile::Models::PreferredName.new(text: 'A' * 26)

          put('/mobile/v0/user/preferred_name', params: preferred_name.to_h, headers: sis_headers)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('errors')
          expect(errors_for(response)).to include 'text - is too long (maximum is 25 characters)'
        end
      end
    end
  end

  describe 'idme user' do
    let!(:user) { sis_user(idme_uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef') }
    let(:csd) { 'IDM' }

    describe 'PUT /mobile/v0/profile/preferred_names' do
      context 'when text is valid' do
        it 'returns 204', :aggregate_failures do
          preferred_name = VAProfile::Models::PreferredName.new(text: 'Pat')
          VCR.use_cassette('mobile/va_profile/post_preferred_name_success', erb: { csd: }) do
            VCR.use_cassette('mobile/va_profile/demographics/demographics') do
              put('/mobile/v0/user/preferred_name', params: preferred_name.to_h, headers: sis_headers)

              expect(response).to have_http_status(:no_content)
            end
          end
        end

        it 'invalidates the cache for the mpi-profile-response', :aggregate_failures do
          preferred_name = VAProfile::Models::PreferredName.new(text: 'Pat')
          VCR.use_cassette('mobile/va_profile/post_preferred_name_success', erb: { csd: }) do
            VCR.use_cassette('mobile/demographics/logingov') do
              expect_any_instance_of(User).to receive(:invalidate_mpi_cache)
              put('/mobile/v0/user/preferred_name', params: preferred_name.to_h, headers: sis_headers)

              expect(response).to have_http_status(:no_content)
            end
          end
        end
      end

      context 'when text is blank' do
        it 'matches the errors schema', :aggregate_failures do
          preferred_name = VAProfile::Models::PreferredName.new(text: nil)

          put('/mobile/v0/user/preferred_name', params: preferred_name.to_h, headers: sis_headers)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('errors')
          expect(errors_for(response)).to include "text - can't be blank"
        end
      end

      context 'when text is too long' do
        it 'matches the errors schema', :aggregate_failures do
          preferred_name = VAProfile::Models::PreferredName.new(text: 'A' * 26)

          put('/mobile/v0/user/preferred_name', params: preferred_name.to_h, headers: sis_headers)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('errors')
          expect(errors_for(response)).to include 'text - is too long (maximum is 25 characters)'
        end
      end
    end
  end

  describe 'unauthorized user' do
    let!(:user) { sis_user(idme_uuid: nil, logingov_uuid: nil) }

    describe 'PUT /mobile/v0/profile/preferred_names' do
      context 'when text is valid' do
        it 'returns 402', :aggregate_failures do
          preferred_name = VAProfile::Models::PreferredName.new(text: 'Pat')
          put('/mobile/v0/user/preferred_name', params: preferred_name.to_h, headers: sis_headers)

          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end
end
