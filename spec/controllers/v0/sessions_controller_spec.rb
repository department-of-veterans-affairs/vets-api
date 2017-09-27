# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::SessionsController, type: :controller do
  let(:uuid) { '1234abcd' }
  let(:token) { 'abracadabra-open-sesame' }
  let(:auth_header) { ActionController::HttpAuthentication::Token.encode_credentials(token) }
  let(:loa1_user) { build(:loa1_user, uuid: uuid) }
  let(:loa3_user) { build(:loa3_user, uuid: uuid) }
  let(:invalid_user) { build(:loa3_user, uuid: '') }

  let(:settings_no_context) { build(:settings_no_context) }
  let(:rubysaml_settings) { build(:rubysaml_settings) }

  let(:response_xml_stub) { REXML::Document.new(File.read('spec/support/saml/saml_response_dslogon.xml')) }
  let(:valid_saml_response) do
    double('saml_response', is_valid?: true, errors: [],
                            in_response_to: uuid,
                            decrypted_document: response_xml_stub)
  end
  let(:invalid_saml_response) do
    double('saml_response', is_valid?: false,
                            in_response_to: uuid,
                            decrypted_document: response_xml_stub)
  end
  let(:saml_response_click_deny) do
    double('saml_response', is_valid?: false,
                            in_response_to: uuid,
                            errors: ['ruh roh'],
                            status_message: 'Subject did not consent to attribute release',
                            decrypted_document: response_xml_stub)
  end
  let(:saml_response_too_late) do
    double('saml_response', is_valid?: false, status_message: '', in_response_to: uuid,
                            errors: ['Current time is on or after NotOnOrAfter ' \
                              'condition (2017-02-10 17:03:40 UTC >= 2017-02-10 17:03:30 UTC)'],
                            decrypted_document: response_xml_stub)
  end
  # "Current time is earlier than NotBefore condition #{(now + allowed_clock_drift)} < #{not_before})"
  let(:saml_response_too_early) do
    double('saml_response', is_valid?: false, status_message: '', in_response_to: uuid,
                            errors: ['Current time is earlier than NotBefore ' \
                              'condition (2017-02-10 17:03:30 UTC) < 2017-02-10 17:03:40 UTC)'],
                            decrypted_document: response_xml_stub)
  end

  let(:logout_uuid) { '1234' }
  let(:invalid_logout_response) do
    double('logout_response', validate: false, in_response_to: logout_uuid, errors: ['bad thing'])
  end
  let(:succesful_logout_response) do
    double('logout_response', validate: true, success?: true, in_response_to: logout_uuid, errors: [])
  end

  before do
    allow(SAML::SettingsService).to receive(:saml_settings).and_return(rubysaml_settings)
    allow(OneLogin::RubySaml::Response).to receive(:new).and_return(valid_saml_response)
    Redis.current.set("benchmark_api.auth.login_#{uuid}", Time.now.to_f)
    Redis.current.set("benchmark_api.auth.logout_#{uuid}", Time.now.to_f)
  end

  context 'when logged in' do
    before do
      allow_any_instance_of(described_class).to receive(:new_user_from_saml).and_return(loa3_user)
      Session.create(uuid: uuid, token: token)
      User.create(loa1_user.attributes)
    end

    it 'returns a url for leveling up or verifying current level' do
      request.env['HTTP_AUTHORIZATION'] = auth_header
      get :identity_proof
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body).keys).to eq %w(identity_proof_url)
    end

    it 'returns a url for adding multifactor authentication to your account' do
      request.env['HTTP_AUTHORIZATION'] = auth_header
      get :multifactor
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body).keys).to eq %w(multifactor_url)
    end

    it 'returns a logout url' do
      request.env['HTTP_AUTHORIZATION'] = auth_header
      delete :destroy
      expect(response).to have_http_status(202)
    end
    it 'responds with error when logout request is not found' do
      expect(Rails.logger).to receive(:error).exactly(1).times
      expect(post(:saml_logout_callback, SAMLResponse: '-'))
        .to redirect_to(Settings.saml.logout_relay + '?success=false')
    end
    context ' logout has been requested' do
      before { SingleLogoutRequest.create(uuid: logout_uuid, token: token) }
      context ' logout_response is invalid' do
        before do
          allow(OneLogin::RubySaml::Logoutresponse).to receive(:new).and_return(invalid_logout_response)
        end
        it 'redirects to error' do
          expect(Rails.logger).to receive(:error).with(/bad thing/).exactly(1).times
          expect(post(:saml_logout_callback, SAMLResponse: '-'))
            .to redirect_to(Settings.saml.logout_relay + '?success=false')
        end
      end
      context ' logout_response is success' do
        before do
          mhv_account = double('mhv_account', ineligible?: false, needs_terms_acceptance?: false, upgraded?: true)
          allow(MhvAccount).to receive(:find_or_initialize_by).and_return(mhv_account)
          allow(OneLogin::RubySaml::Logoutresponse).to receive(:new).and_return(succesful_logout_response)
        end
        it 'redirects to success and destroy the session' do
          expect(Session.find(token)).to_not be_nil
          expect(User.find(uuid)).to_not be_nil
          expect(post(:saml_logout_callback, SAMLResponse: '-'))
            .to redirect_to(redirect_to(Settings.saml.logout_relay + '?success=true'))
          expect(Session.find(token)).to be_nil
          expect(User.find(uuid)).to be_nil
        end
      end
    end
    describe ' POST saml_callback' do
      let(:saml_user) { instance_double('SAML::User', changing_multifactor?: false) }
      before(:each) do
        allow_any_instance_of(described_class).to receive(:saml_user).and_return(saml_user)
      end

      it 'uplevels an LOA 1 session to LOA 3' do
        expect(User.find(uuid).loa).to eq(highest: LOA::ONE, current: LOA::ONE)
        post :saml_callback
        expect(User.find(uuid).loa).to eq(highest: LOA::THREE, current: LOA::THREE)
      end
      it 'creates a valid session and user' do
        post :saml_callback
        expect(User.find(uuid)).to_not be_nil
        expect(User.find(uuid).attributes).to eq(User.from_merged_attrs(loa1_user, loa3_user).attributes)
      end

      context ' when user clicked DENY' do
        before { allow(OneLogin::RubySaml::Response).to receive(:new).and_return(saml_response_click_deny) }
        it 'redirects to an auth failure page' do
          expect(Rails.logger).to receive(:warn).with(/#{SAML::AuthFailHandler::CLICKED_DENY_MSG}/)
          expect(post(:saml_callback)).to redirect_to(Settings.saml.relay + '?auth=fail')
          expect(response).to have_http_status(:found)
        end
      end
      context ' when too much time passed to consume the SAML Assertion' do
        before { allow(OneLogin::RubySaml::Response).to receive(:new).and_return(saml_response_too_late) }
        it 'redirects to an auth failure page' do
          expect(Rails.logger).to receive(:warn).with(/#{SAML::AuthFailHandler::TOO_LATE_MSG}/)
          expect(post(:saml_callback)).to redirect_to(Settings.saml.relay + '?auth=fail')
          expect(response).to have_http_status(:found)
        end
      end
      context ' when clock drift causes us to consume the Assertion before its creation' do
        before { allow(OneLogin::RubySaml::Response).to receive(:new).and_return(saml_response_too_early) }
        it 'redirects to an auth failure page' do
          expect(Rails.logger).to receive(:error).with(/#{SAML::AuthFailHandler::TOO_EARLY_MSG}/)
          expect(post(:saml_callback)).to redirect_to(Settings.saml.relay + '?auth=fail')
          expect(response).to have_http_status(:found)
        end
        it 'increments the failed and total statsd counters' do
          once = { times: 1, value: 1 }
          early_msg_tag = ['error:auth_too_early']
          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_LOGIN_FAILED_KEY, tags: early_msg_tag, **once)
            .and trigger_statsd_increment(described_class::STATSD_LOGIN_TOTAL_KEY, **once)
        end
      end
      context ' when a required saml attribute is missing' do
        before { allow_any_instance_of(described_class).to receive(:new_user_from_saml).and_return(invalid_user) }
        it 'logs a generic error' do
          expect(Rails.logger).to receive(:error).with(/user:    \'valid\?=false errors=\["Uuid can\'t be blank"\]/)
          expect(post(:saml_callback)).to redirect_to(Settings.saml.relay + '?auth=fail')
          expect(response).to have_http_status(:found)
        end
      end
    end
  end

  context 'when not logged in' do
    describe ' GET new' do
      it 'creates the saml authn request with LOA 1 if supplied level=1' do
        get :new, level: 1
        expect(SAML::AuthnRequestHelper.new(response).loa1?).to eq(true)
      end

      it 'returns the urls for for all three possible authN requests' do
        get :authn_urls
        expect(response).to have_http_status(200)
        expect(JSON.parse(response.body).keys).to eq %w(mhv dslogon idme)
      end

      it 'returns does not allow fetching the identity proof url' do
        get :identity_proof
        expect(response).to have_http_status(401)
      end

      it 'does not allow fetching the multifactor url' do
        get :multifactor
        expect(response).to have_http_status(401)
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
        allow_any_instance_of(described_class).to receive(:new_user_from_saml).and_return(loa1_user)
        expect { post :saml_callback }.to_not change(EVSS::CreateUserAccountJob.jobs, :size)
      end
      it 'creates a job to create an evss user when user has loa3 and evss attrs' do
        allow_any_instance_of(described_class).to receive(:new_user_from_saml).and_return(loa3_user)
        expect { post :saml_callback }.to change(EVSS::CreateUserAccountJob.jobs, :size).by(1)
      end
    end
  end
end
