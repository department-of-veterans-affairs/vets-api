# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Proxy Headers Rack 3', type: :request do
  describe 'X-Forwarded headers handling' do
    it 'respects X-Forwarded-Proto for SSL detection' do
      get '/debug/headers', headers: { 'X-Forwarded-Proto' => 'https' }

      body = JSON.parse(response.body)
      expect(body['X-Forwarded-Proto']).to eq('https')
      expect(body['request.ssl?']).to be(true)
      expect(body['request.protocol']).to eq('https://')
    end

    it 'handles X-Forwarded-For headers' do
      get '/v0/status', headers: {
        'X-Forwarded-For' => '1.2.3.4, 10.0.0.1'
      }

      expect(response.status).to be < 500
    end

    it 'processes requests with proxy headers' do
      get '/v0/status', headers: {
        'X-Forwarded-For' => '1.2.3.4',
        'X-Forwarded-Proto' => 'https',
        'X-Forwarded-Host' => 'api.va.gov'
      }

      expect(response.status).to be < 500
    end
  end

  describe 'trusted proxy configuration' do
    it 'has trusted_proxies configuration in production.rb' do
      prod_config = Rails.root.join('config', 'environments', 'production.rb').read

      expect(prod_config).to include('RAILS_TRUSTED_PROXIES')
      expect(prod_config).to include('config.action_dispatch.trusted_proxies')
      expect(prod_config).to include('IPAddr.new')
    end

    it 'parses comma-separated proxy IPs from environment variable' do
      test_env_value = '10.0.0.0/8, 172.16.0.0/12'
      proxies = test_env_value.split(',').map { |proxy| IPAddr.new(proxy.strip) }

      expect(proxies.length).to eq(2)
      expect(proxies[0]).to be_a(IPAddr)
      expect(proxies[1]).to be_a(IPAddr)
    end
  end

  describe 'debug endpoint' do
    it 'provides header debugging information' do
      get '/debug/headers'

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')

      body = JSON.parse(response.body)
      expect(body).to have_key('X-Forwarded-Proto')
      expect(body).to have_key('request.ssl?')
      expect(body).to have_key('request.protocol')
    end

    it 'returns Rack 3.x compliant response' do
      get '/debug/headers'

      expect(response.status).to be_a(Integer)
      expect(response.body).to be_a(String)

      expect { JSON.parse(response.body) }.not_to raise_error
    end
  end

  describe 'Rack 3.x header handling' do
    it 'processes various header combinations without errors' do
      headers_to_test = [
        { 'X-Forwarded-Proto' => 'https' },
        { 'X-Forwarded-For' => '1.2.3.4' },
        { 'X-Real-IP' => '1.2.3.4' },
        { 'X-Forwarded-Host' => 'api.va.gov' }
      ]

      headers_to_test.each do |headers|
        get('/v0/status', headers:)
        expect(response.status).to be < 500
      end
    end
  end
end
