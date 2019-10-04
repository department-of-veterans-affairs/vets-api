# frozen_string_literal: true

require 'rails_helper'
require 'saml/url_service'
require 'support/url_service_helpers'

RSpec.describe SAML::URLService do
  SAML::URLService::VIRTUAL_HOST_MAPPINGS.each do |vhost_url, values|
    subject { described_class.new(saml_settings, session: session, user: user, params: params) }

    let(:user) { build(:user) }
    let(:session) { Session.create(uuid: user.uuid, token: 'abracadabra') }

    around(:each) do |example|
      User.create(user)
      Timecop.freeze('2018-04-09T17:52:03Z')
      Thread.current['request_id'] = '123'
      example.run
      Timecop.return
    end

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
            expect(subject.login_redirect_url(auth: 'fail', code: '001'))
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
