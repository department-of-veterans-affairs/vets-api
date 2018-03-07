# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::SessionsController, type: :controller do
  let(:uuid) { '1234abcd' }
  let(:token) { 'abracadabra-open-sesame' }
  let(:auth_header) { ActionController::HttpAuthentication::Token.encode_credentials(token) }
  let(:loa1_user) { build(:user, :loa1, uuid: uuid) }
  let(:loa3_user) { build(:user, :loa3, uuid: uuid) }
  let(:saml_user_attributes) { loa3_user.attributes.merge(loa3_user.identity.attributes) }
  let(:user_attributes) { double('user_attributes', saml_user_attributes) }
  let(:saml_user) do
    instance_double('SAML::User',
                    changing_multifactor?: false,
                    user_attributes: user_attributes,
                    to_hash: saml_user_attributes)
  end

  let(:settings_no_context) { build(:settings_no_context) }
  let(:rubysaml_settings) { build(:rubysaml_settings) }

  let(:response_xml_stub) { REXML::Document.new(File.read('spec/support/saml/saml_response_dslogon.xml')) }
  let(:valid_saml_response) do
    double('saml_response', is_valid?: true, errors: [],
                            in_response_to: uuid,
                            status_message: '',
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

  let(:saml_response_unknown_error) do
    double('saml_response', is_valid?: false, status_message: '', in_response_to: uuid,
                            errors: ['The status code of the Response was not Success, ' \
                              'was Requester => NoAuthnContext -> AuthnRequest without ' \
                              'an authentication context.'],
                            decrypted_document: response_xml_stub)
  end

  let(:saml_response_multi_error) do
    double('saml_response', is_valid?: false, status_message: '', in_response_to: uuid,
                            errors: [
                              'Subject did not consent to attribute release',
                              'Other random error'
                            ],
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

  context 'when not logged in' do
    describe 'new' do
      context 'routes not requiring auth' do
        %w[mhv dslogon idme].each do |type|
          it "routes /sessions/#{type}/new to SessionsController#new with type: #{type}" do
            get(:new, type: type)
            expect(response).to be_redirect
          end
        end
      end

      context 'routes requiring auth' do
        %w[mfa verify slo].each do |type|
          it "routes /sessions/#{type}/new to SessionsController#new with type: #{type}" do
            get(:new, type: type)
            expect(response).not_to be_redirect
            expect(response).to have_http_status(:unauthorized)
          end
        end
      end
    end
  end

  context 'when logged in' do
    before do
      allow(SAML::User).to receive(:new).and_return(saml_user)
      Session.create(uuid: uuid, token: token)
      User.create(loa1_user.attributes)
      UserIdentity.create(loa1_user.identity.attributes)
    end

    describe 'new' do
      context 'routes not requiring auth' do
        %w[mhv dslogon idme mfa verify slo].each do |type|
          it "routes /sessions/#{type}/new to SessionsController#new with type: #{type}" do
            request.env['HTTP_AUTHORIZATION'] = auth_header
            get(:new, type: type)
            expect(response).to be_redirect
          end
        end
      end
    end

    it 'returns a url for leveling up or verifying current level' do
      request.env['HTTP_AUTHORIZATION'] = auth_header
      get :identity_proof
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body).keys).to eq %w[identity_proof_url]
    end

    it 'returns a url for adding multifactor authentication to your account' do
      request.env['HTTP_AUTHORIZATION'] = auth_header
      get :multifactor
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body).keys).to eq %w[multifactor_url]
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

    describe 'POST saml_callback' do
      before(:each) do
        allow(SAML::User).to receive(:new).and_return(saml_user)
      end

      it 'uplevels an LOA 1 session to LOA 3' do
        existing_user = User.find(uuid)
        expect(existing_user.last_signed_in).to be_a(Time)
        expect(existing_user.multifactor).to be_falsey
        expect(existing_user.loa).to eq(highest: LOA::ONE, current: LOA::ONE)
        expect(existing_user.ssn).to eq('796111863')
        allow(StringHelpers).to receive(:levenshtein_distance).and_return(8)
        expect(controller).to receive(:log_message_to_sentry).with(
          'SSNS DO NOT MATCH!!',
          :warn,
          identity_compared_with_mvi: {
            length: [9, 9],
            only_digits: [true, true],
            encoding: ['UTF-8', 'UTF-8'],
            levenshtein_distance: 8
          }
        )

        once = { times: 1, value: 1 }
        callback_tags = ['status:success', 'context:dslogon']
        expect { post(:saml_callback) }
          .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, tags: callback_tags, **once)
          .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)

        expect(response.location).to start_with(Settings.saml.relay + '?token=')

        new_user = User.find(uuid)
        expect(new_user.ssn).to eq('796111863')
        expect(new_user.va_profile.ssn).not_to eq('155256322')
        expect(new_user.loa).to eq(highest: LOA::THREE, current: LOA::THREE)
        expect(new_user.multifactor).to be_falsey
        expect(new_user.last_signed_in).not_to eq(existing_user.last_signed_in)
      end

      it 'does not log to sentry when SSN matches' do
        existing_user = User.find(uuid)
        allow_any_instance_of(User).to receive_message_chain('va_profile.ssn').and_return('796111863')
        expect(existing_user.ssn).to eq('796111863')
        expect_any_instance_of(SSOService).not_to receive(:log_message_to_sentry)
        post :saml_callback
        new_user = User.find(uuid)
        expect(new_user.ssn).to eq('796111863')
        expect(new_user.va_profile.ssn).to eq('796111863')
      end

      context 'changing multifactor' do
        let(:saml_user_attributes) do
          loa1_user.attributes.merge(loa1_user.identity.attributes).merge(multifactor: 'true')
        end

        it 'changes the multifactor to true, time is the same' do
          existing_user = User.find(uuid)
          expect(existing_user.last_signed_in).to be_a(Time)
          expect(existing_user.multifactor).to be_falsey
          expect(existing_user.loa).to eq(highest: LOA::ONE, current: LOA::ONE)
          allow(saml_user).to receive(:changing_multifactor?).and_return(true)
          post :saml_callback
          new_user = User.find(uuid)
          expect(new_user.loa).to eq(highest: LOA::ONE, current: LOA::ONE)
          expect(new_user.multifactor).to be_truthy
          expect(new_user.last_signed_in).to eq(existing_user.last_signed_in)
        end
      end

      context 'when user has LOA current 1 and highest 3' do
        let(:saml_user_attributes) do
          loa1_user.attributes.merge(loa1_user.identity.attributes).merge(loa: { current: LOA::ONE, highest: LOA::THREE })
        end

        it 'redirects to identity proof URL' do
          expect(SAML::SettingsService).to receive(:idme_loa3_url)
          post :saml_callback
        end
      end

      context 'when user clicked DENY' do
        before { allow(OneLogin::RubySaml::Response).to receive(:new).and_return(saml_response_click_deny) }

        it 'redirects to an auth failure page' do
          expect(Rails.logger).to receive(:warn).with(/#{SAML::AuthFailHandler::CLICKED_DENY_MSG}/)
          expect(post(:saml_callback)).to redirect_to(Settings.saml.relay + '?auth=fail')
          expect(response).to have_http_status(:found)
        end
      end

      context 'when too much time passed to consume the SAML Assertion' do
        before { allow(OneLogin::RubySaml::Response).to receive(:new).and_return(saml_response_too_late) }

        it 'redirects to an auth failure page' do
          expect(Rails.logger).to receive(:warn).with(/#{SAML::AuthFailHandler::TOO_LATE_MSG}/)
          expect(post(:saml_callback)).to redirect_to(Settings.saml.relay + '?auth=fail')
          expect(response).to have_http_status(:found)
        end
      end

      context 'when clock drift causes us to consume the Assertion before its creation' do
        before { allow(OneLogin::RubySaml::Response).to receive(:new).and_return(saml_response_too_early) }

        it 'redirects to an auth failure page' do
          expect(Rails.logger).to receive(:error).with(/#{SAML::AuthFailHandler::TOO_EARLY_MSG}/)
          expect(post(:saml_callback)).to redirect_to(Settings.saml.relay + '?auth=fail')
          expect(response).to have_http_status(:found)
        end

        it 'increments the failed and total statsd counters' do
          once = { times: 1, value: 1 }
          callback_tags = ['status:failure', 'context:dslogon']
          failed_tags = ['error:auth_too_early']

          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, tags: callback_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_FAILED_KEY, tags: failed_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)
        end
      end

      context 'when saml response returns an unknown type of error' do
        before { allow(OneLogin::RubySaml::Response).to receive(:new).and_return(saml_response_unknown_error) }

        it 'logs a generic error' do
          expect_any_instance_of(SSOService).to receive(:log_message_to_sentry)
            .with(
              'Login Fail! Other SAML Response Error(s)',
              :error,                 saml_response: {
                status_message: '',
                errors: [
                  'The status code of the Response was not Success, was Requester => NoAuthnContext ' \
                  '-> AuthnRequest without an authentication context.'
                ]
              }
            )
          expect(post(:saml_callback)).to redirect_to(Settings.saml.relay + '?auth=fail')
          expect(response).to have_http_status(:found)
        end

        it 'increments the failed and total statsd counters' do
          once = { times: 1, value: 1 }
          callback_tags = ['status:failure', 'context:dslogon']
          failed_tags = ['error:unknown']

          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, tags: callback_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_FAILED_KEY, tags: failed_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)
        end
      end

      context 'when saml response contains multiple errors (known or otherwise)' do
        before { allow(OneLogin::RubySaml::Response).to receive(:new).and_return(saml_response_multi_error) }

        it 'logs a generic error' do
          expect_any_instance_of(SSOService).to receive(:log_message_to_sentry)
            .with(
              'Login Fail! Other SAML Response Error(s)',
              :error,                 saml_response: {
                status_message: '',
                errors: [
                  'Subject did not consent to attribute release',
                  'Other random error'
                ]
              }
            )
          expect(post(:saml_callback)).to redirect_to(Settings.saml.relay + '?auth=fail')
          expect(response).to have_http_status(:found)
        end

        it 'increments the failed and total statsd counters' do
          once = { times: 1, value: 1 }
          callback_tags = ['status:failure', 'context:dslogon']
          failed_tags = ['error:multiple']

          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, tags: callback_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_FAILED_KEY, tags: failed_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)
        end
      end

      context 'when a required saml attribute is missing' do
        let(:saml_user_attributes) do
          loa1_user.attributes.merge(loa1_user.identity.attributes).merge(uuid: nil)
        end

        before { allow(SAML::User).to receive(:new).and_return(saml_user) }

        it 'logs a generic user validation error' do
          expect_any_instance_of(SSOService).to receive(:log_message_to_sentry)
            .with(
              'Login Fail! on User/Session Validation',
              :error,
              uuid: nil,
              user: {
                valid: false,
                errors: ["Uuid can't be blank"]
              },
              session: {
                valid: false,
                errors: ["Uuid can't be blank"]
              }
            )
          expect(post(:saml_callback)).to redirect_to(Settings.saml.relay + '?auth=fail')
          expect(response).to have_http_status(:found)
        end

        it 'increments the failed and total statsd counters' do
          once = { times: 1, value: 1 }
          callback_tags = ['status:failure', 'context:dslogon']
          failed_tags = ['error:validations_failed']

          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, tags: callback_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_FAILED_KEY, tags: failed_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)
        end
      end
    end
  end

  context 'when not logged in' do
    it 'returns the urls for for all three possible authN requests' do
      get :authn_urls
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body).keys).to eq %w[mhv dslogon idme]
    end

    it 'does not allow fetching the identity proof url' do
      get :identity_proof
      expect(response).to have_http_status(401)
    end

    it 'does not allow fetching the multifactor url' do
      get :multifactor
      expect(response).to have_http_status(401)
    end

    describe ' DELETE destroy' do
      it 'returns unauthorized' do
        delete :destroy
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe 'POST saml_callback' do
      context 'loa1_user' do
        let(:saml_user_attributes) { loa1_user.attributes.merge(loa1_user.identity.attributes) }

        it 'does not create a job to create an evss user' do
          allow(SAML::User).to receive(:new).and_return(saml_user)
          expect { post :saml_callback }.to_not change(EVSS::CreateUserAccountJob.jobs, :size)
        end
      end

      context 'loa3_user' do
        let(:saml_user_attributes) { loa3_user.attributes.merge(loa3_user.identity.attributes) }

        it 'creates a job to create an evss user' do
          allow(SAML::User).to receive(:new).and_return(saml_user)
          expect { post :saml_callback }.to change(EVSS::CreateUserAccountJob.jobs, :size).by(1)
        end
      end
    end
  end
end
