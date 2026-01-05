# frozen_string_literal: true

module MHV
  # Batch processor job for Unique User Metrics (UUM) events
  #
  # This job consumes events from a Redis buffer and batch-inserts them into the database.
  # It runs via Sidekiq Enterprise periodic jobs and processes events in batches
  # to reduce database load and improve API response times.
  #
  # Architecture (Peek-then-Trim Pattern with Loop):
  # The job loops until the queue is empty (with safeguards to prevent runaway execution):
  #
  # Per iteration:
  # 1. PEEK: Read batch of events from Redis list without removing (LRANGE)
  # 2. Deduplicate in-memory
  # 3. Batch check Redis cache for existing events (read_multi)
  # 4. Bulk insert new events (insert_all with unique_by)
  # 5. Batch update cache for inserted events (write_multi)
  # 6. Increment StatsD counters for new events
  # 7. TRIM: Remove processed events only after successful processing (LTRIM)
  # 8. Repeat until queue empty or safeguard limit reached
  #
  # The peek-then-trim pattern ensures events remain in Redis until processing succeeds.
  # If the job fails mid-processing, events are still in the buffer for the next retry.
  #
  # @see UniqueUserEvents::Buffer for the buffer API
  # @see https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/products/health-care/digital-health-modernization/mhv-to-va.gov/metrics-performance-monitoring/Unique-Users/2025-08-unique-user-metrics.md#re-architecture-asynchronous-batch-processing-december-2025
  class UniqueUserMetricsProcessorJob
    include Sidekiq::Job

    # Prevent duplicate job execution (matches 10-minute schedule interval)
    sidekiq_options retry: 3, unique_for: 10.minutes

    # Configuration from Settings (AWS Parameter Store)
    # These must be configured in settings.yml - job will fail fast if missing
    BATCH_SIZE = Settings.unique_user_metrics&.processor_job&.batch_size
    MAX_ITERATIONS = Settings.unique_user_metrics&.processor_job&.max_iterations
    MAX_QUEUE_DEPTH = Settings.unique_user_metrics&.processor_job&.max_queue_depth

    unless BATCH_SIZE.is_a?(Integer) && BATCH_SIZE.positive?
      raise 'unique_user_metrics.processor_job.batch_size must be a positive integer'
    end
    unless MAX_ITERATIONS.is_a?(Integer) && MAX_ITERATIONS.positive?
      raise 'unique_user_metrics.processor_job.max_iterations must be a positive integer'
    end
    unless MAX_QUEUE_DEPTH.is_a?(Integer) && MAX_QUEUE_DEPTH.positive?
      raise 'unique_user_metrics.processor_job.max_queue_depth must be a positive integer'
    end

    # StatsD metrics keys
    STATSD_PREFIX = 'uum.processor_job'

    # Cache configuration (matches MHVMetricsUniqueUserEvent)
    CACHE_NAMESPACE = 'unique_user_metrics'
    CACHE_TTL = REDIS_CONFIG[:unique_user_metrics][:each_ttl]

    def perform
      job_start_time = Time.current
      iterations = 0
      total_events_processed = 0

      loop do
        # Check safeguard before each iteration
        break if iterations >= MAX_ITERATIONS

        # PEEK - Read events without removing them from buffer
        events = peek_events_from_buffer
        break if events.empty?

        iteration_start_time = Time.current

        # Process this batch (dedup, cache check, insert, cache write, StatsD)
        process_events(events, iteration_start_time)

        # TRIM - Remove events only after successful processing
        trim_processed_events(events.size)

        iterations += 1
        total_events_processed += events.size
      end

      # Record aggregate metrics for the entire job run
      record_job_summary(job_start_time, iterations, total_events_processed)
    rescue => e
      handle_job_failure(e, total_events_processed, iterations)
      raise # Re-raise to trigger Sidekiq retry
    end

    private

    # Peek at a batch of events from the Redis buffer without removing them
    #
    # @return [Array<Hash>] Array of event hashes with :user_id and :event_name keys
    def peek_events_from_buffer
      UniqueUserEvents::Buffer.peek_batch(BATCH_SIZE)
    end

    # Trim processed events from the buffer after successful processing
    #
    # @param count [Integer] Number of events to remove from buffer
    def trim_processed_events(count)
      UniqueUserEvents::Buffer.trim_batch(count)
    end

    # Handle job failure with detailed metrics and logging
    #
    # @param exception [Exception] The exception that caused the failure
    # @param total_events [Integer] Total events processed before failure
    # @param iterations [Integer] Number of completed iterations before failure
    def handle_job_failure(exception, total_events, iterations)
      # Track failure with error class for debugging
      StatsD.increment("#{STATSD_PREFIX}.failure", tags: ["error_class:#{exception.class.name}"])

      # Track events at risk (events in current batch that may not have been trimmed)
      events_at_risk = UniqueUserEvents::Buffer.pending_count
      StatsD.gauge("#{STATSD_PREFIX}.events_at_risk", events_at_risk)

      Rails.logger.error('UUM Processor: Job failed', {
                           error: exception.class.name,
                           message: exception.message,
                           events_at_risk:,
                           total_events_processed: total_events,
                           iterations_completed: iterations,
                           queue_depth: events_at_risk,
                           backtrace: exception.backtrace.first(5)
                         })
    end

    # Record summary metrics for the entire job run
    #
    # @param job_start_time [Time] When the job started
    # @param iterations [Integer] Number of batch iterations completed
    # @param total_events [Integer] Total events processed across all iterations
    def record_job_summary(job_start_time, iterations, total_events)
      return if iterations.zero? # No work done, skip metrics

      duration_ms = ((Time.current - job_start_time) * 1000).round
      queue_depth = UniqueUserEvents::Buffer.pending_count

      StatsD.gauge("#{STATSD_PREFIX}.iterations", iterations)
      StatsD.gauge("#{STATSD_PREFIX}.total_events_processed", total_events)
      StatsD.gauge("#{STATSD_PREFIX}.queue_depth", queue_depth)
      StatsD.histogram("#{STATSD_PREFIX}.job_duration_ms", duration_ms)

      Rails.logger.debug('UUM Processor: Job completed', {
                           iterations:,
                           total_events_processed: total_events,
                           duration_ms:,
                           queue_depth:
                         })

      check_queue_overflow(queue_depth)
    end

    # Process a single batch of events
    #
    # @param events [Array<Hash>] Raw events from buffer
    # @param iteration_start_time [Time] Iteration start time (unused, kept for signature compatibility)
    def process_events(events, _iteration_start_time = nil)
      # Step 1: Deduplicate in-memory
      unique_events = deduplicate_events(events)

      # Step 2: Filter out events already in cache
      uncached_events = filter_cached_events(unique_events)
      return if uncached_events.empty?

      # Step 3: Bulk insert to database
      inserted_events = bulk_insert_events(uncached_events)

      # Step 4: Update cache for inserted events
      cache_inserted_events(inserted_events)

      # Step 5: Increment StatsD for new events
      increment_statsd_counters(inserted_events)
    end

    # Deduplicate events
    #
    # @param events [Array<Hash>] Raw events with possible duplicates
    # @return [Array<Hash>] Unique events (first occurrence wins)
    def deduplicate_events(events)
      events.uniq { |event| [event[:user_id], event[:event_name]] }
    end

    # Filter out events that are already in the Redis cache
    #
    # @param events [Array<Hash>] Unique events to check
    # @return [Array<Hash>] Events not found in cache
    def filter_cached_events(events)
      return events if events.empty?

      # Generate cache keys for all events
      cache_keys = events.map { |e| generate_cache_key(e[:user_id], e[:event_name]) }

      # Batch read from cache
      cached_results = Rails.cache.read_multi(*cache_keys, namespace: CACHE_NAMESPACE)

      # Filter out events that are cached
      events.reject.with_index do |_event, index|
        cached_results.key?(cache_keys[index])
      end
    end

    # Bulk insert events to database using insert_all
    #
    # @param events [Array<Hash>] Events to insert
    # @return [Array<Hash>] Events that were actually inserted (new records)
    def bulk_insert_events(events)
      return [] if events.empty?

      # Prepare records for insert_all
      records = events.map do |event|
        {
          user_id: event[:user_id],
          event_name: event[:event_name],
          created_at: Time.current
        }
      end

      # rubocop:disable Rails/SkipsModelValidations
      # Validations are handled at buffer push time; insert_all is safe here
      result = MHVMetricsUniqueUserEvent.insert_all(
        records,
        unique_by: %i[user_id event_name],
        returning: %i[user_id event_name]
      )
      # rubocop:enable Rails/SkipsModelValidations

      # Return only the events that were actually inserted
      result.rows.map do |row|
        { user_id: row[0], event_name: row[1] }
      end
    end

    # Cache inserted events using write_multi
    #
    # @param events [Array<Hash>] Events that were inserted
    def cache_inserted_events(events)
      return if events.empty?

      # Build hash for write_multi: { cache_key => true }
      cache_entries = events.each_with_object({}) do |event, hash|
        key = generate_cache_key(event[:user_id], event[:event_name])
        hash[key] = true
      end

      Rails.cache.write_multi(cache_entries, namespace: CACHE_NAMESPACE, expires_in: CACHE_TTL)
    end

    # Increment StatsD counters for new events
    #
    # @param events [Array<Hash>] Events that were newly inserted
    def increment_statsd_counters(events)
      # Group events by event_name for efficient counter increments
      events.group_by { |e| e[:event_name] }.each do |event_name, grouped_events|
        StatsD.increment(
          'uum.unique_user_metrics.event',
          grouped_events.size,
          tags: ["event_name:#{event_name}"]
        )
      end
    end

    # Generate consistent cache key for user/event combination
    #
    # @param user_id [String] UUID of the user
    # @param event_name [String] Name of the event
    # @return [String] Cache key
    def generate_cache_key(user_id, event_name)
      "#{user_id}:#{event_name}"
    end

    # Check if queue depth exceeds threshold and alert if so
    #
    # @param queue_depth [Integer] Current queue depth
    def check_queue_overflow(queue_depth)
      return unless queue_depth > MAX_QUEUE_DEPTH

      StatsD.increment("#{STATSD_PREFIX}.queue_overflow")
      Rails.logger.warn('UUM Processor: Queue depth exceeds threshold', {
                          queue_depth:,
                          max_queue_depth: MAX_QUEUE_DEPTH
                        })
    end
  end
end
