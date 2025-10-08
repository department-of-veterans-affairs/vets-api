# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::SignInController, type: :controller do
  include_context 'logingov_logout_proxy_setup'

  describe 'GET logingov_logout_proxy' do
    context 'when state param is not given' do
      let(:state) { {} }
      let(:expected_error) { 'State is not defined' }

      it_behaves_like 'logingov_logout_proxy_error_response'
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
