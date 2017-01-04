# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::SessionsController, type: :controller do
  let(:uuid) { '1234abcd' }
  let(:token) { 'abracadabra-open-sesame' }
  let(:auth_header) { ActionController::HttpAuthentication::Token.encode_credentials(token) }
  let(:loa1_user) { build(:loa1_user, uuid: uuid) }
  let(:loa3_user) { build(:loa3_user, uuid: uuid) }

  let(:settings_no_context) { build(:settings_no_context) }
  let(:rubysaml_settings) { build(:rubysaml_settings) }

  let(:valid_saml_response) { double('saml_response', is_valid?: true) }
  let(:invalid_saml_response) { double('saml_response', is_valid?: false, errors: ['ruh roh']) }

  before do
    allow(SAML::SettingsService).to receive(:saml_settings).and_return(rubysaml_settings)
    allow(OneLogin::RubySaml::Response).to receive(:new).and_return(valid_saml_response)
  end

  context 'when logged in' do
    before do
      allow(User).to receive(:from_saml).and_return(loa3_user)
      Session.create(uuid: uuid, token: token)
      User.create(loa1_user.attributes)
    end
    it 'destroys a session' do
      request.env['HTTP_AUTHORIZATION'] = auth_header
      delete :destroy
      expect(response).to have_http_status(202)
    end
    describe ' POST saml_callback' do
      it 'uplevels an LOA 1 session to LOA 3' do
        expect(User.find(uuid).loa).to eq(highest: LOA::ONE, current: LOA::ONE)
        post :saml_callback
        expect(User.find(uuid).loa).to eq(highest: LOA::THREE, current: LOA::THREE)
      end
      it 'redirects to an auth failure page if saml_response is invalid' do
        allow(OneLogin::RubySaml::Response).to receive(:new).and_return(invalid_saml_response)

        expect(Rails.logger).to receive(:error).exactly(1).times
        expect(post(:saml_callback)).to redirect_to(SAML_CONFIG['relay'] + '?auth=fail')
        expect(response).to have_http_status(:found)
      end
      it 'creates a valid session and user' do
        post :saml_callback
        expect(User.find(uuid)).to_not be_nil
        expect(User.find(uuid).attributes).to eq(User.from_merged_attrs(loa1_user, loa3_user).attributes)
      end
    end
  end

  context 'when not logged in' do
    describe ' GET new' do
      it 'creates the saml authn request with LOA 1 if supplied level=1' do
        get :new, level: 1
        expect(SAML::AuthnRequestHelper.new(response).loa1?).to eq(true)
      end
      it 'creates the saml authn request with LOA 3 if supplied level=3' do
        get :new, level: 3
        expect(SAML::AuthnRequestHelper.new(response).loa3?).to eq(true)
      end
      it 'creates the saml authn request with LOA 1 if supplied level=nil' do
        get :new, level: 3
        expect(SAML::AuthnRequestHelper.new(response).loa3?).to eq(true)
      end
      it 'creates the saml authn request with LOA 1 if supplied level is invalid' do
        get :new, level: 'bad_level!!'
        expect(SAML::AuthnRequestHelper.new(response).loa1?).to eq(true)
      end
      it 'shows the ID.me authentication url' do
        get :new
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('authenticate_via_get')
        expect(json_response['authenticate_via_get']).to start_with(rubysaml_settings.idp_sso_target_url)
      end
    end
    describe ' DELETE destroy' do
      it 'returns unauthorized' do
        delete :destroy
        expect(response).to have_http_status(:unauthorized)
      end
    end
    describe ' POST saml_callback' do
      it 'does not create a job to create an evss user when user has loa1' do
        allow(User).to receive(:from_saml).and_return(loa1_user)
        expect { post :saml_callback }.to_not change(EVSS::CreateUserAccountJob.jobs, :size)
      end
      it 'creates a job to create an evss user when user has loa3 and evss attrs' do
        allow(User).to receive(:from_saml).and_return(loa3_user)
        expect { post :saml_callback }.to change(EVSS::CreateUserAccountJob.jobs, :size).by(1)
      end
    end
  end
end
