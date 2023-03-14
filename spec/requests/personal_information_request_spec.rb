# frozen_string_literal: true

require 'rails_helper'
require 'support/error_details'

RSpec.describe 'personal_information' do
  include SchemaMatchers
  include ErrorDetails

  let(:user) { create(:user, :loa3, mpi_profile: mpi_profile) }
  let(:mpi_profile) { {} }
  let(:idme_uuid) { 'b2fab2b5-6af0-45e1-a9e2-394347af91ef' }

  before do
    sign_in(user)
  end

  describe 'GET /v0/profile/personal_information' do
    context 'with a 200 response' do
      it 'matches the personal information schema' do
        VCR.use_cassette('mpi/find_candidate/valid') do
          VCR.use_cassette('va_profile/demographics/demographics') do
            get '/v0/profile/personal_information'

            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('personal_information_response')
          end
        end
      end
    end

    context 'when MVI does not return a gender nor birthday', skip_mvi: true do
      let(:mpi_profile) { { birth_date: nil, gender: nil } }

      it 'matches the errors schema', :aggregate_failures do
        VCR.use_cassette('mpi/find_candidate/missing_birthday_and_gender') do
          VCR.use_cassette('va_profile/demographics/demographics') do
            get '/v0/profile/personal_information'
            expect(response).to have_http_status(:bad_gateway)
            expect(response).to match_response_schema('errors')
          end
        end
      end

      it 'includes the correct error code' do
        VCR.use_cassette('mpi/find_candidate/missing_birthday_and_gender') do
          VCR.use_cassette('va_profile/demographics/demographics') do
            get '/v0/profile/personal_information'

            expect(error_details_for(response, key: 'code')).to eq 'MVI_BD502'
          end
        end
      end
    end

    context 'when VAProfile does not return a preferred name nor gender identity' do
      it 'matches the errors schema', :aggregate_failures do
        VCR.use_cassette('mpi/find_candidate/valid') do
          VCR.use_cassette('va_profile/demographics/demographics_error_503') do
            get '/v0/profile/personal_information'

            expect(response).to have_http_status(:bad_gateway)
            expect(response).to match_response_schema('errors')
          end
        end
      end
    end
  end
end
