# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Eps::RedisClient do
  subject(:client) { described_class.new }

  let(:uuid) { '123' }
  let(:appointment_id) { '987654321' }
  let(:email) { 'test@example.com' }
  let(:appointment_data_key) { "#{described_class::CACHE_KEY}:#{uuid}:#{appointment_id.last(4)}" }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
  end

  describe '#store_appointment_data' do
    it 'stores encrypted appointment data in Redis with TTL' do
      client.store_appointment_data(uuid:, appointment_id:, email:)

      # Verify data was written to cache
      cached_data = Rails.cache.read(appointment_data_key, namespace: described_class::CACHE_NAMESPACE)
      expect(cached_data).to be_present
      expect(cached_data).to be_a(String) # Encrypted ciphertext
      expect(cached_data).not_to include(email) # Email should not be visible in plaintext
    end

    it 'encrypts data before storing' do
      lockbox_instance = client.send(:lockbox)
      expect(lockbox_instance).to receive(:encrypt).and_call_original

      client.store_appointment_data(uuid:, appointment_id:, email:)
    end

    describe 'configuration' do
      it 'has 26 hour TTL to exceed retry duration' do
        expect(described_class::CACHE_TTL).to eq(26.hours)
      end
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
    context 'with encrypted data in cache' do
      before do
        client.store_appointment_data(uuid:, appointment_id:, email:)
      end

      it 'retrieves and decrypts appointment data from Redis' do
        result = client.fetch_appointment_data(uuid:, appointment_id:)

        expect(result).to be_a(Hash)
        expect(result[:appointment_id]).to eq(appointment_id)
        expect(result[:email]).to eq(email)
      end

      it 'decrypts data after retrieval' do
        lockbox_instance = client.send(:lockbox)
        expect(lockbox_instance).to receive(:decrypt).and_call_original

        client.fetch_appointment_data(uuid:, appointment_id:)
      end
    end

    context 'with no data in cache' do
      it 'returns nil when no data exists' do
        expect(client.fetch_appointment_data(uuid:, appointment_id:)).to be_nil
      end
    end

    context 'with invalid encrypted data' do
      before do
        # Store invalid encrypted data
        Rails.cache.write(
          appointment_data_key,
          'invalid-encrypted-data',
          namespace: described_class::CACHE_NAMESPACE
        )
      end

      it 'returns nil and logs warning when decryption fails' do
        expect(Rails.logger).to receive(:warn).with(/Failed to decrypt cached data/)

        result = client.fetch_appointment_data(uuid:, appointment_id:)
        expect(result).to be_nil
      end
    end

    it 'returns nil when uuid is blank' do
      expect(client.fetch_appointment_data(uuid: nil, appointment_id:)).to be_nil
    end

    it 'returns nil when appointment_id is blank' do
      expect(client.fetch_appointment_data(uuid:, appointment_id: nil)).to be_nil
    end
  end

  describe 'encryption round-trip' do
    it 'successfully encrypts and decrypts data' do
      client.store_appointment_data(uuid:, appointment_id:, email:)
      result = client.fetch_appointment_data(uuid:, appointment_id:)

      expect(result).to eq({ appointment_id:, email: })
    end

    it 'handles special characters in email' do
      special_email = 'test+special@example.com'
      client.store_appointment_data(uuid:, appointment_id:, email: special_email)
      result = client.fetch_appointment_data(uuid:, appointment_id:)

      expect(result[:email]).to eq(special_email)
    end
  end

  describe '#generate_appointment_data_key' do
    it 'generates correct key format' do
      expect(client.send(:generate_appointment_data_key, uuid, appointment_id))
        .to eq("#{described_class::CACHE_KEY}:#{uuid}:#{appointment_id.last(4)}")
    end

    it 'handles nil appointment_id' do
      expect(client.send(:generate_appointment_data_key, uuid, nil))
        .to eq("#{described_class::CACHE_KEY}:#{uuid}:0000")
    end
  end

  describe '#lockbox' do
    context 'when Settings.lockbox.master_key is a string' do
      it 'creates a Lockbox instance successfully' do
        expect { client.send(:lockbox) }.not_to raise_error
        expect(client.send(:lockbox)).to be_a(Lockbox::Encryptor)
      end
    end

    context 'when Settings.lockbox.master_key is nil' do
      before do
        allow(Settings.lockbox).to receive(:master_key).and_return(nil)
      end

      it 'raises ArgumentError' do
        expect { client.send(:lockbox) }
          .to raise_error(ArgumentError, 'Lockbox master key is required')
      end
    end

    context 'when Settings.lockbox.master_key is an unexpected type (env_parse_values edge case)' do
      before do
        # Simulate env_parse_values converting a numeric string to an integer
        allow(Settings.lockbox).to receive(:master_key).and_return(123)
      end

      it 'converts to string and attempts to use it' do
        # The integer will be converted to string, but Lockbox will reject it due to invalid format
        # This tests that our .to_s coercion happens before Lockbox validation
        expect { client.send(:lockbox) }.to raise_error(Lockbox::Error)
      end
    end
  end
end
