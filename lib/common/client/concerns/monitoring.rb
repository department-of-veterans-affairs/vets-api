# frozen_string_literal: true

module Common
  module Client
    module Concerns
      module Monitoring
        extend ActiveSupport::Concern

        def with_monitoring(trace_location = 1)
          caller = caller_locations(trace_location, 1)[0].label
          yield
        rescue => e
          increment_failure(caller, e)
          raise e
        ensure
          increment_total(caller)
        end

        private

        def increment_total(caller)
          increment("#{self.class::STATSD_KEY_PREFIX}.#{caller}.total")
        end

        def increment_failure(caller, error)
          clean_error_class = error.class.to_s.gsub(':', '')
          tags = ["error:#{clean_error_class}"]
          tags << "status:#{error.status}" if error.try(:status)

          increment("#{self.class::STATSD_KEY_PREFIX}.#{caller}.fail", tags)
        end

        def increment(key, tags = nil)
          StatsDMetric.new(key:).save
          if tags.blank?
            StatsD.increment(key)
          else
            StatsD.increment(key, tags:)
          end
        end
      end
    end
  end
end
