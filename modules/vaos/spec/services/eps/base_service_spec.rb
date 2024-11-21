# frozen_string_literal: true

require 'rails_helper'

describe Eps::BaseService do
  let(:user) { double('User', account_uuid: '1234') }
  let(:service) { described_class.new(user) }

  describe '#headers' do
    it 'returns the correct headers' do
      allow(RequestStore.store).to receive(:[]).with('request_id').and_return('request-id')

      expected_headers = {
        'Authorization' => 'Bearer 1234',
        'Content-Type' => 'application/json',
        'X-Request-ID' => 'request-id'
      }
      expect(service.headers).to eq(expected_headers)
    end
  end

  describe '#config' do
    it 'returns the Eps::Configuration instance' do
      expect(service.config).to be_instance_of(Eps::Configuration)
    end
  end
end
