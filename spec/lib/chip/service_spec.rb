# frozen_string_literal: true

require 'rails_helper'
require 'chip/service'
require 'chip/service_exception'

describe Chip::Service do
  subject { described_class }

  let(:tenant_name) { 'mobile_app' }
  let(:tenant_id) { Settings.chip[tenant_name].tenant_id }
  let(:username) { 'test_username' }
  let(:password) { 'test_password' }
  let(:options) { { tenant_id:, tenant_name:, username:, password: } }

  describe '#initialize' do
    let(:expected_error) { ArgumentError }

    context 'when username is blank' do
      let(:expected_error_message) { 'Invalid username' }

      it 'raises error' do
        expect do
          subject.new(tenant_id:, tenant_name:, username: '', password:)
        end.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when password is blank' do
      let(:expected_error_message) { 'Invalid password' }

      it 'raises error' do
        expect do
          subject.new(tenant_id:, tenant_name:, username:, password: '')
        end.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when tenant_name is blank' do
      let(:expected_error_message) { 'Invalid tenant parameters' }

      it 'raises error' do
        expect do
          subject.new(tenant_id:, tenant_name: '', username:, password:)
        end.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when tenant_id is blank' do
      let(:expected_error_message) { 'Invalid tenant parameters' }

      it 'raises error' do
        expect do
          subject.new(tenant_id: '', tenant_name:, username:, password:)
        end.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when tenant_name does not exist' do
      let(:expected_error_message) { 'Tenant parameters do not exist' }

      it 'raises error' do
        expect do
          subject.new(tenant_id:, tenant_name: 'abc', username:, password:)
        end.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when tenant_name and tenant_id do not match' do
      let(:expected_error_message) { 'Tenant parameters do not exist' }

      it 'raises error' do
        expect do
          subject.new(tenant_id: '12345', tenant_name:, username:, password:)
        end.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when called with valid parameters' do
      it 'creates service object' do
        service_obj = subject.new(tenant_id:, tenant_name:, username:, password:)
        expect(service_obj).to be_a(Chip::Service)
        expect(service_obj.redis_client).to be_a(Chip::RedisClient)
      end
    end
  end

  describe 'token' do
    let(:service_obj) { subject.build(options) }
    let(:redis_client) { double }
    let(:token) { '123' }

    context 'when token is already cached in redis' do
      before do
        allow(Chip::RedisClient).to receive(:build).and_return(redis_client)
        allow(redis_client).to receive(:get).and_return(token)
      end

      it 'returns token from redis' do
        expect(service_obj).not_to receive(:get_token)

        expect(service_obj.send(:token)).to eq(token)
      end
    end

    context 'when token is not cached in redis' do
      let(:token) { 'test_token' }
      let(:faraday_response) { double('Faraday::Response', body: { 'token' => token }.to_json) }

      before do
        allow(Chip::RedisClient).to receive(:build).and_return(redis_client)
        allow(redis_client).to receive(:get).and_return(nil)
      end

      it 'calls get_token and returns token' do
        expect(service_obj).to receive(:get_token).and_return(faraday_response)
        expect(redis_client).to receive(:save).with(token:)

        expect(service_obj.send(:token)).to eq(token)
      end
    end
  end

  describe '#get_token' do
    let(:service_obj) { subject.build(options) }
    let(:response_body) { { 'token' => 'chip-123-abc' } }

    context 'when chip returns successful response' do
      before do
        expect(StatsD).to receive(:increment).once.with('api.chip.get_token.total')
      end

      it 'returns response' do
        VCR.use_cassette('chip/token/token_200') do
          response = service_obj.get_token

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)).to eq(response_body)
        end
      end
    end

    context 'when chip returns a failure' do
      let(:key) { 'CHIP_500' }
      let(:response_values) { { status: 500, detail: nil, code: key, source: nil } }
      let(:original_body) { '{"status":"500", "title":"Could not retrieve a token from LoROTA"}' }
      let(:exception) { Common::Exceptions::BackendServiceException.new(key, response_values, 500, original_body) }

      before do
        expect(StatsD).to receive(:increment).once.with('api.chip.get_token.fail', tags: ['error:ChipServiceException'])
        expect(StatsD).to receive(:increment).once.with('api.chip.get_token.total')
      end

      it 'throws exception' do
        VCR.use_cassette('chip/token/token_500') do
          expect { service_obj.get_token }.to raise_exception(Chip::ServiceException) { |error|
            expect(error.key).to eq(key)
            expect(error.response_values).to eq(response_values)
            expect(error.original_body).to eq(original_body)
            expect(error.original_status).to eq(500)
          }
        end
      end
    end
  end
end
