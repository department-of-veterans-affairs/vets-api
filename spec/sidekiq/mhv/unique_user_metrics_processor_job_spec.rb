# frozen_string_literal: true

require 'rails_helper'
require 'unique_user_events'

Sidekiq::Testing.fake!

RSpec.describe MHV::UniqueUserMetricsProcessorJob, type: :job do
  let(:job) { described_class.new }
  let(:user_id) { SecureRandom.uuid }
  let(:event_name) { 'prescriptions_accessed' }

  # Test configuration values
  let(:batch_size) { 100 }
  let(:max_iterations) { 10 }
  let(:max_queue_depth) { 1000 }

  before do
    allow(StatsD).to receive_messages(increment: nil, gauge: nil, histogram: nil)
    allow(Rails.logger).to receive_messages(debug: nil, info: nil, warn: nil, error: nil)

    # Stub Settings for processor_job configuration
    processor_job_config = double(
      batch_size:,
      max_iterations:,
      max_queue_depth:
    )
    unique_user_metrics_config = double(processor_job: processor_job_config)
    allow(Settings).to receive(:unique_user_metrics).and_return(unique_user_metrics_config)
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
        expect(StatsD).to have_received(:gauge).with('uum.processor_job.total_db_inserts', 2)
        expect(StatsD).to have_received(:gauge).with('uum.processor_job.queue_depth', 0)
        expect(StatsD).to have_received(:histogram).with('uum.processor_job.job_duration_ms', kind_of(Numeric))
        expect(Rails.logger).to have_received(:debug).with(
          'UUM Processor: Job completed',
          hash_including(:iterations, :total_events_processed, :total_db_inserts, :duration_ms, :queue_depth)
        )
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
          hash_including(queue_depth: high_queue_depth, max_queue_depth:)
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

      it 'only processes actually inserted events' do
        # Simulate one event already existed (not returned by insert_all)
        allow(MHVMetricsUniqueUserEvent).to receive(:insert_all).and_return(
          double(rows: [[user1_id, 'event_1']]) # Only one inserted
        )

        job.perform

        # Cache should only be written for the inserted event
        expect(Rails.cache).to have_received(:write_multi).with(
          { "#{user1_id}:event_1" => true },
          namespace: 'unique_user_metrics',
          expires_in: described_class::CACHE_TTL
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

  describe 'configuration validation' do
    let(:events) { [] }

    before do
      allow(UniqueUserEvents::Buffer).to receive_messages(peek_batch: events, pending_count: 0)
    end

    context 'when batch_size is missing' do
      before do
        processor_job_config = double(batch_size: nil, max_iterations: 10, max_queue_depth: 1000)
        unique_user_metrics_config = double(processor_job: processor_job_config)
        allow(Settings).to receive(:unique_user_metrics).and_return(unique_user_metrics_config)
      end

      it 'does not raise (no retry) but logs configuration error' do
        expect { job.perform }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(
          'UUM Processor: Configuration error - job will not retry',
          hash_including(message: 'UUM Processor: batch_size is missing')
        )
      end
    end

    context 'when max_iterations is missing' do
      before do
        processor_job_config = double(batch_size: 100, max_iterations: nil, max_queue_depth: 1000)
        unique_user_metrics_config = double(processor_job: processor_job_config)
        allow(Settings).to receive(:unique_user_metrics).and_return(unique_user_metrics_config)
      end

      it 'does not raise (no retry) but logs configuration error' do
        expect { job.perform }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(
          'UUM Processor: Configuration error - job will not retry',
          hash_including(message: 'UUM Processor: max_iterations is missing')
        )
      end
    end

    context 'when max_queue_depth is missing' do
      before do
        processor_job_config = double(batch_size: 100, max_iterations: 10, max_queue_depth: nil)
        unique_user_metrics_config = double(processor_job: processor_job_config)
        allow(Settings).to receive(:unique_user_metrics).and_return(unique_user_metrics_config)
      end

      it 'does not raise (no retry) but logs configuration error' do
        expect { job.perform }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(
          'UUM Processor: Configuration error - job will not retry',
          hash_including(message: 'UUM Processor: max_queue_depth is missing')
        )
      end
    end

    context 'when processor_job config is missing entirely' do
      before do
        unique_user_metrics_config = double(processor_job: nil)
        allow(Settings).to receive(:unique_user_metrics).and_return(unique_user_metrics_config)
      end

      it 'does not raise (no retry) but logs configuration error' do
        expect { job.perform }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(
          'UUM Processor: Configuration error - job will not retry',
          hash_including(message: /batch_size is missing/)
        )
      end
    end

    context 'when unique_user_metrics config is missing entirely' do
      before do
        allow(Settings).to receive(:unique_user_metrics).and_return(nil)
      end

      it 'does not raise (no retry) but logs configuration error' do
        expect { job.perform }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(
          'UUM Processor: Configuration error - job will not retry',
          hash_including(message: /batch_size is missing/)
        )
      end
    end

    context 'when batch_size is zero' do
      before do
        processor_job_config = double(batch_size: 0, max_iterations: 10, max_queue_depth: 1000)
        unique_user_metrics_config = double(processor_job: processor_job_config)
        allow(Settings).to receive(:unique_user_metrics).and_return(unique_user_metrics_config)
      end

      it 'does not raise (no retry) but logs configuration error' do
        expect { job.perform }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(
          'UUM Processor: Configuration error - job will not retry',
          hash_including(message: 'UUM Processor: batch_size must be a positive integer')
        )
      end
    end

    context 'when batch_size is negative' do
      before do
        processor_job_config = double(batch_size: -5, max_iterations: 10, max_queue_depth: 1000)
        unique_user_metrics_config = double(processor_job: processor_job_config)
        allow(Settings).to receive(:unique_user_metrics).and_return(unique_user_metrics_config)
      end

      it 'does not raise (no retry) but logs configuration error' do
        expect { job.perform }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(
          'UUM Processor: Configuration error - job will not retry',
          hash_including(message: 'UUM Processor: batch_size must be a positive integer')
        )
      end
    end

    context 'when batch_size is a valid string' do
      before do
        processor_job_config = double(batch_size: '100', max_iterations: '10', max_queue_depth: '1000')
        unique_user_metrics_config = double(processor_job: processor_job_config)
        allow(Settings).to receive(:unique_user_metrics).and_return(unique_user_metrics_config)
      end

      it 'coerces string to integer and succeeds' do
        expect { job.perform }.not_to raise_error
        expect(Rails.logger).not_to have_received(:error)
      end
    end

    context 'when batch_size is a non-numeric string' do
      before do
        processor_job_config = double(batch_size: 'abc', max_iterations: 10, max_queue_depth: 1000)
        unique_user_metrics_config = double(processor_job: processor_job_config)
        allow(Settings).to receive(:unique_user_metrics).and_return(unique_user_metrics_config)
      end

      it 'does not raise (no retry) but logs configuration error' do
        expect { job.perform }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(
          'UUM Processor: Configuration error - job will not retry',
          hash_including(message: 'UUM Processor: batch_size must be a positive integer')
        )
      end
    end
  end
end
