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

    # StatsD metrics keys
    STATSD_PREFIX = 'uum.processor_job'

    # Cache configuration (matches MHVMetricsUniqueUserEvent)
    CACHE_NAMESPACE = 'unique_user_metrics'
    CACHE_TTL = REDIS_CONFIG[:unique_user_metrics][:each_ttl]

    # Job configuration (from Settings, validated at class load time)
    # Values require restart to change; raises error if missing or invalid
    def self.fetch_positive_integer_setting(setting_name)
      raw_value = Settings.unique_user_metrics&.processor_job&.send(setting_name)
      raise ArgumentError, "UUM Processor: #{setting_name} is missing from Settings" if raw_value.blank?

      value = raw_value.to_i
      raise ArgumentError, "UUM Processor: #{setting_name} must be a positive integer" unless value.positive?

      value
    end
    private_class_method :fetch_positive_integer_setting

    BATCH_SIZE = fetch_positive_integer_setting(:batch_size)
    MAX_ITERATIONS = fetch_positive_integer_setting(:max_iterations)
    MAX_QUEUE_DEPTH = fetch_positive_integer_setting(:max_queue_depth)

    def perform
      job_start_time = Time.current

      # Early check for queue backlog - alert immediately if overflow detected
      check_queue_overflow(UniqueUserEvents::Buffer.pending_count)

      # Process all batches and collect metrics
      iterations, total_events_processed, total_db_queries, total_db_inserts = process_all_batches

      # Record aggregate metrics for the entire job run
      record_job_summary(job_start_time, iterations, total_events_processed, total_db_queries, total_db_inserts)
    rescue => e
      handle_job_failure(e, total_events_processed || 0, iterations || 0)
      raise # Re-raise to trigger Sidekiq retry
    end

    private

    # Process batches in a loop until queue is empty or max iterations reached
    #
    # @return [Array<Integer>] [iterations, total_events_processed, total_db_queries, total_db_inserts]
    def process_all_batches
      iterations = 0
      total_events_processed = 0
      total_db_queries = 0
      total_db_inserts = 0

      loop do
        # Check safeguard before each iteration
        break if iterations >= MAX_ITERATIONS

        # PEEK - Read events without removing them from buffer
        events = peek_events_from_buffer
        break if events.empty?

        # Process this batch (dedup, cache check, insert, cache write, StatsD)
        db_queries, inserted_count = process_events(events)

        # TRIM - Remove events only after successful processing
        trim_processed_events(events.size)

        iterations += 1
        total_events_processed += events.size
        total_db_queries += db_queries
        total_db_inserts += inserted_count
      end

      [iterations, total_events_processed, total_db_queries, total_db_inserts]
    end

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

    # Handle job failure with logging
    #
    # @param exception [Exception] The exception that caused the failure
    # @param total_events [Integer] Total events processed before failure
    # @param iterations [Integer] Number of completed iterations before failure
    def handle_job_failure(exception, total_events, iterations)
      events_at_risk = UniqueUserEvents::Buffer.pending_count

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
    # @param total_db_queries [Integer] Total events sent to database (cache misses)
    # @param total_db_inserts [Integer] Total events inserted to database (new unique events)
    def record_job_summary(job_start_time, iterations, total_events, total_db_queries, total_db_inserts)
      return if iterations.zero? # No work done, skip metrics

      duration_ms = ((Time.current - job_start_time) * 1000).round
      queue_depth = UniqueUserEvents::Buffer.pending_count

      StatsD.gauge("#{STATSD_PREFIX}.iterations", iterations)
      StatsD.gauge("#{STATSD_PREFIX}.total_events_processed", total_events)
      StatsD.gauge("#{STATSD_PREFIX}.total_db_queries", total_db_queries)
      StatsD.gauge("#{STATSD_PREFIX}.total_db_inserts", total_db_inserts)
      StatsD.gauge("#{STATSD_PREFIX}.queue_depth", queue_depth)
      StatsD.histogram("#{STATSD_PREFIX}.job_duration_ms", duration_ms)

      Rails.logger.debug('UUM Processor: Job completed', {
                           iterations:,
                           total_events_processed: total_events,
                           total_db_queries:,
                           total_db_inserts:,
                           duration_ms:,
                           queue_depth:
                         })
    end

    # Process a single batch of events
    #
    # @param events [Array<Hash>] Raw events from buffer
    # @return [Array<Integer>] [db_queries (cache misses), db_inserts (new events)]
    def process_events(events)
      # Step 1: Deduplicate in-memory
      unique_events = deduplicate_events(events)

      # Step 2: Filter out events already in cache
      uncached_events = filter_cached_events(unique_events)
      return [0, 0] if uncached_events.empty?

      # Step 3: Bulk insert to database (uncached_events = cache misses = db queries)
      inserted_events = bulk_insert_events(uncached_events)

      # Step 4: Cache ALL events sent to DB
      # This prevents repeated DB lookups when cache expires but record exists
      cache_events(uncached_events)

      # Step 5: Increment StatsD for new events
      increment_statsd_counters(inserted_events)

      # Return counts: cache misses (sent to DB) and actual inserts (new unique events)
      [uncached_events.size, inserted_events.size]
    end

    # Deduplicate events
    #
    # @param events [Array<Hash>] Raw events with possible duplicates
    # @return [Array<Hash>] Unique events (first occurrence wins)
    def deduplicate_events(events)
      events.uniq { |event| [event[:user_id], event[:event_name]] }
    end

    # Filter out events that are already in the Redis cache and refresh their TTL
    #
    # @param events [Array<Hash>] Unique events to check
    # @return [Array<Hash>] Events not found in cache
    def filter_cached_events(events)
      return events if events.empty?

      # Generate cache keys for all events
      cache_keys = events.map { |e| MHVMetricsUniqueUserEvent.generate_cache_key(e[:user_id], e[:event_name]) }

      # Batch read from cache
      cached_results = Rails.cache.read_multi(*cache_keys, namespace: CACHE_NAMESPACE)

      # Refresh TTL for cached events (keeps active users in cache longer)
      Rails.cache.write_multi(cached_results, namespace: CACHE_NAMESPACE, expires_in: CACHE_TTL) if cached_results.any?

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

    # Cache events using write_multi
    #
    # @param events [Array<Hash>] Events to cache
    def cache_events(events)
      return if events.empty?

      # Build hash for write_multi: { cache_key => true }
      cache_entries = events.each_with_object({}) do |event, hash|
        key = MHVMetricsUniqueUserEvent.generate_cache_key(event[:user_id], event[:event_name])
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

    # Check if queue depth exceeds threshold and alert if so
    #
    # @param queue_depth [Integer] Current queue depth
    def check_queue_overflow(queue_depth)
      return unless queue_depth > MAX_QUEUE_DEPTH

      Rails.logger.warn('UUM Processor: Queue depth exceeds threshold', {
                          queue_depth:,
                          max_queue_depth: MAX_QUEUE_DEPTH
                        })
    end
  end
end
