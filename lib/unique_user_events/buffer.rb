# frozen_string_literal: true

module UniqueUserEvents
  # Redis list buffer for asynchronous event processing
  #
  # This module provides a Redis list-based buffer for queuing unique user events
  # before batch processing by the UniqueUserMetricsProcessorJob. Events are pushed
  # to a Redis list (LPUSH) and atomically popped in batches (RPOP with count).
  #
  # Architecture:
  # - Uses Redis list for FIFO ordering and atomic operations
  # - Events are serialized as JSON for storage
  # - Batch pop uses Redis 6.2+ RPOP with count for atomic retrieval
  # - Designed for high throughput with minimal latency impact on API requests
  #
  # @example Push an event to the buffer
  #   UniqueUserEvents::Buffer.push(user_id: user.uuid, event_name: 'prescriptions_accessed')
  #
  # @example Peek and trim events for processing
  #   events = UniqueUserEvents::Buffer.peek_batch(500)
  #   # ... process events ...
  #   UniqueUserEvents::Buffer.trim_batch(events.size)
  #
  # @see MHV::UniqueUserMetricsProcessorJob for the batch processor
  module Buffer
    # Redis key for the event buffer list
    BUFFER_KEY = 'unique_user_metrics:event_buffer'

    # Push an event to the buffer
    #
    # @param user_id [String] UUID of the user
    # @param event_name [String] Name of the event
    # @return [Integer] Length of the list after push
    # @raise [ArgumentError] if user_id or event_name is blank
    def self.push(user_id:, event_name:)
      validate_inputs!(user_id, event_name)

      event = { user_id:, event_name:, buffered_at: Time.current.to_i }.to_json
      redis.lpush(BUFFER_KEY, event)
    rescue => e
      Rails.logger.error('UUM Buffer: Failed to push event', {
                           event_name:,
                           error: e.message
                         })
      raise
    end

    # Peek at a batch of events from the buffer without removing them
    #
    # Uses LRANGE to read events from the tail of the list (oldest events first).
    # This is part of the "peek-then-trim" pattern for safe event processing:
    # events remain in Redis until explicitly trimmed after successful processing.
    #
    # @param count [Integer] Maximum number of events to peek
    # @return [Array<Hash>] Array of event hashes with :user_id and :event_name keys
    def self.peek_batch(count)
      return [] if count <= 0

      # LRANGE with negative indices: -count to -1 gets the last `count` elements
      # These are the oldest events (pushed via LPUSH, so tail = oldest)
      raw_events = redis.lrange(BUFFER_KEY, -count, -1)
      return [] if raw_events.blank?

      raw_events.filter_map do |raw_event|
        parse_event(raw_event)
      end
    rescue => e
      Rails.logger.error('UUM Buffer: Failed to peek batch', { count:, error: e.message })
      []
    end

    # Trim processed events from the buffer after successful processing
    #
    # Uses LTRIM to remove events from the tail of the list.
    # Only call this after successful processing to avoid data loss.
    #
    # @param count [Integer] Number of events to trim from the tail
    # @return [Boolean] true if trim was successful
    def self.trim_batch(count)
      return true if count <= 0

      # LTRIM keeps elements from index 0 to -(count + 1), removing the last `count` elements.
      # When count >= buffer size, -(count + 1) resolves to before index 0, which empties the list.
      # This is the desired behavior - we want to remove all processed events.
      redis.ltrim(BUFFER_KEY, 0, -(count + 1))
      true
    rescue => e
      Rails.logger.error('UUM Buffer: Failed to trim batch', { count:, error: e.message })
      false
    end

    # Get the number of pending events in the buffer
    #
    # @return [Integer] Number of events waiting to be processed
    def self.pending_count
      redis.llen(BUFFER_KEY)
    rescue => e
      Rails.logger.error('UUM Buffer: Failed to get pending count', { error: e.message })
      0
    end

    # Clear all events from the buffer (use with caution!)
    #
    # This is primarily for testing purposes.
    #
    # @return [Integer] Number of events that were cleared
    def self.clear!
      count = pending_count
      redis.del(BUFFER_KEY)
      count
    end

    # Private methods
    class << self
      private

      # Get the Redis connection
      #
      # @return [Redis] Redis connection instance
      def redis
        $redis
      end

      # Validate input parameters
      #
      # @param user_id [String] UUID of the user
      # @param event_name [String] Name of the event
      # @raise [ArgumentError] if inputs are invalid
      def validate_inputs!(user_id, event_name)
        raise ArgumentError, 'user_id is required' if user_id.blank?
        raise ArgumentError, 'event_name is required' if event_name.blank?
        raise ArgumentError, 'event_name must be 50 characters or less' if event_name.length > 50
      end

      # Parse a raw JSON event string into a hash
      #
      # @param raw_event [String] JSON-encoded event string
      # @return [Hash, nil] Parsed event hash or nil if parsing fails
      def parse_event(raw_event)
        parsed = JSON.parse(raw_event, symbolize_names: true)
        # Return only the fields needed by the processor
        { user_id: parsed[:user_id], event_name: parsed[:event_name] }
      rescue JSON::ParserError => e
        Rails.logger.error('UUM Buffer: Failed to parse event', { raw_event:, error: e.message })
        nil
      end
    end
  end
end
