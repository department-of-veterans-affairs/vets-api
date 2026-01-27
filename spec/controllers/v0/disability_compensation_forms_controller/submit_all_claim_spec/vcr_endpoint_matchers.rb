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

      entry.match_requests_on.all? do |matcher|
        matcher.is_a?(Symbol) and matcher = VCR.request_matchers[matcher].callable
        matcher.call(in_flight, recorded)
      end
    end

    def add_entry(&)
      @entries << Entry.new.tap(&)
    end

    class Entry
      def match_endpoint_on(&block) = @match_endpoint_on ||= block
      attr_accessor :match_requests_on

      EVERYTHING = new.tap do |matcher|
        matcher.match_endpoint_on { true }
        matcher.match_requests_on = %i[
          method uri headers body_as_json
        ]
      end
    end
  end
end
