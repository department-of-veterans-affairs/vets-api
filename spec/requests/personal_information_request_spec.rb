# frozen_string_literal: true

require 'rails_helper'
require 'support/error_details'

RSpec.describe 'personal_information' do
  include SchemaMatchers
  include ErrorDetails

  before do
    sign_in
  end

  describe 'GET /v0/profile/personal_information' do
    context 'with a 200 response' do
      it 'matches the personal information schema' do
        VCR.use_cassette('mpi/find_candidate/valid') do
          get '/v0/profile/personal_information'

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('personal_information_response')
        end
      end
    end

    context 'when MVI does not return a gender nor birthday', skip_mvi: true do
      it 'matches the errors schema', :aggregate_failures do
        VCR.use_cassette('mpi/find_candidate/missing_birthday_and_gender') do
          get '/v0/profile/personal_information'

          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
        end
      end

      it 'includes the correct error code' do
        VCR.use_cassette('mpi/find_candidate/missing_birthday_and_gender') do
          get '/v0/profile/personal_information'

          expect(error_details_for(response, key: 'code')).to eq 'MVI_BD502'
        end
      end
    end
  end
end
