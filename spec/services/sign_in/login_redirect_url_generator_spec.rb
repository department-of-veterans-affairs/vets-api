# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::LoginRedirectUrlGenerator do
  describe '#perform' do
    subject do
      SignIn::LoginRedirectUrlGenerator.new(user_code_map: user_code_map).perform
    end

    let(:user_code_map) do
      create(:user_code_map, login_code: login_code, type: type, client_id: client_id, client_state: client_state)
    end
    let(:login_code) { 'some-login-code' }
    let(:type) { 'some-type' }
    let(:client_id) { 'some-client-id' }
    let(:client_state) { 'some-client-state' }
    let(:expected_redirect_uri) { "#{redirect_uri}?#{code_param}#{state_param}#{type_param}" }
    let(:code_param) { "code=#{login_code}" }
    let(:type_param) { "&type=#{type}" }
    let(:state_param) { "&state=#{client_state}" }
    let(:client_config) { create(:client_config) }

    context 'when client_state is not nil' do
      let(:client_state) { 'some-client-state' }
      let(:state_param) { "&state=#{client_state}" }
      let(:redirect_uri) { client_config.redirect_uri }
      let(:client_id) { client_config.client_id }

      it 'returns expected redirect uri with state param' do
        expect(subject).to eq(expected_redirect_uri)
      end
    end

    context 'when client_state is nil' do
      let(:client_state) { nil }
      let(:state_param) { nil }
      let(:redirect_uri) { client_config.redirect_uri }
      let(:client_id) { client_config.client_id }

      it 'returns expected redirect uri without state param' do
        expect(subject).to eq(expected_redirect_uri)
      end
    end
  end
end
