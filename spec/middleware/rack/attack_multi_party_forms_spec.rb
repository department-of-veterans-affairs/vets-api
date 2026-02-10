# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rack::Attack Multi-Party Forms Throttling', type: :request do
  let(:user) { create(:user, :loa3) }
  let(:user2) { create(:user, :loa3) }

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
    let(:primary_endpoints) do
      [
        { method: :post, path: '/v0/multi_party_forms/primary' },
        { method: :get, path: '/v0/multi_party_forms/primary/123' },
        { method: :put, path: '/v0/multi_party_forms/primary/123' },
        { method: :post, path: '/v0/multi_party_forms/primary/123/complete' }
      ]
    end

    let(:secondary_endpoints) do
      [
        { method: :get, path: '/v0/multi_party_forms/secondary/123' },
        { method: :put, path: '/v0/multi_party_forms/secondary/123' },
        { method: :post, path: '/v0/multi_party_forms/secondary/123/submit' }
      ]
    end

    context 'when authenticated user makes requests' do
      before { sign_in_as(user) }

      it 'allows requests up to the rate limit (60 per minute)' do
        59.times do
          post '/v0/multi_party_forms/primary'
          expect(response).not_to have_http_status(:too_many_requests)
        end

        post '/v0/multi_party_forms/primary'
        expect(response).not_to have_http_status(:too_many_requests)
      end

      it 'throttles requests exceeding the rate limit' do
        60.times { post '/v0/multi_party_forms/primary' }

        post '/v0/multi_party_forms/primary'
        expect(response).to have_http_status(:too_many_requests)
      end

      it 'returns proper 429 response with rate limit headers' do
        61.times { post '/v0/multi_party_forms/primary' }

        expect(response).to have_http_status(:too_many_requests)
        expect(response.headers['X-RateLimit-Limit']).to eq('60')
        expect(response.headers['X-RateLimit-Remaining']).to eq('0')
        expect(response.headers['X-RateLimit-Reset']).to be_present
      end

      it 'throttles all primary endpoints together' do
        20.times { post '/v0/multi_party_forms/primary' }
        20.times { get '/v0/multi_party_forms/primary/123' }
        20.times { put '/v0/multi_party_forms/primary/123' }

        # 61st request should be throttled
        post '/v0/multi_party_forms/primary/123/complete'
        expect(response).to have_http_status(:too_many_requests)
      end

      it 'throttles all secondary endpoints together' do
        30.times { get '/v0/multi_party_forms/secondary/123' }
        30.times { put '/v0/multi_party_forms/secondary/123' }

        # 61st request should be throttled
        post '/v0/multi_party_forms/secondary/123/submit'
        expect(response).to have_http_status(:too_many_requests)
      end

      it 'throttles primary and secondary endpoints together' do
        30.times { post '/v0/multi_party_forms/primary' }
        30.times { get '/v0/multi_party_forms/secondary/123' }

        # 61st request should be throttled regardless of endpoint
        put '/v0/multi_party_forms/primary/123'
        expect(response).to have_http_status(:too_many_requests)
      end

      it 'resets the rate limit after the time period expires' do
        60.times { post '/v0/multi_party_forms/primary' }

        # Should be throttled
        post '/v0/multi_party_forms/primary'
        expect(response).to have_http_status(:too_many_requests)

        # Travel forward 61 seconds to reset the rate limit
        travel 61.seconds do
          post '/v0/multi_party_forms/primary'
          expect(response).not_to have_http_status(:too_many_requests)
        end
      end
    end

    context 'when different users make requests' do
      it 'maintains independent rate limit counters per user' do
        sign_in_as(user)
        60.times { post '/v0/multi_party_forms/primary' }

        # User 1 should be throttled
        post '/v0/multi_party_forms/primary'
        expect(response).to have_http_status(:too_many_requests)

        # User 2 should have their own rate limit
        sign_in_as(user2)
        post '/v0/multi_party_forms/primary'
        expect(response).not_to have_http_status(:too_many_requests)
      end

      it 'does not share rate limits across different users' do
        # User 1 makes 30 requests
        sign_in_as(user)
        30.times { post '/v0/multi_party_forms/primary' }

        # User 2 should start with full rate limit
        sign_in_as(user2)
        60.times { post '/v0/multi_party_forms/primary' }

        # User 2's 61st request should be throttled
        post '/v0/multi_party_forms/primary'
        expect(response).to have_http_status(:too_many_requests)

        # But User 1 should still have requests available
        sign_in_as(user)
        post '/v0/multi_party_forms/primary'
        expect(response).not_to have_http_status(:too_many_requests)
      end
    end

    context 'when user is not authenticated' do
      it 'does not apply throttle to unauthenticated requests' do
        # Throttle only applies when warden user exists
        # Unauthenticated requests will fail for other reasons (401)
        # but won't be throttled by this specific rule
        61.times { post '/v0/multi_party_forms/primary' }

        # Should get 401 Unauthorized, not 429 Too Many Requests
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'StatsD metrics tracking' do
      before { sign_in_as(user) }

      it 'tracks throttled requests in StatsD' do
        allow(StatsD).to receive(:increment)

        61.times { post '/v0/multi_party_forms/primary' }

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

        # Simulate request from load testing IP
        60.times do
          post '/v0/multi_party_forms/primary', headers: { 'X-Real-Ip' => '100.103.248.1' }
        end

        # Should not be throttled even after exceeding limit
        post '/v0/multi_party_forms/primary', headers: { 'X-Real-Ip' => '100.103.248.1' }
        expect(response).not_to have_http_status(:too_many_requests)
      end
    end
  end
end
