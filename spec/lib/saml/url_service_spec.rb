# frozen_string_literal: true

require 'rails_helper'
require 'saml/url_service'
require 'support/url_service_helpers'

RSpec.describe SAML::URLService do
  context 'using loa/3/vets context' do
    subject do
      described_class.new(saml_settings, session: session, user: user, params: params)
    end

    let(:user) { build(:user) }
    let(:session) { Session.create(uuid: user.uuid, token: 'abracadabra') }

    around do |example|
      User.create(user)
      Timecop.freeze('2018-04-09T17:52:03Z')
      RequestStore.store['request_id'] = '123'
      example.run
      Timecop.return
    end

    SAML::URLService::VIRTUAL_HOST_MAPPINGS.each do |vhost_url, values|
      context "virtual host: #{vhost_url}" do
        let(:saml_settings) do
          build(:settings_no_context, assertion_consumer_service_url: "#{vhost_url}/auth/saml/callback")
        end

        let(:params) { { action: 'new' } }

        it 'has sign in url: mhv_url' do
          expect(subject.mhv_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('originating_request_id' => '123', 'type' => 'mhv')
        end

        it 'has sign in url: dslogon_url' do
          expect(subject.dslogon_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('originating_request_id' => '123', 'type' => 'dslogon')
        end

        it 'has sign in url: idme_url' do
          expect(subject.idme_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('originating_request_id' => '123', 'type' => 'idme')
        end

        it 'has sign up url: signup_url' do
          expect(subject.signup_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('originating_request_id' => '123', 'type' => 'signup')
            .with_params('op' => 'signup')
        end

        context 'verify_url' do
          it 'has sign in url: with (default authn_context)' do
            expect(user.authn_context).to eq('http://idmanagement.gov/ns/assurance/loa/1/vets')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('http://idmanagement.gov/ns/assurance/loa/3/vets')
            expect(subject.verify_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'verify')
          end

          it 'has sign in url: with (multifactor authn_context)' do
            allow(user).to receive(:authn_context).and_return('multifactor')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('http://idmanagement.gov/ns/assurance/loa/3/vets')
            expect(subject.verify_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'verify')
          end

          it 'has sign in url: with (myhealthevet authn_context)' do
            allow(user).to receive(:authn_context).and_return('myhealthevet')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('myhealthevet_loa3')
            expect(subject.verify_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'verify')
          end

          it 'has sign in url: with (myhealthevet_multifactor authn_context)' do
            allow(user).to receive(:authn_context).and_return('myhealthevet_multifactor')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('myhealthevet_loa3')
            expect(subject.verify_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'verify')
          end

          it 'has sign in url: with (dslogon authn_context)' do
            allow(user).to receive(:authn_context).and_return('dslogon')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('dslogon_loa3')
            expect(subject.verify_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'verify')
          end

          it 'has sign in url: with (dslogon_multifactor authn_context)' do
            allow(user).to receive(:authn_context).and_return('dslogon_multifactor')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('dslogon_loa3')
            expect(subject.verify_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'verify')
          end
        end

        context 'mfa_url' do
          it 'has mfa url: with (default authn_context)' do
            expect(user.authn_context).to eq('http://idmanagement.gov/ns/assurance/loa/1/vets')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('multifactor')
            expect(subject.mfa_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'mfa')
          end

          it 'has mfa url: with (myhealthevet authn_context)' do
            allow(user).to receive(:authn_context).and_return('myhealthevet')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('myhealthevet_multifactor')
            expect(subject.mfa_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'mfa')
          end

          it 'has mfa url: with (myhealthevet_loa3 authn_context)' do
            allow(user).to receive(:authn_context).and_return('myhealthevet_loa3')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('myhealthevet_multifactor')
            expect(subject.mfa_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'mfa')
          end

          it 'has mfa url: with (dslogon authn_context)' do
            allow(user).to receive(:authn_context).and_return('dslogon')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('dslogon_multifactor')
            expect(subject.mfa_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'mfa')
          end

          it 'has mfa url: with (dslogon_loa3 authn_context)' do
            allow(user).to receive(:authn_context).and_return('dslogon_loa3')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('dslogon_multifactor')
            expect(subject.mfa_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'mfa')
          end
        end

        it 'has sign out url: slo_url' do
          expect(subject.slo_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleLogoutService?SAMLRequest=')
            .with_relay_state('originating_request_id' => '123', 'type' => 'slo')
        end

        context 'redirect urls' do
          let(:params) { { action: 'saml_callback', RelayState: '{"type":"idme"}' } }

          it 'has a base url' do
            expect(subject.base_redirect_url).to eq(values[:base_redirect])
          end

          context 'with an user that needs to verify' do
            it 'goes to verify URL before login redirect' do
              expect(user.authn_context).to eq('http://idmanagement.gov/ns/assurance/loa/1/vets')
              expect_any_instance_of(OneLogin::RubySaml::Settings)
                .to receive(:authn_context=).with('http://idmanagement.gov/ns/assurance/loa/3/vets')
              expect(subject.login_redirect_url)
                .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
                .with_relay_state('originating_request_id' => '123', 'type' => 'idme')
            end
          end

          context 'with user that does not need to verify' do
            let(:user) { build(:user, :loa3) }

            it 'has a login redirect url with success' do
              expect(subject.login_redirect_url)
                .to eq(values[:base_redirect] + SAML::URLService::LOGIN_REDIRECT_PARTIAL + '?type=idme')
            end

            it 'has a login redirect url with fail' do
              expect(subject.login_redirect_url(auth: 'fail', code: SAML::Responses::Base::CLICKED_DENY_ERROR_CODE))
                .to eq(values[:base_redirect] +
                       SAML::URLService::LOGIN_REDIRECT_PARTIAL +
                       '?auth=fail&code=001&type=idme')
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

            it 'is successful' do
              expect(subject.login_redirect_url)
                .to eq(values[:base_redirect] + SAML::URLService::LOGIN_REDIRECT_PARTIAL + '?type=custom')
            end

            it 'is a failure' do
              expect(subject.login_redirect_url(auth: 'fail', code: SAML::Responses::Base::CLICKED_DENY_ERROR_CODE))
                .to eq(values[:base_redirect] +
                       SAML::URLService::LOGIN_REDIRECT_PARTIAL +
                       '?auth=force-needed&code=001&type=custom')
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
      described_class.new(saml_settings, session: session, user: user,
                                         params: params, loa3_context: LOA::IDME_LOA3)
    end

    let(:user) { build(:user) }
    let(:session) { Session.create(uuid: user.uuid, token: 'abracadabra') }

    around do |example|
      User.create(user)
      Timecop.freeze('2018-04-09T17:52:03Z')
      RequestStore.store['request_id'] = '123'
      example.run
      Timecop.return
    end

    SAML::URLService::VIRTUAL_HOST_MAPPINGS.each do |vhost_url, values|
      context "virtual host: #{vhost_url}" do
        let(:saml_settings) do
          build(:settings_no_context, assertion_consumer_service_url: "#{vhost_url}/auth/saml/callback")
        end

        let(:params) { { action: 'new' } }

        it 'has sign in url: mhv_url' do
          expect(subject.mhv_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('originating_request_id' => '123', 'type' => 'mhv')
        end

        it 'has sign in url: dslogon_url' do
          expect(subject.dslogon_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('originating_request_id' => '123', 'type' => 'dslogon')
        end

        it 'has sign in url: idme_url' do
          expect(subject.idme_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('originating_request_id' => '123', 'type' => 'idme')
        end

        it 'has sign in url: custom_url' do
          allow(user).to receive(:authn_context).and_return('X')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('X')
          expect(subject.custom_url('X'))
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('originating_request_id' => '123', 'type' => 'custom')
        end

        it 'has sign up url: signup_url' do
          expect(subject.signup_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('originating_request_id' => '123', 'type' => 'signup')
            .with_params('op' => 'signup')
        end

        context 'verify_url' do
          it 'has sign in url: with (default authn_context)' do
            expect(user.authn_context).to eq('http://idmanagement.gov/ns/assurance/loa/1/vets')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('http://idmanagement.gov/ns/assurance/loa/3')
            expect(subject.verify_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'verify')
          end

          it 'has sign in url: with (multifactor authn_context)' do
            allow(user).to receive(:authn_context).and_return('multifactor')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('http://idmanagement.gov/ns/assurance/loa/3')
            expect(subject.verify_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'verify')
          end

          it 'has sign in url: with (myhealthevet authn_context)' do
            allow(user).to receive(:authn_context).and_return('myhealthevet')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('myhealthevet_loa3')
            expect(subject.verify_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'verify')
          end

          it 'has sign in url: with (myhealthevet_multifactor authn_context)' do
            allow(user).to receive(:authn_context).and_return('myhealthevet_multifactor')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('myhealthevet_loa3')
            expect(subject.verify_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'verify')
          end

          it 'has sign in url: with (dslogon authn_context)' do
            allow(user).to receive(:authn_context).and_return('dslogon')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('dslogon_loa3')
            expect(subject.verify_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'verify')
          end

          it 'has sign in url: with (dslogon_multifactor authn_context)' do
            allow(user).to receive(:authn_context).and_return('dslogon_multifactor')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('dslogon_loa3')
            expect(subject.verify_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'verify')
          end

          it 'has sign in url: with (ssoe inbound authn_context)' do
            allow(user).to receive(:authn_context).and_return('urn:oasis:names:tc:SAML:2.0:ac:classes:Password')
            allow(user.identity).to receive(:sign_in).and_return({ service_name: 'dslogon' })
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('dslogon_loa3')
            expect(subject.verify_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'verify')
          end
        end

        context 'mfa_url' do
          it 'has mfa url: with (default authn_context)' do
            expect(user.authn_context).to eq('http://idmanagement.gov/ns/assurance/loa/1/vets')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('multifactor')
            expect(subject.mfa_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'mfa')
          end

          it 'has mfa url: with (myhealthevet authn_context)' do
            allow(user).to receive(:authn_context).and_return('myhealthevet')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('myhealthevet_multifactor')
            expect(subject.mfa_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'mfa')
          end

          it 'has mfa url: with (myhealthevet_loa3 authn_context)' do
            allow(user).to receive(:authn_context).and_return('myhealthevet_loa3')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('myhealthevet_multifactor')
            expect(subject.mfa_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'mfa')
          end

          it 'has mfa url: with (dslogon authn_context)' do
            allow(user).to receive(:authn_context).and_return('dslogon')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('dslogon_multifactor')
            expect(subject.mfa_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'mfa')
          end

          it 'has mfa url: with (dslogon_loa3 authn_context)' do
            allow(user).to receive(:authn_context).and_return('dslogon_loa3')
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('dslogon_multifactor')
            expect(subject.mfa_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'mfa')
          end

          it 'has mfa url: with (ssoe inbound authn_context)' do
            allow(user).to receive(:authn_context).and_return('urn:oasis:names:tc:SAML:2.0:ac:classes:Password')
            allow(user.identity).to receive(:sign_in).and_return({ service_name: 'myhealthevet' })
            expect_any_instance_of(OneLogin::RubySaml::Settings)
              .to receive(:authn_context=).with('myhealthevet_multifactor')
            expect(subject.mfa_url)
              .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
              .with_relay_state('originating_request_id' => '123', 'type' => 'mfa')
          end
        end

        it 'has sign out url: slo_url' do
          expect(subject.slo_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleLogoutService?SAMLRequest=')
            .with_relay_state('originating_request_id' => '123', 'type' => 'slo')
        end

        context 'redirect urls' do
          let(:params) { { action: 'saml_callback', RelayState: '{"type":"idme"}' } }

          it 'has a base url' do
            expect(subject.base_redirect_url).to eq(values[:base_redirect])
          end

          context 'with an user that needs to verify' do
            it 'goes to verify URL before login redirect' do
              expect(user.authn_context).to eq('http://idmanagement.gov/ns/assurance/loa/1/vets')
              expect_any_instance_of(OneLogin::RubySaml::Settings)
                .to receive(:authn_context=).with('http://idmanagement.gov/ns/assurance/loa/3')
              expect(subject.login_redirect_url)
                .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
                .with_relay_state('originating_request_id' => '123', 'type' => 'idme')
            end
          end

          context 'with user that does not need to verify' do
            let(:user) { build(:user, :loa3) }

            it 'has a login redirect url with success' do
              expect(subject.login_redirect_url)
                .to eq(values[:base_redirect] + SAML::URLService::LOGIN_REDIRECT_PARTIAL + '?type=idme')
            end

            it 'has a login redirect url with fail' do
              expect(subject.login_redirect_url(auth: 'fail', code: SAML::Responses::Base::CLICKED_DENY_ERROR_CODE))
                .to eq(values[:base_redirect] +
                       SAML::URLService::LOGIN_REDIRECT_PARTIAL +
                       '?auth=fail&code=001&type=idme')
            end
          end

          context 'for logout' do
            let(:params) { { action: 'saml_logout_callback' } }

            it 'has a logout redirect url' do
              expect(subject.logout_redirect_url)
                .to eq(values[:base_redirect] + SAML::URLService::LOGOUT_REDIRECT_PARTIAL)
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
    subject { described_class.new(saml_settings, session: session, user: user, params: params) }

    let(:user) { build(:user) }
    let(:session) { Session.create(uuid: user.uuid, token: 'abracadabra') }
    let(:slug_id) { '617bed45ccb1fc2a87872b567c721009' }
    let(:saml_settings) do
      build(:settings_no_context, assertion_consumer_service_url: 'https://staging-api.vets.gov/review_instance/saml/callback')
    end

    around do |example|
      User.create(user)
      Timecop.freeze('2018-04-09T17:52:03Z')
      RequestStore.store['request_id'] = '123'
      with_settings(Settings.saml, relay: "http://#{slug_id}.review.vetsgov-internal/auth/login/callback") do
        with_settings(Settings, review_instance_slug: slug_id) do
          example.run
        end
      end
      Timecop.return
    end

    context 'new url' do
      let(:params) { { action: 'new' } }

      it 'has sign in url: mhv_url' do
        expect(subject.mhv_url)
          .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
          .with_relay_state('originating_request_id' => '123', 'type' => 'mhv', 'review_instance_slug' => slug_id)
      end
    end

    context 'up-leveling' do
      let(:params) do
        { action: 'saml_callback', RelayState: "{\"type\":\"idme\",\"review_instance_slug:\":\"#{slug_id}\"}" }
      end

      it 'goes to verify URL before login redirect' do
        expect(user.authn_context).to eq('http://idmanagement.gov/ns/assurance/loa/1/vets')
        expect_any_instance_of(OneLogin::RubySaml::Settings)
          .to receive(:authn_context=).with('http://idmanagement.gov/ns/assurance/loa/3/vets')
        expect(subject.login_redirect_url)
          .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
          .with_relay_state('originating_request_id' => '123', 'type' => 'idme', 'review_instance_slug' => slug_id)
      end
    end
  end
end
