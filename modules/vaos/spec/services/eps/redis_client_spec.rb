# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Eps::RedisClient do
  subject(:client) { described_class.new }

  let(:uuid) { '123' }
  let(:appointment_id) { '987654321' }
  let(:email) { 'test@example.com' }
  let(:cache_key) { "#{described_class::CACHE_KEY}:#{uuid}:#{appointment_id.last(4)}" }

  before do
    allow(Rails.cache).to receive(:write)
    allow(Rails.cache).to receive(:read)
    stub_const('Eps::AppointmentStatusCheckWorker', Class.new { def self.const_missing(*); end })
    stub_const('Eps::AppointmentStatusCheckWorker::CACHE_KEY_PREFIX', described_class::CACHE_KEY)
  end

  describe '#store_appointment_data' do
    before do
      allow(client).to receive(:generate_appointment_data_key).and_return(cache_key)
    end

    it 'stores appointment data in Redis with TTL' do
      expect(Rails.cache).to receive(:write).with(
        cache_key,
        { appointment_id:, email: },
        namespace: described_class::CACHE_NAMESPACE,
        expires_in: described_class::CACHE_TTL
      )

      client.store_appointment_data(uuid:, appointment_id:, email:)
    end

    context 'with missing parameters' do
      it 'raises ArgumentError when uuid is missing' do
        expect { client.store_appointment_data(uuid: nil, appointment_id:, email:) }
          .to raise_error(ArgumentError, 'User UUID is required')
      end

      it 'raises ArgumentError when appointment_id is missing' do
        expect { client.store_appointment_data(uuid:, appointment_id: nil, email:) }
          .to raise_error(ArgumentError, 'Appointment ID is required')
      end

      it 'raises ArgumentError when email is missing' do
        expect { client.store_appointment_data(uuid:, appointment_id:, email: nil) }
          .to raise_error(ArgumentError, 'Email is required')
      end
    end
  end

  describe '#fetch_appointment_data' do
    before do
      allow(client).to receive(:generate_appointment_data_key).and_return(cache_key)
    end

    it 'retrieves appointment data from Redis' do
      expect(Rails.cache).to receive(:read).with(
        cache_key,
        namespace: described_class::CACHE_NAMESPACE
      )

      client.fetch_appointment_data(uuid:, appointment_id:)
    end

    it 'returns nil when uuid is blank' do
      expect(client.fetch_appointment_data(uuid: nil, appointment_id:)).to be_nil
    end

    it 'returns nil when appointment_id is blank' do
      expect(client.fetch_appointment_data(uuid:, appointment_id: nil)).to be_nil
    end
  end

  describe '#generate_appointment_data_key' do
    let(:expected_key) { "#{described_class::CACHE_KEY}:#{uuid}:#{appointment_id.last(4)}" }

    before do
      allow_any_instance_of(described_class).to receive(:generate_appointment_data_key).and_call_original
    end

    it 'generates correct key format' do
      expect(client.send(:generate_appointment_data_key, uuid, appointment_id))
        .to eq(expected_key)
    end

    it 'handles nil appointment_id' do
      expect(client.send(:generate_appointment_data_key, uuid, nil))
        .to eq("#{described_class::CACHE_KEY}:#{uuid}:0000")
    end
  end
end