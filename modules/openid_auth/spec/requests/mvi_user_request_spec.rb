# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Return ICN for a User from MVI', type: :request, skip_emis: true do
  describe 'via GET with headers' do
    context 'looking up with an SSN' do
      let(:auth_headers) do
        {
          'apiKey' => 'saml-key',
          'x-va-idp-uuid' => 'ae9ff5f4e4b741389904087d94cd19b2',
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

      it 'returns the icn data for a user' do
        VCR.use_cassette('mvi/find_candidate/valid_icn_full') do
          get '/internal/auth/v0/mvi-user', params: nil, headers: auth_headers
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes'].keys).to eq(%w[icn first_name last_name])
          expect(JSON.parse(response.body)['data']['attributes']['icn']).to eq('1008714701V416111')
        end
      end

      it 'returns an error if icn is missing' do
        VCR.use_cassette('mvi/find_candidate/no_subject') do
          auth_headers['x-va-level-of-assurance'] = 1
          get '/internal/auth/v0/mvi-user', params: nil, headers: auth_headers
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'looking up with an icn' do
      let(:auth_headers) do
        {
          'apiKey' => 'saml-key',
          'x-va-idp-uuid' => 'ae9ff5f4e4b741389904087d94cd19b2',
          'x-va-level-of-assurance' => 3,
          'x-va-user-email' => 'test@123.com',
          'x-va-mhv-icn' => '1008714701V416111'
        }
      end

      it 'returns the first and last names for a user' do
        VCR.use_cassette('mvi/find_candidate/valid_icn_full') do
          get '/internal/auth/v0/mvi-user', params: nil, headers: auth_headers
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes'].keys).to eq(%w[icn first_name last_name])
          expect(JSON.parse(response.body)['data']['attributes']['first_name']).to eq('Mitchell')
        end
      end
    end

    context 'looking up with an edipi' do
      let(:auth_headers) do
        {
          'apiKey' => 'saml-key',
          'x-va-idp-uuid' => 'ae9ff5f4e4b741389904087d94cd19b2',
          'x-va-dslogon-edipi' => '7961223060',
          'x-va-ssn' => '796122306',
          'x-va-level-of-assurance' => 3,
          'x-va-user-email' => 'test@123.com',
          'x-va-dob' => '1949-03-04',
          'x-va-gender' => 'male',
          'x-va-first-name' => 'Edward',
          'x-va-middle-name' => 'John',
          'x-va-last-name' => 'Paget'
        }
      end

      it 'returns the icn data for a user' do
        VCR.use_cassette('mvi/find_candidate/valid_icn_full') do
          get '/internal/auth/v0/mvi-user', params: nil, headers: auth_headers
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes'].keys).to eq(%w[icn first_name last_name])
          expect(JSON.parse(response.body)['data']['attributes']['icn']).not_to eq(nil)
        end
      end

      it 'returns an error if icn is missing' do
        VCR.use_cassette('mvi/find_candidate/no_subject') do
          auth_headers['x-va-level-of-assurance'] = 1
          get '/internal/auth/v0/mvi-user', params: nil, headers: auth_headers
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'raising errors when missing parameters' do
      it 'requires level of assurance' do
        auth_headers = {
          'x-va-ssn' => '123456789',
          'x-va-idp-uuid' => 'ae9ff5f4e4b741389904087d94cd19b2'
        }
        get '/internal/auth/v0/mvi-user', params: nil, headers: auth_headers
        data = JSON.parse(response.body)
        expect(data['errors'].first['title']).to eq('Missing parameter')
        expect(data['errors'].first['detail']).to include('x-va-level-of-assurance')
      end
    end

    context 'MVI communication issues' do
      let(:auth_headers) do
        {
          'apiKey' => 'saml-key',
          'x-va-idp-uuid' => 'ae9ff5f4e4b741389904087d94cd19b2',
          'x-va-ssn' => '796122306',
          'x-va-edipi' => '796122306',
          'x-va-level-of-assurance' => 3,
          'x-va-user-email' => 'test@123.com',
          'x-va-dob' => '1949-03-04',
          'x-va-first-name' => 'Edward',
          'x-va-middle-name' => 'John',
          'x-va-last-name' => 'Paget'
        }
      end

      let(:body) { File.read('spec/support/mvi/find_candidate_ar_code_database_error_response.xml') }

      it 'responds properly when MVI is down' do
        stub_request(:post, Settings.mvi.url).to_return(status: 200, body: body)
        get '/internal/auth/v0/mvi-user', params: nil, headers: auth_headers
        expect(response).to have_http_status(:bad_gateway)
      end
    end
  end

  describe 'via POST with user info in request body' do
    let(:headers) do
      {
        'content-type' => 'application/json',
        'apiKey' => 'saml-key'
      }
    end

    context 'looking up with an SSN' do
      let(:req_body) do
        {
          'idp_uuid' => 'ae9ff5f4e4b741389904087d94cd19b2',
          'ssn' => '796122306',
          'dob' => '1949-03-04',
          'first_name' => 'Edward',
          'middle_name' => 'John',
          'last_name' => 'Paget',
          'gender' => 'male',
          'level_of_assurance' => 3,
          'user_email' => 'test@123.com'
        }
      end

      it 'returns the icn data for a user' do
        VCR.use_cassette('mvi/find_candidate/valid_icn_full') do
          post '/internal/auth/v0/mvi-user', params: JSON.generate(req_body), headers: headers
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes'].keys).to eq(%w[icn first_name last_name])
          expect(JSON.parse(response.body)['data']['attributes']['icn']).to eq('1008714701V416111')
        end
      end

      it 'returns an error if icn is missing' do
        VCR.use_cassette('mvi/find_candidate/no_subject') do
          req_body['level_of_assurance'] = 1
          post '/internal/auth/v0/mvi-user', params: JSON.generate(req_body), headers: headers
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'looking up with an icn' do
      let(:req_body) do
        {
          'idp_uuid' => 'ae9ff5f4e4b741389904087d94cd19b2',
          'level_of_assurance' => 3,
          'user_email' => 'test@123.com',
          'mhv_icn' => '1008714701V416111'
        }
      end

      it 'returns the first and last names for a user' do
        VCR.use_cassette('mvi/find_candidate/valid_icn_full') do
          post '/internal/auth/v0/mvi-user', params: JSON.generate(req_body), headers: headers
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes'].keys).to eq(%w[icn first_name last_name])
          expect(JSON.parse(response.body)['data']['attributes']['first_name']).to eq('Mitchell')
        end
      end
    end

    context 'looking up with an edipi' do
      let(:req_body) do
        {
          'idp_uuid' => 'ae9ff5f4e4b741389904087d94cd19b2',
          'dslogon_edipi' => '7961223060',
          'ssn' => '796122306',
          'level_of_assurance' => 3,
          'user_email' => 'test@123.com',
          'dob' => '1949-03-04',
          'gender' => 'male',
          'first_name' => 'Edward',
          'middle_name' => 'John',
          'last_name' => 'Paget'
        }
      end

      it 'returns the icn data for a user' do
        VCR.use_cassette('mvi/find_candidate/valid_icn_full') do
          post '/internal/auth/v0/mvi-user', params: JSON.generate(req_body), headers: headers
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes'].keys).to eq(%w[icn first_name last_name])
          expect(JSON.parse(response.body)['data']['attributes']['icn']).not_to eq(nil)
        end
      end

      it 'returns an error if icn is missing' do
        VCR.use_cassette('mvi/find_candidate/no_subject') do
          req_body['level_of_assurance'] = 1
          post '/internal/auth/v0/mvi-user', params: JSON.generate(req_body), headers: headers
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'raising errors when missing parameters' do
      it 'requires level of assurance' do
        req_body = {
          'ssn' => '123456789',
          'idp_uuid' => 'ae9ff5f4e4b741389904087d94cd19b2'
        }
        post '/internal/auth/v0/mvi-user', params: JSON.generate(req_body), headers: headers
        data = JSON.parse(response.body)
        expect(data['errors'].first['title']).to eq('Missing parameter')
        expect(data['errors'].first['detail']).to include('level_of_assurance')
      end
    end

    context 'MVI communication issues' do
      let(:req_body) do
        {
          'idp_uuid' => 'ae9ff5f4e4b741389904087d94cd19b2',
          'ssn' => '796122306',
          'edipi' => '796122306',
          'level_of_assurance' => 3,
          'user_email' => 'test@123.com',
          'dob' => '1949-03-04',
          'first_name' => 'Edward',
          'middle_name' => 'John',
          'last_name' => 'Paget'
        }
      end

      let(:body) { File.read('spec/support/mvi/find_candidate_ar_code_database_error_response.xml') }

      it 'responds properly when MVI is down' do
        stub_request(:post, Settings.mvi.url).to_return(status: 200, body: body)
        post '/internal/auth/v0/mvi-user', params: JSON.generate(req_body), headers: headers
        expect(response).to have_http_status(:bad_gateway)
      end
    end
  end
end
