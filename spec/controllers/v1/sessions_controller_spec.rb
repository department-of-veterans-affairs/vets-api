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
  let(:callback_url)        { "http://#{request_host}/v1/sessions/callback" }
  let(:logout_redirect_url) { 'http://127.0.0.1:3001/logout/' }

  let(:settings_no_context) { build(:settings_no_context_v1, assertion_consumer_service_url: callback_url) }
  let(:rubysaml_settings)   { build(:rubysaml_settings_v1, assertion_consumer_service_url: callback_url) }

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
      attributes: build(:ssoe_idme_loa1, va_eauth_ial: 3),
      in_response_to: login_uuid,
      issuer: 'https://int.eauth.va.gov/FIM/sps/saml20fedCSP/saml20'
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
    allow(SAML::SSOeSettingsService).to receive(:saml_settings).and_return(rubysaml_settings)
    allow(SAML::Responses::Login).to receive(:new).and_return(valid_saml_response)
    Redis.current.set("benchmark_api.auth.login_#{uuid}", Time.now.to_f)
    Redis.current.set("benchmark_api.auth.logout_#{uuid}", Time.now.to_f)
  end

  context 'when not logged in' do
    describe 'new' do
      context 'routes not requiring auth' do
        %w[mhv dslogon idme].each do |type|
          context "routes /sessions/#{type}/new to SessionsController#new with type: #{type}" do
            let(:authn) do
              case type
              when 'mhv'
                'myhealthevet'
              when 'idme'
                'http://idmanagement.gov/ns/assurance/loa/1/vets'
              when 'dslogon'
                'dslogon'
              end
            end

            it 'presents login form' do
              expect(SAML::SSOeSettingsService)
                .to receive(:saml_settings)
                .with(force_authn: true)

              expect { get(:new, params: { type: type, clientId: '123123' }) }
                .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                             tags: ["context:#{type}", 'version:v1'], **once)
                .and trigger_statsd_increment(described_class::STATSD_SSO_SAMLREQUEST_KEY,
                                              tags: ["type:#{type}", "context:#{authn}", 'version:v1'], **once)

              expect(response).to have_http_status(:ok)
              expect_saml_post_form(response.body, 'https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login',
                                    'originating_request_id' => nil, 'type' => type)
              expect(SAMLRequestTracker.keys.length).to eq(1)
              payload = SAMLRequestTracker.find(SAMLRequestTracker.keys[0]).payload
              expect(payload)
                .to eq({
                         type: type,
                         authn_context: authn,
                         transaction_id: payload[:transaction_id]
                       })
            end
          end
        end

        context 'routes /sessions/custom/new to SessionController#new' do
          it 'redirects for an inbound ssoe' do
            expect(SAML::SSOeSettingsService)
              .to receive(:saml_settings)
              .with(force_authn: false)

            expect { get(:new, params: { type: 'custom', authn: 'myhealthevet', clientId: '123123' }) }
              .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                           tags: ['context:custom', 'version:v1'], **once)

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
                                               tags: ['context:custom', 'version:v1'], **once)
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
        end

        context 'routes /sessions/signup/new to SessionsController#new' do
          it 'redirects' do
            expect { get(:new, params: { type: :signup, client_id: '123123' }) }
              .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                           tags: ['context:signup', 'version:v1'], **once)
            expect(response).to have_http_status(:ok)
            expect_saml_post_form(response.body, 'https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login',
                                  'originating_request_id' => nil, 'type' => 'signup')
          end
        end

        context 'routes /v1/sessions/slo/new to SessionController#new' do
          it 'redirects' do
            expect(get(:new, params: { type: :slo }))
              .to redirect_to('https://int.eauth.va.gov/pkmslogout?filename=vagov-logout.html')
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
          expect(post(:saml_callback)).to redirect_to('http://127.0.0.1:3001/auth/login/callback?auth=fail&code=005')
          expect(response).to have_http_status(:found)
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

      it 'redirect user to home page when no SAMLRequestTracker exists' do
        allow(SAML::User).to receive(:new).and_return(saml_user)
        expect(post(:saml_callback)).to redirect_to('http://127.0.0.1:3001/auth/login/callback')
      end

      context 'for a user with semantically invalid SAML attributes' do
        let(:invalid_attributes) do
          build(:ssoe_idme_mhv_loa3,
                va_eauth_mhvuuid: ['999888'],
                va_eauth_mhvien: ['888777'])
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

        it 'redirects to an auth failure page' do
          expect(controller).to receive(:log_message_to_sentry)
          expect(post(:saml_callback)).to redirect_to('http://127.0.0.1:3001/auth/login/callback?auth=fail&code=101')
          expect(response).to have_http_status(:found)
          expect(cookies['vagov_session_dev']).to be_nil
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
                                          tags: ['context:idme', 'version:v1', 'error:101'])
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_FAILED_KEY,
                                          tags: ['error:multiple_mhv_ids', 'version:v1'])

          expect(response).to have_http_status(:found)
          expect(cookies['vagov_session_dev']).to be_nil
        end
      end
    end

    describe 'track' do
      it 'ignores a SAML stat without params' do
        expect { get(:tracker) }
          .not_to trigger_statsd_increment(described_class::STATSD_SSO_SAMLTRACKER_KEY,
                                           tags: ['type:',
                                                  'context:',
                                                  'version:v1'])
      end

      it 'logs a SAML stat with valid params' do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger)
          .to receive(:info).with('SSOe: SAML Tracker => {"id"=>"1", "type"=>"mhv", "authn"=>"myhealthevet"}')
        expect { get(:tracker, params: { id: 1, type: 'mhv', authn: 'myhealthevet' }) }
          .to trigger_statsd_increment(described_class::STATSD_SSO_SAMLTRACKER_KEY,
                                       tags: ['type:mhv',
                                              'context:myhealthevet',
                                              'version:v1'])
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
          around do |example|
            Settings.sso.cookie_enabled = true
            example.run
            Settings.sso.cookie_enabled = false
          end

          context "routes /sessions/#{type}/new to SessionsController#new with type: #{type}" do
            it 'responds' do
              expect { get(:new, params: { type: type }) }
                .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                             tags: ["context:#{type}", 'version:v1'], **once)
              expect(response).to have_http_status(:ok)
              expect(cookies['vagov_session_dev']).not_to be_nil unless type.in?(%w[mhv dslogon idme slo])
              expect(cookies['vagov_saml_request_localhost']).not_to be_nil
            end
          end
        end
      end

      context 'slo routes' do
        around do |example|
          Settings.sso.cookie_enabled = true
          example.run
          Settings.sso.cookie_enabled = false
        end

        context 'routes /sessions/slo/new to SessionsController#new with type: #slo' do
          it 'redirects' do
            expect { get(:new, params: { type: 'slo' }) }
              .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                           tags: ['context:slo', 'version:v1'], **once)
            expect(response).to have_http_status(:found)
          end
        end
      end
    end

    describe 'GET sessions/slo/new' do
      before do
        mhv_account = double('mhv_account', ineligible?: false, needs_terms_acceptance?: false, upgraded?: true)
        allow(MHVAccount).to receive(:find_or_initialize_by).and_return(mhv_account)
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

          # it has the cookie set
          expect(cookies['vagov_session_dev']).not_to be_nil
          get(:new, params: { type: 'slo' })
          expect(response.location)
            .to eq('https://int.eauth.va.gov/pkmslogout?filename=vagov-logout.html')

          # these should be destroyed.
          expect(Session.find(token)).to be_nil
          expect(session).to be_empty
          expect(User.find(uuid)).to be_nil
          expect(cookies['vagov_session_dev']).to be_nil
        end
      end
    end

    it 'redirects on callback from external logout' do
      expect(get(:ssoe_slo_callback)).to redirect_to(logout_redirect_url)
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
        let(:authn_context) { LOA::IDME_LOA3 }

        it 'uplevels an LOA 1 session to LOA 3', :aggregate_failures do
          SAMLRequestTracker.create(
            uuid: login_uuid,
            payload: { type: 'verify' }
          )
          existing_user = User.find(uuid)
          expect(existing_user.last_signed_in).to be_a(Time)
          expect(existing_user.multifactor).to be_falsey
          expect(existing_user.loa).to eq(highest: LOA::ONE, current: LOA::ONE)
          expect(existing_user.ssn).to eq('796111863')
          allow(StringHelpers).to receive(:levenshtein_distance).and_return(8)
          expect(controller).to receive(:log_message_to_sentry).with(
            'SSNS DO NOT MATCH!!',
            :warn,
            identity_compared_with_mpi: {
              length: [9, 9],
              only_digits: [true, true],
              encoding: %w[UTF-8 UTF-8],
              levenshtein_distance: 8
            }
          )
          expect(Raven).to receive(:tags_context).once

          callback_tags = ['status:success', "context:#{LOA::IDME_LOA3}", 'version:v1']

          Timecop.freeze(Time.current)
          cookie_expiration_time = 30.minutes.from_now.iso8601(0)
          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, tags: callback_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)

          expect(response.location).to start_with('http://127.0.0.1:3001/auth/login/callback')

          new_user = User.find(uuid)
          expect(new_user.ssn).to eq('796111863')
          expect(new_user.va_profile.ssn).not_to eq('155256322')
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
                                         tags: ['status:success', 'context:multifactor', 'version:v1'], **once)
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

        context 'with mismatched UUIDs' do
          let(:saml_user_attributes) do
            loa3_user.attributes.merge(loa3_user.identity.attributes.merge(uuid: 'invalid', mhv_icn: '11111111111'))
          end
          let(:loa1_user) { build(:user, :loa1, uuid: uuid, idme_uuid: uuid, mhv_icn: '11111111111') }

          it 'logs a message to Sentry' do
            allow(saml_user).to receive(:changing_multifactor?).and_return(true)
            expect(Raven).to receive(:extra_context).with(current_user_uuid: uuid, current_user_icn: '11111111111')
            expect(Raven).to receive(:extra_context).with(saml_uuid: 'invalid', saml_icn: '11111111111')
            expect(Raven).to receive(:capture_message).with(
              "Couldn't locate exiting user after MFA establishment",
              level: 'warning'
            )
            expect(Raven).to receive(:capture_message).at_least(:once)
            expect(Raven).to receive(:extra_context).at_least(:once) # From PostURLService#initialize
            with_settings(Settings.sentry, dsn: 'T') do
              post(:saml_callback, params: { RelayState: '{"type": "mfa"}' })
            end
          end
        end
      end

      context 'when user has LOA current 1 and highest 3' do
        let(:saml_user_attributes) do
          loa1_user.attributes.merge(loa1_user.identity.attributes).merge(
            loa: { current: LOA::ONE, highest: LOA::THREE }
          )
        end

        it 'responds with form for idme for up-level' do
          expect(post(:saml_callback)).to have_http_status(:ok)
        end

        it 'counts the triggered SAML request' do
          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_SAMLREQUEST_KEY,
                                         tags: ['type:', "context:#{LOA::IDME_LOA3}", 'version:v1'], **once)
        end

        it 'redirects to identity proof URL', :aggregate_failures do
          Timecop.freeze(Time.current)
          expect_any_instance_of(SAML::PostURLService).to receive(:should_uplevel?).once.and_return(true)
          expect_any_instance_of(SAML::PostURLService).to receive(:verify_url).and_return(['http://uplevel', {}])
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
          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY,
                                         tags: ['status:success', "context:#{LOA::IDME_LOA1_VETS}", 'version:v1'],
                                         **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)
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
          callback_tags = ['status:failure', 'context:unknown', 'version:v1']
          failed_tags = ['error:auth_too_early', 'version:v1']

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
              extra_context: [{ code: '007',
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

      context 'when saml response contains multiple errors (known or otherwise)' do
        let(:multi_error_uuid) { '2222' }

        before do
          allow(SAML::Responses::Login).to receive(:new).and_return(saml_response_multi_error(multi_error_uuid))
        end

        it 'logs a generic error' do
          expect(controller).to receive(:log_message_to_sentry)
            .with(
              'Login Failed! Subject did not consent to attribute release Multiple SAML Errors',
              :warn,
              extra_context: [{ code: '001',
                                tag: :clicked_deny,
                                short_message: 'Subject did not consent to attribute release',
                                level: :warn,
                                full_message: 'Subject did not consent to attribute release' },
                              { code: '007',
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
          SAMLRequestTracker.create(
            uuid: multi_error_uuid,
            payload: { type: 'idme' }
          )
          callback_tags = ['status:failure', 'context:unknown', 'version:v1']
          callback_failed_tags = ['error:clicked_deny', 'version:v1']
          login_failed_tags = ['context:idme', 'version:v1', 'error:001']

          expect { post(:saml_callback) }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, tags: callback_tags, **once)
            .and trigger_statsd_increment(
              described_class::STATSD_SSO_CALLBACK_FAILED_KEY, tags: callback_failed_tags, **once
            )
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)
            .and trigger_statsd_increment(described_class::STATSD_LOGIN_STATUS_FAILURE, tags: login_failed_tags)
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
              extra_context: {
                code: '004',
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
          expect(post(:saml_callback)).to redirect_to('http://127.0.0.1:3001/auth/login/callback?auth=fail&code=004')
          expect(response).to have_http_status(:found)
          expect(cookies['vagov_session_dev']).to be_nil
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

        before { allow(SAML::User).to receive(:new).and_return(saml_user) }

        it 'logs a generic user validation error', :aggregate_failures do
          expect(controller).to receive(:log_message_to_sentry)
          expect(post(:saml_callback)).to redirect_to('http://127.0.0.1:3001/auth/login/callback?auth=fail&code=101')

          expect(response).to have_http_status(:found)
          expect(cookies['vagov_session_dev']).to be_nil
        end
      end

      context 'when EDIPI user attribute validation fails' do
        let(:saml_attributes) do
          build(:ssoe_idme_mhv_loa3,
                va_eauth_dodedipnid: ['0123456789,1111111111'])
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

        before { allow(SAML::User).to receive(:new).and_return(saml_user) }

        it 'redirects to the auth failed endpoint with a specific code', :aggregate_failures do
          expect(controller).to receive(:log_message_to_sentry)
          expect(post(:saml_callback)).to redirect_to('http://127.0.0.1:3001/auth/login/callback?auth=fail&code=102')
          expect(response).to have_http_status(:found)
          expect(cookies['vagov_session_dev']).to be_nil
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

        before { allow(SAML::User).to receive(:new).and_return(saml_user) }

        it 'logs a generic user validation error', :aggregate_failures do
          expect(controller).to receive(:log_message_to_sentry)
          expect(post(:saml_callback)).to redirect_to('http://127.0.0.1:3001/auth/login/callback?auth=fail&code=103')
          expect(response).to have_http_status(:found)
          expect(cookies['vagov_session_dev']).to be_nil
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
    end
  end
end
