# frozen_string_literal: true

# This file is for exercising routes that should require CSRF protection.
# It is very much a WIP

require 'rails_helper'

RSpec.describe 'CSRF scenarios', type: :request do
  # ActionController::Base.allow_forgery_protection = false in the 'test' environment
  # We explicity enable it for this spec
  before(:all) do
    Settings.sentry.dsn = 'truthy'
    @original_val = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  after(:all) do
    Settings.sentry.dsn = nil
    ActionController::Base.allow_forgery_protection = @original_val
  end

  before do
    # innocuous route chosen for setting the CSRF token in the cookie
    get(v0_maintenance_windows_path)
    @token = response.cookies['X-CSRF-Token']
  end

  describe 'CSRF protection' do
    before(:all) do
      Rails.application.routes.draw do
        namespace :v0, defaults: { format: 'json' } do
          resources :maintenance_windows, only: [:index]
        end
        match 'csrf_test', to: 'v0/example#index', via: :all
      end
    end

    after(:all) do
      Rails.application.reload_routes!
    end
  
    %i[post put patch delete].each do |verb|
      context "for #{verb.upcase} requests" do
        context 'without a CSRF token present' do
          it 'raises an exception' do
            expect(Raven).to receive(:capture_message).with('Request susceptible to CSRF', level: 'info')
            send(verb, '/csrf_test')
            # expect(response.status).to eq 500
          end
        end
        context 'with a CSRF token present' do
          it 'succeeds' do
            send(verb, '/csrf_test', headers: { 'X-CSRF-Token' => @token })
            expect(response.status).to eq 200
          end
        end
      end
    end
    
    context 'for GET requests' do
      context 'without a CSRF token present' do
        it 'succeeds' do
          expect(Raven).not_to receive(:capture_message)
          get '/csrf_test'
          expect(response.status).to eq 200
        end
      end
      context 'with a CSRF token present' do
        it 'succeeds' do
          expect(Raven).not_to receive(:capture_message)
          get '/csrf_test', headers: { 'X-CSRF-Token' => @token }
          expect(response.status).to eq 200
        end
      end
    end
  end

  # SAML callback
  describe 'POST SAML callback' do
    context 'without a CSRF token' do
      context 'v0' do
        it 'does not raise an error' do
          expect(Raven).not_to receive(:capture_message).with('Request susceptible to CSRF', level: 'info')
          post(auth_saml_callback_path)
          # expect(response.body).not_to match(/ActionController::InvalidAuthenticityToken/)
        end
      end

      context 'v1' do
        it 'does not raise an error' do
          expect(Raven).not_to receive(:capture_message).with('Request susceptible to CSRF', level: 'info')
          post(v1_sessions_callback_path)
          # expect(response.body).not_to match(/ActionController::InvalidAuthenticityToken/)
        end
      end
    end
  end
end
