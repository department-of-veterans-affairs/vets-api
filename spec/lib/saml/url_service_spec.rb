# frozen_string_literal: true

require 'rails_helper'
require 'saml/url_service'
require 'support/url_service_helpers'

RSpec.describe SAML::URLService do
  SAML::URLService::VIRTUAL_HOST_MAPPINGS.each do |vhost_url, values|
    let(:user) { build(:user) }
    let(:session) { Session.create(uuid: user.uuid, token: 'abracadabra') }

    subject { described_class.new(saml_settings, session: session, user: user) }

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

      it 'has sign in url: mhv_url' do
        expect(subject.mhv_url)
          .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
          .with_relay_state('originating_request_id' => '123')
      end

      it 'has sign in url: dslogon_url' do
        expect(subject.dslogon_url)
          .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
          .with_relay_state('originating_request_id' => '123')
      end

      it 'has sign in url: idme_url' do
        expect(subject.idme_url)
          .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
          .with_relay_state('originating_request_id' => '123')
      end

      it 'has sign in url: idme_url for new signup' do
        expect(subject.signup_url)
          .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
          .with_relay_state('originating_request_id' => '123')
          .with_params('op' => 'signup')
      end

      context 'verify_url' do
        it 'has sign in url: with (default authn_context)' do
          expect(user.authn_context).to eq('http://idmanagement.gov/ns/assurance/loa/1/vets')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('http://idmanagement.gov/ns/assurance/loa/3/vets')
          expect(subject.verify_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('originating_request_id' => '123')
        end

        it 'has sign in url: with (default authn_context) first time verification' do
          expect(user.authn_context).to eq('http://idmanagement.gov/ns/assurance/loa/1/vets')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('http://idmanagement.gov/ns/assurance/loa/3/vets')
          expect(subject.verify_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state(
              'originating_request_id' => '123'
            )
        end

        it 'has sign in url: with (myhealthevet authn_context)' do
          allow(user).to receive(:authn_context).and_return('myhealthevet')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('myhealthevet_loa3')
          expect(subject.verify_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('originating_request_id' => '123')
        end

        it 'has sign in url: with (myhealthevet authn_context) first time verification' do
          allow(user).to receive(:authn_context).and_return('myhealthevet')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('myhealthevet_loa3')
          expect(subject.verify_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state(
              'originating_request_id' => '123'
            )
        end

        it 'has sign in url: with (myhealthevet_multifactor authn_context)' do
          allow(user).to receive(:authn_context).and_return('myhealthevet_multifactor')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('myhealthevet_loa3')
          expect(subject.verify_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('originating_request_id' => '123')
        end

        it 'has sign in url: with (myhealthevet_multifactor authn_context) first time verification' do
          allow(user).to receive(:authn_context).and_return('myhealthevet_multifactor')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('myhealthevet_loa3')
          expect(subject.verify_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state(
              'originating_request_id' => '123'
            )
        end

        it 'has sign in url: with (dslogon authn_context)' do
          allow(user).to receive(:authn_context).and_return('dslogon')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('dslogon_loa3')
          expect(subject.verify_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('originating_request_id' => '123')
        end

        it 'has sign in url: with (dslogon authn_context) first time verification' do
          allow(user).to receive(:authn_context).and_return('dslogon')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('dslogon_loa3')
          expect(subject.verify_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state(
              'originating_request_id' => '123'
            )
        end

        it 'has sign in url: with (dslogon_multifactor authn_context)' do
          allow(user).to receive(:authn_context).and_return('dslogon_multifactor')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('dslogon_loa3')
          expect(subject.verify_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('originating_request_id' => '123')
        end

        it 'has sign in url: with (dslogon_multifactor authn_context) first time verification' do
          allow(user).to receive(:authn_context).and_return('dslogon_multifactor')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('dslogon_loa3')
          expect(subject.verify_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state(
              'originating_request_id' => '123'
            )
        end
      end

      context 'mfa_url' do
        it 'has mfa url: with (default authn_context)' do
          expect(user.authn_context).to eq('http://idmanagement.gov/ns/assurance/loa/1/vets')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('multifactor')
          expect(subject.mfa_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('originating_request_id' => '123')
        end

        it 'has mfa url: with (myhealthevet authn_context)' do
          allow(user).to receive(:authn_context).and_return('myhealthevet')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('myhealthevet_multifactor')
          expect(subject.mfa_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('originating_request_id' => '123')
        end

        it 'has mfa url: with (myhealthevet_loa3 authn_context)' do
          allow(user).to receive(:authn_context).and_return('myhealthevet_loa3')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('myhealthevet_multifactor')
          expect(subject.mfa_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('originating_request_id' => '123')
        end

        it 'has mfa url: with (dslogon authn_context)' do
          allow(user).to receive(:authn_context).and_return('dslogon')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('dslogon_multifactor')
          expect(subject.mfa_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('originating_request_id' => '123')
        end

        it 'has mfa url: with (dslogon_loa3 authn_context)' do
          allow(user).to receive(:authn_context).and_return('dslogon_loa3')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('dslogon_multifactor')
          expect(subject.mfa_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('originating_request_id' => '123')
        end
      end

      it 'has sign out url: slo_url' do
        expect(subject.slo_url).to include('https://api.idmelabs.com/saml/SingleLogoutService?SAMLRequest=')
      end

      context 'redirect urls' do
        it 'has a base url' do
          expect(subject.base_redirect_url).to eq(values[:base_redirect])
        end

        it 'has a login redirect url' do
          expect(subject.login_redirect_url).to eq(values[:base_redirect] + SAML::URLService::LOGIN_REDIRECT_PARTIAL)
        end

        it 'has a logout redirect url' do
          expect(subject.logout_redirect_url).to eq(values[:base_redirect] + SAML::URLService::LOGOUT_REDIRECT_PARTIAL)
        end
      end
    end
  end
end
