# frozen_string_literal: true

require 'va_profile/service'

module VAProfile
  class Stats
    STATSD_KEY_PREFIX = 'api.va_profile'
    FINAL_SUCCESS = %w[COMPLETED_SUCCESS COMPLETED_NO_CHANGES_DETECTED].freeze
    FINAL_FAILURE = %w[REJECTED COMPLETED_FAILURE].freeze

    class << self
      # Triggers the associated StatsD.increment method for the VAProfile buckets that are
      # initialized in the config/initializers/statsd.rb file.
      #
      # @param *args [String] A variable number of string arguments. Each one represents
      #   a bucket in StatsD.  For example passing in ('policy', 'success') would increment
      #   the 'api.va_profile.policy.success' bucket
      #
      def increment(*args)
        buckets = args.map(&:downcase).join('.')

        StatsD.increment("#{STATSD_KEY_PREFIX}.#{buckets}")
      end

      # If the passed response contains a transaction status that is in one of the final
      # success or failure states, it increments the associated StatsD bucket.
      #
      # @param response [FaradayObject] The raw response from the Faraday HTTP call
      # @param bucket1 [String] The VAProfile bucket to increment.  This bucket must
      #   already be initialized in config/initializers/statsd.rb.
      # @return [Nil] Returns nil only if the passed transaction status is not a final status
      #
      def increment_transaction_results(response, bucket1 = 'posts_and_puts')
        status = status_in(response)

        return unless final_status?(status)

        increment(bucket1, bucket_for(status))
      end

      # Increments the associated StatsD bucket with the passed in exception error key.
      #
      # @param key [String] A VAProfile exception key from the locales/exceptions file
      #   For example, 'VET360_ADDR133'.
      #
      def increment_exception(key)
        StatsD.increment("#{STATSD_KEY_PREFIX}.exceptions", tags: ["exception:#{key.downcase}"])
      end

      private

      def status_in(response)
        response&.body&.dig('tx_status')&.upcase
      end

      def final_status?(status)
        (status.present? && success?(status)) || failure?(status)
      end

      def success?(status)
        FINAL_SUCCESS.include? status
      end

      def failure?(status)
        FINAL_FAILURE.include? status
      end

      def bucket_for(status)
        if success?(status)
          'success'
        elsif failure?(status)
          'failure'
        end
      end
    end
  end
end
