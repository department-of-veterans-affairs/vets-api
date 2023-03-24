# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::LoginRedirectUrlGenerator do
  describe '#perform' do
    subject do
      SignIn::LoginRedirectUrlGenerator.new(user_code_map: user_code_map).perform
    end

    let(:user_code_map) do
      create(:user_code_map,
             login_code: login_code,
             type: type,
             client_config: client_config,
             client_state: client_state)
    end
    let(:login_code) { 'some-login-code' }
    let(:type) { 'some-type' }
    let(:client_state) { 'some-client-state' }
    let(:client_config) { create(:client_config) }
    let(:redirect_uri) { client_config.redirect_uri }
    let(:client_id) { client_config.client_id }

    it 'renders the oauth_get_form template' do
      expect(subject).to include('form id="oauth-form"')
    end

    it 'directs to the given redirect url set in the client configuration' do
      expect(subject).to include("action=\"#{redirect_uri}\"")
    end

    it 'includes expected code param' do
      expect(subject).to include("value=\"#{login_code}\"")
    end

    it 'includes expected type param' do
      expect(subject).to include("value=\"#{type}\"")
    end

    context 'when client_state is not nil' do
      let(:client_state) { 'some-client-state' }

      it 'includes expected state param' do
        expect(subject).to include("value=\"#{client_state}\"")
      end
    end

    context 'when client_state is nil' do
      let(:client_state) { nil }

      it 'does not include expected state param' do
        expect(subject).not_to include("value=\"#{client_state}\"")
      end
    end
  end
end
