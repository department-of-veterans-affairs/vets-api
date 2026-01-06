# frozen_string_literal: true

require 'rails_helper'
require 'unique_user_events'

RSpec.describe UniqueUserEvents::Buffer do
  let(:user_id) { SecureRandom.uuid }
  let(:event_name) { 'prescriptions_accessed' }
  let(:redis) { $redis }

  describe '.push' do
    it 'pushes event to Redis list and returns list length' do
      result = described_class.push(user_id:, event_name:)

      expect(result).to eq(1)
      expect(described_class.pending_count).to eq(1)
    end

    it 'stores event as JSON with user_id, event_name, and buffered_at' do
      Timecop.freeze do
        described_class.push(user_id:, event_name:)

        raw_event = redis.lrange(described_class::BUFFER_KEY, 0, -1).first
        parsed = JSON.parse(raw_event, symbolize_names: true)

        expect(parsed[:user_id]).to eq(user_id)
        expect(parsed[:event_name]).to eq(event_name)
        expect(parsed[:buffered_at]).to eq(Time.current.to_i)
      end
    end

    it 'supports multiple events in LIFO order via LPUSH' do
      described_class.push(user_id:, event_name: 'event_1')
      described_class.push(user_id:, event_name: 'event_2')
      described_class.push(user_id:, event_name: 'event_3')

      expect(described_class.pending_count).to eq(3)
    end

    context 'with invalid inputs' do
      it 'raises ArgumentError when user_id is blank' do
        expect do
          described_class.push(user_id: '', event_name:)
        end.to raise_error(ArgumentError, 'user_id is required')
      end

      it 'raises ArgumentError when user_id is nil' do
        expect do
          described_class.push(user_id: nil, event_name:)
        end.to raise_error(ArgumentError, 'user_id is required')
      end

      it 'raises ArgumentError when event_name is blank' do
        expect do
          described_class.push(user_id:, event_name: '')
        end.to raise_error(ArgumentError, 'event_name is required')
      end

      it 'raises ArgumentError when event_name is nil' do
        expect do
          described_class.push(user_id:, event_name: nil)
        end.to raise_error(ArgumentError, 'event_name is required')
      end

      it 'raises ArgumentError when event_name exceeds 50 characters' do
        long_event_name = 'a' * 51
        expect do
          described_class.push(user_id:, event_name: long_event_name)
        end.to raise_error(ArgumentError, 'event_name must be 50 characters or less')
      end

      it 'allows event_name of exactly 50 characters' do
        valid_event_name = 'a' * 50
        expect do
          described_class.push(user_id:, event_name: valid_event_name)
        end.not_to raise_error
      end
    end

    context 'when Redis fails' do
      before do
        allow(redis).to receive(:lpush).and_raise(Redis::ConnectionError, 'Connection refused')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error and re-raises exception' do
        expect do
          described_class.push(user_id:, event_name:)
        end.to raise_error(Redis::ConnectionError)

        expect(Rails.logger).to have_received(:error).with(
          'UUM Buffer: Failed to push event',
          { event_name:, error: 'Connection refused' }
        )
      end
    end
  end

  describe '.peek_batch' do
    before do
      # Push events: oldest first (LPUSH means first pushed is at tail)
      described_class.push(user_id:, event_name: 'event_1')
      described_class.push(user_id:, event_name: 'event_2')
      described_class.push(user_id:, event_name: 'event_3')
    end

    it 'returns oldest events first (from tail of list)' do
      events = described_class.peek_batch(2)

      expect(events.length).to eq(2)
      # LRANGE -2 to -1 returns [second-to-last, last] = [event_2, event_1]
      # event_1 is oldest (pushed first, at tail), event_3 is newest (pushed last, at head)
      expect(events[0][:event_name]).to eq('event_2')
      expect(events[1][:event_name]).to eq('event_1')
    end

    it 'does not remove events from the buffer' do
      described_class.peek_batch(2)

      expect(described_class.pending_count).to eq(3)
    end

    it 'returns all events when count exceeds buffer size' do
      events = described_class.peek_batch(100)

      expect(events.length).to eq(3)
    end

    it 'returns empty array when buffer is empty' do
      described_class.clear!

      events = described_class.peek_batch(10)

      expect(events).to eq([])
    end

    it 'returns empty array when count is zero' do
      events = described_class.peek_batch(0)

      expect(events).to eq([])
    end

    it 'returns empty array when count is negative' do
      events = described_class.peek_batch(-5)

      expect(events).to eq([])
    end

    it 'returns only user_id and event_name keys' do
      events = described_class.peek_batch(1)

      expect(events.first.keys).to contain_exactly(:user_id, :event_name)
    end

    context 'when Redis fails' do
      before do
        allow(redis).to receive(:lrange).and_raise(Redis::ConnectionError, 'Connection refused')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error and returns empty array' do
        events = described_class.peek_batch(10)

        expect(events).to eq([])
        expect(Rails.logger).to have_received(:error).with(
          'UUM Buffer: Failed to peek batch',
          { count: 10, error: 'Connection refused' }
        )
      end
    end

    context 'when JSON parsing fails' do
      before do
        # Push invalid JSON directly to Redis
        redis.lpush(described_class::BUFFER_KEY, 'not valid json')
        allow(Rails.logger).to receive(:error)
      end

      it 'skips malformed events and logs error' do
        events = described_class.peek_batch(10)

        # Should still get the 3 valid events, skip the malformed one
        expect(events.length).to eq(3)
        expect(Rails.logger).to have_received(:error).with(
          'UUM Buffer: Failed to parse event',
          hash_including(:raw_event, :error)
        )
      end
    end
  end

  describe '.trim_batch' do
    before do
      described_class.push(user_id:, event_name: 'event_1')
      described_class.push(user_id:, event_name: 'event_2')
      described_class.push(user_id:, event_name: 'event_3')
    end

    it 'removes events from the tail of the buffer' do
      result = described_class.trim_batch(2)

      expect(result).to be(true)
      expect(described_class.pending_count).to eq(1)

      # Remaining event should be event_3 (newest, at head)
      remaining = described_class.peek_batch(1)
      expect(remaining.first[:event_name]).to eq('event_3')
    end

    it 'removes all events when count equals buffer size' do
      described_class.trim_batch(3)

      expect(described_class.pending_count).to eq(0)
    end

    it 'removes all events when count exceeds buffer size' do
      described_class.trim_batch(100)

      expect(described_class.pending_count).to eq(0)
    end

    it 'returns true when count is zero' do
      result = described_class.trim_batch(0)

      expect(result).to be(true)
      expect(described_class.pending_count).to eq(3)
    end

    it 'returns true when count is negative' do
      result = described_class.trim_batch(-5)

      expect(result).to be(true)
      expect(described_class.pending_count).to eq(3)
    end

    context 'when Redis fails' do
      before do
        allow(redis).to receive(:ltrim).and_raise(Redis::ConnectionError, 'Connection refused')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error and returns false' do
        result = described_class.trim_batch(2)

        expect(result).to be(false)
        expect(Rails.logger).to have_received(:error).with(
          'UUM Buffer: Failed to trim batch',
          { count: 2, error: 'Connection refused' }
        )
      end
    end
  end

  describe '.pop_batch' do
    before do
      described_class.push(user_id:, event_name: 'event_1')
      described_class.push(user_id:, event_name: 'event_2')
      described_class.push(user_id:, event_name: 'event_3')
    end

    it 'returns events from the tail (oldest first) and removes them' do
      events = described_class.pop_batch(2)

      expect(events.length).to eq(2)
      expect(events[0][:event_name]).to eq('event_1')
      expect(events[1][:event_name]).to eq('event_2')
      expect(described_class.pending_count).to eq(1)
    end

    it 'returns all remaining events when count exceeds buffer size' do
      events = described_class.pop_batch(100)

      expect(events.length).to eq(3)
      expect(described_class.pending_count).to eq(0)
    end

    it 'returns empty array when buffer is empty' do
      described_class.clear!

      events = described_class.pop_batch(10)

      expect(events).to eq([])
    end

    it 'returns empty array when count is zero' do
      events = described_class.pop_batch(0)

      expect(events).to eq([])
    end

    it 'returns empty array when count is negative' do
      events = described_class.pop_batch(-5)

      expect(events).to eq([])
    end

    context 'when Redis fails' do
      before do
        allow(redis).to receive(:rpop).and_raise(Redis::ConnectionError, 'Connection refused')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error and returns empty array' do
        events = described_class.pop_batch(10)

        expect(events).to eq([])
        expect(Rails.logger).to have_received(:error).with(
          'UUM Buffer: Failed to pop batch',
          { count: 10, error: 'Connection refused' }
        )
      end
    end
  end

  describe '.pending_count' do
    it 'returns 0 when buffer is empty' do
      expect(described_class.pending_count).to eq(0)
    end

    it 'returns correct count after pushing events' do
      described_class.push(user_id:, event_name: 'event_1')
      described_class.push(user_id:, event_name: 'event_2')

      expect(described_class.pending_count).to eq(2)
    end

    context 'when Redis fails' do
      before do
        allow(redis).to receive(:llen).and_raise(Redis::ConnectionError, 'Connection refused')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error and returns 0' do
        count = described_class.pending_count

        expect(count).to eq(0)
        expect(Rails.logger).to have_received(:error).with(
          'UUM Buffer: Failed to get pending count',
          { error: 'Connection refused' }
        )
      end
    end
  end

  describe '.clear!' do
    it 'returns 0 when buffer is already empty' do
      count = described_class.clear!

      expect(count).to eq(0)
    end

    it 'removes all events and returns the count' do
      described_class.push(user_id:, event_name: 'event_1')
      described_class.push(user_id:, event_name: 'event_2')
      described_class.push(user_id:, event_name: 'event_3')

      count = described_class.clear!

      expect(count).to eq(3)
      expect(described_class.pending_count).to eq(0)
    end
  end

  describe 'peek-then-trim pattern integration' do
    it 'processes events correctly with peek followed by trim' do
      # Push 5 events (LPUSH: event_1 first, event_5 last)
      # List order: [event_5, event_4, event_3, event_2, event_1] (head to tail)
      5.times { |i| described_class.push(user_id:, event_name: "event_#{i + 1}") }

      # Peek at last 3 elements (oldest: event_3, event_2, event_1)
      events = described_class.peek_batch(3)
      expect(events.map { |e| e[:event_name] }).to eq(%w[event_3 event_2 event_1])

      # Buffer still has all 5
      expect(described_class.pending_count).to eq(5)

      # Trim the 3 we processed (removes from tail)
      described_class.trim_batch(3)

      # Buffer now has 2 remaining (event_5, event_4)
      expect(described_class.pending_count).to eq(2)

      # Next peek should get the remaining events
      remaining = described_class.peek_batch(10)
      expect(remaining.map { |e| e[:event_name] }).to eq(%w[event_5 event_4])
    end
  end
end
