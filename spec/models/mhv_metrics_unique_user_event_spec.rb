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
