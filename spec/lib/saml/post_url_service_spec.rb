# frozen_string_literal: true

require 'rails_helper'
require 'support/saml/form_validation_helpers'
require 'saml/post_url_service'

RSpec.describe SAML::PostURLService do
  include SAML::ValidationHelpers

  let(:request_id) { SecureRandom.uuid }

  context 'using ial/1 context' do
    subject do
      described_class.new(saml_settings, session:, user:, params:)
    end

    let(:user) { build(:logingov_ial1_user) }
    let(:session) { Session.create(uuid: user.uuid, token: 'abracadabra') }

    around do |example|
      Timecop.freeze('2018-04-09T17:52:03Z')
      RequestStore.store['request_id'] = request_id
      example.run
      Timecop.return
    end

    SAML::URLService::VIRTUAL_HOST_MAPPINGS.each_key do |vhost_url|
      context "virtual host: #{vhost_url}" do
        let(:saml_settings) do
          callback_path = URI.parse(IdentitySettings.saml_ssoe.callback_url).path
          build(:settings_no_context, assertion_consumer_service_url: "#{vhost_url}#{callback_path}")
        end
        let(:params) { { action: 'new' } }

        it 'has sign in url: logingov_url' do
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with(
              [IAL::LOGIN_GOV_IAL1,
               AAL::LOGIN_GOV_AAL2,
               AuthnContext::LOGIN_GOV]
            )
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context_comparison=).with('minimum')
          url, params = subject.login_url('logingov', [IAL::LOGIN_GOV_IAL1, AAL::LOGIN_GOV_AAL2],
                                          AuthnContext::LOGIN_GOV, AuthnContext::MINIMUM)
          expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
          expect_saml_form_parameters(params,
                                      'originating_request_id' => request_id, 'type' => 'logingov')
        end

        it 'has sign in url: logingov_verified' do
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with(
              [IAL::LOGIN_GOV_IAL2,
               AAL::LOGIN_GOV_AAL2,
               AuthnContext::LOGIN_GOV]
            )
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context_comparison=).with('minimum')
          url, params = subject.login_url('logingov', [IAL::LOGIN_GOV_IAL2, AAL::LOGIN_GOV_AAL2],
                                          AuthnContext::LOGIN_GOV, AuthnContext::MINIMUM)
          expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
          expect_saml_form_parameters(params,
                                      'originating_request_id' => request_id, 'type' => 'logingov')
        end

        it 'has sign up url: logingov_signup_url' do
          url, params = subject.logingov_signup_url([IAL::LOGIN_GOV_IAL1, AAL::LOGIN_GOV_AAL2])
          expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
          expect_saml_form_parameters(params,
                                      'originating_request_id' => request_id, 'type' => 'signup')
        end

        it 'has sign up url: logingov_verified_signup' do
          url, params = subject.logingov_signup_url([IAL::LOGIN_GOV_IAL2, AAL::LOGIN_GOV_AAL2])
          expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
          expect_saml_form_parameters(params,
                                      'originating_request_id' => request_id, 'type' => 'signup')
        end
      end
    end
  end

  context 'using loa/3/vets context' do
    subject do
      described_class.new(saml_settings, session:, user:, params:)
    end

    let(:user) { build(:user) }
    let(:session) { Session.create(uuid: user.uuid, token: 'abracadabra') }

    around do |example|
      Timecop.freeze('2018-04-09T17:52:03Z')
      RequestStore.store['request_id'] = request_id
      example.run
      Timecop.return
    end

    SAML::URLService::VIRTUAL_HOST_MAPPINGS.each do |vhost_url, values|
      context "virtual host: #{vhost_url}" do
        let(:saml_settings) do
          callback_path = URI.parse(IdentitySettings.saml_ssoe.callback_url).path
          build(:settings_no_context, assertion_consumer_service_url: "#{vhost_url}#{callback_path}")
        end

        let(:params) { { action: 'new' } }

        it 'has sign in url: mhv_url' do
          url, params = subject.login_url('mhv', 'myhealthevet', AuthnContext::MHV)
          expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
          expect_saml_form_parameters(params,
                                      'originating_request_id' => request_id, 'type' => 'mhv')
        end

        it 'has sign in url: mhv_verified' do
          url, params = subject.login_url('mhv', 'myhealthevet_loa3', AuthnContext::MHV)
          expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
          expect_saml_form_parameters(params,
                                      'originating_request_id' => request_id, 'type' => 'mhv')
        end

        it 'has sign in url: dslogon_url' do
          url, params = subject.login_url('dslogon', 'dslogon', AuthnContext::DSLOGON)
          expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
          expect_saml_form_parameters(params,
                                      'originating_request_id' => request_id, 'type' => 'dslogon')
        end

        it 'has sign in url: dslogon_verified' do
          url, params = subject.login_url('dslogon', 'dslogon_loa3', AuthnContext::DSLOGON)
          expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
          expect_saml_form_parameters(params,
                                      'originating_request_id' => request_id, 'type' => 'dslogon')
        end

        it 'has sign in url: idme_url' do
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context_comparison=).with('minimum')
          url, params = subject.login_url('idme', LOA::IDME_LOA1_VETS, AuthnContext::ID_ME, AuthnContext::MINIMUM)
          expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
          expect_saml_form_parameters(params,
                                      'originating_request_id' => request_id, 'type' => 'idme')
        end

        it 'has sign in url: idme_verified' do
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context_comparison=).with('minimum')
          url, params = subject.login_url('idme', LOA::IDME_LOA3, AuthnContext::ID_ME, AuthnContext::MINIMUM)
          expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
          expect_saml_form_parameters(params,
                                      'originating_request_id' => request_id, 'type' => 'idme')
        end

        it 'has sign up url: idme_signup_url' do
          url, params = subject.idme_signup_url(LOA::IDME_LOA1_VETS)
          expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
          expect_saml_form_parameters(params,
                                      'originating_request_id' => request_id, 'type' => 'signup')
        end

        it 'has sign up url: idme_verified_signup' do
          url, params = subject.idme_signup_url(LOA::IDME_LOA3)
          expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
          expect_saml_form_parameters(params,
                                      'originating_request_id' => request_id, 'type' => 'signup')
        end

        context 'verify_url' do
          it 'has sign in url: with (default authn_context)' do
            expect(user.authn_context).to eq('http://idmanagement.gov/ns/assurance/loa/1/vets')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with([LOA::IDME_LOA3_VETS, AuthnContext::ID_ME])
            url, params = subject.verify_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'verify')
          end

          it 'has sign in url: with (multifactor authn_context)' do
            allow(user).to receive(:authn_context).and_return('multifactor')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with([LOA::IDME_LOA3_VETS, AuthnContext::ID_ME])
            url, params = subject.verify_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'verify')
          end

          it 'has sign in url: with (myhealthevet authn_context)' do
            allow(user).to receive(:authn_context).and_return('myhealthevet')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with(['myhealthevet_loa3', AuthnContext::MHV])
            url, params = subject.verify_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'verify')
          end

          it 'has sign in url: with (myhealthevet_multifactor authn_context)' do
            allow(user).to receive(:authn_context).and_return('myhealthevet_multifactor')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with(['myhealthevet_loa3', AuthnContext::MHV])
            url, params = subject.verify_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'verify')
          end

          it 'has sign in url: with (dslogon authn_context)' do
            allow(user).to receive(:authn_context).and_return('dslogon')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with(['dslogon_loa3', AuthnContext::DSLOGON])
            url, params = subject.verify_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'verify')
          end

          it 'has sign in url: with (dslogon_multifactor authn_context)' do
            allow(user).to receive(:authn_context).and_return('dslogon_multifactor')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with(['dslogon_loa3', AuthnContext::DSLOGON])
            url, params = subject.verify_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'verify')
          end
        end

        context 'mfa_url' do
          it 'has mfa url: with (default authn_context)' do
            expect(user.authn_context).to eq('http://idmanagement.gov/ns/assurance/loa/1/vets')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with(['multifactor', AuthnContext::ID_ME])
            url, params = subject.mfa_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'mfa')
          end

          it 'has mfa url: with (myhealthevet authn_context)' do
            allow(user).to receive(:authn_context).and_return('myhealthevet')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with(['myhealthevet_multifactor', AuthnContext::MHV])
            url, params = subject.mfa_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'mfa')
          end

          it 'has mfa url: with (myhealthevet_loa3 authn_context)' do
            allow(user).to receive(:authn_context).and_return('myhealthevet_loa3')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with(['myhealthevet_multifactor', AuthnContext::MHV])
            url, params = subject.mfa_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'mfa')
          end

          it 'has mfa url: with (dslogon authn_context)' do
            allow(user).to receive(:authn_context).and_return('dslogon')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with(['dslogon_multifactor', AuthnContext::DSLOGON])
            url, params = subject.mfa_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'mfa')
          end

          it 'has mfa url: with (dslogon_loa3 authn_context)' do
            allow(user).to receive(:authn_context).and_return('dslogon_loa3')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with(['dslogon_multifactor', AuthnContext::DSLOGON])
            url, params = subject.mfa_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'mfa')
          end
        end

        context 'redirect urls' do
          let(:params) { { action: 'saml_callback', RelayState: '{"type":"idme"}' } }

          it 'has a base url' do
            expect(subject.base_redirect_url).to eq(values[:base_redirect])
          end

          context 'with an MHV outbound-redirect user' do
            context 'with a valid redirect code' do
              let(:redirect) { 'https://int.eauth.va.gov/mhv-portal-web/eauth?deeplinking=secure_messaging' }

              it 'redirects to MHV' do
                params[:redirect] = redirect
                expect(subject.login_redirect_url).to eq(redirect)
              end
            end

            context 'with a postLogin param' do
              let(:redirect) do
                'https://int.eauth.va.gov/mhv-portal-web/eauth?deeplinking=secure_messaging&postLogin=true'
              end

              it 'adds the postLogin param to the final redirect URL' do
                params[:redirect] = redirect
                params[:postLogin] = true
                expect(subject.login_redirect_url).to eq(redirect)
              end
            end
          end

          context 'for login' do
            let(:user) { build(:user, :loa3) }
            let(:request_id) { SecureRandom.uuid }

            it 'has a login redirect url with success' do
              expect(subject.login_redirect_url)
                .to eq("#{values[:base_redirect]}#{SAML::URLService::LOGIN_REDIRECT_PARTIAL}?type=idme")
            end

            it 'has a login redirect url with fail' do
              expect(subject.login_redirect_url(auth: 'fail',
                                                code: SAML::Responses::Base::CLICKED_DENY_ERROR_CODE,
                                                request_id:))
                .to eq("#{values[:base_redirect]}#{SAML::URLService::LOGIN_REDIRECT_PARTIAL}" \
                       "?auth=fail&code=001&request_id=#{request_id}&type=idme")
            end
          end

          context 'for logout' do
            let(:params) { { action: 'saml_logout_callback' } }

            it 'has a logout redirect url' do
              expect(subject.logout_redirect_url)
                .to eq(values[:base_redirect] + SAML::URLService::LOGOUT_REDIRECT_PARTIAL)
            end
          end

          context 'for a user authenticating with inbound ssoe' do
            let(:user) { build(:user, :loa3) }
            let(:params) { { action: 'saml_callback', RelayState: '{"type":"custom"}', type: 'custom' } }
            let(:request_id) { SecureRandom.uuid }

            it 'is successful' do
              expect(subject.login_redirect_url)
                .to eq("#{values[:base_redirect]}#{SAML::URLService::LOGIN_REDIRECT_PARTIAL}?type=custom")
            end

            it 'is a failure' do
              expect(subject.login_redirect_url(auth: 'fail',
                                                code: SAML::Responses::Base::CLICKED_DENY_ERROR_CODE,
                                                request_id:))
                .to eq("#{values[:base_redirect]}#{SAML::URLService::LOGIN_REDIRECT_PARTIAL}" \
                       "?auth=force-needed&code=001&request_id=#{request_id}&type=custom")
            end
          end
        end

        context 'instance created by invalid action' do
          let(:params) { { action: 'saml_slo_callback' } }

          it 'raises an exception' do
            expect { subject }.to raise_error(Common::Exceptions::RoutingError)
          end
        end
      end
    end
  end

  context 'using loa/3 context' do
    subject do
      described_class.new(saml_settings, session:, user:,
                                         params:, loa3_context: LOA::IDME_LOA3)
    end

    let(:user) { build(:user) }
    let(:session) { Session.create(uuid: user.uuid, token: 'abracadabra') }

    around do |example|
      Timecop.freeze('2018-04-09T17:52:03Z')
      RequestStore.store['request_id'] = request_id
      example.run
      Timecop.return
    end

    SAML::URLService::VIRTUAL_HOST_MAPPINGS.each do |vhost_url, values|
      context "virtual host: #{vhost_url}" do
        let(:saml_settings) do
          callback_path = URI.parse(IdentitySettings.saml_ssoe.callback_url).path
          build(:settings_no_context, assertion_consumer_service_url: "#{vhost_url}#{callback_path}")
        end

        let(:params) { { action: 'new' } }

        it 'has sign in url: mhv_url' do
          url, params = subject.login_url('mhv', 'myhealthevet', AuthnContext::MHV)
          expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
          expect_saml_form_parameters(params,
                                      'originating_request_id' => request_id, 'type' => 'mhv')
        end

        it 'has sign in url: dslogon_url' do
          url, params = subject.login_url('dslogon', 'dslogon', AuthnContext::DSLOGON)
          expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
          expect_saml_form_parameters(params,
                                      'originating_request_id' => request_id, 'type' => 'dslogon')
        end

        it 'has sign in url: idme_url' do
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context_comparison=).with('minimum')
          url, params = subject.login_url('idme', LOA::IDME_LOA1_VETS, AuthnContext::ID_ME, AuthnContext::MINIMUM)
          expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
          expect_saml_form_parameters(params,
                                      'originating_request_id' => request_id, 'type' => 'idme')
        end

        it 'has sign in url: custom_url' do
          allow(user).to receive(:authn_context).and_return('X')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('X')
          url, params = subject.custom_url('X')
          expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
          expect_saml_form_parameters(params,
                                      'originating_request_id' => request_id, 'type' => 'custom')
        end

        it 'has sign up url: idme_signup_url' do
          url, params = subject.idme_signup_url(LOA::IDME_LOA1_VETS)
          expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
          expect_saml_form_parameters(params,
                                      'originating_request_id' => request_id, 'type' => 'signup')
        end

        context 'verify_url' do
          it 'has sign in url: with (default authn_context)' do
            expect(user.authn_context).to eq('http://idmanagement.gov/ns/assurance/loa/1/vets')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with([LOA::IDME_LOA3, AuthnContext::ID_ME])
            url, params = subject.verify_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'verify')
          end

          it 'has sign in url: with (multifactor authn_context)' do
            allow(user).to receive(:authn_context).and_return('multifactor')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with([LOA::IDME_LOA3, AuthnContext::ID_ME])
            url, params = subject.verify_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'verify')
          end

          it 'has sign in url: with (myhealthevet authn_context)' do
            allow(user).to receive(:authn_context).and_return('myhealthevet')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with(['myhealthevet_loa3', AuthnContext::MHV])
            url, params = subject.verify_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'verify')
          end

          it 'has sign in url: with (myhealthevet_multifactor authn_context)' do
            allow(user).to receive(:authn_context).and_return('myhealthevet_multifactor')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with(['myhealthevet_loa3', AuthnContext::MHV])
            url, params = subject.verify_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'verify')
          end

          it 'has sign in url: with (dslogon authn_context)' do
            allow(user).to receive(:authn_context).and_return('dslogon')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with(['dslogon_loa3', AuthnContext::DSLOGON])
            url, params = subject.verify_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'verify')
          end

          it 'has sign in url: with (dslogon_multifactor authn_context)' do
            allow(user).to receive(:authn_context).and_return('dslogon_multifactor')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with(['dslogon_loa3', AuthnContext::DSLOGON])
            url, params = subject.verify_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'verify')
          end

          it 'has sign in url: with (ssoe inbound authn_context)' do
            allow(user).to receive(:authn_context).and_return('urn:oasis:names:tc:SAML:2.0:ac:classes:Password')
            allow(user.identity).to receive(:sign_in).and_return({ service_name: 'dslogon' })
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('dslogon_loa3')
            url, params = subject.verify_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'verify')
          end
        end

        context 'mfa_url' do
          it 'has mfa url: with (default authn_context)' do
            expect(user.authn_context).to eq('http://idmanagement.gov/ns/assurance/loa/1/vets')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with(['multifactor', AuthnContext::ID_ME])
            url, params = subject.mfa_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'mfa')
          end

          it 'has mfa url: with (myhealthevet authn_context)' do
            allow(user).to receive(:authn_context).and_return('myhealthevet')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with(['myhealthevet_multifactor', AuthnContext::MHV])
            url, params = subject.mfa_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'mfa')
          end

          it 'has mfa url: with (myhealthevet_loa3 authn_context)' do
            allow(user).to receive(:authn_context).and_return('myhealthevet_loa3')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with(['myhealthevet_multifactor', AuthnContext::MHV])
            url, params = subject.mfa_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'mfa')
          end

          it 'has mfa url: with (dslogon authn_context)' do
            allow(user).to receive(:authn_context).and_return('dslogon')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with(['dslogon_multifactor', AuthnContext::DSLOGON])
            url, params = subject.mfa_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'mfa')
          end

          it 'has mfa url: with (dslogon_loa3 authn_context)' do
            allow(user).to receive(:authn_context).and_return('dslogon_loa3')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with(['dslogon_multifactor', AuthnContext::DSLOGON])
            url, params = subject.mfa_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'mfa')
          end

          it 'has mfa url: with (ssoe inbound authn_context)' do
            allow(user).to receive(:authn_context).and_return('urn:oasis:names:tc:SAML:2.0:ac:classes:Password')
            allow(user.identity).to receive(:sign_in).and_return({ service_name: 'myhealthevet' })
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('myhealthevet_multifactor')
            url, params = subject.mfa_url
            expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
            expect_saml_form_parameters(params,
                                        'originating_request_id' => request_id, 'type' => 'mfa')
          end
        end

        context 'redirect urls' do
          let(:params) { { action: 'saml_callback', RelayState: '{"type":"idme"}', application: } }
          let(:application) { 'vaweb' }

          it 'has a base url' do
            expect(subject.base_redirect_url).to eq(values[:base_redirect])
          end

          context 'for login' do
            let(:user) { build(:user, :loa3) }

            it 'has a login redirect url with success' do
              expect(subject.login_redirect_url)
                .to eq("#{values[:base_redirect]}#{SAML::URLService::LOGIN_REDIRECT_PARTIAL}?type=idme")
            end

            it 'has a login redirect url with fail' do
              expect(subject.login_redirect_url(auth: 'fail',
                                                code: SAML::Responses::Base::CLICKED_DENY_ERROR_CODE,
                                                request_id:))
                .to eq("#{values[:base_redirect]}#{SAML::URLService::LOGIN_REDIRECT_PARTIAL}" \
                       "?auth=fail&code=001&request_id=#{request_id}&type=idme")
            end
          end

          context 'for logout' do
            let(:params) { { action: 'saml_logout_callback' } }

            it 'has a logout redirect url' do
              expect(subject.logout_redirect_url)
                .to eq(values[:base_redirect] + SAML::URLService::LOGOUT_REDIRECT_PARTIAL)
            end
          end

          context 'for terms of use' do
            let(:user) { build(:user, :loa3) }
            let(:expected_redirect_url_param) do
              expected_login_redirect_url.to_query('redirect_url')
            end
            let(:expected_login_redirect_url) do
              "#{values[:base_redirect]}#{SAML::URLService::LOGIN_REDIRECT_PARTIAL}?type=idme"
            end
            let(:expected_log_message) { 'Redirecting to /terms-of-use' }
            let(:expected_log_payload) { { type: :ssoe } }

            shared_examples 'terms of use redirected url' do
              it 'has a login redirect url as a parameter embedded in review instance terms of use page' do
                expect(subject.terms_of_use_redirect_url)
                  .to eq("#{base_url}/terms-of-use?#{expected_redirect_url_param}")
              end

              it 'logs expected message and payload' do
                expect(Rails.logger).to receive(:info).with(expected_log_message, expected_log_payload)
                subject.terms_of_use_redirect_url
              end

              context 'and tracker application is within SKIP_MHV_ACCOUNT_CREATION_CLIENTS' do
                let(:application) { SAML::URLService::SKIP_MHV_ACCOUNT_CREATION_CLIENTS.first }
                let(:skip_mhv_account_creation_param) { 'skip_mhv_account_creation=true' }

                it 'appends skip_mhv_account_creation query parameter' do
                  expect(subject.terms_of_use_redirect_url)
                    .to eq("#{base_url}/terms-of-use?#{expected_redirect_url_param}&#{skip_mhv_account_creation_param}")
                end
              end
            end

            context 'when associated terms of use redirect user cache object exists' do
              let(:cache_key) { "terms_of_use_redirect_user_#{user.uuid}" }
              let(:enabled_clients) { application }
              let(:cache_expiration) { 5.minutes }

              before do
                allow(IdentitySettings.terms_of_use).to receive(:enabled_clients).and_return(enabled_clients)
                allow(Rails.cache).to receive(:read).with(cache_key).and_return(application)
              end

              context 'and application is within IdentitySettings.terms_of_use.enabled_clients' do
                let(:enabled_clients) { application }

                context 'and authentication is occuring on a review instance' do
                  let(:review_instance_slug) { 'some-review-instance-slug' }
                  let(:base_url) { "https://#{review_instance_slug}.vfs.va.gov" }

                  before { allow(Settings).to receive(:review_instance_slug).and_return(review_instance_slug) }

                  it_behaves_like 'terms of use redirected url'
                end

                context 'and authentication is not occurring on a review instance' do
                  let(:base_url) { values[:base_redirect] }

                  it_behaves_like 'terms of use redirected url'
                end
              end

              context 'and stored application is not within IdentitySettings.terms_of_use.enabled_clients' do
                let(:enabled_clients) { '' }

                it 'has a login redirect url with success not embedded in a terms of use page' do
                  expect(subject.terms_of_use_redirect_url).to eq(expected_login_redirect_url)
                end
              end

              it 'deletes the cached terms of use redirect user object' do
                expect(Rails.cache).to receive(:delete).with(cache_key)
                subject.terms_of_use_redirect_url
              end
            end

            context 'when associated terms of use redirect user cache object does not exist' do
              context 'when tracker application is within IdentitySettings.terms_of_use.enabled_clients' do
                before do
                  allow(IdentitySettings.terms_of_use).to receive(:enabled_clients).and_return(application)
                end

                context 'and authentication is occuring on a review instance' do
                  let(:review_instance_slug) { 'some-review-instance-slug' }
                  let(:base_url) { "https://#{review_instance_slug}.vfs.va.gov" }

                  before { allow(Settings).to receive(:review_instance_slug).and_return(review_instance_slug) }

                  it_behaves_like 'terms of use redirected url'
                end

                context 'and authentication is not occurring on a review instance' do
                  let(:base_url) { values[:base_redirect] }

                  it_behaves_like 'terms of use redirected url'
                end
              end

              context 'when tracker application is nil' do
                let(:application) { nil }
                let(:base_url) { values[:base_redirect] }

                it_behaves_like 'terms of use redirected url'
              end

              context 'when tracker application is not within IdentitySettings.terms_of_use.enabled_clients' do
                before do
                  allow(IdentitySettings.terms_of_use).to receive(:enabled_clients).and_return('')
                end

                it 'has a login redirect url with success not embedded in a terms of use page' do
                  expect(subject.terms_of_use_redirect_url)
                    .to eq(expected_login_redirect_url)
                end
              end
            end
          end
        end

        context 'instance created by invalid action' do
          let(:params) { { action: 'saml_slo_callback' } }

          it 'raises an exception' do
            expect { subject }.to raise_error(Common::Exceptions::RoutingError)
          end
        end
      end
    end
  end

  context 'review instance' do
    subject { described_class.new(saml_settings, session:, user:, params:) }

    let(:user) { build(:user) }
    let(:session) { Session.create(uuid: user.uuid, token: 'abracadabra') }
    let(:slug_id) { '617bed45ccb1fc2a87872b567c721009' }
    let(:saml_settings) do
      build(:settings_no_context, assertion_consumer_service_url: 'https://staging-api.vets.gov/review_instance/saml/callback')
    end

    around do |example|
      Timecop.freeze('2018-04-09T17:52:03Z')
      RequestStore.store['request_id'] = request_id
      with_settings(IdentitySettings.saml_ssoe,
                    relay: "https://#{slug_id}.vfs.va.gov/auth/login/callback") do
        with_settings(Settings, review_instance_slug: slug_id) do
          example.run
        end
      end
      Timecop.return
    end

    context 'new url' do
      let(:params) { { action: 'new' } }

      it 'has sign in url: mhv_url' do
        url, params = subject.login_url('mhv', 'myhealthevet', AuthnContext::MHV)
        expect(url).to eq('https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login')
        expect_saml_form_parameters(params,
                                    'originating_request_id' => request_id, 'type' => 'mhv',
                                    'review_instance_slug' => slug_id)
      end
    end
  end
end
