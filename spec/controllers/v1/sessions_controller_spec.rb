# frozen_string_literal: true

require 'rails_helper'
require 'support/saml/form_validation_helpers'
require 'support/saml/response_builder'
require 'support/url_service_helpers'

RSpec.describe V1::SessionsController, type: :controller do
  include SAML::ResponseBuilder
  include SAML::ValidationHelpers

  # General test set-up
  let(:request_host) { '127.0.0.1:3000' }
  let(:request_id) { SecureRandom.uuid }

  # User test set-up
  let(:correlation_mpi_record) { build(:mpi_profile, ssn: correlation_mpi_ssn) }
  let(:mpi_profile) { build(:mpi_profile) }

  let(:user) { build(:user, loa, :with_terms_of_use_agreement, mpi_profile:) }
  let(:loa) { :loa3 }
  let(:token) { 'abracadabra-open-sesame' }
  let(:saml_user_attributes) { user.attributes.merge(user.identity.attributes) }
  let(:user_attributes) { double('user_attributes', saml_user_attributes) }
  let(:saml_user) do
    instance_double(SAML::User,
                    changing_multifactor?: false,
                    user_attributes:,
                    to_hash: saml_user_attributes,
                    needs_csp_id_mpi_update?: false,
                    validate!: nil)
  end

  # SAML test set-up
  let(:rubysaml_settings) { build(:rubysaml_settings, assertion_consumer_service_url: callback_url) }
  let(:callback_url) { "http://#{request_host}/v1/sessions/callback" }

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
  let(:attributes) do
    build(:ssoe_idme_loa1,
          va_eauth_ial: 3,
          va_eauth_uid: [saml_user_attributes[:idme_uuid] || saml_user_attributes[:logingov_uuid]])
  end
  let(:valid_saml_response) do
    build_saml_response(
      authn_context:,
      level_of_assurance: ['3'],
      attributes:,
      in_response_to: login_uuid,
      issuer: 'https://int.eauth.va.gov/FIM/sps/saml20fedCSP/saml20'
    )
  end

  # Helper variable
  let(:once) { { times: 1, value: 1 } }

  let(:mpi_service) { instance_double(MPI::Service) }
  let(:identifier_type) { saml_user_attributes[:sign_in][:service_name] }
  let(:identifier) { saml_user_attributes[:idme_uuid] }
  let(:find_profile_response) { create(:find_profile_response, profile: correlation_mpi_record) }
  let(:correlation_mpi_ssn) { saml_user_attributes[:ssn] }

  shared_examples 'a successful UserAudit log' do
    let(:user_verification) { user.user_verification }
    let(:event) { :sign_in }
    let!(:user_action_event) { create(:user_action_event, identifier: event) }
    let(:icn) { user.icn }
    let(:remote_ip) { Faker::Internet.ip_v4_address }
    let(:user_agent) { Faker::Internet.user_agent }
    let(:expected_log_payload) do
      {
        event: :sign_in,
        user_verification_id: user_verification.id,
        status: :success
      }
    end
    let(:expected_log_tags) { { remote_ip:, user_agent: } }
    let(:expected_audit_log_message) do
      expected_log_payload.merge(acting_ip_address: remote_ip, acting_user_agent: user_agent).as_json
    end

    before do
      allow(SemanticLogger).to receive(:named_tags).and_return(expected_log_tags)
      allow(UserAudit.logger).to receive(:success).and_call_original
    end

    it 'creates a user audit log' do
      expect { call_endpoint }.to change(Audit::Log, :count).by(1)
      expect(UserAudit.logger).to have_received(:success).with(event:, user_verification:)
    end

    it 'creates a user action' do
      expect { call_endpoint }.to change(UserAction, :count).by(1)
      expect(UserAudit.logger).to have_received(:success).with(event: :sign_in, user_verification:)
    end
  end

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
    request.remote_ip = Faker::Internet.ip_v4_address
    request.user_agent = Faker::Internet.user_agent

    allow(SAML::SSOeSettingsService).to receive(:saml_settings).and_return(rubysaml_settings)
    allow(SAML::Responses::Login).to receive(:new).and_return(valid_saml_response)
    allow_any_instance_of(ActionController::TestRequest).to receive(:request_id).and_return(request_id)
    allow(MPI::Service).to receive(:new).and_return(mpi_service)
    allow(mpi_service).to receive(:find_profile_by_identifier).with(identifier:, identifier_type:,
                                                                    view_type: 'COR')
                                                              .and_return(find_profile_response)
  end

  after do
    saml_user { nil }
    successful_logout_response { nil }
  end

  describe 'GET #new' do
    subject(:call_endpoint) { get(:new, params:) }

    context 'when not logged in' do
      context 'routes not requiring auth' do
        %w[mhv mhv_verified dslogon dslogon_verified idme idme_verified logingov logingov_verified].each do |type|
          context "routes /sessions/#{type}/new to SessionsController#new with type: #{type}" do
            let(:params) { { type:, clientId: '123123' } }
            let(:authn) do
              case type
              when 'mhv', 'mhv_verified'
                ['myhealthevet', AuthnContext::MHV]
              when 'idme'
                [LOA::IDME_LOA1_VETS, AuthnContext::ID_ME]
              when 'idme_verified'
                [LOA::IDME_LOA3, AuthnContext::ID_ME]
              when 'dslogon', 'dslogon_verified'
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
                .with(force_authn: true)
              expect { call_endpoint }
                .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                             tags: ["type:#{type}",
                                                    'version:v1',
                                                    'client_id:vaweb',
                                                    'operation:authorize'],
                                             **once)
                .and trigger_statsd_increment(described_class::STATSD_SSO_SAMLREQUEST_KEY,
                                              tags: ["type:#{type}",
                                                     "context:_#{authn&.join('_')}",
                                                     'client_id:vaweb',
                                                     'version:v1'],
                                              **once)
              expect(response).to have_http_status(:ok)
              expect(SAMLRequestTracker.keys.length).to eq(1)
              payload = SAMLRequestTracker.find(SAMLRequestTracker.keys[0]).payload
              expect(payload)
                .to eq({
                         type:,
                         authn_context: authn,
                         application: 'vaweb',
                         operation: 'authorize',
                         transaction_id: payload[:transaction_id]
                       })
            end

            context 'USiP user' do
              let(:params) { { type:, clientId: '123123', application: 'vamobile' } }

              it 'logs the USiP client application' do
                expect { call_endpoint }
                  .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                               tags: ["type:#{type}",
                                                      'version:v1',
                                                      'client_id:vamobile',
                                                      'operation:authorize'],
                                               **once)
              end
            end
          end

          context 'cerner eligiblility check' do
            let(:params) { { type:, clientId: '123123' } }
            let(:cerner_eligible_cookie) { 'CERNER_ELIGIBLE' }
            let(:expected_log_message) { '[SessionsController] Cerner Eligibility' }
            let(:expected_log_payload) { { eligible:, cookie_action: } }

            context 'when cerner eligible cookie is present' do
              let(:cookie_action) { :found }

              before do
                cookies.signed[cerner_eligible_cookie] = eligible.to_s
                allow(Rails.logger).to receive(:info)
              end

              context 'when cerner eligible cookie is true' do
                let(:eligible) { true }

                it 'logs the cerner eligibility' do
                  call_endpoint

                  expect(Rails.logger).to have_received(:info).with(expected_log_message, expected_log_payload)
                end
              end

              context 'when cerner eligible cookie is false' do
                let(:eligible) { false }

                it 'logs the cerner eligibility' do
                  call_endpoint

                  expect(Rails.logger).to have_received(:info).with(expected_log_message, expected_log_payload)
                end
              end
            end

            context 'when cerner eligible cookie is not present' do
              let(:cookie_action) { :not_found }
              let(:eligible) { :unknown }

              before do
                cookies.delete(cerner_eligible_cookie)
                allow(Rails.logger).to receive(:info)
              end

              it 'logs the cerner eligibility' do
                call_endpoint

                expect(Rails.logger).to have_received(:info).with(expected_log_message, expected_log_payload)
              end
            end
          end
        end

        context 'when type is idme_verified' do
          context 'and the operation param is valid' do
            let(:params) { { type: 'idme_verified', clientId: '123123', operation: 'interstitial_verify' } }

            it 'does not raise an error and triggers statsd' do
              expect { call_endpoint }
                .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                             tags: ['type:idme_verified',
                                                    'version:v1',
                                                    'client_id:vaweb',
                                                    'operation:interstitial_verify'],
                                             **once)
              expect(response).to have_http_status(:success)
            end
          end

          context 'and the operation param is invalid' do
            subject(:call_endpoint) { get(:new, params:) }

            let(:params) { { type: 'idme_verified', clientId: '123123', operation: 'asdf' } }

            it 'responds with bad request' do
              call_endpoint
              expect(response).to have_http_status(:bad_request)
              errors = response.parsed_body['errors']
              expect(errors).to eq([{ 'title' => 'Invalid field value',
                                      'detail' =>
                                        '"asdf" is not a valid value for "operation"',
                                      'code' => '103',
                                      'status' => '400' }])
            end
          end
        end

        context 'when type is custom' do
          context 'logingov inbound ssoe' do
            let(:params) do
              { type: 'custom', csp_type: 'logingov', ial: IAL::TWO, client_id: '123123', operation: 'authorize' }
            end

            it 'redirects for an inbound ssoe' do
              expect(SAML::SSOeSettingsService)
                .to receive(:saml_settings)
                .with(force_authn: false)

              expect { call_endpoint }
                .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                             tags: ['type:custom',
                                                    'version:v1',
                                                    'client_id:vaweb',
                                                    'operation:authorize'],
                                             **once)
                .and trigger_statsd_increment(described_class::STATSD_SSO_SAMLREQUEST_KEY,
                                              tags: ['type:custom',
                                                     "context:#{IAL::LOGIN_GOV_IAL2}",
                                                     'client_id:vaweb',
                                                     'version:v1'],
                                              **once)
              expect(response).to have_http_status(:ok)
              expect_saml_post_form(response.body, 'https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login',
                                    'originating_request_id' => nil, 'type' => 'custom')
              expect(SAMLRequestTracker.keys.length).to eq(1)
              payload = SAMLRequestTracker.find(SAMLRequestTracker.keys[0]).payload
              expect(payload)
                .to eq({
                         type: 'custom',
                         authn_context: IAL::LOGIN_GOV_IAL2,
                         application: payload[:application],
                         operation: payload[:operation],
                         transaction_id: payload[:transaction_id]
                       })
            end

            context 'when missing ial parameter' do
              let(:params) { { type: :custom, csp_type: 'logingov', ial: '', client_id: '123123' } }

              it 'raises exception' do
                expect { call_endpoint }
                  .not_to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                                   tags: ['type:custom',
                                                          'version:v1',
                                                          'client_id:vaweb',
                                                          'operation:authorize'],
                                                   **once)
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
            end

            context 'when ial parameter is not 1 or 2' do
              let(:params) { { type: :custom, csp_type: 'logingov', ial: '3', client_id: '123123' } }

              it 'raises exception when ial parameter is not 1 or 2' do
                expect { call_endpoint }
                  .not_to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                                   tags: ['type:custom',
                                                          'version:v1',
                                                          'client_id:vaweb',
                                                          'operation:authorize'],
                                                   **once)
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
          end

          context 'dslogon mhv idme inbound ssoe' do
            let(:params) { { type: 'custom', authn: 'myhealthevet', clientId: '123123', operation: 'authorize' } }

            it 'redirects for an inbound ssoe' do
              expect(SAML::SSOeSettingsService)
                .to receive(:saml_settings)
                .with(force_authn: false)

              expect { call_endpoint }
                .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                             tags: ['type:custom',
                                                    'version:v1',
                                                    'client_id:vaweb',
                                                    'operation:authorize'],
                                             **once)

              expect(response).to have_http_status(:ok)
              expect_saml_post_form(response.body, 'https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login',
                                    'originating_request_id' => nil, 'type' => 'custom')
              expect(SAMLRequestTracker.keys.length).to eq(1)
              payload = SAMLRequestTracker.find(SAMLRequestTracker.keys[0]).payload
              expect(payload)
                .to eq({
                         type: 'custom',
                         authn_context: 'myhealthevet',
                         application: payload[:application],
                         operation: payload[:operation],
                         transaction_id: payload[:transaction_id]
                       })
            end

            context 'when missing authn parameter' do
              let(:params) { { type: :custom, authn: '', client_id: '123123' } }

              it 'raises exception' do
                expect { call_endpoint }
                  .not_to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                                   tags: ['type:custom',
                                                          'version:v1',
                                                          'client_id:vaweb',
                                                          'operation:authorize'],
                                                   **once)
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

            context 'when authn parameter is not in list of AUTHN_CONTEXTS' do
              let(:params) { { type: :custom, authn: 'qwerty', client_id: '123123' } }

              it 'raises exception' do
                expect { call_endpoint }
                  .not_to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                                   tags: ['type:custom',
                                                          'version:v1',
                                                          'client_id:vaweb',
                                                          'operation:authorize'],
                                                   **once)
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
        end

        context 'when type is idme_signup' do
          let(:params) { { type: :idme_signup, client_id: '123123' } }

          it 'routes /sessions/idme_signup/new to SessionsController#new' do
            expect { call_endpoint }
              .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                           tags: ['type:idme_signup',
                                                  'version:v1',
                                                  'client_id:vaweb',
                                                  'operation:authorize'],
                                           **once)
            expect(response).to have_http_status(:ok)
            expect_saml_post_form(response.body, 'https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login',
                                  'originating_request_id' => nil, 'type' => 'signup')
          end
        end

        context 'when type is idme_signup_verified' do
          let(:params) { { type: :idme_signup_verified, client_id: '123123' } }

          it 'routes /sessions/idme_signup_verified/new to SessionsController#new' do
            expect { call_endpoint }
              .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                           tags: ['type:idme_signup_verified',
                                                  'version:v1',
                                                  'client_id:vaweb',
                                                  'operation:authorize'],
                                           **once)
            expect(response).to have_http_status(:ok)
            expect_saml_post_form(response.body, 'https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login',
                                  'originating_request_id' => nil, 'type' => 'signup')
          end
        end

        context 'when type is logingov_signup' do
          let(:params) { { type: :logingov_signup, client_id: '123123' } }

          it 'routes /sessions/logingov_signup/new to SessionsController#new' do
            expect { call_endpoint }
              .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                           tags: ['type:logingov_signup',
                                                  'version:v1',
                                                  'client_id:vaweb',
                                                  'operation:authorize'],
                                           **once)
            expect(response).to have_http_status(:ok)
            expect_saml_post_form(response.body, 'https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login',
                                  'originating_request_id' => nil, 'type' => 'signup')
          end
        end

        context 'when type is logingov_signup_verified' do
          let(:params) { { type: :logingov_signup_verified, client_id: '123123' } }

          it 'routes /sessions/logingov_signup_verified/new to SessionsController#new' do
            expect { call_endpoint }
              .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                           tags: ['type:logingov_signup_verified',
                                                  'version:v1',
                                                  'client_id:vaweb',
                                                  'operation:authorize'],
                                           **once)
            expect(response).to have_http_status(:ok)
            expect_saml_post_form(response.body, 'https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login',
                                  'originating_request_id' => nil, 'type' => 'signup')
          end
        end

        context 'when type is slo' do
          let(:params) { { type: :slo } }
          let(:expected_redirect_url) { "https://int.eauth.va.gov/slo/globallogout?appKey=#{expected_app_key}" }
          let(:expected_app_key) { 'https%253A%252F%252Fssoe-sp-dev.va.gov' }

          it 'redirects to eauth' do
            expect(call_endpoint).to redirect_to(expected_redirect_url)
          end

          it 'routes /v1/sessions/slo/new to SessionController#new' do
            expect { call_endpoint }
              .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                           tags: ['type:slo',
                                                  'version:v1',
                                                  'client_id:vaweb',
                                                  'operation:authorize'],
                                           **once)
            expect(response).to have_http_status(:found)
          end

          context 'when agreements_declined is true' do
            let(:params) { { type: :slo, agreements_declined: true } }
            let(:expected_app_key) { 'https%253A%252F%252Fdev-api.va.gov%252Fagreements_declined' }

            it 'redirects to eauth with app key expected path' do
              expect(call_endpoint).to redirect_to(expected_redirect_url)
            end
          end
        end

        context 'when type is mhv' do
          let(:params) { { type:, operation: } }
          let(:type) { 'mhv' }
          let(:expected_tags) do
            [
              "type:#{type}",
              'version:v1',
              'client_id:vaweb',
              "operation:#{operation}"
            ]
          end

          context 'when operation is mhv_exception' do
            let(:operation) { 'mhv_exception' }

            it 'increments statsd with the expected tags' do
              expect do
                call_endpoint
              end.to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY, tags: expected_tags, **once)

              expect(response).to have_http_status(:ok)
            end
          end
        end
      end

      context 'routes requiring auth' do
        %w[mfa verify].each do |type|
          let(:params) { { type: } }

          it "routes /sessions/#{type}/new to SessionsController#new with type: #{type}" do
            call_endpoint
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

    context 'sign in service cookies deletion' do
      let(:params) { { type: 'idme' } }

      let(:access_token_cookie_name) { SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME }
      let(:anti_csrf_cookie_name) { SignIn::Constants::Auth::ANTI_CSRF_COOKIE_NAME }
      let(:info_cookie_name) { SignIn::Constants::Auth::INFO_COOKIE_NAME }
      let(:refresh_token_cookie_name) { SignIn::Constants::Auth::REFRESH_TOKEN_COOKIE_NAME }

      let(:expected_expiration_time) { Time.at(0).utc.httpdate }
      let(:expected_value) { '' }
      let(:expected_info_cookie_domain) { IdentitySettings.sign_in.info_cookie_domain }
      let(:expected_path) { '/' }

      let(:expected_access_token_cookie) do
        a_string_including(
          "#{access_token_cookie_name}=#{expected_value}",
          "path=#{expected_path}",
          "expires=#{expected_expiration_time}"
        )
      end

      let(:expected_anti_csrf_cookie) do
        a_string_including(
          "#{anti_csrf_cookie_name}=#{expected_value}",
          "path=#{expected_path}",
          "expires=#{expected_expiration_time}"
        )
      end

      let(:expected_info_cookie) do
        a_string_including(
          "#{info_cookie_name}=#{expected_value}",
          "domain=#{expected_info_cookie_domain}",
          "path=#{expected_path}",
          "expires=#{expected_expiration_time}"
        )
      end

      let(:expected_refresh_token_cookie) do
        a_string_including(
          "#{refresh_token_cookie_name}=#{expected_value}",
          "path=#{expected_path}",
          "expires=#{expected_expiration_time}"
        )
      end

      before do
        cookies[access_token_cookie_name] = 'some_access_token_value'
        cookies[anti_csrf_cookie_name] = 'some_anti_csrf_token_value'
        cookies[info_cookie_name] = { value: 'some_info_value', domain: expected_info_cookie_domain }
        cookies[refresh_token_cookie_name] = { value: 'some_access_token_value', path: 'some/path' }
      end

      it 'sets the cookies with a blank value and expiration in the past' do
        call_endpoint

        set_cookies = response.headers['Set-Cookie'].to_s.split("\n")

        expect(set_cookies).to include(
          expected_access_token_cookie,
          expected_anti_csrf_cookie,
          expected_info_cookie,
          expected_refresh_token_cookie
        )
      end
    end

    context 'when logged in' do
      let(:loa1_user) { build(:user, :loa1) }

      before do
        allow(SAML::User).to receive(:new).and_return(saml_user)
        session_object = Session.create(uuid: loa1_user.uuid, token:)
        session_object.to_hash.each { |k, v| session[k] = v }
        loa1 = User.create(loa1_user.attributes)
        UserIdentity.create(loa1_user.identity.attributes)
        sign_in_as(loa1, token)
      end

      %w[mhv dslogon idme mfa verify].each do |type|
        context "routes /sessions/#{type}/new to SessionsController#new with type: #{type}" do
          let(:params) { { type: } }

          it 'does not delete cookies' do
            expect { call_endpoint }
              .to trigger_statsd_increment(described_class::STATSD_SSO_NEW_KEY,
                                           tags: ["type:#{type}",
                                                  'version:v1',
                                                  'client_id:vaweb',
                                                  'operation:authorize'],
                                           **once)
            expect(response).to have_http_status(:ok)
            expect(cookies['vagov_saml_request_localhost']).not_to be_nil
          end
        end
      end

      context 'when type is slo' do
        let(:params) { { type: 'slo' } }
        let(:expected_redirect_url) { "https://int.eauth.va.gov/slo/globallogout?appKey=#{expected_app_key}" }
        let(:expected_app_key) { 'https%253A%252F%252Fssoe-sp-dev.va.gov' }

        it 'destroys the user, session, and cookie, persists logout_request object, sets url to SLO url' do
          # these should not have been destroyed yet
          verify_session_cookie
          expect(User.find(loa1_user.user_account.id)).not_to be_nil

          call_endpoint
          expect(response.location).to eq(expected_redirect_url)

          # these should be destroyed.
          expect(Session.find(token)).to be_nil
          expect(session).to be_empty
          expect(User.find(loa1_user.user_account.id)).to be_nil
        end

        context 'when agreements_declined is true' do
          let(:params) { { type: 'slo', agreements_declined: true } }
          let(:expected_app_key) { 'https%253A%252F%252Fdev-api.va.gov%252Fagreements_declined' }

          it 'destroys the user, session, and cookie, persists logout_request object, sets url to SLO url' do
            verify_session_cookie
            expect(User.find(loa1_user.user_account.id)).not_to be_nil

            call_endpoint
            expect(response.location).to eq(expected_redirect_url)

            expect(Session.find(token)).to be_nil
            expect(session).to be_empty
            expect(User.find(loa1_user.user_account.id)).to be_nil
          end
        end
      end
    end
  end

  describe 'GET #ssoe_slo_callback' do
    subject(:call_endpoint) { get :ssoe_slo_callback, params: }

    let(:params) { {} }

    it 'redirects on callback from external logout' do
      expect(call_endpoint).to redirect_to('http://127.0.0.1:3001/logout/')
    end

    context 'when agreements_declined is true' do
      let(:params) { { agreements_declined: true } }
      let(:expected_redirect_url) { 'http://127.0.0.1:3001/terms-of-use/declined' }

      it 'redirects to terms-of-use-declined-page' do
        expect(call_endpoint).to redirect_to(expected_redirect_url)
      end
    end
  end

  describe 'POST #saml_callback' do
    subject(:call_endpoint) { post :saml_callback, params: }

    let(:params) { {} }

    let(:expected_redirect_url) { 'http://127.0.0.1:3001/auth/login/callback' }
    let(:error_code) { '007' }
    let(:expected_redirect_params) { { auth: 'fail', code: error_code, request_id: }.to_query }
    let(:expected_redirect) do
      uri = URI.parse(expected_redirect_url)
      uri.query = expected_redirect_params
      uri.to_s
    end

    context 'when too much time passed to consume the SAML Assertion' do
      let(:error_code) { '005' }

      before { allow(SAML::Responses::Login).to receive(:new).and_return(saml_response_too_late) }

      it 'redirects to an auth failure page' do
        expect(Rails.logger)
          .to receive(:error).with(
            '[V1][Sessions Controller] error',
            hash_including(message: /#{SAML::Responses::Login::ERRORS[:auth_too_late][:short_message]}/)
          )
        expect(call_endpoint).to redirect_to(expected_redirect)
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(expected_redirect)
      end
    end

    context 'when user has level of assurance 1' do
      let(:loa) { :loa1 }

      before { allow(SAML::User).to receive(:new).and_return(saml_user) }

      context 'when user has not accepted the current terms of use' do
        let(:user) { build(:user, loa) }
        let(:application) { 'some-applicaton' }

        before do
          SAMLRequestTracker.create(uuid: login_uuid, payload: { type: 'idme', application: })
        end

        context 'and authentication occurred with a application in IdentitySettings.terms_of_use.enabled_clients' do
          before do
            allow(IdentitySettings.terms_of_use).to receive(:enabled_clients).and_return(application)
          end

          context 'when the application is not in SKIP_MHV_ACCOUNT_CREATION_CLIENTS' do
            it 'redirects to terms of use page' do
              expect(call_endpoint).to redirect_to(
                'http://127.0.0.1:3001/terms-of-use?redirect_url=http%3A%2F%2F127.0.0.1%3A3001%2Fauth%2Flogin%2Fcallback'
              )
            end
          end

          context 'when the application is in SKIP_MHV_ACCOUNT_CREATION_CLIENTS' do
            let(:application) { 'mhv' }

            it 'redirects to terms of use page with skip_mhv_account_creation query param' do
              expect(call_endpoint).to redirect_to(a_string_including('skip_mhv_account_creation=true'))
            end
          end
        end

        context 'and auth occurred with an application not in IdentitySettings.terms_of_use.enabled_clients' do
          before do
            allow(IdentitySettings.terms_of_use).to receive(:enabled_clients).and_return('')
          end

          it 'redirects to expected auth page' do
            expect(call_endpoint).to redirect_to(expected_redirect_url)
          end
        end
      end

      context 'when user has accepted the current terms of use' do
        it 'redirects to expected auth page' do
          expect(call_endpoint).to redirect_to(expected_redirect_url)
        end
      end

      context 'after redirecting the client' do
        it_behaves_like 'a successful UserAudit log'
      end
    end

    context 'when user has level of assurance 3' do
      let(:loa) { :loa3 }

      before { allow(SAML::User).to receive(:new).and_return(saml_user) }

      context 'when user has not accepted the current terms of use' do
        let(:user) { build(:user, loa) }
        let(:application) { 'some-applicaton' }

        before do
          SAMLRequestTracker.create(uuid: login_uuid, payload: { type: 'idme', application: })
        end

        context 'and authentication occurred with a application in IdentitySettings.terms_of_use.enabled_clients' do
          before do
            allow(IdentitySettings.terms_of_use).to receive(:enabled_clients).and_return(application)
          end

          context 'when the application is not in SKIP_MHV_ACCOUNT_CREATION_CLIENTS' do
            it 'redirects to terms of use page' do
              expect(call_endpoint).to redirect_to(
                'http://127.0.0.1:3001/terms-of-use?redirect_url=http%3A%2F%2F127.0.0.1%3A3001%2Fauth%2Flogin%2Fcallback'
              )
            end
          end

          context 'when the application is in SKIP_MHV_ACCOUNT_CREATION_CLIENTS' do
            let(:application) { 'mhv' }

            it 'redirects to terms of use page with skip_mhv_account_creation query param' do
              expect(call_endpoint).to redirect_to(a_string_including('skip_mhv_account_creation=true'))
            end
          end
        end

        context 'and auth occurred with an application not in IdentitySettings.terms_of_use.enabled_clients' do
          before do
            allow(IdentitySettings.terms_of_use).to receive(:enabled_clients).and_return('')
          end

          it 'redirects to expected auth page' do
            expect(call_endpoint).to redirect_to(expected_redirect_url)
          end
        end
      end

      context 'when user has accepted the current terms of use' do
        it 'redirects to expected auth page' do
          expect(call_endpoint).to redirect_to(expected_redirect_url)
        end
      end

      context 'after redirecting the client' do
        it_behaves_like 'a successful UserAudit log'
      end

      context 'when cerner eligibility is checked' do
        let(:user) { build(:user, :loa3, cerner_id:) }
        let(:cerner_id) { 'some-cerner-id' }
        let(:cerner_eligible_cookie) { 'CERNER_ELIGIBLE' }
        let(:expected_log_message) { '[SessionsController] Cerner Eligibility' }
        let(:previous_value) { nil }
        let(:expected_log_payload) { { eligible:, previous_value:, cookie_action: :set, icn: user.icn } }

        before do
          SAMLRequestTracker.create(uuid: login_uuid, payload: { type: 'idme', application: 'some-applicaton' })
          allow(Rails.logger).to receive(:info)
        end

        context 'when the cerner eligible cookie is not present' do
          before do
            allow(IdentitySettings.sign_in).to receive(:info_cookie_domain).and_return('some-domain')
          end

          context 'when the user is cerner eligible' do
            let(:eligible) { true }

            it 'sets the cookie and logs the cerner eligibility' do
              call_endpoint

              expect(response.headers['set-cookie']).to include('domain=some-domain')
              expect(cookies[cerner_eligible_cookie]).to eq(eligible.to_s)
              expect(Rails.logger).to have_received(:info).with(expected_log_message, expected_log_payload)
            end
          end

          context 'when the user is not cerner eligible' do
            let(:cerner_id) { nil }
            let(:eligible) { false }

            it 'sets the cookie and logs the cerner eligibility' do
              call_endpoint

              expect(cookies[cerner_eligible_cookie]).to eq(eligible.to_s)
              expect(Rails.logger).to have_received(:info).with(expected_log_message, expected_log_payload)
            end
          end
        end

        context 'when the cerner eligible cookie is present' do
          let(:eligible) { true }
          let(:previous_value) { true }

          before do
            cookies[cerner_eligible_cookie] = true
          end

          it 'logs the cerner eligibility with the previous value' do
            call_endpoint

            expect(Rails.logger).to have_received(:info).with(expected_log_message, expected_log_payload)
          end
        end

        context 'when the correlation mpi ssn does not match the saml response ssn' do
          let(:correlation_mpi_ssn) { '123456789' }
          let(:expected_log_message) { '[V1][Sessions Controller] error' }
          let(:expected_log_payload) do
            {
              message: "Attribute mismatch: ssn in primary view doesn't match correlation record",
              context: {
                icn: saml_user_attributes[:mhv_icn],
                credential_uuid: saml_user_attributes[:idme_uuid],
                type: saml_user_attributes[:sign_in][:service_name]
              }
            }
          end
          let(:expected_redirect_params) { { auth: 'fail', code: '113', request_id: }.to_query }

          before do
            allow(Rails.logger).to receive(:error)
            allow(SAML::User).to receive(:new).and_return(saml_user)
            SAMLRequestTracker.create(uuid: login_uuid, payload: { type: 'idme', application: 'some-applicaton' })
            call_endpoint
          end

          it 'logs the correlation error' do
            expect(Rails.logger).to have_received(:error).with(expected_log_message, expected_log_payload)
          end

          it 'responds with a correlation error message and code' do
            expect(call_endpoint).to redirect_to(expected_redirect)
          end
        end
      end
    end

    context 'for a user with semantically invalid SAML attributes' do
      let(:params) { { RelayState: '{"type": "idme"}' } }
      let(:expected_redirect_params) { { auth: 'fail', code: error_code, request_id:, type: 'idme' }.to_query }
      let(:error_code) { '102' }
      let(:error_message) do
        ['[V1][Sessions Controller] error',
         { context: {}, message: 'User attributes contain multiple distinct EDIPI values' }]
      end
      let(:invalid_attributes) do
        build(:ssoe_idme_mhv_loa3, va_eauth_gcIds: ['0123456789^NI^200DOD^USDOD^A|0000000054^NI^200DOD^USDOD^A|'])
      end
      let(:valid_saml_response) do
        build_saml_response(
          authn_context:,
          level_of_assurance: ['3'],
          attributes: invalid_attributes,
          in_response_to: login_uuid,
          issuer: 'https://int.eauth.va.gov/FIM/sps/saml20fedCSP/saml20'
        )
      end

      it 'redirects to an auth failure page' do
        expect(Rails.logger).to receive(:error).with(*error_message)

        expect(call_endpoint).to redirect_to(expected_redirect)
        expect(response).to have_http_status(:found)
      end

      it 'logs a status failure stat' do
        SAMLRequestTracker.create(
          uuid: login_uuid,
          payload: { type: 'idme', application: 'vaweb' }
        )
        expect(Rails.logger).to receive(:error).with(*error_message)
        expect { call_endpoint }
          .to trigger_statsd_increment(described_class::STATSD_SSO_SAMLRESPONSE_KEY,
                                       tags: ['type:idme',
                                              'client_id:vaweb',
                                              'context:http://idmanagement.gov/ns/assurance/loa/1/vets',
                                              'version:v1'])
          .and trigger_statsd_increment(described_class::STATSD_LOGIN_STATUS_FAILURE,
                                        tags: ['type:idme',
                                               'version:v1',
                                               'client_id:vaweb',
                                               'operation:authorize',
                                               'error:102'])
          .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_FAILED_KEY,
                                        tags: ['error:multiple_edipis', 'version:v1'])

        expect(response).to have_http_status(:found)
      end

      context 'USiP user' do
        it 'logs the USiP client application' do
          SAMLRequestTracker.create(uuid: login_uuid, payload: { type: 'idme', application: 'vamobile' })
          login_failed_tags = ['type:idme', 'version:v1', 'client_id:vamobile', 'operation:authorize', 'error:102']

          expect { call_endpoint }
            .to trigger_statsd_increment(described_class::STATSD_LOGIN_STATUS_FAILURE, tags: login_failed_tags)
        end
      end
    end

    context 'when authenticated type is mhv_verified' do
      let(:params) { { RelayState: type_param.to_json } }
      let(:type_param) { { type: } }
      let(:type) { 'mhv_verified' }

      context 'and authenticated user is loa three' do
        let(:loa) { :loa3 }

        it 'makes a call to AfterLoginActions' do
          allow(SAML::User).to receive(:new).and_return(saml_user)
          expect_any_instance_of(Login::AfterLoginActions).to receive(:perform)
          call_endpoint
        end
      end

      context 'and authenticated user is loa one' do
        let(:loa) { :loa1 }
        let(:error_code) { SAML::UserAttributeError::MHV_UNVERIFIED_BLOCKED_CODE }
        let(:expected_redirect_params) { { auth: 'fail', code: error_code, request_id:, type: }.to_query }
        let(:expected_error_message) do
          ['[V1][Sessions Controller] error', {
            context: {},
            message: 'MHV account is unverified for context requiring verified account'
          }]
        end

        it 'redirects to an auth failure page' do
          expect(Rails.logger).to receive(:error).with(*expected_error_message)
          expect(call_endpoint).to redirect_to(expected_redirect)
          expect(response).to have_http_status(:found)
        end
      end
    end

    context 'when user already logged in' do
      let(:loa1_user) { build(:user, :loa1, uuid: user.uuid, idme_uuid: user.idme_uuid) }

      before do
        allow(SAML::User).to receive(:new).and_return(saml_user)
        session_object = Session.create(uuid: loa1_user.uuid, token:)
        session_object.to_hash.each { |k, v| session[k] = v }
        loa1 = User.create(loa1_user.attributes)
        UserIdentity.create(loa1_user.identity.attributes)
        sign_in_as(loa1, token)
      end

      it 'sets the session cookie' do
        call_endpoint
        verify_session_cookie
      end

      context 'verifying' do
        let(:authn_context) { IAL::LOGIN_GOV_IAL1 }

        it 'uplevels an LOA 1 session to LOA 3', :aggregate_failures do
          SAMLRequestTracker.create(
            uuid: login_uuid,
            payload: { type: 'verify', application: 'vaweb', operation: 'authorize' }
          )
          existing_user = User.find(loa1_user.uuid)
          expect(existing_user.last_signed_in).to be_a(Time)
          expect(existing_user.multifactor).to be_falsey
          expect(existing_user.loa).to eq(highest: IAL::ONE, current: IAL::ONE)
          expect(existing_user.ssn).to eq('796111863')
          expect(Sentry).to receive(:set_tags).once

          callback_tags = ['status:success',
                           "context:#{IAL::LOGIN_GOV_IAL1}",
                           'version:v1',
                           'type:verify',
                           'client_id:vaweb',
                           'operation:authorize']

          new_user_sign_in = 30.minutes.from_now
          Timecop.freeze(new_user_sign_in)
          expect { call_endpoint }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, tags: callback_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)

          expect(response.location).to start_with(expected_redirect_url)

          new_user = User.find(loa1_user.uuid)
          expect(new_user.ssn).to eq('796111863')
          expect(new_user.ssn_mpi).not_to eq('155256322')
          expect(new_user.loa).to eq(highest: LOA::THREE, current: LOA::THREE)
          expect(new_user.multifactor).to be_falsey
          expect(new_user.last_signed_in).not_to eq(existing_user.last_signed_in)
          Timecop.return
        end

        context 'USiP user' do
          let(:params) { { RelayState: '{"type": "idme"}' } }

          before do
            SAMLRequestTracker.create(uuid: login_uuid, payload: { type: 'idme', application: 'vamobile' })
          end

          it 'logs the USiP client application' do
            callback_tags = ['type:idme', 'version:v1', 'client_id:vamobile', 'operation:authorize']

            expect { call_endpoint }
              .to trigger_statsd_increment(described_class::STATSD_LOGIN_STATUS_SUCCESS, tags: callback_tags, **once)
          end
        end

        context 'UserIdentity & MPI ID validations' do
          let(:mpi_profile) { build(:mpi_profile) }
          let(:user) { build(:user, :loa3, mpi_profile:) }
          let(:expected_error_data) do
            { identity_value: expected_identity_value, mpi_value: expected_mpi_value, icn: user.icn }
          end
          let(:expected_error_message) do
            "[SessionsController version:v1] User Identity & MPI #{validation_id} values conflict"
          end

          before { allow(Rails.logger).to receive(:warn) }

          shared_examples 'identity-mpi id validation' do
            it 'logs a warning when Identity & MPI values conflict' do
              expect(Rails.logger).to receive(:warn).at_least(:once).with(expected_error_message, expected_error_data)
              call_endpoint
            end
          end

          context 'ssn validation' do
            let(:expected_identity_value) { user.identity.ssn }
            let(:expected_mpi_value) { user.ssn_mpi }
            let(:validation_id) { 'SSN' }
            let(:expected_error_data) { { icn: user.icn } }

            it_behaves_like 'identity-mpi id validation'
          end

          context 'edipi validation' do
            let(:mpi_profile) { build(:mpi_profile, edipi: Faker::Number.number(digits: 10)) }
            let(:expected_identity_value) { user.identity.edipi }
            let(:expected_mpi_value) { user.edipi_mpi }
            let(:validation_id) { 'EDIPI' }

            it_behaves_like 'identity-mpi id validation'
          end

          context 'icn validation' do
            let(:mpi_profile) { build(:mpi_profile, icn: 'some-mpi-icn') }
            let(:expected_identity_value) { user.identity.icn }
            let(:expected_mpi_value) { user.mpi_icn }
            let(:validation_id) { 'ICN' }

            it_behaves_like 'identity-mpi id validation'
          end
        end
      end

      context 'changing multifactor' do
        let(:loa) { :loa1 }
        let(:authn_context) { 'multifactor' }
        let(:saml_user_attributes) do
          user.attributes.merge(user.identity.attributes).merge(multifactor: 'true')
        end

        it 'changes the multifactor to true, time is the same', :aggregate_failures do
          existing_user = User.find(loa1_user.uuid)
          expect(existing_user.last_signed_in).to be_a(Time)
          expect(existing_user.multifactor).to be_falsey
          expect(existing_user.loa).to eq(highest: LOA::ONE, current: LOA::ONE)
          allow(saml_user).to receive(:changing_multifactor?).and_return(true)
          call_endpoint
          new_user = User.find(loa1_user.uuid)
          expect(new_user.loa).to eq(highest: LOA::ONE, current: LOA::ONE)
          expect(new_user.multifactor).to be_truthy
          expect(new_user.last_signed_in).to eq(existing_user.last_signed_in)
        end

        context 'with mismatched UUIDs' do
          let(:params) { { RelayState: '{"type": "mfa"}' } }
          let(:loa1_user) { build(:user, :loa1, uuid: user.uuid, idme_uuid: user.idme_uuid, mhv_icn: '11111111111') }
          let(:loa3_user) { build(:user, :loa3, uuid: user.uuid, idme_uuid: user.idme_uuid, mhv_icn: '11111111111') }
          let(:saml_user_attributes) do
            loa3_user.attributes.merge(loa3_user.identity.attributes.merge(mhv_icn: '11111111111'))
          end

          before do
            allow_any_instance_of(UserAccount).to receive(:id).and_return('invalid')
            allow(User).to receive(:find).with(user.uuid).and_return(loa1_user)
            allow(User).to receive(:find).with('invalid').and_return(nil)
          end

          it 'logs a message to Sentry' do
            allow(saml_user).to receive(:changing_multifactor?).and_return(true)
            expect(Sentry).to receive(:set_extras).with(current_user_uuid: user.uuid, current_user_icn: '11111111111')
            expect(Rails.logger).to receive(:warn).with(
              "[UserSessionForm] Couldn't locate existing user after MFA establishment",
              saml_uuid: 'invalid',
              saml_icn: '11111111111'
            )
            expect(Sentry).to receive(:set_extras).at_least(:once) # From PostURLService#initialize
            with_settings(Settings.sentry, dsn: 'T') { call_endpoint }
          end
        end
      end

      context 'when user has LOA current 1 and highest nil' do
        let(:loa) { :loa1 }
        let(:saml_user_attributes) do
          user.attributes.merge(user.identity.attributes).merge(
            loa: { current: nil, highest: nil }
          )
        end
        let(:error_code) { '004' }

        it 'handles no loa_highest present on new user_identity' do
          expect(call_endpoint).to redirect_to(expected_redirect)
        end
      end

      context 'when user clicked DENY' do
        let(:error_code) { '001' }

        before { allow(SAML::Responses::Login).to receive(:new).and_return(saml_response_click_deny) }

        it 'redirects to an auth failure page' do
          expect(Sentry).to receive(:set_tags).once
          expect(Rails.logger)
            .to receive(:error).with(
              '[V1][Sessions Controller] error',
              hash_including(message: /#{SAML::Responses::Login::ERRORS[:clicked_deny][:short_message]}/)
            )
          expect(call_endpoint).to redirect_to(expected_redirect)
          expect(response).to have_http_status(:found)
        end
      end

      context 'when too much time passed to consume the SAML Assertion' do
        let(:error_code) { '002' }

        before { allow(SAML::Responses::Login).to receive(:new).and_return(saml_response_too_late) }

        it 'redirects to an auth failure page' do
          expect(Rails.logger)
            .to receive(:error).with(
              '[V1][Sessions Controller] error',
              hash_including(message: /#{SAML::Responses::Login::ERRORS[:auth_too_late][:short_message]}/)
            )
          expect(call_endpoint).to redirect_to(expected_redirect)
          expect(response).to have_http_status(:found)
        end
      end

      context 'when clock drift causes us to consume the Assertion before its creation' do
        let(:error_code) { '003' }

        before { allow(SAML::Responses::Login).to receive(:new).and_return(saml_response_too_early) }

        it 'redirects to an auth failure page', :aggregate_failures do
          expect(Rails.logger)
            .to receive(:error).with(
              '[V1][Sessions Controller] error',
              hash_including(message: /#{SAML::Responses::Login::ERRORS[:auth_too_early][:short_message]}/)
            )
          expect(call_endpoint).to redirect_to(expected_redirect)
          expect(response).to have_http_status(:found)
        end

        it 'increments the failed and total statsd counters' do
          callback_tags = ['status:failure',
                           'context:unknown',
                           'version:v1',
                           'type:',
                           'client_id:vaweb',
                           'operation:authorize']
          failed_tags = ['error:auth_too_early', 'version:v1']

          expect { call_endpoint }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, tags: callback_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_FAILED_KEY, tags: failed_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)
        end
      end

      context 'when saml response returns an unknown type of error' do
        let(:error_code) { '007' }
        let(:error_context) do
          [{
            code: '007',
            tag: :unknown,
            short_message: 'Other SAML Response Error(s)',
            level: :error,
            full_message: 'The status code of the Response was not Success, was Requester => ' \
                          'NoAuthnContext -> AuthnRequest without an authentication context.'
          }]
        end
        let(:expected_log_message) do
          ['[V1][Sessions Controller] error', {
            context: error_context,
            message: 'Login Failed! Other SAML Response Error(s)'
          }]
        end

        before { allow(SAML::Responses::Login).to receive(:new).and_return(saml_response_unknown_error) }

        it 'logs a generic error', :aggregate_failures do
          expect(Rails.logger).to receive(:error).with(*expected_log_message)
          expect(call_endpoint).to redirect_to(expected_redirect)
          expect(response).to have_http_status(:found)
        end

        it 'increments the failed and total statsd counters' do
          callback_tags = ['status:failure',
                           'context:unknown',
                           'version:v1',
                           'type:',
                           'client_id:vaweb',
                           'operation:authorize']
          failed_tags = ['error:unknown', 'version:v1']

          expect { call_endpoint }
            .to trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_KEY, tags: callback_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_FAILED_KEY, tags: failed_tags, **once)
            .and trigger_statsd_increment(described_class::STATSD_SSO_CALLBACK_TOTAL_KEY, **once)
        end

        it 'captures the invalid saml response in a PersonalInformationLog' do
          call_endpoint
          expect(PersonalInformationLog.count).to be_positive
          expect(PersonalInformationLog.last.error_class).to eq('Login Failed! Other SAML Response Error(s)')
        end
      end

      context 'when saml response error contains status_detail' do
        status_detail_xml = '<samlp:StatusCode Value="urn:oasis:names:tc:SAML:2.0:status:Responder">' \
                            '</samlp:StatusCode>' \
                            '<samlp:StatusDetail>' \
                            '<fim:FIMStatusDetail MessageID="could_not_perform_token_exchange"></fim:FIMStatusDetail>' \
                            '</samlp:StatusDetail>' \

        let(:extra_content) do
          [
            { code: '007', tag: :unknown, short_message: 'Other SAML Response Error(s)',
              level: :error, full_message: 'Test1' },
            { code: '007', tag: :unknown, short_message: 'Other SAML Response Error(s)',
              level: :error, full_message: 'Test2' },
            { code: '007', tag: :unknown, short_message: 'Other SAML Response Error(s)',
              level: :error, full_message: 'Test3' }
          ]
        end

        let(:expected_error_message) do
          ['[V1][Sessions Controller] error', {
            context: extra_content,
            message: "<fim:FIMStatusDetail MessageID='could_not_perform_token_exchange'/>"
          }]
        end

        before do
          allow(SAML::Responses::Login).to receive(:new).and_return(saml_response_detail_error(status_detail_xml))
        end

        it 'logs status_detail message to Rails logger' do
          expect(Rails.logger).to receive(:error).with(*expected_error_message)
          call_endpoint
        end
      end

      context 'when saml response error contains invalid_message_timestamp' do
        let(:status_detail_xml) do
          '<samlp:StatusCode Value="urn:oasis:names:tc:SAML:2.0:status:Responder">' \
            '</samlp:StatusCode>' \
            '<samlp:StatusDetail>' \
            '<fim:FIMStatusDetail MessageID="invalid_message_timestamp"></fim:FIMStatusDetail>' \
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
        let(:expected_log_message) do
          ['[V1][Sessions Controller] error', {
            context: extra_content,
            message: expected_error_message
          }]
        end

        before do
          allow(SAML::Responses::Login).to receive(:new).and_return(saml_response_detail_error(status_detail_xml))
        end

        it 'logs a generic user validation error', :aggregate_failures do
          expect(Rails.logger).to receive(:error).with(*expected_log_message)
          expect(call_endpoint).to redirect_to(expected_redirect)

          expect(response).to have_http_status(:found)
        end
      end

      context 'when saml response contains multiple errors (known or otherwise)' do
        let(:multi_error_uuid) { '2222' }
        let(:error_code) { '001' }
        let(:error_context) do
          [
            { code: '001', tag: :clicked_deny, short_message: 'Subject did not consent to attribute release',
              level: :warn, full_message: 'Subject did not consent to attribute release' },
            { code: '007', tag: :unknown, short_message: 'Other SAML Response Error(s)',
              level: :error, full_message: 'Other random error' }
          ]
        end
        let(:expected_log_message) do
          ['[V1][Sessions Controller] error', {
            context: error_context,
            message: 'Login Failed! Subject did not consent to attribute release Multiple SAML Errors'
          }]
        end

        before do
          allow(SAML::Responses::Login).to receive(:new).and_return(saml_response_multi_error(multi_error_uuid))
        end

        it 'logs a generic error' do
          expect(Rails.logger).to receive(:error).with(*expected_log_message)
          expect(call_endpoint).to redirect_to(expected_redirect)
          expect(response).to have_http_status(:found)
        end

        it 'increments the failed and total statsd counters' do
          SAMLRequestTracker.create(
            uuid: multi_error_uuid,
            payload: { type: 'idme', application: 'vaweb' }
          )
          callback_tags = ['status:failure',
                           'context:unknown',
                           'version:v1',
                           'type:idme',
                           'client_id:vaweb',
                           'operation:authorize']
          callback_failed_tags = ['error:clicked_deny', 'version:v1']
          login_failed_tags = ['type:idme', 'version:v1', 'client_id:vaweb', 'operation:authorize', 'error:001']

          expect { call_endpoint }
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
            login_failed_tags = ['type:idme', 'version:v1', 'client_id:vamobile', 'operation:authorize', 'error:001']

            expect { call_endpoint }
              .to trigger_statsd_increment(described_class::STATSD_LOGIN_STATUS_FAILURE, tags: login_failed_tags)
          end
        end
      end

      context 'when EDIPI user attribute validation fails' do
        let(:edipi_ids) { %w[0123456789 0000000054] }
        let(:expected_icn) { '1013183292V131165' }
        let(:expected_warning_message) { '[SAML::UserAttributes::SSOe] User attributes contain multiple distinct EDIPI values' }
        let(:expected_warning_data) { { mismatched_ids: edipi_ids, icn: expected_icn } }
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
          expect(Rails.logger).to receive(:warn).with(expected_warning_message, expected_warning_data)
          expect(call_endpoint).to redirect_to(expected_redirect)
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
          expect(Rails.logger).to receive(:warn)
          expect(call_endpoint).to redirect_to(expected_redirect)
          expect(response).to have_http_status(:found)
        end
      end
    end
  end

  describe 'GET #metadata' do
  end
end
