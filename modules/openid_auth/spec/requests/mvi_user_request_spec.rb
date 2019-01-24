# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Return ICN for a User from MVI', type: :request, skip_emis: true do
  include SchemaMatchers

  context 'looking up with an SSN' do
    let(:auth_headers) do
      {
        'apiKey' => 'saml-key',
        'x-va-ssn' => '333-99-9999',
        'x-va-first-name' => 'Edward',
        'x-va-middle-name' => 'John',
        'x-va-last-name' => 'Paget',
        'x-va-dob' => '1/23/1990',
        'x-va-gender' => 'male',
        'x-va-current-level-of-assurance' => 3,
        'x-va-highest-level-of-assurance' => 3,
        'x-va-user-email' => 'test@123.com'
      }
    end
    it 'should return the icn data for a user' do
      get '/internal/auth/v0/mvi-user', nil, auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to be_a(String)
      expect(JSON.parse(response.body)['data']['attributes'].keys).to eq(['icn'])
      expect(JSON.parse(response.body)['data']['attributes'].values).to_not eq([nil])
    end

    it 'should return an error if icn is missing' do
      auth_headers['x-va-current-level-of-assurance'] = 1
      get '/internal/auth/v0/mvi-user', nil, auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to be_a(String)
      expect(JSON.parse(response.body)['data']['errors'].keys).to eq(['icn'])
      expect(JSON.parse(response.body)['data']['errors'].values).to eq(['could not locate ICN'])
    end
  end

  context 'looking up with an edipi' do
    let(:auth_headers) do
      {
        'apiKey' => 'saml-key',
        'x-va-edipi' => '123456789',
        'x-va-current-level-of-assurance' => 3,
        'x-va-highest-level-of-assurance' => 3,
        'x-va-user-email' => 'test@123.com'
      }
    end

    it 'should return the icn data for a user' do
      get '/internal/auth/v0/mvi-user', nil, auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to be_a(String)
      expect(JSON.parse(response.body)['data']['attributes'].keys).to eq(['icn'])
      expect(JSON.parse(response.body)['data']['attributes'].values).to_not eq([nil])
    end

    it 'should return an error if icn is missing' do
      auth_headers['x-va-current-level-of-assurance'] = 1
      get '/internal/auth/v0/mvi-user', nil, auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to be_a(String)
      expect(JSON.parse(response.body)['data']['errors'].keys).to eq(['icn'])
      expect(JSON.parse(response.body)['data']['errors'].values).to eq(['could not locate ICN'])
    end
  end
end
