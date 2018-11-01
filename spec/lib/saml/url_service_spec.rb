# frozen_string_literal: true

require 'rails_helper'
require 'saml/url_service'

RSpec.describe SAML::URLService do
  SAML::URLService::VIRTUAL_HOST_MAPPINGS.each do |vhost_url, values|
    let(:user) { build(:user, :loa3) }
    let(:session) { Session.create(uuid: user.uuid, token: 'abracadabra') }

    subject { described_class.new(saml_settings, session: session, user: user) }

    before(:each) { User.create(user) }

    context "virtual host: #{vhost_url}" do
      let(:saml_settings) do
        build(:settings_no_context, assertion_consumer_service_url: "#{vhost_url}/auth/saml/callback")
      end
      
      it 'has sign in url: mhv_url' do
        expect(subject.mhv_url).to include('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
      end

      it 'has sign in url: dslogon_url' do
        expect(subject.dslogon_url).to include('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
      end

      it 'has sign in url: idme_loa1_url' do
        expect(subject.idme_loa1_url).to include('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
      end

      it 'has sign in url: idme_loa3_url' do
        expect(subject.idme_loa3_url).to include('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
      end

      it 'has sign in url: mfa_url' do
        expect(subject.mfa_url).to include('https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=')
      end

      it 'has sign out url: logout_url' do
        expect(subject.logout_url).to include('http://www.example.com/v0/sessions/logout?session=')
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
