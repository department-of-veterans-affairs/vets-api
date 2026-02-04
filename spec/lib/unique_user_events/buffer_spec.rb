# frozen_string_literal: true

require 'rails_helper'
require 'unique_user_events'

RSpec.describe UniqueUserEvents::Buffer do
  let(:user_id) { SecureRandom.uuid }
  let(:event_name) { 'prescriptions_accessed' }
  let(:redis) { $redis }

  # Helper to push a single event for test setup
  def push_event(uid: user_id, name: event_name)
    described_class.push_batch([{ user_id: uid, event_name: name }])
  end

  describe '.push_batch' do
    let(:user2_id) { SecureRandom.uuid }
    let(:events) do
      [
        { user_id:, event_name: 'event_1' },
        { user_id: user2_id, event_name: 'event_2' },
        { user_id:, event_name: 'event_3' }
      ]
    end

    it 'pushes all events in a single Redis call and returns list length' do
      result = described_class.push_batch(events)

      expect(result).to eq(3)
      expect(described_class.pending_count).to eq(3)
    end

    it 'stores all events as JSON with correct fields' do
      Timecop.freeze do
        described_class.push_batch(events)

        raw_events = redis.lrange(described_class::BUFFER_KEY, 0, -1)
        expect(raw_events.length).to eq(3)

        # Events are stored via LPUSH, so order is reversed (last pushed is at head)
        parsed = raw_events.map { |e| JSON.parse(e, symbolize_names: true) }
        expect(parsed.map { |e| e[:event_name] }).to eq(%w[event_3 event_2 event_1])
        expect(parsed.all? { |e| e[:buffered_at] == Time.current.to_i }).to be(true)
      end
    end

    it 'returns 0 when events array is empty' do
      result = described_class.push_batch([])

      expect(result).to eq(0)
      expect(described_class.pending_count).to eq(0)
    end

    it 'returns 0 when events is nil' do
      result = described_class.push_batch(nil)

      expect(result).to eq(0)
    end

    it 'pushes single event when array has one element' do
      result = described_class.push_batch([{ user_id:, event_name: }])

      expect(result).to eq(1)
      expect(described_class.pending_count).to eq(1)
    end

    context 'with invalid inputs' do
      it 'raises ArgumentError when any user_id is blank' do
        invalid_events = [
          { user_id:, event_name: 'event_1' },
          { user_id: '', event_name: 'event_2' }
        ]

        expect do
          described_class.push_batch(invalid_events)
        end.to raise_error(ArgumentError, 'user_id is required')
      end

      it 'raises ArgumentError when any event_name is blank' do
        invalid_events = [
          { user_id:, event_name: 'event_1' },
          { user_id:, event_name: '' }
        ]

        expect do
          described_class.push_batch(invalid_events)
        end.to raise_error(ArgumentError, 'event_name is required')
      end

      it 'raises ArgumentError when any event_name exceeds 50 characters' do
        invalid_events = [
          { user_id:, event_name: 'event_1' },
          { user_id:, event_name: 'a' * 51 }
        ]

        expect do
          described_class.push_batch(invalid_events)
        end.to raise_error(ArgumentError, 'event_name must be 50 characters or less')
      end

      it 'allows event_name of exactly 50 characters' do
        valid_events = [{ user_id:, event_name: 'a' * 50 }]

        expect do
          described_class.push_batch(valid_events)
        end.not_to raise_error
      end
    end

    context 'when Redis fails' do
      before do
        allow(redis).to receive(:lpush).and_raise(Redis::ConnectionError, 'Connection refused')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error with event count and re-raises exception' do
        expect do
          described_class.push_batch(events)
        end.to raise_error(Redis::ConnectionError)

        expect(Rails.logger).to have_received(:error).with(
          'UUM Buffer: Failed to push batch',
          { event_count: 3, error: 'Connection refused' }
        )
      end
    end
  end

  describe '.peek_batch' do
    before do
      # Push events: oldest first (LPUSH means first pushed is at tail)
      push_event(name: 'event_1')
      push_event(name: 'event_2')
      push_event(name: 'event_3')
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

    context 'when event JSON is malformed' do
      before do
        # Push a malformed event directly to Redis
        redis.lpush(described_class::BUFFER_KEY, 'not-valid-json')
        allow(Rails.logger).to receive(:error)
      end

      it 'skips malformed events and logs error' do
        events = described_class.peek_batch(10)

        # Should get the 3 valid events, skipping the malformed one
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
      push_event(name: 'event_1')
      push_event(name: 'event_2')
      push_event(name: 'event_3')
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

  describe '.pending_count' do
    it 'returns 0 when buffer is empty' do
      expect(described_class.pending_count).to eq(0)
    end

    it 'returns correct count after pushing events' do
      push_event(name: 'event_1')
      push_event(name: 'event_2')

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
      push_event(name: 'event_1')
      push_event(name: 'event_2')
      push_event(name: 'event_3')

      count = described_class.clear!

      expect(count).to eq(3)
      expect(described_class.pending_count).to eq(0)
    end
  end

  describe 'peek-then-trim pattern integration' do
    it 'processes events correctly with peek followed by trim' do
      # Push 5 events (LPUSH: event_1 first, event_5 last)
      # List order: [event_5, event_4, event_3, event_2, event_1] (head to tail)
      5.times { |i| push_event(name: "event_#{i + 1}") }

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
