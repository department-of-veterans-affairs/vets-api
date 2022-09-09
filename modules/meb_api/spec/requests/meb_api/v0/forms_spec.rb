# frozen_string_literal: true

require 'rails_helper'

Rspec.describe MebApi::V0::FormsController, type: :request do
  include SchemaMatchers
  include ActiveSupport::Testing::TimeHelpers

  VCR.configure do |config|
    config.filter_sensitive_data('removed') do |interaction|
      if interaction.request.headers['Authorization']
        token = interaction.request.headers['Authorization'].first

        if (match = token.match(/^Bearer.+/) || token.match(/^token.+/))
          match[0]
        end
      end
    end

    let(:user_details) do
      {
        first_name: 'Herbert',
        last_name: 'Hoover',
        middle_name: '',
        birth_date: '1970-01-01',
        ssn: '796121200'
      }
    end

    let(:claimant_id) { 1 }
    let(:user) { build(:user, :loa3, user_details) }
    let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
    let(:faraday_response) { double('faraday_connection') }

    before do
      allow(faraday_response).to receive(:env)
      sign_in_as(user)
    end

    describe 'POST form_sponsors' do
      context 'Retrieves sponsors for Toes' do
        it 'returns a 200 status when it' do
          VCR.use_cassette('dgi/forms/sponsor_toes') do
            post '/meb_api/v0/forms_sponsors', params: { "ssn": '796121200', "form_type": 'Toes' }
            expect(response).to have_http_status(:ok)
          end
        end
      end

      context 'Retrieves sponsors for FryDea' do
        it 'returns a 200 status when it' do
          VCR.use_cassette('dgi/forms/sponsor_fry_dea') do
            post '/meb_api/v0/forms_sponsors', params: { "ssn": '796121200', "form_type": 'FryDea' }
            expect(response).to have_http_status(:ok)
          end
        end
      end
    end

    describe 'GET /meb_api/v0/toe/claimant_info' do
      context 'Looks up veteran in LTS ' do
        it 'returns a 200 with toe claimant info' do
          VCR.use_cassette('dgi/post_toe_claimant_info') do
            get '/meb_api/v0/toe/claimant_info'
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('dgi/toe_claimant_info_response', { strict: false })
          end
        end
      end
    end

    # describe 'GET /meb_api/v0/forms_claim_letter' do
    #   context 'Retrieves a fry veterans claim letter' do
    #     it 'returns a 200 status when given claimant id as parameter' do
    #       VCR.use_cassette('dgi/forms/get_fry_claim_letter') do
    #         post '/meb_api/v0/forms_claim_letter', params: { "ssn": '796121200', "form_type": 'fry' }
    #         expect(response).to have_http_status(:ok)
    #       end
    #     end
    #   end

    #   context 'Retrieves a TOE veterans claim letter' do
    #     it 'returns a 200 status when given claimant id as parameter' do
    #       VCR.use_cassette('dgi/forms/get_toe_claim_letter') do
    #         post '/meb_api/v0/forms_claim_letter', params: { "ssn": '796121200' }
    #         expect(response).to have_http_status(:ok)
    #       end
    #     end
    #   end
    # end
  end
end
