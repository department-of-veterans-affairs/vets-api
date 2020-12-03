# frozen_string_literal: true

module Mobile
  module V0
    module Profile
      # Connect's to VAMF's VA appointment and Community Care appointment services.
      #
      # @example create a new instance and call the get_appointment's endpoint
      #   service = Mobile::V0::Appointments::Service.new(user)
      #   response = service.get_appointments(start_date, end_date)
      #
      class Service
        # Given a date range returns a list of VA appointments, including video appointments, and
        # a list of Community Care appointments. The calls are made in parallel using the Typhoeus
        # HTTP adapter.
        #
        # @start_date DateTime the start of the date range
        # @end_date DateTime the end of the date range
        # @use_cache Boolean whether or not to use the appointments cache within VAMF
        #
        # @return Hash two lists of appointments, va and cc (community care)
        #
        def update(resource:, params:, method: 'post')
        
        end
        
        private

        def with_exponential_backoff
          start = Time.now.utc.to_i
          tries = 0
          begin
            yield
          rescue ArgumentError => e
            tries += 1
            puts tries
            now = Time.now.utc.to_i
            elapsed = now - start
            raise "Giving up" if elapsed >= 10
            # sleep with exponential backoff,
            # retry at most (depending on service latency) 10 times over 10 seconds
            sleep Float(2.75 ** tries) / 1000
            retry
          end
        end
      end
    end
  end
end
