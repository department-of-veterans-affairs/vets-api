# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExternalApiApplicationController, type: :controller do
  controller do
    skip_before_action :authenticate
    def index
      render json: { 'test' => 'random data' }
    end
  end

  it 'does not set a CSRF token for GET requests' do
    get :index
    expect(response).to be_ok
    expect(cookies['X-CSRF-Token']).to be_nil
  end

  describe 'with forgery_protection and logging enabled' do
    around do |example|
      forgery_protection = ActionController::Base.allow_forgery_protection
      begin
        Settings.sentry.dsn = 'asdf'
        ActionController::Base.allow_forgery_protection = true
        example.run
      ensure
        Settings.sentry.dsn = nil
        ActionController::Base.allow_forgery_protection = forgery_protection
      end
    end

    it 'can post without a CSRF token header' do
      post :index
      expect(response).to be_ok
    end

    it 'will not log to sentry without CSRF token header' do
      expect(Raven).not_to receive(:capture_message)
      post :index
    end
  end
end
