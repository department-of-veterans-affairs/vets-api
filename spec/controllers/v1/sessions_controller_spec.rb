# frozen_string_literal: true

require 'rails_helper'
require 'support/saml/form_validation_helpers'
require 'support/saml/response_builder'
require 'support/url_service_helpers'

RSpec.describe V1::SessionsController, type: :controller do
  include SAML::ResponseBuilder
  include SAML::ValidationHelpers

  let(:uuid) { SecureRandom.uuid }
  let(:token) { 'abracadabra-open-sesame' }
  let(:loa1_user) { build(:user, :loa1, uuid: uuid, idme_uuid: uuid) }
  let(:loa3_user) { build(:user, :loa3, uuid: uuid, idme_uuid: uuid) }
  let(:ial1_user) { build(:user, :ial1, uuid: uuid, logingov_uuid: uuid) }
  let(:saml_user_attributes) { loa3_user.attributes.merge(loa3_user.identity.attributes) }
  let(:user_attributes) { double('user_attributes', saml_user_attributes) }
  let(:saml_user) do
    instance_double('SAML::User',
                    changing_multifactor?: false,
                    user_attributes: user_attributes,
                    to_hash: saml_user_attributes,
                    needs_csp_id_mpi_update?: false,
                    validate!: nil)
  end

  let(:request_host)        { '127.0.0.1:3000' }
  let(:request_id)          { SecureRandom.uuid }
  let(:callback_url)        { "http://#{request_host}/v1/sessions/callback" }
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
  let(:authn_context) { LOA::IDME_LOA1_VETS }
  let(:valid_saml_response) do
    build_saml_response(
      authn_context: authn_context,
      level_of_assurance: ['3'],
      attributes: build(:ssoe_idme_loa1, va_eauth_ial: 3),
      in_response_to: login_uuid,
      issuer: 'https://int.eauth.va.gov/FIM/sps/saml20fedCSP/saml20'
    )
  end

  let(:expected_redirect_url) { 'http://127.0.0.1:3001/auth/login/callback' }
  let(:error_code) { '007' }
  let(:expected_redirect_params) { { auth: 'fail', code: error_code, request_id: request_id }.to_query }
  let(:expected_redirect) do
    uri = URI.parse(expected_redirect_url)
    uri.query = expected_redirect_params
    uri.to_s
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
    allow(SAML::SSOeSettingsService).to receive(:saml_settings).and_return(rubysaml_settings)
    allow(SAML::Responses::Login).to receive(:new).and_return(valid_saml_response)
    allow_any_instance_of(ActionController::TestRequest).to receive(:request_id).and_return(request_id)
  end

  context 'when not logged in' do
    describe 'new' do
      context 'routes not requiring auth' do
        %w[mhv mhv_verified dslogon dslogon_verified idme idme_verified logingov logingov_verified].each do |type|
          context "routes /sessions/#{type}/new to SessionsController#new with type: #{type}" do
            let(:expected_force_authn) { true }
            let(:authn) do
              case type
              when 'mhv'
                ['myhealthevet', AuthnContext::MHV]
              when 'mhv_verified'
                ['myhealthevet', AuthnContext::MHV]
              when 'idme'
                [LOA::IDME_LOA1_VETS, AuthnContext::ID_ME]
              when 'idme_verified'
                [LOA::IDME_LOA3, AuthnContext::ID_ME]
              when 'dslogon'
                ['dslogon', AuthnContext::DSLOGON]
              when 'dslogon_verified'
                ['dslogon', AuthnContext::DSLOGON]
              when 'logingov'
                [IAL::LOGIN_GOV_IAL1,
                 AAL::LOGIN_GOV_AAL2,
                 AuthnContext::LOGIN_GOV]
              when 'logingov_verified'
                [IAL::LOGIN_GOV_IAL2,
                 AAL::LOGIN_GOV_AAL2,
                 AuthnContext::LOGIN_GOV]
              end
            end

            it 'presents login form' do
              expect(SAML::SSOeSettingsService)
                .to receive(:saml_settings)
                .with(force_authn: expected_force_authn)
              expect { get(:new, params: { type: type, clientId: '123123' }) }
                .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                             tags: ["context:#{type}", 'version:v1', 'client_id:vaweb'], **once)
                .and trigger_statsd_increment(described_class::STATSD_SSO_SAMLREQUEST_KEY, **once)
              expect(response).to have_http_status(:ok)
              expect(SAMLRequestTracker.keys.length).to eq(1)
              payload = SAMLRequestTracker.find(SAMLRequestTracker.keys[0]).payload
              expect(payload)
                .to eq({
                         type: type,
                         authn_context: authn,
                         transaction_id: payload[:transaction_id]
                       })
            end

            context 'USiP user' do
              it 'logs the USiP client application' do
                expect { get(:new, params: { type: type, clientId: '123123', application: 'vamobile' }) }
                  .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                               tags: ["context:#{type}", 'version:v1', 'client_id:vamobile'], **once)
              end
            end
          end
        end

        context 'routes /sessions/custom/new to SessionController#new' do
          context 'logingov inbound ssoe' do
            it 'redirects for an inbound ssoe' do
              expect(SAML::SSOeSettingsService)
                .to receive(:saml_settings)
                .with(force_authn: false)

              expect do
                get(:new, params: {
                      type: 'custom',
                      csp_type: 'logingov',
                      ial: IAL::TWO,
                      client_id: '123123'
                    })
              end
                .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                             tags: ['context:custom', 'version:v1', 'client_id:vaweb'], **once)

              expect(response).to have_http_status(:ok)
              expect_saml_post_form(response.body, 'https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login',
                                    'originating_request_id' => nil, 'type' => 'custom')
              expect(SAMLRequestTracker.keys.length).to eq(1)
              payload = SAMLRequestTracker.find(SAMLRequestTracker.keys[0]).payload
              expect(payload)
                .to eq({
                         type: 'custom',
                         authn_context: IAL::LOGIN_GOV_IAL2,
                         transaction_id: payload[:transaction_id]
                       })
            end

            it 'raises exception when missing ial parameter' do
              expect { get(:new, params: { type: :custom, csp_type: 'logingov', ial: '', client_id: '123123' }) }
                .not_to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                                 tags: ['context:custom', 'version:v1', 'client_id:vaweb'], **once)
              expect(response).to have_http_status(:bad_request)
              expect(JSON.parse(response.body))
                .to eq({
                         'errors' => [{
                           'title' => 'Missing parameter',
                           'detail' => 'The required parameter "ial", is missing',
                           'code' => '108',
                           'status' => '400'
                         }]
                       })
            end

            it 'raises exception when ial parameter is not 1 or 2' do
              expect { get(:new, params: { type: :custom, csp_type: 'logingov', ial: '3', client_id: '123123' }) }
                .not_to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                                 tags: ['context:custom', 'version:v1', 'client_id:vaweb'], **once)
              expect(response).to have_http_status(:bad_request)
              expect(JSON.parse(response.body))
                .to eq({
                         'errors' => [{
                           'title' => 'Invalid field value',
                           'detail' => '"3" is not a valid value for "ial"',
                           'code' => '103',
                           'status' => '400'
                         }]
                       })
            end
          end

          context 'dslogon mhv idme inbound ssoe' do
            it 'redirects for an inbound ssoe' do
              expect(SAML::SSOeSettingsService)
                .to receive(:saml_settings)
                .with(force_authn: false)

              expect { get(:new, params: { type: 'custom', authn: 'myhealthevet', clientId: '123123' }) }
                .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                             tags: ['context:custom', 'version:v1', 'client_id:vaweb'], **once)

              expect(response).to have_http_status(:ok)
              expect_saml_post_form(response.body, 'https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login',
                                    'originating_request_id' => nil, 'type' => 'custom')
              expect(SAMLRequestTracker.keys.length).to eq(1)
              payload = SAMLRequestTracker.find(SAMLRequestTracker.keys[0]).payload
              expect(payload)
                .to eq({
                         type: 'custom',
                         authn_context: 'myhealthevet',
                         transaction_id: payload[:transaction_id]
                       })
            end

            it 'raises exception when missing authn parameter' do
              expect { get(:new, params: { type: :custom, authn: '', client_id: '123123' }) }
                .not_to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                                 tags: ['context:custom', 'version:v1', 'client_id:vaweb'], **once)
              expect(response).to have_http_status(:bad_request)
              expect(JSON.parse(response.body))
                .to eq({
                         'errors' => [{
                           'title' => 'Missing parameter',
                           'detail' => 'The required parameter "authn", is missing',
                           'code' => '108',
                           'status' => '400'
                         }]
                       })
            end

            it 'raises exception when authn parameter is not in list of AUTHN_CONTEXTS' do
              expect { get(:new, params: { type: :custom, authn: 'qwerty', client_id: '123123' }) }
                .not_to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                                 tags: ['context:custom', 'version:v1', 'client_id:vaweb'], **once)
              expect(response).to have_http_status(:bad_request)
              expect(JSON.parse(response.body))
                .to eq({
                         'errors' => [{
                           'title' => 'Invalid field value',
                           'detail' => '"qwerty" is not a valid value for "authn"',
                           'code' => '103',
                           'status' => '400'
                         }]
                       })
            end
          end
        end

        context 'routes /sessions/idme_signup/new to SessionsController#new' do
          it 'redirects' do
            expect { get(:new, params: { type: :idme_signup, client_id: '123123' }) }
              .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                           tags: ['context:idme_signup', 'version:v1', 'client_id:vaweb'], **once)
            expect(response).to have_http_status(:ok)
            expect_saml_post_form(response.body, 'https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login',
                                  'originating_request_id' => nil, 'type' => 'signup')
          end
        end

        context 'routes /sessions/idme_signup_verified/new to SessionsController#new' do
          it 'redirects' do
            expect { get(:new, params: { type: :idme_signup_verified, client_id: '123123' }) }
              .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                           tags: ['context:idme_signup_verified',
                                                  'version:v1',
                                                  'client_id:vaweb'], **once)
            expect(response).to have_http_status(:ok)
            expect_saml_post_form(response.body, 'https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login',
                                  'originating_request_id' => nil, 'type' => 'signup')
          end
        end

        context 'routes /sessions/logingov_signup/new to SessionsController#new' do
          it 'redirects' do
            expect { get(:new, params: { type: :logingov_signup, client_id: '123123' }) }
              .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                           tags: ['context:logingov_signup', 'version:v1', 'client_id:vaweb'], **once)
            expect(response).to have_http_status(:ok)
            expect_saml_post_form(response.body, 'https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login',
                                  'originating_request_id' => nil, 'type' => 'signup')
          end
        end

        context 'routes /sessions/logingov_signup_verified/new to SessionsController#new' do
          it 'redirects' do
            expect { get(:new, params: { type: :logingov_signup_verified, client_id: '123123' }) }
              .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                           tags: ['context:logingov_signup_verified',
                                                  'version:v1',
                                                  'client_id:vaweb'], **once)
            expect(response).to have_http_status(:ok)
            expect_saml_post_form(response.body, 'https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login',
                                  'originating_request_id' => nil, 'type' => 'signup')
          end
        end

        context 'routes /v1/sessions/slo/new to SessionController#new' do
          it 'redirects' do
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
        let(:error_code) { '005' }

        before { allow(SAML::Responses::Login).to receive(:new).and_return(saml_response_too_late) }

        it 'redirects to an auth failure page' do
          expect(Rails.logger)
            .to receive(:warn).with(/#{SAML::Responses::Login::ERRORS[:auth_too_late][:short_message]}/)
          expect(post(:saml_callback)).to redirect_to(expected_redirect)
          expect(response).to have_http_status(:found)
        end
      end

      context 'loa3_user' do
        let(:saml_user_attributes) { loa3_user.attributes.merge(loa3_user.identity.attributes) }

        it 'makes a call to AfterLoginActions' do
          allow(SAML::User).to receive(:new).and_return(saml_user)
          expect_any_instance_of(Login::AfterLoginActions).to receive(:perform)
          post :saml_callback
        end
      end

      context 'when authenticated type is mhv_verified' do
        let(:type_param) { { type: type } }
        let(:type) { 'mhv_verified' }

        context 'and authenticated user is loa three' do
          let(:saml_user_attributes) { loa3_user.attributes.merge(loa3_user.identity.attributes) }

          it 'makes a call to AfterLoginActions' do
            allow(SAML::User).to receive(:new).and_return(saml_user)
            expect_any_instance_of(Login::AfterLoginActions).to receive(:perform)
            post :saml_callback, params: { RelayState: type_param.to_json }
          end
        end

        context 'and authenticated user is loa one' do
          let(:saml_user_attributes) { loa1_user.attributes.merge(loa1_user.identity.attributes) }
          let(:error_code) { SAML::UserAttributeError::MHV_UNVERIFIED_BLOCKED_CODE }
          let(:expected_redirect_params) do
            { auth: 'fail', code: error_code, request_id: request_id, type: type }.to_query
          end

          it 'redirects to an auth failure page' do
            expect(controller).to receive(:log_message_to_sentry)
            expect(post(:saml_callback, params: { RelayState: type_param.to_json })).to redirect_to(expected_redirect)
            expect(response).to have_http_status(:found)
          end
        end
      end

      it 'redirect user to home page when no SAMLRequestTracker exists' do
        allow(SAML::User).to receive(:new).and_return(saml_user)
        expect(post(:saml_callback)).to redirect_to(expected_redirect_url)
      end

      context 'for a user with semantically invalid SAML attributes' do
        let(:invalid_attributes) do
          build(:ssoe_idme_mhv_loa3, va_eauth_gcIds: ['0123456789^NI^200DOD^USDOD^A|0000000054^NI^200DOD^USDOD^A|'])
        end
        let(:valid_saml_response) do
          build_saml_response(
            authn_context: authn_context,
            level_of_assurance: ['3'],
            attributes: invalid_attributes,
            in_response_to: login_uuid,
            issuer: 'https://int.eauth.va.gov/FIM/sps/saml20fedCSP/saml20'
          )
        end
        let(:error_code) { '102' }

        it 'redirects to an auth failure page' do
          expect(controller).to receive(:log_message_to_sentry)
          expect(post(:saml_callback)).to redirect_to(expected_redirect)
          expect(response).to have_http_status(:found)
        end

        it 'logs a status failure stat' do
          SAMLRequestTracker.create(
            uuid: login_uuid,
            payload: { type: 'idme' }
          )
          expect(controller).to receive(:log_message_to_sentry)
          expect { post(:saml_callback, params: { RelayState: '{"type": "idme"}' }) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_SAMLRESPONSE_KEY,
                                         tags: ['type:idme',
                                                'context:http://idmanagement.gov/ns/assurance/loa/1/vets',
                                                'version:v1'])
            .and trigger_statsd_increment(described_class::STATSD_LOGIN_STATUS_FAILURE,
                                          tags: ['context:idme', 'version:v1', 'client_id:', 'error:102'])
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_FAILED_KEY,
                                          tags: ['error:multiple_edipis', 'version:v1'])

          expect(response).to have_http_status(:found)
        end

        context 'USiP user' do
          it 'logs the USiP client application' do
            SAMLRequestTracker.create(uuid: login_uuid, payload: { type: 'idme', application: 'vamobile' })
            login_failed_tags = ['context:idme', 'version:v1', 'client_id:vamobile', 'error:102']

            expect { post(:saml_callback, params: { RelayState: '{"type": "idme"}' }) }
              .to trigger_statsd_increment(described_class::STATSD_LOGIN_STATUS_FAILURE, tags: login_failed_tags)
          end
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
      context 'all login routes' do
        %w[mhv dslogon idme mfa verify].each do |type|
          context "routes /sessions/#{type}/new to SessionsController#new with type: #{type}" do
            it 'responds' do
              expect { get(:new, params: { type: type }) }
                .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                             tags: ["context:#{type}", 'version:v1', 'client_id:vaweb'], **once)
              expect(response).to have_http_status(:ok)
              expect(cookies['vagov_saml_request_localhost']).not_to be_nil
            end
          end
        end
      end

      context 'slo routes' do
        context 'routes /sessions/slo/new to SessionsController#new with type: #slo' do
          it 'redirects' do
            expect { get(:new, params: { type: 'slo' }) }
              .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                           tags: ['context:slo', 'version:v1', 'client_id:vaweb'], **once)
            expect(response).to have_http_status(:found)
          end
        end
      end
    end

    describe 'GET sessions/slo/new' do
      before do
        Session.find(token).to_hash.each { |k, v| session[k] = v }
      end

      context 'can find an active session' do
        it 'destroys the user, session, and cookie, persists logout_request object, sets url to SLO url' do
          # these should not have been destroyed yet
          verify_session_cookie
          expect(User.find(uuid)).not_to be_nil

          get(:new, params: { type: 'slo' })
          expect(response.location)
            .to eq('https://int.eauth.va.gov/slo/globallogout?appKey=https%253A%252F%252Fssoe-sp-dev.va.gov')

          # these should be destroyed.
          expect(Session.find(token)).to be_nil
          expect(session).to be_empty
          expect(User.find(uuid)).to be_nil
        end
      end
    end

    it 'redirects on callback from external logout' do
      expect(get(:ssoe_slo_callback)).to redirect_to(logout_redirect_url)
    end

    describe 'POST saml_callback' do
      it 'sets the session cookie' do
        post :saml_callback
        verify_session_cookie
      end

      context 'verifying' do
        let(:authn_context) { IAL::LOGIN_GOV_IAL1 }

        it 'uplevels an LOA 1 session to LOA 3', :aggregate_failures do
          SAMLRequestTracker.create(
            uuid: login_uuid,
            payload: { type: 'verify' }
          )
          existing_user = User.find(uuid)
          expect(existing_user.last_signed_in).to be_a(Time)
          expect(existing_user.multifactor).to be_falsey
          expect(existing_user.loa).to eq(highest: IAL::ONE, current: IAL::ONE)
          expect(existing_user.ssn).to eq('796111863')
          expect(Raven).to receive(:tags_context).once

          callback_tags = ['status:success', "context:#{IAL::LOGIN_GOV_IAL1}", 'version:v1']

          new_user_sign_in = Time.current + 30.minutes
          Timecop.freeze(new_user_sign_in)
          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, tags: callback_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)

          expect(response.location).to start_with(expected_redirect_url)

          new_user = User.find(uuid)
          expect(new_user.ssn).to eq('796111863')
          expect(new_user.ssn_mpi).not_to eq('155256322')
          expect(new_user.loa).to eq(highest: LOA::THREE, current: LOA::THREE)
          expect(new_user.multifactor).to be_falsey
          expect(new_user.last_signed_in).not_to eq(existing_user.last_signed_in)
          Timecop.return
        end

        context 'USiP user' do
          it 'logs the USiP client application' do
            SAMLRequestTracker.create(uuid: login_uuid, payload: { type: 'idme', application: 'vamobile' })
            callback_tags = ['context:idme', 'version:v1', 'client_id:vamobile']

            expect { post(:saml_callback, params: { RelayState: '{"type": "idme"}' }) }
              .to trigger_statsd_increment(described_class::STATSD_LOGIN_STATUS_SUCCESS, tags: callback_tags, **once)
          end
        end

        context 'UserIdentity & MPI ID validations' do
          let(:loa3_user) { build(:user, :loa3, uuid: uuid, idme_uuid: uuid, stub_mpi: false) }
          let(:mpi_profile) { build(:mvi_profile) }
          let(:expected_error_data) do
            { identity_value: expected_identity_value, mpi_value: expected_mpi_value, icn: loa3_user.icn }
          end
          let(:expected_error_message) do
            "[SessionsController version:v1] User Identity & MPI #{validation_id} values conflict"
          end

          before do
            allow(Rails.logger).to receive(:warn)
            allow_any_instance_of(User).to receive(:mpi_profile).and_return(mpi_profile)
          end

          shared_examples 'identity-mpi id validation' do
            it 'logs a warning when Identity & MPI values conflict' do
              expect(Rails.logger).to receive(:warn).at_least(:once).with(expected_error_message, expected_error_data)
              post(:saml_callback)
            end
          end

          context 'ssn validation' do
            let(:expected_identity_value) { loa3_user.identity.ssn }
            let(:expected_mpi_value) { loa3_user.ssn_mpi }
            let(:validation_id) { 'SSN' }
            let(:expected_error_data) { { icn: loa3_user.icn } }

            it_behaves_like 'identity-mpi id validation'
          end

          context 'edipi validation' do
            let(:mpi_profile) { build(:mvi_profile, edipi: Faker::Number.number(digits: 10)) }
            let(:expected_identity_value) { loa3_user.identity.edipi }
            let(:expected_mpi_value) { loa3_user.edipi_mpi }
            let(:validation_id) { 'EDIPI' }

            it_behaves_like 'identity-mpi id validation'
          end

          context 'icn validation' do
            let(:mpi_profile) { build(:mvi_profile, icn: 'some-mpi-icn') }
            let(:expected_identity_value) { loa3_user.identity.icn }
            let(:expected_mpi_value) { loa3_user.mpi_icn }
            let(:validation_id) { 'ICN' }

            it_behaves_like 'identity-mpi id validation'
          end

          context 'MHV correlation id validation' do
            let(:mpi_profile) { build(:mvi_profile, mhv_ids: [Faker::Number.number(digits: 11)]) }
            let(:expected_identity_value) { loa3_user.identity.mhv_correlation_id }
            let(:expected_mpi_value) { loa3_user.mpi_mhv_correlation_id }
            let(:validation_id) { 'MHV Correlation ID' }

            it_behaves_like 'identity-mpi id validation'
          end
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

        context 'with mismatched UUIDs' do
          let(:saml_user_attributes) do
            loa3_user.attributes.merge(loa3_user.identity.attributes.merge(uuid: 'invalid', mhv_icn: '11111111111'))
          end
          let(:loa1_user) { build(:user, :loa1, uuid: uuid, idme_uuid: uuid, mhv_icn: '11111111111') }

          it 'logs a message to Sentry' do
            allow(saml_user).to receive(:changing_multifactor?).and_return(true)
            expect(Raven).to receive(:extra_context).with(current_user_uuid: uuid, current_user_icn: '11111111111')
            expect(Raven).to receive(:extra_context).with({ saml_uuid: 'invalid', saml_icn: '11111111111' })
            expect(Raven).to receive(:capture_message).with(
              "Couldn't locate exiting user after MFA establishment",
              level: 'warning'
            )
            expect(Raven).to receive(:extra_context).at_least(:once) # From PostURLService#initialize
            with_settings(Settings.sentry, dsn: 'T') do
              post(:saml_callback, params: { RelayState: '{"type": "mfa"}' })
            end
          end
        end
      end

      context 'when user has LOA current 1 and highest nil' do
        let(:saml_user_attributes) do
          loa1_user.attributes.merge(loa1_user.identity.attributes).merge(
            loa: { current: nil, highest: nil }
          )
        end
        let(:error_code) { '004' }

        it 'handles no loa_highest present on new user_identity' do
          post :saml_callback
          expect(response.location).to start_with(expected_redirect)
        end
      end

      context 'when user clicked DENY' do
        let(:error_code) { '001' }

        before { allow(SAML::Responses::Login).to receive(:new).and_return(saml_response_click_deny) }

        it 'redirects to an auth failure page' do
          expect(Raven).to receive(:tags_context).once
          expect(Rails.logger)
            .to receive(:warn).with(/#{SAML::Responses::Login::ERRORS[:clicked_deny][:short_message]}/)
          expect(post(:saml_callback)).to redirect_to(expected_redirect)
          expect(response).to have_http_status(:found)
        end
      end

      context 'when too much time passed to consume the SAML Assertion' do
        let(:error_code) { '002' }

        before { allow(SAML::Responses::Login).to receive(:new).and_return(saml_response_too_late) }

        it 'redirects to an auth failure page' do
          expect(Rails.logger)
            .to receive(:warn).with(/#{SAML::Responses::Login::ERRORS[:auth_too_late][:short_message]}/)
          expect(post(:saml_callback)).to redirect_to(expected_redirect)
          expect(response).to have_http_status(:found)
        end
      end

      context 'when clock drift causes us to consume the Assertion before its creation' do
        let(:error_code) { '003' }

        before { allow(SAML::Responses::Login).to receive(:new).and_return(saml_response_too_early) }

        it 'redirects to an auth failure page', :aggregate_failures do
          expect(Rails.logger)
            .to receive(:error).with(/#{SAML::Responses::Login::ERRORS[:auth_too_early][:short_message]}/)
          expect(post(:saml_callback)).to redirect_to(expected_redirect)
          expect(response).to have_http_status(:found)
        end

        it 'increments the failed and total statsd counters' do
          callback_tags = ['status:failure', 'context:unknown', 'version:v1']
          failed_tags = ['error:auth_too_early', 'version:v1']

          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, tags: callback_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_FAILED_KEY, tags: failed_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)
        end
      end

      context 'when saml response returns an unknown type of error' do
        let(:error_code) { '007' }

        before { allow(SAML::Responses::Login).to receive(:new).and_return(saml_response_unknown_error) }

        it 'logs a generic error', :aggregate_failures do
          expect(controller).to receive(:log_message_to_sentry)
            .with(
              'Login Failed! Other SAML Response Error(s)',
              :error,
              extra_context: [{ code: SAML::Responses::Base::UNKNOWN_OR_BLANK_ERROR_CODE,
                                tag: :unknown,
                                short_message: 'Other SAML Response Error(s)',
                                level: :error,
                                full_message: 'The status code of the Response was not Success, was Requester =>'\
                                              ' NoAuthnContext -> AuthnRequest without an authentication context.' }]
            )
          expect(post(:saml_callback)).to redirect_to(expected_redirect)
          expect(response).to have_http_status(:found)
        end

        it 'increments the failed and total statsd counters' do
          callback_tags = ['status:failure', 'context:unknown', 'version:v1']
          failed_tags = ['error:unknown', 'version:v1']

          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, tags: callback_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_FAILED_KEY, tags: failed_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)
        end

        it 'captures the invalid saml response in a PersonalInformationLog' do
          post(:saml_callback)
          expect(PersonalInformationLog.count).to be_positive
          expect(PersonalInformationLog.last.error_class).to eq('Login Failed! Other SAML Response Error(s)')
        end
      end

      context 'when saml response error contains status_detail' do
        status_detail_xml = '<samlp:StatusCode Value="urn:oasis:names:tc:SAML:2.0:status:Responder">'\
                            '</samlp:StatusCode>'\
                            '<samlp:StatusDetail>'\
                            '<fim:FIMStatusDetail MessageID="could_not_perform_token_exchange"></fim:FIMStatusDetail>'\
                            '</samlp:StatusDetail>'\

        before do
          allow(SAML::Responses::Login).to receive(:new).and_return(saml_response_detail_error(status_detail_xml))
        end

        it 'logs status_detail message to sentry' do
          expect(controller).to receive(:log_message_to_sentry)
            .with(
              "<fim:FIMStatusDetail MessageID='could_not_perform_token_exchange'/>",
              :error,
              extra_context: [
                { code: SAML::Responses::Base::UNKNOWN_OR_BLANK_ERROR_CODE,
                  tag: :unknown,
                  short_message: 'Other SAML Response Error(s)',
                  level: :error,
                  full_message: 'Test1' },
                { code: SAML::Responses::Base::UNKNOWN_OR_BLANK_ERROR_CODE,
                  tag: :unknown,
                  short_message: 'Other SAML Response Error(s)',
                  level: :error,
                  full_message: 'Test2' },
                { code: SAML::Responses::Base::UNKNOWN_OR_BLANK_ERROR_CODE,
                  tag: :unknown,
                  short_message: 'Other SAML Response Error(s)',
                  level: :error,
                  full_message: 'Test3' }
              ]
            )
          post(:saml_callback)
        end
      end

      context 'when saml response error contains invalid_message_timestamp' do
        let(:status_detail_xml) do
          '<samlp:StatusCode Value="urn:oasis:names:tc:SAML:2.0:status:Responder">'\
            '</samlp:StatusCode>'\
            '<samlp:StatusDetail>'\
            '<fim:FIMStatusDetail MessageID="invalid_message_timestamp"></fim:FIMStatusDetail>'\
            '</samlp:StatusDetail>'
        end
        let(:expected_error_message) { "<fim:FIMStatusDetail MessageID='invalid_message_timestamp'/>" }
        let(:extra_content) do
          [
            { code: SAML::Responses::Base::UNKNOWN_OR_BLANK_ERROR_CODE,
              tag: :unknown,
              short_message: 'Other SAML Response Error(s)',
              level: :error,
              full_message: 'Test1' },
            { code: SAML::Responses::Base::UNKNOWN_OR_BLANK_ERROR_CODE,
              tag: :unknown,
              short_message: 'Other SAML Response Error(s)',
              level: :error,
              full_message: 'Test2' },
            { code: SAML::Responses::Base::UNKNOWN_OR_BLANK_ERROR_CODE,
              tag: :unknown,
              short_message: 'Other SAML Response Error(s)',
              level: :error,
              full_message: 'Test3' }
          ]
        end
        let(:version) { 'v1' }
        let(:expected_warn_message) do
          "SessionsController version:#{version} context:#{extra_content} message:#{expected_error_message}"
        end

        before do
          allow(SAML::Responses::Login).to receive(:new).and_return(saml_response_detail_error(status_detail_xml))
        end

        it 'logs a generic user validation error', :aggregate_failures do
          expect(Rails.logger).to receive(:warn).with(expected_warn_message)
          expect(post(:saml_callback)).to redirect_to(expected_redirect)

          expect(response).to have_http_status(:found)
        end
      end

      context 'when saml response contains multiple errors (known or otherwise)' do
        let(:multi_error_uuid) { '2222' }
        let(:error_code) { '001' }

        before do
          allow(SAML::Responses::Login).to receive(:new).and_return(saml_response_multi_error(multi_error_uuid))
        end

        it 'logs a generic error' do
          expect(controller).to receive(:log_message_to_sentry)
            .with(
              'Login Failed! Subject did not consent to attribute release Multiple SAML Errors',
              :warn,
              extra_context: [{ code: SAML::Responses::Base::CLICKED_DENY_ERROR_CODE,
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
          expect(post(:saml_callback)).to redirect_to(expected_redirect)
          expect(response).to have_http_status(:found)
        end

        it 'increments the failed and total statsd counters' do
          SAMLRequestTracker.create(
            uuid: multi_error_uuid,
            payload: { type: 'idme' }
          )
          callback_tags = ['status:failure', 'context:unknown', 'version:v1']
          callback_failed_tags = ['error:clicked_deny', 'version:v1']
          login_failed_tags = ['context:idme', 'version:v1', 'client_id:', 'error:001']

          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, tags: callback_tags, **once)
            .and trigger_statsd_increment(
              described_class::STATSD_SSO_CALLBACK_FAILED_KEY, tags: callback_failed_tags, **once
            )
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)
            .and trigger_statsd_increment(described_class::STATSD_LOGIN_STATUS_FAILURE, tags: login_failed_tags)
        end

        context 'USiP user' do
          it 'logs the USiP client application' do
            SAMLRequestTracker.create(uuid: multi_error_uuid, payload: { type: 'idme', application: 'vamobile' })
            login_failed_tags = ['context:idme', 'version:v1', 'client_id:vamobile', 'error:001']

            expect { post(:saml_callback) }
              .to trigger_statsd_increment(described_class::STATSD_LOGIN_STATUS_FAILURE, tags: login_failed_tags)
          end
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
          callback_tags = ['status:success', 'context:myhealthevet', 'version:v1']
          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, tags: callback_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)
          expect(response.location).to start_with(expected_redirect_url)
          MPI::Configuration.instance.breakers_service.end_forced_outage!
        end
      end

      context 'when a required saml attribute is missing' do
        let(:saml_user_attributes) do
          loa1_user.attributes.merge(loa1_user.identity.attributes).merge(uuid: nil)
        end
        let(:error_code) { '004' }

        before { allow(SAML::User).to receive(:new).and_return(saml_user) }

        it 'logs a generic user validation error', :aggregate_failures do
          expect(controller).to receive(:log_message_to_sentry)
            .with(
              'Login Failed! on User/Session Validation',
              :error,
              extra_context: {
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
              }
            )
          expect(post(:saml_callback)).to redirect_to(expected_redirect)
          expect(response).to have_http_status(:found)
        end

        it 'increments the failed and total statsd counters' do
          callback_tags = ['status:failure', "context:#{LOA::IDME_LOA1_VETS}", 'version:v1']
          failed_tags = ['error:validations_failed', 'version:v1']

          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, tags: callback_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_FAILED_KEY, tags: failed_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)
        end

        it 'captures the invalid saml response in a PersonalInformationLog' do
          post(:saml_callback)
          expect(PersonalInformationLog.count).to be_positive
          expect(PersonalInformationLog.last.error_class).to eq('Login Failed! on User/Session Validation')
        end
      end

      context 'when MHV user attribute validation fails' do
        let(:saml_attributes) do
          build(:ssoe_idme_mhv_loa3,
                va_eauth_mhvuuid: ['999888'],
                va_eauth_mhvien: ['888777'])
        end
        let(:saml_response) do
          build_saml_response(
            authn_context: 'myhealthevet',
            level_of_assurance: ['3'],
            attributes: saml_attributes,
            existing_attributes: nil,
            issuer: 'https://int.eauth.va.gov/FIM/sps/saml20fedCSP/saml20'
          )
        end
        let(:saml_user) { SAML::User.new(saml_response) }
        let(:expected_error_message) { SAML::UserAttributeError::ERRORS[:multiple_mhv_ids][:message] }
        let(:version) { 'v1' }
        let(:expected_warn_message) do
          "SessionsController version:#{version} context:{} message:#{expected_error_message}"
        end
        let(:error_code) { '101' }

        before { allow(SAML::User).to receive(:new).and_return(saml_user) }

        it 'logs a generic user validation error', :aggregate_failures do
          expect(controller).not_to receive(:log_message_to_sentry)
          expect(Rails.logger).to receive(:warn).ordered
          expect(Rails.logger).to receive(:warn).ordered.with(expected_warn_message)
          expect(post(:saml_callback)).to redirect_to(expected_redirect)

          expect(response).to have_http_status(:found)
        end
      end

      context 'when EDIPI user attribute validation fails' do
        let(:saml_attributes) do
          build(:ssoe_idme_mhv_loa3,
                va_eauth_gcIds: ['0123456789^NI^200DOD^USDOD^A|0000000054^NI^200DOD^USDOD^A|'])
        end
        let(:saml_response) do
          build_saml_response(
            authn_context: 'myhealthevet',
            level_of_assurance: ['3'],
            attributes: saml_attributes,
            existing_attributes: nil,
            issuer: 'https://int.eauth.va.gov/FIM/sps/saml20fedCSP/saml20'
          )
        end
        let(:saml_user) { SAML::User.new(saml_response) }
        let(:error_code) { '102' }

        before { allow(SAML::User).to receive(:new).and_return(saml_user) }

        it 'redirects to the auth failed endpoint with a specific code', :aggregate_failures do
          expect(controller).to receive(:log_message_to_sentry)
          expect(post(:saml_callback)).to redirect_to(expected_redirect)
          expect(response).to have_http_status(:found)
        end
      end

      context 'when ICN user attribute validation fails' do
        let(:saml_attributes) do
          build(:ssoe_idme_mhv_loa3,
                va_eauth_mhvicn: ['11111111V222222'],
                va_eauth_icn: ['222222222V333333'])
        end
        let(:saml_response) do
          build_saml_response(
            authn_context: 'myhealthevet',
            level_of_assurance: ['3'],
            attributes: saml_attributes,
            existing_attributes: nil,
            issuer: 'https://int.eauth.va.gov/FIM/sps/saml20fedCSP/saml20'
          )
        end
        let(:saml_user) { SAML::User.new(saml_response) }
        let(:error_code) { '103' }

        before { allow(SAML::User).to receive(:new).and_return(saml_user) }

        it 'logs a generic user validation error', :aggregate_failures do
          expect(controller).to receive(:log_message_to_sentry)
          expect(post(:saml_callback)).to redirect_to(expected_redirect)
          expect(response).to have_http_status(:found)
        end
      end

      context 'when creating a user account' do
        context 'and the current user does not yet have an Account record' do
          before do
            Account.first.destroy
            expect(Account.count).to eq 0
          end

          it 'creates an Account record for the user' do
            post :saml_callback

            expect(Account.first.idme_uuid).to eq uuid
          end
        end

        context 'and the current user already has an Account record' do
          it 'does not create a new Account record for the user', :aggregate_failures do
            post :saml_callback

            expect(Account.count).to eq 1
            expect(Account.first.idme_uuid).to eq loa3_user.idme_uuid
          end
        end
      end
    end
  end
end
