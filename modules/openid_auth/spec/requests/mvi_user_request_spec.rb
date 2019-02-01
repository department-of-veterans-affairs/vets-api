# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Return ICN for a User from MVI', type: :request, skip_emis: true do
  include SchemaMatchers

  let(:user_hash) do
    {
      first_name: 'Mitchell',
      last_name: 'Jenkins',
      middle_name: 'G',
      birth_date: '1949-03-04',
      ssn: '796122306'
    }
  end

  let(:user) { build(:user, :loa3, user_hash) }

  context 'looking up with an SSN' do
    let(:auth_headers) do
      {
        'apiKey' => 'saml-key',
        'x-va-ssn' => '796122306',
        'x-va-dob' => '1949-03-04',
        'x-va-first-name' => 'Edward',
        'x-va-middle-name' => 'John',
        'x-va-last-name' => 'Paget',
        'x-va-gender' => 'male',
        'x-va-level-of-assurance' => 3,
        'x-va-user-email' => 'test@123.com'
      }
    end
    it 'should return the icn data for a user' do
      VCR.use_cassette('mvi/find_candidate/valid_icn_full') do
        get '/internal/auth/v0/mvi-user', nil, auth_headers
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['data']['attributes'].keys).to eq(['icn'])
        expect(JSON.parse(response.body)['data']['attributes'].values).to eq(['1008714701V416111'])
      end
    end

    it 'should return an error if icn is missing' do
      VCR.use_cassette('mvi/find_candidate/no_subject') do
        auth_headers['x-va-level-of-assurance'] = 1
        get '/internal/auth/v0/mvi-user', nil, auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  context 'looking up with an edipi' do
    let(:auth_headers) do
      {
        'apiKey' => 'saml-key',
        'x-va-edipi' => '796122306',
        'x-va-level-of-assurance' => 3,
        'x-va-user-email' => 'test@123.com',
        'x-va-dob' => '1949-03-04',
        'x-va-first-name' => 'Edward',
        'x-va-middle-name' => 'John',
        'x-va-last-name' => 'Paget'
      }
    end

    it 'should return the icn data for a user' do
      VCR.use_cassette('mvi/find_candidate/valid_icn_full') do
        get '/internal/auth/v0/mvi-user', nil, auth_headers
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['data']['attributes'].keys).to eq(['icn'])
        expect(JSON.parse(response.body)['data']['attributes'].values).to_not eq([nil])
      end
    end

    it 'should return an error if icn is missing' do
      VCR.use_cassette('mvi/find_candidate/no_subject') do
        auth_headers['x-va-level-of-assurance'] = 1
        get '/internal/auth/v0/mvi-user', nil, auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  context 'raising errors when missing parameters' do
    it 'should require either ssn or edipi' do
      get '/internal/auth/v0/mvi-user'
      data = JSON.parse(response.body)
      expect(data['errors'].first['title']).to eq('Missing parameter')
    end

    it 'should require level of assurance' do
      get '/internal/auth/v0/mvi-user', nil, 'x-va-ssn' => '123456789'
      data = JSON.parse(response.body)
      expect(data['errors'].first['title']).to eq('Missing parameter')
      expect(data['errors'].first['detail']).to include('x-va-level-of-assurance')
    end

    it 'should require user email' do
      headers = { 'x-va-ssn' => '123456789', 'x-va-level-of-assurance' => '3' }
      get '/internal/auth/v0/mvi-user', nil, headers
      data = JSON.parse(response.body)
      expect(data['errors'].first['title']).to eq('Missing parameter')
      expect(data['errors'].first['detail']).to include('x-va-user-email')
    end
  end

  context 'MVI communication issues' do
    let(:auth_headers) do
      {
        'apiKey' => 'saml-key',
        'x-va-edipi' => '796122306',
        'x-va-level-of-assurance' => 3,
        'x-va-user-email' => 'test@123.com',
        'x-va-dob' => '1949-03-04',
        'x-va-first-name' => 'Edward',
        'x-va-middle-name' => 'John',
        'x-va-last-name' => 'Paget'
      }
    end
    it 'should respond properly when MVI is down' do
      VCR.use_cassette('mvi/find_candidate/failure') do
        get '/internal/auth/v0/mvi-user', nil, auth_headers
        expect(response).to have_http_status(:bad_gateway)
      end
    end
  end
end
