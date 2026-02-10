# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rack::Attack Multi-Party Forms Throttling', type: :request do
  let(:user) { create(:user, :loa3) }
  let(:headers) { { 'REMOTE_ADDR' => '1.2.3.4' } }

  before do
    # Enable Rack::Attack for these tests
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.flushdb
  end

  after do
    Rack::Attack.cache.store.flushdb
    Rack::Attack.enabled = false
  end

  describe 'multi_party_forms/authenticated throttle' do
    context 'when requests are made from an IP address' do
      before { sign_in_as(user) }

      it 'allows requests up to the rate limit (60 per minute)' do
        59.times do
          post '/v0/multi_party_forms/primary', headers: headers
          expect(response).not_to have_http_status(:too_many_requests)
        end

        post '/v0/multi_party_forms/primary', headers: headers
        expect(response).not_to have_http_status(:too_many_requests)
      end

      it 'throttles requests exceeding the rate limit' do
        60.times { post '/v0/multi_party_forms/primary', headers: headers }

        post '/v0/multi_party_forms/primary', headers: headers
        expect(response).to have_http_status(:too_many_requests)
      end

      it 'returns proper 429 response with rate limit headers' do
        61.times { post '/v0/multi_party_forms/primary', headers: headers }

        expect(response).to have_http_status(:too_many_requests)
        expect(response.headers['X-RateLimit-Limit']).to eq('60')
        expect(response.headers['X-RateLimit-Remaining']).to eq('0')
        expect(response.headers['X-RateLimit-Reset']).to be_present
      end

      it 'throttles all primary endpoints together' do
        20.times { post '/v0/multi_party_forms/primary', headers: headers }
        20.times { get '/v0/multi_party_forms/primary/123', headers: headers }
        20.times { put '/v0/multi_party_forms/primary/123', headers: headers }

        # 61st request should be throttled
        post '/v0/multi_party_forms/primary/123/complete', headers: headers
        expect(response).to have_http_status(:too_many_requests)
      end

      it 'throttles all secondary endpoints together' do
        30.times { get '/v0/multi_party_forms/secondary/123', headers: headers }
        30.times { put '/v0/multi_party_forms/secondary/123', headers: headers }

        # 61st request should be throttled
        post '/v0/multi_party_forms/secondary/123/submit', headers: headers
        expect(response).to have_http_status(:too_many_requests)
      end

      it 'throttles primary and secondary endpoints together' do
        30.times { post '/v0/multi_party_forms/primary', headers: headers }
        30.times { get '/v0/multi_party_forms/secondary/123', headers: headers }

        # 61st request should be throttled regardless of endpoint
        put '/v0/multi_party_forms/primary/123', headers: headers
        expect(response).to have_http_status(:too_many_requests)
      end

      it 'resets the rate limit after the time period expires' do
        60.times { post '/v0/multi_party_forms/primary', headers: headers }

        # Should be throttled
        post '/v0/multi_party_forms/primary', headers: headers
        expect(response).to have_http_status(:too_many_requests)

        # Travel forward 61 seconds to reset the rate limit
        travel 61.seconds do
          post '/v0/multi_party_forms/primary', headers: headers
          expect(response).not_to have_http_status(:too_many_requests)
        end
      end
    end

    context 'when requests come from different IP addresses' do
      before { sign_in_as(user) }

      it 'maintains independent rate limit counters per IP' do
        ip1_headers = { 'REMOTE_ADDR' => '1.2.3.4' }
        ip2_headers = { 'REMOTE_ADDR' => '5.6.7.8' }

        # IP 1 makes 60 requests
        60.times { post '/v0/multi_party_forms/primary', headers: ip1_headers }

        # IP 1 should be throttled
        post '/v0/multi_party_forms/primary', headers: ip1_headers
        expect(response).to have_http_status(:too_many_requests)

        # IP 2 should have its own rate limit
        post '/v0/multi_party_forms/primary', headers: ip2_headers
        expect(response).not_to have_http_status(:too_many_requests)
      end
    end

    context 'when user is not authenticated' do
      it 'still applies IP-based throttle to unauthenticated requests' do
        # Throttle applies to all requests from the same IP, regardless of authentication
        60.times { post '/v0/multi_party_forms/primary', headers: headers }

        post '/v0/multi_party_forms/primary', headers: headers
        # Should be throttled even without authentication
        expect(response).to have_http_status(:too_many_requests)
      end
    end

    context 'StatsD metrics tracking' do
      before { sign_in_as(user) }

      it 'tracks throttled requests in StatsD' do
        allow(StatsD).to receive(:increment)

        61.times { post '/v0/multi_party_forms/primary', headers: headers }

        expect(StatsD).to have_received(:increment).with(
          'api.rack_attack.throttled',
          tags: [
            'path:/v0/multi_party_forms/primary',
            'throttle_name:multi_party_forms/authenticated'
          ]
        )
      end
    end

    context 'load testing safelist' do
      it 'bypasses throttle for load testing IP addresses' do
        sign_in_as(user)
        loadtest_headers = { 'X-Real-Ip' => '100.103.248.1' }

        # Simulate request from load testing IP
        60.times do
          post '/v0/multi_party_forms/primary', headers: loadtest_headers
        end

        # Should not be throttled even after exceeding limit
        post '/v0/multi_party_forms/primary', headers: loadtest_headers
        expect(response).not_to have_http_status(:too_many_requests)
      end
    end
  end
end
