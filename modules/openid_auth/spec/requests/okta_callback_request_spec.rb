# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Return Okta commands for a User from MVI', type: :request, skip_emis: true do
  describe 'via POST with user info in request body' do
    let(:headers) do
      {
        'content-type' => 'application/json',
        'apiKey' => 'saml-key'
      }
    end

    context 'callback from IDme login' do
      let(:req_body) do
        JSON.parse(File.read(Rails.root.join('spec', 'fixtures', 'okta', 'okta_callback_request_idme_1567760195.json.json')))
      end

      it 'should return Okta commands for a user' do
        VCR.use_cassette('mvi/find_candidate/valid_icn_full') do
          post '/internal/auth/v0/okta', params: JSON.generate(req_body), headers: headers
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['commands'].length).not_to eq(0)
          # TODO: validate commands shape and data within commands
        end
      end

      it 'should return an error if MVI profile not found' do
        VCR.use_cassette('mvi/find_candidate/no_subject') do
          req_body['level_of_assurance'] = 1
          post '/internal/auth/v0/okta', params: JSON.generate(req_body), headers: headers
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
