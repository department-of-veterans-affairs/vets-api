# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CSRF Token Refresh', type: :request do
  describe 'HEAD /v0/csrf_token' do
    before do
      allow(ActionController::Base).to receive(:allow_forgery_protection).and_return(true)
    end

    it 'returns a 200 status and sets the X-CSRF-Token header' do
      head '/v0/csrf_token'

      expect(response).to have_http_status(:no_content)
      expect(response.headers['X-CSRF-Token']).to be_present
    end
  end
end
