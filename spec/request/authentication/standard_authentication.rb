# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'sessions', type: :request do
  let(:saml_login_response) do
    File.read('spec/fixtures/saml_responses/standard_login_pre_2FA.txt').strip
  end

  let(:saml_logout_response) do
    File.read('spec/fixtures/saml_responses/standard_logout.txt').strip
  end

  let(:session_token) { 'r9d1xgyBjsTv6QeY7258DGaMqZbGqkEncVeybmsC' }
  let(:time_of_saml_response) { '2017-08-21T06:59:13Z' }

  context 'new' do
    it 'fetches the authentication endpoint' do
      saml_settings_cassette do
        get '/v0/sessions/new'
      end

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)['authenticate_via_get'])
        .to include('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
    end
  end

  context 'saml_callback' do
    before(:each) do
      Timecop.freeze(time_of_saml_response)
      allow_any_instance_of(Session).to receive(:token).and_return(session_token)
    end

    it 'persists a user session and fethes the saml_callback' do
      expect_any_instance_of(SAML::AuthFailHandler).not_to receive(:error)

      saml_settings_cassette do
        post '/auth/saml/callback', SAMLResponse: saml_login_response
      end

      expect(response).to redirect_to("http://localhost:3001/auth/login/callback?token=#{session_token}")
    end

    context 'with errors' do
      before(:each) { Timecop.freeze('2017-08-21T07:59:13Z') }

      it 'persists a user session and fethes the saml_callback' do
        expect_any_instance_of(SAML::AuthFailHandler).to receive(:error).and_call_original

        saml_settings_cassette do
          post '/auth/saml/callback', SAMLResponse: saml_login_response
        end

        expect(response).to redirect_to('http://localhost:3001/auth/login/callback?auth=fail')
      end
    end
  end

  context 'destroy' do
    let(:session) { use_authenticated_saml_user(saml_login_response) }

    it 'fetches the authentication destroy endpoint' do
      delete "/v0/sessions/", nil, {'Authorization' => "Token token=#{session.token}"}

      expect(response.status).to eq(202)
      expect(JSON.parse(response.body)['logout_via_get'])
        .to include('https://api.idmelabs.com/saml/SingleLogoutService?SAMLRequest=')
    end
  end

  context 'saml_logout_callback' do
    before(:each) do
      Timecop.freeze(time_of_saml_response)
      allow_any_instance_of(Session).to receive(:token).and_return(session_token)
      session = use_authenticated_saml_user(saml_login_response)
      binding.pry
      logout_request = OneLogin::RubySaml::Logoutrequest.new
      SingleLogoutRequest.create(uuid: logout_request.uuid, token: session.token)
    end

    it 'persists a user session and fethes the saml_callback' do
      expect_any_instance_of(SAML::AuthFailHandler).not_to receive(:error)

      saml_settings_cassette do
        get '/auth/saml/logout', SAMLResponse: saml_logout_response
      end

      binding.pry
      expect(response).to redirect_to("http://localhost:3001/auth/login/callback?token=#{session_token}")
    end

    context 'with errors' do
      before(:each) { Timecop.freeze('2017-08-21T07:59:13Z') }

      it 'persists a user session and fethes the saml_callback' do
        expect_any_instance_of(SAML::AuthFailHandler).to receive(:error).and_call_original

        saml_settings_cassette do
          get '/auth/saml/logout', SAMLResponse: saml_logout_response
        end

        expect(response).to redirect_to('http://localhost:3001/auth/login/callback?auth=fail')
      end
    end
  end
end
