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

    context 'when client_id is set to mobile' do
      let(:client_id) { 'mobile' }
      let(:redirect_uri) { 'some-redirect-uri' }

      before do
        allow(Settings.sign_in).to receive(:redirect_uri).and_return(redirect_uri)
      end

      it 'returns expected redirect uri for mobile client' do
        expect(subject).to eq(expected_redirect_uri)
      end
    end

    context 'when client_id is set to web' do
      let(:client_id) { 'web' }
      let(:redirect_uri) { 'some-redirect-uri' }

      before do
        allow(Settings.sign_in).to receive(:web_redirect_uri).and_return(redirect_uri)
      end

      it 'returns expected redirect uri for mobile client' do
        expect(subject).to eq(expected_redirect_uri)
      end
    end

    context 'when client_id is set to an arbitrary value' do
      let(:client_id) { 'some-client-id' }
      let(:redirect_uri) { 'some-redirect-uri' }
      let(:expected_error) { SignIn::Errors::InvalidClientIdError }
      let(:expected_error_log) { 'Client id is not valid' }

      it 'raises an invalid client error' do
        expect { subject }.to raise_exception(expected_error, expected_error_log)
      end
    end

    context 'when client_state is nil' do
      let(:client_id) { 'web' }
      let(:redirect_uri) { 'some-redirect-uri' }
      let(:client_state) { nil }
      let(:state_param) { nil }

      before do
        allow(Settings.sign_in).to receive(:web_redirect_uri).and_return(redirect_uri)
      end

      it 'returns expected redirect uri without state param' do
        expect(subject).to eq(expected_redirect_uri)
      end
    end
  end
end
