# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CSRF scenarios' do
  # ActionController::Base.allow_forgery_protection = false in the 'test' environment
  # We explicitly enable it for this spec
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
    # innocuous route chosen for setting the CSRF token in the response header
    get(v0_maintenance_windows_path)
    @token = response.headers['X-CSRF-Token']
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
            send(verb, '/csrf_test')
            expect(response.status).to eq 403
            expect(response.body).to match(/Invalid Authenticity Token/)
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
          get '/csrf_test'
          expect(response.status).to eq 200
        end
      end

      context 'with a CSRF token present' do
        it 'succeeds' do
          get '/csrf_test', headers: { 'X-CSRF-Token' => @token }
          expect(response.status).to eq 200
        end
      end
    end
  end

  # SAML callback
  describe 'POST SAML callback' do
    context 'without a CSRF token' do
      it 'does not raise an error' do
        post(v1_sessions_callback_path)
        expect(response.body).not_to match(/Invalid Authenticity Token/)
      end
    end
  end

  describe 'unknown route' do
    it 'skips CSRF validation' do
      post '/non_existent_route'
      expect(response.status).to eq(404)
      expect(response.body).to match(/There are no routes matching your request/)
    end
  end
end
