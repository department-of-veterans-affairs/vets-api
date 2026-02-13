# frozen_string_literal: true

require 'rails_helper'
require 'unique_user_events'

Sidekiq::Testing.fake!

RSpec.describe MHV::UniqueUserMetricsProcessorJob, type: :job do
  let(:job) { described_class.new }
  let(:user_id) { SecureRandom.uuid }
  let(:event_name) { 'prescriptions_accessed' }

  # Test configuration values (stub the class constants)
  let(:batch_size) { 100 }
  let(:max_iterations) { 10 }
  let(:max_queue_depth) { 1000 }

  before do
    allow(StatsD).to receive_messages(increment: nil, gauge: nil, histogram: nil)
    allow(Rails.logger).to receive_messages(debug: nil, info: nil, warn: nil, error: nil)

    # Stub class constants for testing
    stub_const("#{described_class}::BATCH_SIZE", batch_size)
    stub_const("#{described_class}::MAX_ITERATIONS", max_iterations)
    stub_const("#{described_class}::MAX_QUEUE_DEPTH", max_queue_depth)
  end

  describe '#perform' do
    context 'when buffer is empty' do
      before do
        allow(UniqueUserEvents::Buffer).to receive_messages(peek_batch: [], pending_count: 0)
      end

      it 'does nothing and completes successfully' do
        expect { job.perform }.not_to raise_error
      end

      it 'does not record job summary metrics' do
        job.perform

        expect(StatsD).not_to have_received(:gauge).with('uum.processor_job.iterations', anything)
      end
    end

    context 'when buffer has events' do
      let(:events) do
        [
          { user_id: SecureRandom.uuid, event_name: 'event_1' },
          { user_id: SecureRandom.uuid, event_name: 'event_2' }
        ]
      end

      before do
        allow(UniqueUserEvents::Buffer).to receive(:peek_batch).and_return(events, [])
        allow(UniqueUserEvents::Buffer).to receive(:trim_batch)
        allow(UniqueUserEvents::Buffer).to receive(:pending_count).and_return(0)
        allow(Rails.cache).to receive(:read_multi).and_return({})
        allow(Rails.cache).to receive(:write_multi)
        allow(MHVMetricsUniqueUserEvent).to receive(:insert_all).and_return(
          double(rows: events.map { |e| [e[:user_id], e[:event_name]] })
        )
      end

      it 'peeks events from buffer and trims after processing' do
        job.perform

        expect(UniqueUserEvents::Buffer).to have_received(:peek_batch).with(batch_size).at_least(:once)
        expect(UniqueUserEvents::Buffer).to have_received(:trim_batch).with(events.size)
      end

      it 'records job summary metrics and logs completion' do
        job.perform

        expect(StatsD).to have_received(:gauge).with('uum.processor_job.iterations', 1)
        expect(StatsD).to have_received(:gauge).with('uum.processor_job.total_events_processed', 2)
        expect(StatsD).to have_received(:gauge).with('uum.processor_job.total_db_queries', 2)
        expect(StatsD).to have_received(:gauge).with('uum.processor_job.total_db_inserts', 2)
        expect(StatsD).to have_received(:gauge).with('uum.processor_job.queue_depth', 0)
        expect(StatsD).to have_received(:histogram).with('uum.processor_job.job_duration_ms', kind_of(Numeric))
        expect(Rails.logger).to have_received(:debug).with(
          'UUM Processor: Job completed',
          hash_including(:iterations, :total_events_processed, :total_db_queries, :total_db_inserts, :duration_ms,
                         :queue_depth)
        )
      end
    end

    context 'when some events are cached (cache hits vs misses)' do
      let(:cached_user_id) { SecureRandom.uuid }
      let(:uncached_user_id) { SecureRandom.uuid }
      let(:events) do
        [
          { user_id: cached_user_id, event_name: 'cached_event' },
          { user_id: uncached_user_id, event_name: 'uncached_event' }
        ]
      end
      let(:cached_key) { "#{cached_user_id}:cached_event" }

      before do
        allow(UniqueUserEvents::Buffer).to receive(:peek_batch).and_return(events, [])
        allow(UniqueUserEvents::Buffer).to receive(:trim_batch)
        allow(UniqueUserEvents::Buffer).to receive(:pending_count).and_return(0)
        # Simulate one event already in cache (cache hit)
        allow(Rails.cache).to receive(:read_multi).and_return({ cached_key => true })
        allow(Rails.cache).to receive(:write_multi)
        # Only the uncached event is inserted
        allow(MHVMetricsUniqueUserEvent).to receive(:insert_all).and_return(
          double(rows: [[uncached_user_id, 'uncached_event']])
        )
      end

      it 'tracks db_queries as cache misses only' do
        job.perform

        # 2 events processed, 1 cache miss (db query), 1 insert
        expect(StatsD).to have_received(:gauge).with('uum.processor_job.total_events_processed', 2)
        expect(StatsD).to have_received(:gauge).with('uum.processor_job.total_db_queries', 1)
        expect(StatsD).to have_received(:gauge).with('uum.processor_job.total_db_inserts', 1)
      end
    end

    context 'when processing multiple batches' do
      let(:batch1) { [{ user_id: SecureRandom.uuid, event_name: 'event_1' }] }
      let(:batch2) { [{ user_id: SecureRandom.uuid, event_name: 'event_2' }] }

      before do
        allow(UniqueUserEvents::Buffer).to receive(:peek_batch).and_return(batch1, batch2, [])
        allow(UniqueUserEvents::Buffer).to receive(:trim_batch)
        allow(UniqueUserEvents::Buffer).to receive(:pending_count).and_return(0)
        allow(Rails.cache).to receive(:read_multi).and_return({})
        allow(Rails.cache).to receive(:write_multi)
        allow(MHVMetricsUniqueUserEvent).to receive(:insert_all).and_return(
          double(rows: [[SecureRandom.uuid, 'event']])
        )
      end

      it 'loops until buffer is empty' do
        job.perform

        expect(UniqueUserEvents::Buffer).to have_received(:peek_batch).exactly(3).times
        expect(UniqueUserEvents::Buffer).to have_received(:trim_batch).twice
      end

      it 'records total events across all iterations' do
        job.perform

        expect(StatsD).to have_received(:gauge).with('uum.processor_job.iterations', 2)
        expect(StatsD).to have_received(:gauge).with('uum.processor_job.total_events_processed', 2)
        expect(StatsD).to have_received(:gauge).with('uum.processor_job.total_db_queries', 2)
        expect(StatsD).to have_received(:gauge).with('uum.processor_job.total_db_inserts', 2)
      end
    end

    context 'when max_iterations is reached' do
      let(:events) { [{ user_id: SecureRandom.uuid, event_name: 'event_1' }] }

      before do
        # Always return events to simulate never-ending queue
        allow(UniqueUserEvents::Buffer).to receive(:peek_batch).and_return(events)
        allow(UniqueUserEvents::Buffer).to receive_messages(trim_batch: nil, pending_count: 1000)
        allow(Rails.cache).to receive(:read_multi).and_return({})
        allow(Rails.cache).to receive(:write_multi)
        allow(MHVMetricsUniqueUserEvent).to receive(:insert_all).and_return(
          double(rows: [[events[0][:user_id], events[0][:event_name]]])
        )
      end

      it 'stops after max_iterations' do
        job.perform

        expect(UniqueUserEvents::Buffer).to have_received(:trim_batch)
          .exactly(max_iterations).times
      end
    end

    context 'when an error occurs during processing' do
      let(:events) { [{ user_id: SecureRandom.uuid, event_name: 'event_1' }] }
      let(:error) { StandardError.new('Database connection failed') }

      before do
        allow(UniqueUserEvents::Buffer).to receive(:peek_batch).and_return(events)
        allow(UniqueUserEvents::Buffer).to receive_messages(pending_count: 1)
        allow(Rails.cache).to receive(:read_multi).and_raise(error)
      end

      it 're-raises the error for Sidekiq retry' do
        expect { job.perform }.to raise_error(StandardError, 'Database connection failed')
      end

      it 'logs the error with details' do
        expect { job.perform }.to raise_error(StandardError)

        expect(Rails.logger).to have_received(:error).with(
          'UUM Processor: Job failed',
          hash_including(
            error: 'StandardError',
            message: 'Database connection failed',
            events_at_risk: 1
          )
        )
      end
    end

    context 'when queue depth exceeds max_queue_depth' do
      let(:events) { [{ user_id: SecureRandom.uuid, event_name: 'event_1' }] }
      let(:high_queue_depth) { max_queue_depth + 1000 }

      before do
        allow(UniqueUserEvents::Buffer).to receive(:peek_batch).and_return(events, [])
        allow(UniqueUserEvents::Buffer).to receive(:trim_batch)
        allow(UniqueUserEvents::Buffer).to receive(:pending_count).and_return(high_queue_depth)
        allow(Rails.cache).to receive(:read_multi).and_return({})
        allow(Rails.cache).to receive(:write_multi)
        allow(MHVMetricsUniqueUserEvent).to receive(:insert_all).and_return(
          double(rows: [[events[0][:user_id], events[0][:event_name]]])
        )
      end

      it 'logs a warning about queue overflow' do
        job.perform

        expect(Rails.logger).to have_received(:warn).with(
          'UUM Processor: Queue depth exceeds threshold',
          hash_including(queue_depth: high_queue_depth, max_queue_depth: described_class::MAX_QUEUE_DEPTH)
        )
      end
    end
  end

  describe 'event processing pipeline' do
    let(:user1_id) { SecureRandom.uuid }
    let(:user2_id) { SecureRandom.uuid }

    before do
      allow(UniqueUserEvents::Buffer).to receive_messages(trim_batch: nil, pending_count: 0)
    end

    describe 'deduplication' do
      let(:events_with_duplicates) do
        [
          { user_id: user1_id, event_name: 'event_a' },
          { user_id: user1_id, event_name: 'event_a' }, # duplicate
          { user_id: user2_id, event_name: 'event_a' }
        ]
      end

      before do
        allow(UniqueUserEvents::Buffer).to receive(:peek_batch).and_return(events_with_duplicates, [])
        allow(Rails.cache).to receive(:read_multi).and_return({})
        allow(Rails.cache).to receive(:write_multi)
      end

      it 'deduplicates events before inserting' do
        expect(MHVMetricsUniqueUserEvent).to receive(:insert_all) do |records, **_options|
          # Should only have 2 unique events, not 3
          expect(records.size).to eq(2)
          double(rows: records.map { |r| [r[:user_id], r[:event_name]] })
        end

        job.perform
      end
    end

    describe 'cache filtering' do
      let(:events) do
        [
          { user_id: user1_id, event_name: 'cached_event' },
          { user_id: user2_id, event_name: 'new_event' }
        ]
      end

      before do
        allow(UniqueUserEvents::Buffer).to receive(:peek_batch).and_return(events, [])
        # Simulate first event is already cached
        allow(Rails.cache).to receive(:read_multi).and_return(
          "#{user1_id}:cached_event" => true
        )
        allow(Rails.cache).to receive(:write_multi)
      end

      it 'filters out cached events before inserting' do
        expect(MHVMetricsUniqueUserEvent).to receive(:insert_all) do |records, **_options|
          # Should only insert the non-cached event
          expect(records.size).to eq(1)
          expect(records.first[:event_name]).to eq('new_event')
          double(rows: [[user2_id, 'new_event']])
        end

        job.perform
      end

      it 'refreshes TTL for cached events' do
        allow(MHVMetricsUniqueUserEvent).to receive(:insert_all).and_return(
          double(rows: [[user2_id, 'new_event']])
        )

        job.perform

        # Should refresh TTL for cached events (first write_multi call)
        expect(Rails.cache).to have_received(:write_multi).with(
          { "#{user1_id}:cached_event" => true },
          namespace: 'unique_user_metrics',
          expires_in: described_class::CACHE_TTL
        )
      end
    end

    describe 'bulk insert' do
      let(:events) do
        [
          { user_id: user1_id, event_name: 'event_1' },
          { user_id: user2_id, event_name: 'event_2' }
        ]
      end

      before do
        allow(UniqueUserEvents::Buffer).to receive(:peek_batch).and_return(events, [])
        allow(Rails.cache).to receive(:read_multi).and_return({})
        allow(Rails.cache).to receive(:write_multi)
      end

      it 'inserts events with correct parameters' do
        expect(MHVMetricsUniqueUserEvent).to receive(:insert_all).with(
          array_including(
            hash_including(user_id: user1_id, event_name: 'event_1', created_at: kind_of(Time)),
            hash_including(user_id: user2_id, event_name: 'event_2', created_at: kind_of(Time))
          ),
          unique_by: %i[user_id event_name],
          returning: %i[user_id event_name]
        ).and_return(double(rows: [[user1_id, 'event_1'], [user2_id, 'event_2']]))

        job.perform
      end

      it 'caches all DB-queried events but only increments StatsD for inserts' do
        # Simulate one event already existed in DB (not returned by insert_all)
        allow(MHVMetricsUniqueUserEvent).to receive(:insert_all).and_return(
          double(rows: [[user1_id, 'event_1']]) # Only one actually inserted
        )

        job.perform

        # Cache should be written for ALL events sent to DB (prevents repeated lookups)
        expect(Rails.cache).to have_received(:write_multi).with(
          { "#{user1_id}:event_1" => true, "#{user2_id}:event_2" => true },
          namespace: 'unique_user_metrics',
          expires_in: described_class::CACHE_TTL
        )

        # StatsD should only increment for actually inserted events
        expect(StatsD).to have_received(:increment).with(
          'uum.unique_user_metrics.event',
          1,
          tags: ['event_name:event_1']
        )
        expect(StatsD).not_to have_received(:increment).with(
          'uum.unique_user_metrics.event',
          anything,
          tags: ['event_name:event_2']
        )
      end
    end

    describe 'cache write' do
      let(:events) { [{ user_id: user1_id, event_name: 'event_1' }] }

      before do
        allow(UniqueUserEvents::Buffer).to receive(:peek_batch).and_return(events, [])
        allow(Rails.cache).to receive(:read_multi).and_return({})
        allow(MHVMetricsUniqueUserEvent).to receive(:insert_all).and_return(
          double(rows: [[user1_id, 'event_1']])
        )
      end

      it 'writes inserted events to cache' do
        expect(Rails.cache).to receive(:write_multi).with(
          { "#{user1_id}:event_1" => true },
          namespace: 'unique_user_metrics',
          expires_in: described_class::CACHE_TTL
        )

        job.perform
      end
    end

    describe 'StatsD counters' do
      let(:events) do
        [
          { user_id: user1_id, event_name: 'prescriptions_accessed' },
          { user_id: user2_id, event_name: 'prescriptions_accessed' },
          { user_id: user1_id, event_name: 'secure_messaging_sent' }
        ]
      end

      before do
        allow(UniqueUserEvents::Buffer).to receive(:peek_batch).and_return(events, [])
        allow(Rails.cache).to receive(:read_multi).and_return({})
        allow(Rails.cache).to receive(:write_multi)
        allow(MHVMetricsUniqueUserEvent).to receive(:insert_all).and_return(
          double(rows: events.map { |e| [e[:user_id], e[:event_name]] })
        )
      end

      it 'increments counters grouped by event_name' do
        job.perform

        expect(StatsD).to have_received(:increment).with(
          'uum.unique_user_metrics.event',
          2, # Two prescriptions_accessed events
          tags: ['event_name:prescriptions_accessed']
        )
        expect(StatsD).to have_received(:increment).with(
          'uum.unique_user_metrics.event',
          1, # One secure_messaging_sent event
          tags: ['event_name:secure_messaging_sent']
        )
      end
    end

    describe 'when all events are cached' do
      let(:events) { [{ user_id: user1_id, event_name: 'cached_event' }] }

      before do
        allow(UniqueUserEvents::Buffer).to receive(:peek_batch).and_return(events, [])
        # All events cached
        allow(Rails.cache).to receive(:read_multi).and_return(
          "#{user1_id}:cached_event" => true
        )
      end

      it 'does not call insert_all' do
        expect(MHVMetricsUniqueUserEvent).not_to receive(:insert_all)

        job.perform
      end

      it 'still trims the processed events from buffer' do
        job.perform

        expect(UniqueUserEvents::Buffer).to have_received(:trim_batch).with(1)
      end
    end
  end
end
