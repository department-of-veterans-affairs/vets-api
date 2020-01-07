# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Veteran Status API endpoint', type: :request, skip_emis: true do
  include SchemaMatchers

  let(:valid_attributes) do
    {
      ssn: '123456789',
      first_name: 'Mitchell',
      last_name: 'Jenkins',
      birth_date: '1967-04-13'
    }
  end

  context 'with a valid user' do
    it 'returns confirmed if the veteran status is confirmed' do
      VCR.use_cassette('mvi/find_candidate/valid') do
        VCR.use_cassette('emis/get_veteran_status/valid_icn') do
          post '/services/veteran_confirmation/v0/status', params: valid_attributes

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['veteran_status']).to eq('confirmed')
        end
      end
    end

    it 'returns not confirmed if the user is not a veteran' do
      VCR.use_cassette('mvi/find_candidate/valid') do
        VCR.use_cassette('emis/get_veteran_status/valid_non_veteran_icn') do
          post '/services/veteran_confirmation/v0/status', params: valid_attributes

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['veteran_status']).to eq('not confirmed')
        end
      end
    end
  end

  context 'with invalid attributes' do
    it 'throws an error when missing a required parameter' do
      missing_attributes = {
        ssn: nil,
        first_name: 'Mitchell',
        last_name: 'Jenkins',
        birth_date: '1967-04-13'
      }

      post '/services/veteran_confirmation/v0/status', params: missing_attributes

      expect(response).to have_http_status(:bad_request)
      error_detail = JSON.parse(response.body)['errors'].first['detail']
      expect(error_detail).to eq('The required parameter "ssn", is missing')
    end

    it 'throws an error when ssn format is invalid' do
      invalid_ssn_attributes = {
        ssn: '123123',
        first_name: 'Mitchell',
        last_name: 'Jenkins',
        birth_date: '1967-04-13'
      }

      post '/services/veteran_confirmation/v0/status', params: invalid_ssn_attributes

      expect(response).to have_http_status(:bad_request)
      error_detail = JSON.parse(response.body)['errors'].first['detail']
      expect(error_detail).to eq('"the provided" is not a valid value for "ssn"')
    end

    it 'throws an error when date format is invalid' do
      invalid_date_attributes = {
        ssn: '123456789',
        first_name: 'Mitchell',
        last_name: 'Jenkins',
        birth_date: '1967sep30th'
      }

      post '/services/veteran_confirmation/v0/status', params: invalid_date_attributes

      expect(response).to have_http_status(:bad_request)
      error_detail = JSON.parse(response.body)['errors'].first['detail']
      expect(error_detail).to eq('"1967sep30th" is not a valid value for "birth_date"')
    end
  end
end
