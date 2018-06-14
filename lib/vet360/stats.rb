# frozen_string_literal: true

module Vet360
  class Stats
    FINAL_SUCCESS = %w[COMPLETED_SUCCESS COMPLETED_NO_CHANGES_DETECTED].freeze
    FINAL_FAILURE = %w[REJECTED COMPLETED_FAILURE].freeze

    class << self
      def exception_keys
        exceptions_file
          .dig('en', 'common', 'exceptions')
          .keys
          .select { |exception| exception.include? 'VET360_' }
          .sort
          .map(&:downcase)
      end

      def increment(*args)
        buckets = args.map(&:downcase).join('.')

        StatsD.increment("#{Vet360::Service::STATSD_KEY_PREFIX}.#{buckets}")
      end

      def increment_transaction_results(response, bucket1 = 'posts_and_puts')
        status = status_in(response)

        return unless final_status?(status)

        increment(bucket1, bucket_for(status))
      end

      private

      def exceptions_file
        config = Rails.root + 'config/locales/exceptions.en.yml'

        YAML.load_file(config)
      end

      def status_in(response)
        response&.body&.dig('tx_status')&.upcase
      end

      def final_status?(status)
        status.present? && success?(status) || failure?(status)
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
