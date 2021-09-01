# frozen_string_literal: true

require 'rails_helper'
require 'support/saml/response_builder'
require 'support/url_service_helpers'

RSpec.describe V0::SessionsController, type: :controller do
  include SAML::ResponseBuilder

  let(:uuid) { SecureRandom.uuid }
  let(:token) { 'abracadabra-open-sesame' }
  let(:loa1_user) { build(:user, :loa1, uuid: uuid, idme_uuid: uuid) }
  let(:loa3_user) { build(:user, :loa3, uuid: uuid, idme_uuid: uuid) }
  let(:saml_user_attributes) { loa3_user.attributes.merge(loa3_user.identity.attributes) }
  let(:user_attributes) { double('user_attributes', saml_user_attributes) }
  let(:saml_user) do
    instance_double('SAML::User',
                    changing_multifactor?: false,
                    user_attributes: user_attributes,
                    to_hash: saml_user_attributes,
                    validate!: nil)
  end

  let(:request_host)        { '127.0.0.1:3000' }
  let(:callback_url)        { "http://#{request_host}/auth/saml/callback" }
  let(:logout_redirect_url) { 'http://127.0.0.1:3001/logout/' }

  let(:settings_no_context) { build(:settings_no_context, assertion_consumer_service_url: callback_url) }
  let(:rubysaml_settings)   { build(:rubysaml_settings, assertion_consumer_service_url: callback_url) }

  let(:logout_uuid) { '1234' }
  let(:invalid_logout_response) { SAML::Responses::Logout.new('', rubysaml_settings) }
  let(:successful_logout_response) do
    instance_double(
      SAML::Responses::Logout,
      valid?: true,
      validate: true,
      success?: true,
      in_response_to: logout_uuid,
      errors: []
    )
  end

  let(:login_uuid) { '5678' }
  let(:decrypter) { Aes256CbcEncryptor.new(Settings.sso.cookie_key, Settings.sso.cookie_iv) }
  let(:authn_context) { LOA::IDME_LOA1_VETS }
  let(:valid_saml_response) do
    build_saml_response(
      authn_context: authn_context,
      level_of_assurance: ['3'],
      attributes: build(:idme_loa1, level_of_assurance: ['3']),
      in_response_to: login_uuid
    )
  end

  let(:once) { { times: 1, value: 1 } }

  def verify_session_cookie
    token = session[:token]
    expect(token).not_to be_nil
    session_object = Session.find(token)
    expect(session_object).not_to be_nil
    session_object.to_hash.each do |k, v|
      expect(session[k]).to eq(v)
    end
  end

  def expect_logger_msg(level, msg)
    allow(Rails.logger).to receive(level)
    expect(Rails.logger).to receive(level).with(msg)
  end

  before do
    request.host = request_host
    allow(SAML::SettingsService).to receive(:saml_settings).and_return(rubysaml_settings)
    allow(SAML::Responses::Login).to receive(:new).and_return(valid_saml_response)
    Redis.current.set("benchmark_api.auth.login_#{uuid}", Time.now.to_f)
    Redis.current.set("benchmark_api.auth.logout_#{uuid}", Time.now.to_f)
  end

  context 'when not logged in' do
    describe 'new' do
      context 'routes not requiring auth' do
        %w[mhv dslogon idme].each do |type|
          context "routes /sessions/#{type}/new to SessionsController#new with type: #{type}" do
            it 'redirects' do
              expect { get(:new, params: { type: type, clientId: '123123' }) }
                .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                             tags: ["context:#{type}", 'version:v0'], **once)

              expect(response).to have_http_status(:found)
              expect(response.location)
                .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
                .with_relay_state('originating_request_id' => nil, 'type' => type)
                .with_params('clientId' => '123123')
            end
          end
        end

        context 'routes /sessions/signup/new to SessionsController#new' do
          it 'redirects' do
            expect { get(:new, params: { type: :signup, client_id: '123123' }) }
              .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                           tags: ['context:signup', 'version:v0'], **once)
            expect(response).to have_http_status(:found)
            expect(response.location)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => nil, 'type' => 'signup')
              .with_params('op' => 'signup', 'clientId' => '123123')
          end
        end

        context 'routes /v0/sessions/slo/new to SessionController#new' do
          it 'redirects' do
            get(:new, params: { type: :slo })
            expect(get(:new, params: { type: :slo }))
              .to redirect_to('https://int.eauth.va.gov/slo/globallogout?appKey=https%253A%252F%252Fssoe-sp-dev.va.gov')
          end
        end
      end

      context 'routes requiring auth' do
        %w[mfa verify].each do |type|
          it "routes /sessions/#{type}/new to SessionsController#new with type: #{type}" do
            get(:new, params: { type: type })
            expect(response).to have_http_status(:unauthorized)
            expect(JSON.parse(response.body))
              .to eq('errors' => [{
                       'title' => 'Not authorized',
                       'detail' => 'Not authorized',
                       'code' => '401',
                       'status' => '401'
                     }])
          end
        end
      end
    end

    describe 'POST saml_callback' do
      context 'when too much time passed to consume the SAML Assertion' do
        before { allow(SAML::Responses::Login).to receive(:new).and_return(saml_response_too_late) }

        it 'redirects to an auth failure page' do
          expect(Rails.logger)
            .to receive(:warn).with(/#{SAML::Responses::Login::ERRORS[:auth_too_late][:short_message]}/)
          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_FAILED_KEY,
                                         tags: ['error:auth_too_late', 'version:v0'], **once)
          expect(response).to have_http_status(:found)
          expect(response.location).to eq('http://127.0.0.1:3001/auth/login/callback?auth=fail&code=005')
          expect(cookies['vagov_session_dev']).to be_nil
        end
      end

      context 'loa3_user' do
        let(:saml_user_attributes) { loa3_user.attributes.merge(loa3_user.identity.attributes) }

        it 'creates an after login job' do
          allow(SAML::User).to receive(:new).and_return(saml_user)
          expect { post :saml_callback }.to change(AfterLoginJob.jobs, :size).by(1)
        end
      end
    end
  end

  context 'when logged in' do
    before do
      allow(SAML::User).to receive(:new).and_return(saml_user)
      session_object = Session.create(uuid: uuid, token: token)
      session_object.to_hash.each { |k, v| session[k] = v }
      loa1 = User.create(loa1_user.attributes)
      UserIdentity.create(loa1_user.identity.attributes)
      sign_in_as(loa1, token)
    end

    describe 'new' do
      context 'all routes' do
        %w[mhv dslogon idme mfa verify slo].each do |type|
          around do |example|
            Settings.sso.cookie_enabled = true
            example.run
            Settings.sso.cookie_enabled = false
          end

          context "routes /sessions/#{type}/new to SessionsController#new with type: #{type}" do
            it 'redirects' do
              expect { get(:new, params: { type: type }) }
                .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                             tags: ["context:#{type}", 'version:v0'], **once)
              expect(response).to have_http_status(:found)
              expect(cookies['vagov_session_dev']).not_to be_nil unless type.in?(%w[mhv dslogon idme slo])
            end
          end
        end
      end
    end

    describe 'GET sessions/slo/new' do
      let(:logout_request) { OneLogin::RubySaml::Logoutrequest.new }

      before do
        mhv_account = double('mhv_account', ineligible?: false, needs_terms_acceptance?: false, upgraded?: true)
        allow(MHVAccount).to receive(:find_or_initialize_by).and_return(mhv_account)
        allow(OneLogin::RubySaml::Logoutrequest).to receive(:new).and_return(logout_request)
        Session.find(token).to_hash.each { |k, v| session[k] = v }
        cookies['vagov_session_dev'] = 'bar'
      end

      around do |example|
        Settings.sso.cookie_enabled = true
        example.run
        Settings.sso.cookie_enabled = false
      end

      context 'can find an active session' do
        it 'destroys the user, session, and cookie, persists logout_request object, sets url to SLO url' do
          # these should not have been destroyed yet
          verify_session_cookie
          expect(User.find(uuid)).not_to be_nil

          # this should not exist yet
          expect(SingleLogoutRequest.find(logout_request.uuid)).to be_nil
          # it has the cookie set
          expect(cookies['vagov_session_dev']).not_to be_nil
          get(:new, params: { type: 'slo' })
          expect(response.location)
            .to eq('https://int.eauth.va.gov/slo/globallogout?appKey=https%253A%252F%252Fssoe-sp-dev.va.gov')

          # these should be destroyed.
          expect(Session.find(token)).to be_nil
          expect(session).to be_empty
          expect(User.find(uuid)).to be_nil
          expect(cookies['vagov_session_dev']).to be_nil

          # this should be created in redis
          expect(SingleLogoutRequest.find(logout_request.uuid)).to be_nil
        end
      end
    end

    it 'redirects as success even when logout fails, but it logs the failure' do
      expect(post(:saml_logout_callback)).to redirect_to(logout_redirect_url)
    end

    describe 'POST saml_logout_callback' do
      let(:logout_relay_state_param) { '{"originating_request_id": "blah"}' }

      before { SingleLogoutRequest.create(uuid: logout_uuid, token: token) }

      context 'saml_logout_response is invalid' do
        before do
          allow(OneLogin::RubySaml::Logoutresponse).to receive(:new).and_return(invalid_logout_response)
        end

        it 'redirects as success and logs the failure' do
          msg = "SLO callback response invalid for originating_request_id 'blah'"
          expect_logger_msg(:info, msg)
          expect(controller).to receive(:log_message_to_sentry)
          expect(post(:saml_logout_callback, params: { SAMLResponse: '-', RelayState: logout_relay_state_param }))
            .to redirect_to(logout_redirect_url)
        end
      end

      context 'saml_logout_response is valid but saml_logout_request is not found' do
        context 'saml_logout_response is success' do
          before do
            mhv_account = double('mhv_account', ineligible?: false, needs_terms_acceptance?: false, upgraded?: true)
            allow(MHVAccount).to receive(:find_or_initialize_by).and_return(mhv_account)
            allow(SingleLogoutRequest).to receive(:find).with('1234').and_return(nil)
            allow(OneLogin::RubySaml::Logoutresponse).to receive(:new).and_return(successful_logout_response)
            Session.find(token).to_hash.each { |k, v| session[k] = v }
          end

          it 'redirects to success and destroys nothing' do
            # these should have been destroyed in the initial call to sessions/logout, not in the callback.
            verify_session_cookie
            expect(User.find(uuid)).not_to be_nil
            # this will be destroyed
            expect(SingleLogoutRequest.find(successful_logout_response&.in_response_to)).to be_nil

            msg = "SLO callback response could not resolve logout request for originating_request_id 'blah'"
            expect_logger_msg(:info, msg)
            expect(post(:saml_logout_callback, params: { SAMLResponse: '-', RelayState: logout_relay_state_param }))
              .to redirect_to(logout_redirect_url)
            # these should have been destroyed in the initial call to sessions/logout, not in the callback.
            verify_session_cookie
            expect(User.find(uuid)).not_to be_nil
            # this should be destroyed
            expect(SingleLogoutRequest.find(successful_logout_response&.in_response_to)).to be_nil
          end
        end
      end

      context 'saml_logout_response is success' do
        before do
          mhv_account = double('mhv_account', ineligible?: false, needs_terms_acceptance?: false, upgraded?: true)
          allow(MHVAccount).to receive(:find_or_initialize_by).and_return(mhv_account)
          allow(SingleLogoutRequest).to receive(:find).with('1234').and_call_original
          allow(OneLogin::RubySaml::Logoutresponse).to receive(:new).and_return(successful_logout_response)
          Session.find(token).to_hash.each { |k, v| session[k] = v }
        end

        it 'redirects to success and destroys only the logout request' do
          # these should have been destroyed in the initial call to sessions/logout, not in the callback.
          verify_session_cookie
          expect(User.find(uuid)).not_to be_nil
          # this will be destroyed
          expect(SingleLogoutRequest.find(successful_logout_response&.in_response_to)).not_to be_nil

          msg = "SLO callback response to '1234' for originating_request_id 'blah'"
          expect_logger_msg(:info, msg)
          expect(controller).not_to receive(:log_message_to_sentry)
          expect(post(:saml_logout_callback, params: { SAMLResponse: '-', RelayState: logout_relay_state_param }))
            .to redirect_to(logout_redirect_url)
          # these should have been destroyed in the initial call to sessions/logout, not in the callback.
          verify_session_cookie
          expect(User.find(uuid)).not_to be_nil
          # this should be destroyed
          expect(SingleLogoutRequest.find(successful_logout_response&.in_response_to)).to be_nil
        end
      end
    end

    describe 'POST saml_callback' do
      around do |example|
        Settings.sso.cookie_enabled = true
        example.run
        Settings.sso.cookie_enabled = false
      end

      it 'sets the session cookie' do
        Settings.sso.cookie_enabled = false
        post :saml_callback
        verify_session_cookie
      end

      context 'verifying' do
        let(:authn_context) { LOA::IDME_LOA3_VETS }
        let(:version) { 'v0' }
        let(:expected_ssn_log) do
          "SessionsController version:#{version} message:SSN from MPI Lookup does not match UserIdentity cache"
        end

        it 'uplevels an LOA 1 session to LOA 3', :aggregate_failures do
          existing_user = User.find(uuid)
          expect(existing_user.last_signed_in).to be_a(Time)
          expect(existing_user.multifactor).to be_falsey
          expect(existing_user.loa).to eq(highest: LOA::ONE, current: LOA::ONE)
          expect(existing_user.ssn).to eq('796111863')
          allow(StringHelpers).to receive(:levenshtein_distance).and_return(8)
          expect(controller).to receive(:log_message_to_sentry).with(
            expected_ssn_log,
            :warn,
            identity_compared_with_mpi: {
              length: [9, 9],
              only_digits: [true, true],
              encoding: %w[UTF-8 UTF-8],
              levenshtein_distance: 8
            }
          )
          expect(Raven).to receive(:tags_context).once

          callback_tags = ['status:success', "context:#{LOA::IDME_LOA3_VETS}", 'version:v0']

          Timecop.freeze(Time.current)
          cookie_expiration_time = 30.minutes.from_now.iso8601(0)
          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, tags: callback_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)

          expect(response.location).to start_with('http://127.0.0.1:3001/auth/login/callback')

          new_user = User.find(uuid)
          expect(new_user.ssn).to eq('796111863')
          expect(new_user.ssn_mpi).not_to eq('155256322')
          expect(new_user.loa).to eq(highest: LOA::THREE, current: LOA::THREE)
          expect(new_user.multifactor).to be_falsey
          expect(new_user.last_signed_in).not_to eq(existing_user.last_signed_in)
          expect(cookies['vagov_session_dev']).not_to be_nil
          expect(JSON.parse(decrypter.decrypt(cookies['vagov_session_dev'])))
            .to eq('patientIcn' => loa3_user.icn,
                   'mhvCorrelationId' => loa3_user.mhv_correlation_id,
                   'signIn' => { 'serviceName' => 'idme' },
                   'credential_used' => 'id_me',
                   'expirationTime' => cookie_expiration_time)
          Timecop.return
        end
      end

      context 'changing multifactor' do
        let(:authn_context) { 'multifactor' }
        let(:saml_user_attributes) do
          loa1_user.attributes.merge(loa1_user.identity.attributes).merge(multifactor: 'true')
        end

        it 'changes the multifactor to true, time is the same', :aggregate_failures do
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

        it 'has a cookie, but values are nil because loa1 user', :aggregate_failures do
          Timecop.freeze(Time.current)
          cookie_expiration_time = 30.minutes.from_now.iso8601(0)
          SAMLRequestTracker.create(
            uuid: login_uuid,
            payload: { type: 'mfa' }
          )

          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY,
                                         tags: ['status:success', 'context:multifactor', 'version:v0'], **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)

          expect(cookies['vagov_session_dev']).not_to be_nil
          expect(JSON.parse(decrypter.decrypt(cookies['vagov_session_dev'])))
            .to eq(
              'patientIcn' => nil,
              'mhvCorrelationId' => nil,
              'signIn' => { 'serviceName' => 'idme' },
              'credential_used' => 'id_me',
              'expirationTime' => cookie_expiration_time
            )
          Timecop.return
        end

        # keeping this spec round to easily test out the testing attributes
        xit 'has a cookie, which includes the testing values', :aggregate_failures do
          Timecop.freeze(Time.current)
          with_settings(Settings.sso, testing: true) do
            @cookie_expiration_time = 30.minutes.from_now.iso8601(0)
            post :saml_callback
          end

          expect(cookies['vagov_session_dev']).not_to be_nil
          expect(JSON.parse(decrypter.decrypt(cookies['vagov_session_dev'])))
            .to eq(
              'patientIcn' => nil,
              'mhvCorrelationId' => nil,
              'signIn' => { 'serviceName' => 'idme' },
              'credential_used' => 'id_me',
              'expirationTime' => @cookie_expiration_time
            )
          Timecop.return
        end
      end

      context 'when user has LOA current 1 and highest 3' do
        let(:saml_user_attributes) do
          loa1_user.attributes.merge(loa1_user.identity.attributes).merge(
            loa: { current: LOA::ONE, highest: LOA::THREE }
          )
        end

        it 'redirects to idme for up-level' do
          expect(post(:saml_callback)).to redirect_to(/api.idmelabs.com/)
        end

        it 'redirects to identity proof URL', :aggregate_failures do
          Timecop.freeze(Time.current)
          expect_any_instance_of(SAML::URLService).to receive(:verify_url)
          cookie_expiration_time = 30.minutes.from_now.iso8601(0)

          post :saml_callback

          expect(cookies['vagov_session_dev']).not_to be_nil
          expect(JSON.parse(decrypter.decrypt(cookies['vagov_session_dev'])))
            .to eq(
              'patientIcn' => nil,
              'mhvCorrelationId' => nil,
              'signIn' => { 'serviceName' => 'idme' },
              'credential_used' => 'id_me',
              'expirationTime' => cookie_expiration_time
            )
          Timecop.return
        end

        it 'sends STATSD callback metrics' do
          SAMLRequestTracker.create(
            uuid: login_uuid,
            payload: { type: 'idme' }
          )
          expect { post(:saml_callback, params: { RelayState: '{"type":"idme"}' }) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_SAMLRESPONSE_KEY)
            .and trigger_statsd_increment(described_class::STATSD_SSO_SAMLREQUEST_KEY)
        end
      end

      context 'when user has LOA current 1 and highest nil' do
        let(:saml_user_attributes) do
          loa1_user.attributes.merge(loa1_user.identity.attributes).merge(
            loa: { current: nil, highest: nil }
          )
        end

        it 'handles no loa_highest present on new user_identity' do
          post :saml_callback
          expect(response.location).to start_with('http://127.0.0.1:3001/auth/login/callback?auth=fail&code=004')
          expect(cookies['vagov_session_dev']).to be_nil
        end
      end

      context 'when NoMethodError is encountered elsewhere' do
        it 'redirects to adds context and re-raises the exception', :aggregate_failures do
          allow(UserSessionForm).to receive(:new).and_raise(NoMethodError)
          expect(controller).to receive(:log_exception_to_sentry)
          expect(post(:saml_callback))
            .to redirect_to('http://127.0.0.1:3001/auth/login/callback?auth=fail&code=007')
        end

        it 'increments the failed and total statsd counters' do
          allow(UserSessionForm).to receive(:new).and_raise(NoMethodError)
          callback_tags = ['status:failure', 'context:unknown', 'version:v0']
          failed_tags = ['error:unknown', 'version:v0']

          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, tags: callback_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_FAILED_KEY, tags: failed_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)
        end
      end

      context 'when user clicked DENY' do
        before { allow(SAML::Responses::Login).to receive(:new).and_return(saml_response_click_deny) }

        it 'redirects to an auth failure page' do
          expect(Raven).to receive(:tags_context).once
          expect(Rails.logger)
            .to receive(:warn).with(/#{SAML::Responses::Login::ERRORS[:clicked_deny][:short_message]}/)
          expect(post(:saml_callback)).to redirect_to('http://127.0.0.1:3001/auth/login/callback?auth=fail&code=001')
          expect(response).to have_http_status(:found)
        end
      end

      context 'when too much time passed to consume the SAML Assertion' do
        before { allow(SAML::Responses::Login).to receive(:new).and_return(saml_response_too_late) }

        it 'redirects to an auth failure page' do
          expect(Rails.logger)
            .to receive(:warn).with(/#{SAML::Responses::Login::ERRORS[:auth_too_late][:short_message]}/)
          expect(post(:saml_callback)).to redirect_to('http://127.0.0.1:3001/auth/login/callback?auth=fail&code=002')
          expect(response).to have_http_status(:found)
          expect(cookies['vagov_session_dev']).not_to be_nil
        end
      end

      context 'when clock drift causes us to consume the Assertion before its creation' do
        before { allow(SAML::Responses::Login).to receive(:new).and_return(saml_response_too_early) }

        it 'redirects to an auth failure page', :aggregate_failures do
          expect(Rails.logger)
            .to receive(:error).with(/#{SAML::Responses::Login::ERRORS[:auth_too_early][:short_message]}/)
          expect(post(:saml_callback)).to redirect_to('http://127.0.0.1:3001/auth/login/callback?auth=fail&code=003')
          expect(response).to have_http_status(:found)
          expect(cookies['vagov_session_dev']).to be_nil
        end

        it 'increments the failed and total statsd counters' do
          callback_tags = ['status:failure', 'context:unknown', 'version:v0']
          failed_tags = ['error:auth_too_early', 'version:v0']

          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, tags: callback_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_FAILED_KEY, tags: failed_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)
        end
      end

      context 'when saml response returns an unknown type of error' do
        before { allow(SAML::Responses::Login).to receive(:new).and_return(saml_response_unknown_error) }

        it 'logs a generic error', :aggregate_failures do
          expect(controller).to receive(:log_message_to_sentry)
            .with(
              'Login Failed! Other SAML Response Error(s)',
              :error,
              saml_error_context: [{ code: SAML::Responses::Base::UNKNOWN_OR_BLANK_ERROR_CODE,
                                     tag: :unknown,
                                     short_message: 'Other SAML Response Error(s)',
                                     level: :error,
                                     full_message: 'The status code of the Response was not Success, was Requester =>'\
                                  ' NoAuthnContext -> AuthnRequest without an authentication context.' }]
            )
          expect(post(:saml_callback)).to redirect_to('http://127.0.0.1:3001/auth/login/callback?auth=fail&code=007')
          expect(response).to have_http_status(:found)
          expect(cookies['vagov_session_dev']).to be_nil
        end

        it 'increments the failed and total statsd counters' do
          callback_tags = ['status:failure', 'context:unknown', 'version:v0']
          failed_tags = ['error:unknown', 'version:v0']

          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, tags: callback_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_FAILED_KEY, tags: failed_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)
        end
      end

      context 'when saml response contains multiple errors (known or otherwise)' do
        before { allow(SAML::Responses::Login).to receive(:new).and_return(saml_response_multi_error) }

        it 'logs a generic error' do
          expect(controller).to receive(:log_message_to_sentry)
            .with(
              'Login Failed! Subject did not consent to attribute release Multiple SAML Errors',
              :warn,
              saml_error_context: [{ code: SAML::Responses::Base::CLICKED_DENY_ERROR_CODE,
                                     tag: :clicked_deny,
                                     short_message: 'Subject did not consent to attribute release',
                                     level: :warn,
                                     full_message: 'Subject did not consent to attribute release' },
                                   { code: SAML::Responses::Base::UNKNOWN_OR_BLANK_ERROR_CODE,
                                     tag: :unknown,
                                     short_message: 'Other SAML Response Error(s)',
                                     level: :error,
                                     full_message: 'Other random error' }]
            )
          expect(post(:saml_callback)).to redirect_to('http://127.0.0.1:3001/auth/login/callback?auth=fail&code=001')
          expect(response).to have_http_status(:found)
          expect(cookies['vagov_session_dev']).to be_nil
        end

        it 'increments the failed and total statsd counters' do
          callback_tags = ['status:failure', 'context:unknown', 'version:v0']
          failed_tags = ['error:clicked_deny', 'version:v0']

          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, tags: callback_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_FAILED_KEY, tags: failed_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)
        end
      end

      context 'MVI is down', :aggregate_failures do
        let(:authn_context) { 'myhealthevet' }
        let(:mhv_premium_user) { build(:user, :mhv, uuid: uuid) }
        let(:saml_user_attributes) do
          mhv_premium_user.attributes.merge(mhv_premium_user.identity.attributes).merge(first_name: nil)
        end

        it 'allows user to sign in even if user attributes are not available' do
          SAMLRequestTracker.create(
            uuid: login_uuid,
            payload: { type: 'mhv' }
          )
          MPI::Configuration.instance.breakers_service.begin_forced_outage!
          callback_tags = ['status:success', 'context:myhealthevet', 'version:v0']
          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, tags: callback_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)
          expect(response.location).to start_with('http://127.0.0.1:3001/auth/login/callback')
          expect(cookies['vagov_session_dev']).not_to be_nil
          MPI::Configuration.instance.breakers_service.end_forced_outage!
        end
      end

      context 'when a required saml attribute is missing' do
        let(:saml_user_attributes) do
          loa1_user.attributes.merge(loa1_user.identity.attributes).merge(uuid: nil)
        end

        before { allow(SAML::User).to receive(:new).and_return(saml_user) }

        it 'logs a generic user validation error', :aggregate_failures do
          expect(controller).to receive(:log_message_to_sentry)
            .with(
              'Login Failed! on User/Session Validation',
              :error,
              code: UserSessionForm::VALIDATIONS_FAILED_ERROR_CODE,
              tag: :validations_failed,
              short_message: 'on User/Session Validation',
              level: :error,
              uuid: nil,
              user: {
                valid: false,
                errors: ["Uuid can't be blank"]
              },
              session: {
                valid: false,
                errors: ["Uuid can't be blank"]
              },
              identity: {
                valid: false,
                errors: ["Uuid can't be blank"],
                authn_context: 'http://idmanagement.gov/ns/assurance/loa/1/vets',
                loa: { current: 1, highest: 1 }
              },
              mvi: 'breakers is open for MVI'
            )
          expect(post(:saml_callback)).to redirect_to('http://127.0.0.1:3001/auth/login/callback?auth=fail&code=004')
          expect(response).to have_http_status(:found)
          expect(cookies['vagov_session_dev']).to be_nil
        end

        it 'increments the failed and total statsd counters' do
          callback_tags = ['status:failure', "context:#{LOA::IDME_LOA1_VETS}", 'version:v0']
          failed_tags = ['error:validations_failed', 'version:v0']

          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, tags: callback_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_FAILED_KEY, tags: failed_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)
        end
      end

      context 'when creating a user account' do
        context 'and the current user does not yet have an Account record' do
          before do
            expect(Account.count).to eq 0
          end

          it 'creates an Account record for the user' do
            post :saml_callback
            AfterLoginJob.drain

            expect(Account.first.idme_uuid).to eq uuid
          end
        end

        context 'and the current user already has an Account record' do
          let!(:account) { create :account, idme_uuid: uuid }

          it 'does not create a new Account record for the user', :aggregate_failures do
            post :saml_callback
            AfterLoginJob.drain

            expect(Account.count).to eq 1
            expect(Account.first.idme_uuid).to eq account.idme_uuid
          end
        end
      end

      context 'when user has multiple distinct mhv ids' do
        let(:expected_error_message) { SAML::UserAttributeError::ERRORS[:multiple_mhv_ids][:message] }
        let(:expected_warn_message) do
          "SessionsController version:v0 context:{} message:#{expected_error_message}"
        end

        before do
          allow(UserSessionForm).to receive(:new).and_raise(
            SAML::UserAttributeError, SAML::UserAttributeError::ERRORS[:multiple_mhv_ids]
          )
        end

        it 'logs an info message to rails logger' do
          expect(Rails.logger).to receive(:warn).with(expected_warn_message)
          post(:saml_callback)
        end

        it 'does not log to sentry' do
          expect(controller).not_to receive(:log_message_to_sentry)
          post(:saml_callback)
        end
      end
    end
  end
end
