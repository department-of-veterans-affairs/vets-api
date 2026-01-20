# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MHVMetricsUniqueUserEvent, type: :model do
  let(:user_id) { SecureRandom.uuid }
  let(:event_name) { 'test_event' }
  let(:cache_key) { "#{user_id}:#{event_name}" }

  # Test data setup
  let(:valid_attributes) do
    {
      user_id:,
      event_name:
    }
  end

  describe 'validations' do
    it 'validates presence of user_id' do
      record = described_class.new(valid_attributes.except(:user_id))
      expect(record).not_to be_valid
      expect(record.errors[:user_id]).to include("can't be blank")
    end

    it 'validates presence of event_name' do
      record = described_class.new(valid_attributes.except(:event_name))
      expect(record).not_to be_valid
      expect(record.errors[:event_name]).to include("can't be blank")
    end

    it 'validates event_name length maximum of 50 characters' do
      long_event_name = 'a' * 51
      record = described_class.new(valid_attributes.merge(event_name: long_event_name))
      expect(record).not_to be_valid
      expect(record.errors[:event_name]).to include('is too long (maximum is 50 characters)')
    end

    it 'allows event_name with exactly 50 characters' do
      event_name = 'a' * 50
      record = described_class.new(valid_attributes.merge(event_name:))
      expect(record).to be_valid
    end

    it 'is valid with valid attributes' do
      record = described_class.new(valid_attributes)
      expect(record).to be_valid
    end
  end

  describe '.event_exists?' do
    context 'with invalid parameters' do
      it 'raises ArgumentError when user_id is blank' do
        expect do
          described_class.event_exists?(user_id: '', event_name:)
        end.to raise_error(ArgumentError, 'user_id is required')
      end

      it 'raises ArgumentError when user_id is nil' do
        expect do
          described_class.event_exists?(user_id: nil, event_name:)
        end.to raise_error(ArgumentError, 'user_id is required')
      end

      it 'raises ArgumentError when event_name is blank' do
        expect do
          described_class.event_exists?(user_id:, event_name: '')
        end.to raise_error(ArgumentError, 'event_name is required')
      end

      it 'raises ArgumentError when event_name is too long' do
        long_event_name = 'a' * 51
        expect do
          described_class.event_exists?(user_id:, event_name: long_event_name)
        end.to raise_error(ArgumentError, 'event_name must be 50 characters or less')
      end
    end

    context 'with valid parameters' do
      before do
        allow(described_class).to receive(:key_cached?)
        allow(described_class).to receive(:mark_key_cached)
        allow(described_class).to receive(:exists?)
      end

      it 'returns true when event exists in cache' do
        allow(described_class).to receive(:key_cached?).with(cache_key).and_return(true)

        result = described_class.event_exists?(user_id:, event_name:)

        expect(result).to be(true)
        expect(described_class).not_to have_received(:exists?)
      end

      it 'checks database when not in cache and caches result when found' do
        allow(described_class).to receive(:key_cached?).with(cache_key).and_return(false)
        allow(described_class).to receive(:exists?).with(user_id:, event_name:).and_return(true)

        result = described_class.event_exists?(user_id:, event_name:)

        expect(result).to be(true)
        expect(described_class).to have_received(:exists?).with(user_id:, event_name:)
        expect(described_class).to have_received(:mark_key_cached).with(cache_key)
      end

      it 'returns false when event does not exist and does not cache negative result' do
        allow(described_class).to receive(:key_cached?).with(cache_key).and_return(false)
        allow(described_class).to receive(:exists?).with(user_id:, event_name:).and_return(false)

        result = described_class.event_exists?(user_id:, event_name:)

        expect(result).to be(false)
        expect(described_class).not_to have_received(:mark_key_cached)
      end
    end
  end

  describe '.record_event' do
    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:debug)
      allow(described_class).to receive(:key_cached?)
      allow(described_class).to receive(:mark_key_cached)
    end

    context 'with invalid parameters' do
      it 'raises ArgumentError when user_id is blank' do
        expect do
          described_class.record_event(user_id: '', event_name:)
        end.to raise_error(ArgumentError, 'user_id is required')
      end

      it 'raises ArgumentError when event_name is blank' do
        expect do
          described_class.record_event(user_id:, event_name: '')
        end.to raise_error(ArgumentError, 'event_name is required')
      end
    end

    context 'when event exists in cache' do
      before do
        allow(described_class).to receive(:key_cached?).with(cache_key).and_return(true)
        allow(Rails.logger).to receive(:debug)
      end

      it 'returns false without attempting database operation' do
        result = described_class.record_event(user_id:, event_name:)

        expect(result).to be(false)
        expect(Rails.logger).to have_received(:debug)
          .with('UUM: Event found in cache', { user_id:, event_name: })
      end
    end

    context 'when event does not exist in cache' do
      before do
        allow(described_class).to receive(:key_cached?).with(cache_key).and_return(false)
      end

      context 'and record is successfully created' do
        let(:insert_result) { double('InsertResult', rows: [[user_id, event_name]]) }

        before do
          allow(described_class).to receive(:insert)
            .with(
              { user_id:, event_name: },
              unique_by: %i[user_id event_name],
              returning: %i[user_id event_name]
            )
            .and_return(insert_result)
        end

        it 'returns true and logs success' do
          result = described_class.record_event(user_id:, event_name:)

          expect(result).to be(true)
          expect(described_class).to have_received(:insert)
            .with(
              { user_id:, event_name: },
              unique_by: %i[user_id event_name],
              returning: %i[user_id event_name]
            )
          expect(described_class).to have_received(:mark_key_cached).with(cache_key)
          expect(Rails.logger).to have_received(:debug)
            .with('UUM: New unique event recorded', { user_id:, event_name: })
        end
      end

      context 'and record already exists in database' do
        let(:insert_result) { double('InsertResult', rows: []) }

        before do
          allow(described_class).to receive(:insert)
            .with(
              { user_id:, event_name: },
              unique_by: %i[user_id event_name],
              returning: %i[user_id event_name]
            )
            .and_return(insert_result)
          allow(Rails.logger).to receive(:debug)
        end

        it 'returns false and logs debug message' do
          result = described_class.record_event(user_id:, event_name:)

          expect(result).to be(false)
          expect(described_class).to have_received(:mark_key_cached).with(cache_key)
          expect(Rails.logger).to have_received(:debug)
            .with('UUM: Duplicate event found in database', { user_id:, event_name: })
        end
      end
    end

    context 'integration test with real database' do
      let(:test_user_id) { SecureRandom.uuid }
      let(:test_event_name) { 'integration_test_event' }

      before do
        # Ensure cache is clear for this specific key
        Rails.cache.delete("#{test_user_id}:#{test_event_name}", namespace: 'unique_user_metrics')
      end

      after do
        # Cleanup test data and cache
        described_class.where(user_id: test_user_id).delete_all
        Rails.cache.delete("#{test_user_id}:#{test_event_name}", namespace: 'unique_user_metrics')
      end

      it 'returns correct values for new vs duplicate inserts' do
        # First insert with cache clear - should return true (new event)
        Rails.cache.delete("#{test_user_id}:#{test_event_name}", namespace: 'unique_user_metrics')
        result1 = described_class.record_event(user_id: test_user_id, event_name: test_event_name)
        expect(result1).to be(true), 'First insert should return true for new event'

        # Second insert with cache clear - should return false (duplicate)
        Rails.cache.delete("#{test_user_id}:#{test_event_name}", namespace: 'unique_user_metrics')
        result2 = described_class.record_event(user_id: test_user_id, event_name: test_event_name)
        expect(result2).to be(false), 'Duplicate insert should return false'

        # Subsequent inserts should also return false
        3.times do
          Rails.cache.delete("#{test_user_id}:#{test_event_name}", namespace: 'unique_user_metrics')
          result = described_class.record_event(user_id: test_user_id, event_name: test_event_name)
          expect(result).to be(false), 'Multiple duplicate inserts should all return false'
        end

        # Verify only one record exists (INSERT ON CONFLICT prevented duplicates)
        records = described_class.where(user_id: test_user_id, event_name: test_event_name)
        expect(records.count).to eq(1)
        expect(records.first.created_at).to be_present
      end

      it 'does not raise exceptions on duplicate inserts' do
        # Verify no ActiveRecord::RecordNotUnique exceptions are raised
        expect do
          5.times do
            Rails.cache.delete("#{test_user_id}:#{test_event_name}", namespace: 'unique_user_metrics')
            described_class.record_event(user_id: test_user_id, event_name: test_event_name)
          end
        end.not_to raise_error
      end
    end
  end

  describe 'private class methods' do
    describe '.generate_cache_key' do
      it 'generates correct cache key format' do
        result = described_class.send(:generate_cache_key, user_id, event_name)

        expect(result).to eq("#{user_id}:#{event_name}")
      end
    end

    describe '.validate_inputs' do
      it 'passes with valid inputs' do
        expect do
          described_class.send(:validate_inputs, user_id, event_name)
        end.not_to raise_error
      end

      it 'raises error for blank user_id' do
        expect do
          described_class.send(:validate_inputs, '', event_name)
        end.to raise_error(ArgumentError, 'user_id is required')
      end

      it 'raises error for blank event_name' do
        expect do
          described_class.send(:validate_inputs, user_id, '')
        end.to raise_error(ArgumentError, 'event_name is required')
      end

      it 'raises error for event_name too long' do
        long_name = 'a' * 51
        expect do
          described_class.send(:validate_inputs, user_id, long_name)
        end.to raise_error(ArgumentError, 'event_name must be 50 characters or less')
      end
    end

    describe 'cache methods' do
      let(:test_key) { 'test_key' }

      describe '.key_cached?' do
        before do
          allow(Rails.cache).to receive(:exist?)
        end

        it 'calls Rails.cache.exist? with correct parameters' do
          described_class.send(:key_cached?, test_key)

          expect(Rails.cache).to have_received(:exist?).with(test_key, namespace: 'unique_user_metrics')
        end
      end

      describe '.mark_key_cached' do
        before do
          allow(Rails.cache).to receive(:write)
        end

        it 'calls Rails.cache.write with correct parameters' do
          described_class.send(:mark_key_cached, test_key)

          expect(Rails.cache).to have_received(:write).with(
            test_key,
            true,
            namespace: 'unique_user_metrics',
            expires_in: described_class::CACHE_TTL
          )
        end
      end
    end
  end
end
