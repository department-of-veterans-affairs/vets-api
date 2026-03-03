# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::SignInController, '#logingov_logout_proxy', type: :controller do
  describe 'GET logingov_logout_proxy' do
    subject { get(:logingov_logout_proxy, params: logingov_logout_proxy_params) }

    let(:logingov_logout_proxy_params) do
      {}.merge(state)
    end
    let(:state) { { state: state_value } }
    let(:state_value) { 'some-state-value' }

    context 'when state param is not given' do
      let(:state) { {} }
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:expected_error_status) { :bad_request }
      let(:expected_error_log) { '[SignInService] [V0::SignInController] logingov_logout_proxy error' }
      let(:expected_error_message) do
        { errors: expected_error }
      end
      let(:expected_error) { 'State is not defined' }

      before { allow(Rails.logger).to receive(:info) }

      it 'renders expected error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns expected status' do
        expect(subject).to have_http_status(expected_error_status)
      end

      it 'logs the failed authorize attempt' do
        expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_message)
        subject
      end
    end

    context 'when state param is given' do
      let(:state_value) { encoded_state }
      let(:encoded_state) { Base64.encode64(state_payload.to_json) }
      let(:state_payload) do
        {
          logout_redirect: client_logout_redirect_uri,
          seed:
        }
      end
      let(:seed) { 'some-seed' }
      let(:client_logout_redirect_uri) { 'some-client-logout-redirect-uri' }

      it 'returns ok status' do
        expect(subject).to have_http_status(:ok)
      end

      it 'renders expected logout redirect uri in template' do
        expect(subject.body).to match(client_logout_redirect_uri)
      end
    end
  end
end
