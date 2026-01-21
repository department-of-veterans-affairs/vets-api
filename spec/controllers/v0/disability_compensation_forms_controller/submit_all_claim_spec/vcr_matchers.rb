# frozen_string_literal: true

module SubmitAllClaimSpec
  class VcrMatchers
    class << self
      ##
      # Enables having one cassette per spec example. It does this by defining
      # different request matching logic per endpoint. That per-endpoint logic
      # is applicable across all spec examples.
      #
      def build # rubocop:disable Metrics/MethodLength
        new.tap do |matchers|
          matchers.register do |matcher|
            matcher.condition do |meth, path|
              meth == :post && path.end_with?('/oauth2/claims/system/v1/token')
            end

            matcher.match_requests_on = %i[
              method uri
            ]
          end

          matchers.register do |matcher|
            matcher.condition do |meth, path|
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

            matcher.match_requests_on = [
              :method, :uri, body_matcher
            ]
          end
        end
      end
    end

    def call(in_flight, recorded)
      meth = in_flight.method
      path = URI(in_flight.uri).path

      matcher = matchers.find { |m| m.condition.call(meth, path) }
      matcher ||= Matcher::EVERYTHING

      on = matcher.match_requests_on
      matches?(in_flight, recorded, on:)
    end

    def register(&)
      matchers << Matcher.new.tap(&)
    end

    private

    def matchers
      @matchers ||= []
    end

    def matches?(in_flight, recorded, on:)
      on.all? do |o|
        o.is_a?(Symbol) and o = VCR.request_matchers[o].callable
        o.call(in_flight, recorded)
      end
    end

    class Matcher
      def condition(&block) = @condition ||= block
      attr_accessor :match_requests_on

      EVERYTHING = new.tap do |matcher|
        matcher.condition { true }
        matcher.match_requests_on = %i[
          method uri headers body_as_json
        ]
      end
    end
  end
end
