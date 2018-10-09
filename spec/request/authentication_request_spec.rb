# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Authentication', type: :request do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:session) { Session.create(uuid: user.uuid, token: 'abracadabra') }
  let(:authenticated_resource_path) { '/v0/prescriptions' }

  describe 'cookie based authentication' do
    let(:expiration_time) { 10 }
    let(:expiration_time_json) { expiration_time.minutes.from_now }
    let(:expiration_time_ttl) { expiration_time * 60 }
    let(:session_token) { session.token }
    let(:cookie_data) do
      {
        'vagovToken' => session_token,
        'patientIcn' => user.icn,
        'mhvCorrelationId' => user.mhv_correlation_id,
        'expirationTime' => expiration_time_json.iso8601(0)
      }
    end

    before(:each) do
      # set the users session to expire 10 minutes from now
      session.expire(expiration_time_ttl)
      user.identity.expire(expiration_time_ttl)
      user.expire(expiration_time_ttl)

      cookies[Settings.sso.cookie_name] = encrypt(ActiveSupport::JSON.encode(cookie_data))
      get authenticated_resource_path
    end

    context 'cookie based auth enabled' do
      around(:each) do |example|
        Settings.sso.cookie_enabled = true
        example.run
        Settings.sso.cookie_enabled = false
      end

      context 'with a valid cookie session' do
        it 'gets to the resource controller' do
          expect(response).to have_http_status(:forbidden)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('You do not have access to prescriptions')
        end

        it 'extends the session despite exception' do
          expect(Session.find('abracadabra').ttl).to be > expiration_time_ttl
        end
      end

      context 'with an expired cookie session' do
        let(:expiration_time_json) { 1.minute.ago }

        it 'does not get to the resource controller' do
          expect(response).to have_http_status(:unauthorized)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('Not authorized')
        end

        it 'does not extend the session' do
          expect(Session.find('abracadabra')).to be_nil
        end
      end

      context 'with invalid session token' do
        let(:session_token) { 'open-sessame' }

        it 'does not get to the resource controller' do
          expect(response).to have_http_status(:unauthorized)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('Not authorized')
        end

        it 'does not extend the session' do
          expect(Session.find('abracadabra').ttl).to be <= expiration_time_ttl
        end
      end
    end

    context 'cookie based auth disabled' do
      context 'with a valid cookie session' do
        it 'does not get to the resource controller' do
          expect(response).to have_http_status(:unauthorized)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('Not authorized')
        end

        it 'does not extend the session' do
          expect(Session.find('abracadabra').ttl).to be <= expiration_time_ttl
        end
      end

      context 'with an expired cookie session' do
        let(:expiration_time_json) { 1.minute.ago }

        it 'does not get to the resource controller' do
          expect(response).to have_http_status(:unauthorized)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('Not authorized')
        end

        it 'does not extend the session' do
          expect(Session.find('abracadabra')).to be_nil
        end
      end

      context 'with invalid session token' do
        let(:session_token) { 'open-sessame' }

        it 'does not get to the resource controller' do
          expect(response).to have_http_status(:unauthorized)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('Not authorized')
        end

        it 'does not extend the session' do
          expect(Session.find('abracadabra').ttl).to be <= expiration_time_ttl
        end
      end
    end
  end

  def encrypt(payload)
    Aes256CbcEncryptor.new(Settings.sso.cookie_key, Settings.sso.cookie_iv).encrypt(payload)
  end
end
