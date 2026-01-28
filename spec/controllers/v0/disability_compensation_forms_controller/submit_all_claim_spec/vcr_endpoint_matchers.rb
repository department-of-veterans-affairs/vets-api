# frozen_string_literal: true

module SubmitAllClaimSpec
  class VcrEndpointMatchers
    class << self
      ##
      # Enables having one cassette per spec example. It does this by defining
      # different request matching logic per endpoint. That per-endpoint logic
      # is applicable across all spec examples.
      #
      def build # rubocop:disable Metrics/MethodLength
        new.tap do |memo|
          memo.add_entry do |entry|
            entry.match_endpoint_on do |meth, path|
              meth == :post && path.end_with?('/oauth2/claims/system/v1/token')
            end

            entry.match_requests_on = %i[
              method uri
            ]
          end

          memo.add_entry do |entry|
            entry.match_endpoint_on do |meth, path|
              meth == :post && path.end_with?('/526/synchronous')
            end

            body_matcher = proc do |in_flight, recorded|
              body_i = JSON.parse(in_flight.body)
              body_r = JSON.parse(recorded.body)

              ##
              # This lets us ignore `meta.transactionId` because it is different
              # for _every_ request.
              #
              body_i['data'] == body_r['data']
            end

            entry.match_requests_on = [
              :method, :uri, body_matcher
            ]
          end
        end
      end
    end

    def initialize
      @entries = []
    end

    def call(in_flight, recorded)
      meth = in_flight.method
      path = URI(in_flight.uri).path

      entry = @entries.find { |e| e.match_endpoint_on.call(meth, path) }
      entry ||= Entry::EVERYTHING

      logger = Logger.new(entry.match_requests_on, in_flight, recorded)
      logger.log_preamble

      entry.match_requests_on.all? do |matcher_name|
        matcher =
          if matcher_name.is_a?(Symbol)
            VCR.request_matchers[matcher_name].callable
          else
            matcher_name
          end

        matcher.call(in_flight, recorded).tap do |matched|
          logger.log_matched(matcher_name, matched)
        end
      end
    end

    def add_entry(&)
      @entries << Entry.new.tap(&)
    end

    class Entry
      attr_accessor :match_requests_on

      def match_endpoint_on(&block)
        @match_endpoint_on ||= block
      end

      EVERYTHING = new.tap do |matcher|
        matcher.match_endpoint_on { true }
        matcher.match_requests_on = %i[
          method uri headers body_as_json
        ]
      end
    end

    ##
    # This reimplements VCR logging internals to recover the most useful bits of
    # logging fidelity that would otherwise be lost due to `VcrEndpointMatchers`
    # wrapping a collection of `match_requests_on`s as a single callable.
    #
    # It uses internal VCR APIs, so it is susceptible to breakage, in which case
    # we no-op and warn.
    #
    class Logger
      include VCR::Logger::Mixin if defined?(VCR::Logger::Mixin)

      def initialize(request_matchers, in_flight, recorded)
        @request_matchers = request_matchers
        @in_flight = in_flight
        @recorded = recorded
      end

      def log_preamble
        message  = "Checking if #{in_flight_summary} "
        message += "matches #{recorded_summary} "
        message += "using #{@request_matchers.inspect}"

        log message, 1
      rescue => e
        warn_breakage(e)
      end

      def log_matched(matcher_name, matched)
        message  = "#{matcher_name} (#{matched ? 'matched' : 'did not match'}): "
        message += "current request #{in_flight_summary} "
        message += "vs #{recorded_summary}"

        log message, 2
      rescue => e
        warn_breakage(e)
      end

      private

      def in_flight_summary
        @in_flight_summary ||= request_summary(@in_flight, @request_matchers)
      end

      def recorded_summary
        @recorded_summary ||= request_summary(@recorded, @request_matchers)
      end

      def log_prefix
        @log_prefix ||= "[Cassette: '#{VCR.current_cassette.name}'] "
      end

      def warn_breakage(e)
        ##
        # Don't bother warning unless someone is trying to use the debug logger.
        #
        VCR.configuration.debug_logger and
          Rails.logger.warn(<<~MSG.squish)
            #{self.class} is broken due to changed VCR internals, with error: #{e}
          MSG
      end
    end
  end
end
