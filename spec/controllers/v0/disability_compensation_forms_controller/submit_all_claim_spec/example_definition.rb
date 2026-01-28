# frozen_string_literal: true

module SubmitAllClaimSpec
  class ExampleDefinition
    ##
    # Registers or returns the setup block for the example. Use it to control
    # internal behavior that shapes the scenario under test.
    #
    # @yield [] Runs in the example context before the request.
    # @return [Proc, nil]
    #
    def before(&block)
      @before ||= block
    end

    ##
    # Registers or returns the assertion block for the example. Use it to make
    # assertions about persisted side effects, particularly around job status
    # records.
    #
    # @yieldparam submission [Form526Submission] the persisted submission record.
    # @return [Proc, nil]
    #
    def assert(&block)
      @assert ||= block
    end

    attr_accessor(
      :payload_fixture,
      :user_icn
    )

    class << self
      def build!
        new.tap do |definition|
          yield(definition)

          definition.payload_fixture or
            raise ArgumentError, <<~MSG.squish
              Must supply a `definition.payload_fixture` such that
              `\#{PAYLOAD_FIXTURE_PATH_PREFIX}/\#{definition.payload_fixture}.json`
              contains an example form 526 JSON payload from the frontend.
            MSG

          definition.user_icn or
            raise ArgumentError, <<~MSG.squish
              Must supply `definition.user_icn` with an ICN that exists in
              Lighthouse API's sandbox environment. Such users are documented at
              `https://developer.va.gov/explore/api/benefits-claims/test-users`.
            MSG
        end
      end
    end
  end
end
