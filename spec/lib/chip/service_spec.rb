# frozen_string_literal: true

require 'rails_helper'
require 'chip/service'

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
    let(:service_obj) { described_class.build(options) }
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
end
