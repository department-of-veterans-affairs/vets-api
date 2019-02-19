# frozen_string_literal: true

require 'rails_helper'
require 'saml/url_service'

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
          .with_relay_state('start_time' => 1_523_296_323, 'originating_request_id' => '123')
      end

      it 'has sign in url: dslogon_url' do
        expect(subject.dslogon_url)
          .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
          .with_relay_state('start_time' => 1_523_296_323, 'originating_request_id' => '123')
      end

      it 'has sign in url: idme_loa1_url' do
        expect(subject.idme_loa1_url)
          .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
          .with_relay_state('start_time' => 1_523_296_323, 'originating_request_id' => '123')
      end

      it 'has sign in url: idme_loa1_url for new signup' do
        expect(subject.idme_loa1_url(signup: true))
          .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
          .with_relay_state('signup' => 'idme', 'start_time' => 1_523_296_323, 'originating_request_id' => '123')
          .with_params('op' => 'signup')
      end

      context 'idme_loa3_url' do
        it 'has sign in url: with (default authn_context)' do
          expect(user.authn_context).to eq('http://idmanagement.gov/ns/assurance/loa/1/vets')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('http://idmanagement.gov/ns/assurance/loa/3/vets')
          expect(subject.idme_loa3_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('start_time' => 1_523_296_323, 'originating_request_id' => '123')
        end

        it 'has sign in url: with (default authn_context) first time verification' do
          expect(user.authn_context).to eq('http://idmanagement.gov/ns/assurance/loa/1/vets')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('http://idmanagement.gov/ns/assurance/loa/3/vets')
          expect(subject.idme_loa3_url(verifying: true))
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state(
              'verifying' => LOA::IDME_LOA3,
              'start_time' => 1_523_296_323,
              'originating_request_id' => '123'
            )
        end

        it 'has sign in url: with (myhealthevet authn_context)' do
          allow(user).to receive(:authn_context).and_return('myhealthevet')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('myhealthevet_loa3')
          expect(subject.idme_loa3_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('start_time' => 1_523_296_323, 'originating_request_id' => '123')
        end

        it 'has sign in url: with (myhealthevet authn_context) first time verification' do
          allow(user).to receive(:authn_context).and_return('myhealthevet')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('myhealthevet_loa3')
          expect(subject.idme_loa3_url(verifying: true))
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state(
              'verifying' => 'myhealthevet_loa3',
              'start_time' => 1_523_296_323,
              'originating_request_id' => '123'
            )
        end

        it 'has sign in url: with (myhealthevet_multifactor authn_context)' do
          allow(user).to receive(:authn_context).and_return('myhealthevet_multifactor')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('myhealthevet_loa3')
          expect(subject.idme_loa3_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('start_time' => 1_523_296_323, 'originating_request_id' => '123')
        end

        it 'has sign in url: with (myhealthevet_multifactor authn_context) first time verification' do
          allow(user).to receive(:authn_context).and_return('myhealthevet_multifactor')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('myhealthevet_loa3')
          expect(subject.idme_loa3_url(verifying: true))
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state(
              'verifying' => 'myhealthevet_loa3',
              'start_time' => 1_523_296_323,
              'originating_request_id' => '123'
            )
        end

        it 'has sign in url: with (dslogon authn_context)' do
          allow(user).to receive(:authn_context).and_return('dslogon')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('dslogon_loa3')
          expect(subject.idme_loa3_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('start_time' => 1_523_296_323, 'originating_request_id' => '123')
        end

        it 'has sign in url: with (dslogon authn_context) first time verification' do
          allow(user).to receive(:authn_context).and_return('dslogon')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('dslogon_loa3')
          expect(subject.idme_loa3_url(verifying: true))
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state(
              'verifying' => 'dslogon_loa3',
              'start_time' => 1_523_296_323,
              'originating_request_id' => '123'
            )
        end

        it 'has sign in url: with (dslogon_multifactor authn_context)' do
          allow(user).to receive(:authn_context).and_return('dslogon_multifactor')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('dslogon_loa3')
          expect(subject.idme_loa3_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('start_time' => 1_523_296_323, 'originating_request_id' => '123')
        end

        it 'has sign in url: with (dslogon_multifactor authn_context) first time verification' do
          allow(user).to receive(:authn_context).and_return('dslogon_multifactor')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('dslogon_loa3')
          expect(subject.idme_loa3_url(verifying: true))
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state(
              'verifying' => 'dslogon_loa3',
              'start_time' => 1_523_296_323,
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
            .with_relay_state('start_time' => 1_523_296_323, 'originating_request_id' => '123')
        end

        it 'has mfa url: with (myhealthevet authn_context)' do
          allow(user).to receive(:authn_context).and_return('myhealthevet')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('myhealthevet_multifactor')
          expect(subject.mfa_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('start_time' => 1_523_296_323, 'originating_request_id' => '123')
        end

        it 'has mfa url: with (myhealthevet_loa3 authn_context)' do
          allow(user).to receive(:authn_context).and_return('myhealthevet_loa3')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('myhealthevet_multifactor')
          expect(subject.mfa_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('start_time' => 1_523_296_323, 'originating_request_id' => '123')
        end

        it 'has mfa url: with (dslogon authn_context)' do
          allow(user).to receive(:authn_context).and_return('dslogon')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('dslogon_multifactor')
          expect(subject.mfa_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('start_time' => 1_523_296_323, 'originating_request_id' => '123')
        end

        it 'has mfa url: with (dslogon_loa3 authn_context)' do
          allow(user).to receive(:authn_context).and_return('dslogon_loa3')
          expect_any_instance_of(OneLogin::RubySaml::Settings)
            .to receive(:authn_context=).with('dslogon_multifactor')
          expect(subject.mfa_url)
            .to be_an_idme_saml_url('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
            .with_relay_state('start_time' => 1_523_296_323, 'originating_request_id' => '123')
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

  RSpec::Matchers.define :be_an_idme_saml_url do |expected_url_partial|
    match do |actual_url|
      begin
        # Use the URI library to parse the string, returning false if this fails.
        query_params = CGI.parse(URI.parse(actual_url).query)
        relay_state_params = query_params['RelayState'].present? ? JSON.parse(query_params['RelayState']&.first) : nil
        other_params = Hash[query_params.except('RelayState', 'SAMLRequest').map { |k, v| [k, v.first] }]
        values_match?(Regexp.new(Regexp.escape(expected_url_partial)), actual_url) &&
          (relay_state_params.present? ? values_match?(relay_state_params, @relay_state_params) : true) &&
          (other_params.present? ? values_match?(other_params, @other_params) : true)
      rescue URI::InvalidURIError
        false
      end
    end

    chain :with_relay_state do |relay_state_params|
      @relay_state_params = relay_state_params
    end

    chain :with_params do |other_params|
      @other_params = other_params
    end

    diffable
  end
end
