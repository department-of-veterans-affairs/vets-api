# frozen_string_literal: true

require 'rails_helper'

Rspec.describe 'TestUserDashboard::TudGithubOAuthProxy', type: :request do
  describe '#index' do
    context 'when the token is generated successfully' do
      before do
        allow(Faraday).to receive(:post).and_return(double(body: 'test=123&test=234&access_token=345', success?: true))
      end

      it 'returns the access token as json' do
        get('/test_user_dashboard/tud_github_oauth_proxy?code=123')

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')
        expect(response.body).to eql('{"access_token":"345"}')
      end
    end

    context 'when the token request fails' do
      before { allow(Faraday).to receive(:post).and_return(double(success?: false)) }

      it 'fails and does not return a token' do
        expect_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry)
        get('/test_user_dashboard/tud_github_oauth_proxy?code=123')

        expect(response).to have_http_status(:bad_request)
        expect(response.body).to eql(' ')
      end
    end
  end
end
