# frozen_string_literal: true

require 'rails_helper'

describe VAOS::SessionService do
  let(:klass) do
    Class.new(VAOS::SessionService) do
      def get_systems
        perform(:get, '/mvi/v1/patients/session/identifiers.json', nil, headers)
      end
    end
  end
  let(:user) { build(:user, :vaos) }
  let(:request_id) { SecureRandom.uuid }
  let(:expected_request_headers) do
    {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'Referer' => 'https://review-instance.va.gov',
      'User-Agent' => 'Vets.gov Agent',
      'X-Request-ID' => request_id,
      'X-VAMF-JWT' => 'stubbed_token'
    }
  end

  before do
    RequestStore['request_id'] = request_id
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
    allow(Settings).to receive(:hostname).and_return('id.review.vetsgov-internal')
  end

  describe 'headers' do
    it 'includes Referer, X-VAMF-JWT and X-Request-ID headers in each request' do
      VCR.use_cassette('vaos/systems/get_systems', match_requests_on: %i[method path query]) do
        response = klass.new(user).get_systems
        expect(response.request_headers).to eq(expected_request_headers)
      end
    end
  end
end
