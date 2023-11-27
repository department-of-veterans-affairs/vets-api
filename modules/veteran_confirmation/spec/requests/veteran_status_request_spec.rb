# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Veteran Status API endpoint', type: :request, skip_emis: true do
  include SchemaMatchers

  before do
    allow(Settings.vet_verification).to receive(:mock_emis).and_return(false)
  end

  let(:valid_attributes) do
    {
      ssn: '123456789',
      first_name: 'Mitchell',
      middle_name: 'G',
      last_name: 'Jenkins',
      birth_date: '1967-04-13',
      gender: 'M'
    }
  end
  let(:required_valid_attributes) do
    {
      ssn: '123456789',
      first_name: 'Mitchell',
      last_name: 'Jenkins',
      birth_date: '1967-04-13'
    }
  end

  context 'mock-emis service' do
    before do
      allow(Settings.vet_verification).to receive(:mock_emis).and_return(true)
      allow(Settings.vet_verification).to receive(:mock_emis_host).and_return('https://vaausvrsapp81.aac.va.gov')
    end

    context 'with a valid user' do
      it 'returns confirmed if the veteran status is confirmed' do
        VCR.use_cassette('mpi/find_candidate/valid') do
          VCR.use_cassette('emis/get_veteran_status/valid_icn') do
            post '/services/veteran_confirmation/v0/status', params: valid_attributes

            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)['veteran_status']).to eq('confirmed')
          end
        end
      end

      it 'can confirm without optional attributes' do
        VCR.use_cassette('mpi/find_candidate/valid') do
          VCR.use_cassette('emis/get_veteran_status/valid_icn') do
            post '/services/veteran_confirmation/v0/status', params: required_valid_attributes

            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)['veteran_status']).to eq('confirmed')
          end
        end
      end

      it 'returns not confirmed if the user is not a veteran' do
        VCR.use_cassette('mpi/find_candidate/valid') do
          VCR.use_cassette('emis/get_veteran_status/valid_non_veteran_icn') do
            post '/services/veteran_confirmation/v0/status', params: valid_attributes

            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)['veteran_status']).to eq('not confirmed')
          end
        end
      end
    end

    context 'with invalid attributes' do
      it 'throws an error when params are in the query path' do
        post '/services/veteran_confirmation/v0/status?first_name=Tamara'

        expect(response).to have_http_status(:bad_request)
        error_detail = JSON.parse(response.body)['errors'].first['detail']
        expect(error_detail).to eq('No query params are allowed for this route')
      end

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

      it 'throws an error when gender is an invalid string' do
        invalid_gender_attributes = {
          ssn: '123456789',
          first_name: 'Mitchell',
          last_name: 'Jenkins',
          birth_date: '1967-04-13',
          gender: 'randomstringhere'
        }

        post '/services/veteran_confirmation/v0/status', params: invalid_gender_attributes

        expect(response).to have_http_status(:bad_request)
        error_detail = JSON.parse(response.body)['errors'].first['detail']
        expect(error_detail).to eq('"randomstringhere" is not a valid value for "gender"')
      end

      it 'throws an error when gender is a number' do
        invalid_gender_attributes = {
          ssn: '123456789',
          first_name: 'Mitchell',
          last_name: 'Jenkins',
          birth_date: '1967-04-13',
          gender: 3
        }

        post '/services/veteran_confirmation/v0/status', params: invalid_gender_attributes

        expect(response).to have_http_status(:bad_request)
        error_detail = JSON.parse(response.body)['errors'].first['detail']
        expect(error_detail).to eq('"3" is not a valid value for "gender"')
      end
    end
  end

  context 'betamocks emis' do
    before do
      allow(Settings.vet_verification).to receive(:mock_emis).and_return(false)
    end

    context 'with a valid user' do
      it 'returns confirmed if the veteran status is confirmed' do
        VCR.use_cassette('mpi/find_candidate/valid') do
          VCR.use_cassette('emis/get_veteran_status/valid_icn') do
            post '/services/veteran_confirmation/v0/status', params: valid_attributes

            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)['veteran_status']).to eq('confirmed')
          end
        end
      end

      it 'can confirm without optional attributes' do
        VCR.use_cassette('mpi/find_candidate/valid') do
          VCR.use_cassette('emis/get_veteran_status/valid_icn') do
            post '/services/veteran_confirmation/v0/status', params: required_valid_attributes

            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)['veteran_status']).to eq('confirmed')
          end
        end
      end

      it 'returns not confirmed if the user is not a veteran' do
        VCR.use_cassette('mpi/find_candidate/valid') do
          VCR.use_cassette('emis/get_veteran_status/valid_non_veteran_icn') do
            post '/services/veteran_confirmation/v0/status', params: valid_attributes

            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)['veteran_status']).to eq('not confirmed')
          end
        end
      end
    end

    context 'with invalid attributes' do
      it 'throws an error when params are in the query path' do
        post '/services/veteran_confirmation/v0/status?first_name=Tamara'

        expect(response).to have_http_status(:bad_request)
        error_detail = JSON.parse(response.body)['errors'].first['detail']
        expect(error_detail).to eq('No query params are allowed for this route')
      end

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

      it 'throws an error when gender is an invalid string' do
        invalid_gender_attributes = {
          ssn: '123456789',
          first_name: 'Mitchell',
          last_name: 'Jenkins',
          birth_date: '1967-04-13',
          gender: 'randomstringhere'
        }

        post '/services/veteran_confirmation/v0/status', params: invalid_gender_attributes

        expect(response).to have_http_status(:bad_request)
        error_detail = JSON.parse(response.body)['errors'].first['detail']
        expect(error_detail).to eq('"randomstringhere" is not a valid value for "gender"')
      end

      it 'throws an error when gender is a number' do
        invalid_gender_attributes = {
          ssn: '123456789',
          first_name: 'Mitchell',
          last_name: 'Jenkins',
          birth_date: '1967-04-13',
          gender: 3
        }

        post '/services/veteran_confirmation/v0/status', params: invalid_gender_attributes

        expect(response).to have_http_status(:bad_request)
        error_detail = JSON.parse(response.body)['errors'].first['detail']
        expect(error_detail).to eq('"3" is not a valid value for "gender"')
      end
    end
  end
end
