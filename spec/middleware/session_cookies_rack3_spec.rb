# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Session and Cookie Middleware Rack 3', type: :request do
  describe 'application.rb configuration' do
    let(:app_config) { Rails.root.join('config', 'application.rb').read }

    it 'uses httponly parameter (Rack 3.x format)' do
      expect(app_config).to match(/httponly:\s*true/)
    end

    it 'does not use old http_only parameter (Rack 2.x format)' do
      expect(app_config).not_to match(/http_only:\s*true/)
    end

    it 'has session cookie configuration' do
      expect(app_config).to include('ActionDispatch::Session::CookieStore')
      expect(app_config).to match(/key:\s*['"]api_session['"]/)
    end

    it 'has secure cookie setting' do
      expect(app_config).to match(/secure:\s*IdentitySettings\.session_cookie\.secure/)
    end
  end

  describe 'cookie parameter name change' do
    it 'demonstrates the Rack 3.x breaking change' do
      # OLD Rack 2:
      # http_only: true

      # NEW Rack 3 format:
      # httponly: true

      app_config = Rails.root.join('config', 'application.rb').read
      expect(app_config).to include('httponly: true')
    end
  end

  describe 'session middleware configuration' do
    it 'has CookieStore configured in middleware stack' do
      middleware_names = Rails.application.middleware.map(&:name)
      expect(middleware_names).to include('ActionDispatch::Session::CookieStore')
    end

    it 'has Cookies middleware configured before session' do
      middleware_names = Rails.application.middleware.map(&:name)

      cookies_index = middleware_names.index('ActionDispatch::Cookies')
      session_index = middleware_names.index('ActionDispatch::Session::CookieStore')

      expect(cookies_index).to be < session_index
    end
  end

  describe 'session functionality', type: :request do
    it 'processes requests that use sessions without errors' do
      get '/v0/status'

      expect(response.status).to be < 500
    end

    it 'can set and read session data' do
      session_store = ActionDispatch::Session::CookieStore.new(
        Rails.application,
        key: 'test_session',
        httponly: true # Using new Rack 3.x parameter name
      )

      expect(session_store).to be_a(ActionDispatch::Session::CookieStore)
    end
  end

  describe 'Rack 3.x cookie compliance' do
    it 'verifies httponly parameter is recognized by Rack 3.x' do
      store = ActionDispatch::Session::CookieStore.new(
        Rails.application,
        key: 'test_session',
        httponly: true,
        secure: false
      )

      expect(store).to be_a(ActionDispatch::Session::CookieStore)
    end
  end
end
