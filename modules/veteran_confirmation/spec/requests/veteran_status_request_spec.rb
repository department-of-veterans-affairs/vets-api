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
    before do
      VCR.eject_cassette('mvi/find_candidate/valid')
      VCR.insert_cassette('mvi/find_candidate/valid')
    end

    after do
      VCR.eject_cassette('mvi/find_candidate/valid')
    end

    it 'returns confirmed if the veteran status is confirmed' do
      VCR.insert_cassette('emis/get_veteran_status/valid_icn')

      # in real life, the post body is used, but there is no request spec param for Body.
      # using the params attribute send the data to the params and body in the test.
      post '/services/veteran_confirmation/v0/status', params: valid_attributes.to_json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['veteran_status']).to eq('confirmed')

      VCR.eject_cassette('emis/get_veteran_status/valid_icn')
    end

    it 'returns not confirmed if the user is not a veteran' do
      VCR.insert_cassette('emis/get_veteran_status/valid_non_veteran_icn')

      # in real life, the post body is used, but there is no request spec param for Body.
      # using the params attribute send the data to the params and body in the test.
      post '/services/veteran_confirmation/v0/status', params: valid_attributes.to_json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['veteran_status']).to eq('not confirmed')

      VCR.eject_cassette('emis/get_veteran_status/valid_non_veteran_icn')
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

      post '/services/veteran_confirmation/v0/status', params: missing_attributes.to_json

      expect(response).to have_http_status(:unauthorized)
      error_detail = JSON.parse(response.body)['errors'].first['detail']
      expect(error_detail).to eq('Validation error: Body must include ssn')
    end

    it 'throws an error when ssn format is invalid' do
      invalid_ssn_attributes = {
        ssn: '123123',
        first_name: 'Mitchell',
        last_name: 'Jenkins',
        birth_date: '1967-04-13'
      }

      post '/services/veteran_confirmation/v0/status', params: invalid_ssn_attributes.to_json

      expect(response).to have_http_status(:unauthorized)
      error_detail = JSON.parse(response.body)['errors'].first['detail']
      expect(error_detail).to eq('Validation error: SSN must be 9 digits or have this format: 999-99-9999')

      invalid_ssn_attributes = {
        ssn: '123abc5678',
        first_name: 'Mitchell',
        last_name: 'Jenkins',
        birth_date: '1967-04-13'
      }

      post '/services/veteran_confirmation/v0/status', params: invalid_ssn_attributes.to_json

      expect(response).to have_http_status(:unauthorized)
      error_detail = JSON.parse(response.body)['errors'].first['detail']
      expect(error_detail).to eq('Validation error: SSN must be 9 digits or have this format: 999-99-9999')
    end

    it 'throws an error when date format is invalid' do
      invalid_date_attributes = {
        ssn: '123456789',
        first_name: 'Mitchell',
        last_name: 'Jenkins',
        birth_date: '1967sep30th'
      }

      post '/services/veteran_confirmation/v0/status', params: invalid_date_attributes.to_json

      expect(response).to have_http_status(:unauthorized)
      error_detail = JSON.parse(response.body)['errors'].first['detail']
      expect(error_detail).to eq('Validation error: birth date must be a valid iso8601 format')
    end
  end
end
